-- Converts older append-only leaderboard projects to one-row-per-player best scores.
-- Run this once on an existing project that already used the older leaderboard schema.

alter table public.family_leaderboard
    add column if not exists updated_at timestamptz not null default now();

with ranked_rows as (
    select
        id,
        row_number() over (
            partition by family_id, player_id
            order by score desc, created_at asc, id asc
        ) as row_rank,
        first_value(created_at) over (
            partition by family_id, player_id
            order by score desc, created_at asc, id asc
        ) as best_achieved_at
    from public.family_leaderboard
)
update public.family_leaderboard as leaderboard_row
set updated_at = ranked_rows.best_achieved_at
from ranked_rows
where leaderboard_row.id = ranked_rows.id
  and ranked_rows.row_rank = 1
  and leaderboard_row.updated_at is distinct from ranked_rows.best_achieved_at;

with ranked_rows as (
    select
        id,
        row_number() over (
            partition by family_id, player_id
            order by score desc, created_at asc, id asc
        ) as row_rank
    from public.family_leaderboard
)
delete from public.family_leaderboard
where id in (
    select id
    from ranked_rows
    where row_rank > 1
);

drop index if exists family_leaderboard_family_player_idx;
create unique index if not exists family_leaderboard_family_player_uidx
on public.family_leaderboard (family_id, player_id);

drop index if exists family_leaderboard_family_score_idx;
create index if not exists family_leaderboard_family_score_idx
on public.family_leaderboard (family_id, score desc, updated_at asc, created_at asc);

drop trigger if exists family_leaderboard_touch_updated_at on public.family_leaderboard;

create trigger family_leaderboard_touch_updated_at
before update on public.family_leaderboard
for each row
execute function public.touch_updated_at();

create or replace function public.enforce_unique_leaderboard_names()
returns trigger
language plpgsql
as $$
declare
    conflicting_player_name text;
begin
    new.name := trim(new.name);

    if tg_op = 'UPDATE' then
        new.name := old.name;
        return new;
    end if;

    select name
    into conflicting_player_name
    from public.family_leaderboard
    where family_id = new.family_id
      and player_id <> new.player_id
      and public.normalize_leaderboard_name(name) = public.normalize_leaderboard_name(new.name)
    order by updated_at asc, created_at asc, id asc
    limit 1;

    if conflicting_player_name is not null then
        raise exception using
            errcode = '23505',
            message = 'That player name is already taken. Please choose another.';
    end if;

    return new;
end;
$$;

drop trigger if exists family_leaderboard_name_guard on public.family_leaderboard;

create trigger family_leaderboard_name_guard
before insert or update on public.family_leaderboard
for each row
execute function public.enforce_unique_leaderboard_names();

create or replace function public.notify_family_when_score_beaten()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'UPDATE' and new.score <= old.score then
        return new;
    end if;

    insert into public.family_notifications (
        family_id,
        target_player_id,
        challenger_name,
        challenger_score,
        beaten_score
    )
    select
        new.family_id,
        other_scores.player_id,
        new.name,
        new.score,
        other_scores.score
    from public.family_leaderboard as other_scores
    where other_scores.family_id = new.family_id
      and other_scores.player_id <> new.player_id
      and new.score > other_scores.score;

    return new;
end;
$$;

drop trigger if exists family_score_beaten_notification on public.family_leaderboard;

create trigger family_score_beaten_notification
after insert or update on public.family_leaderboard
for each row
execute function public.notify_family_when_score_beaten();

create or replace function public.submit_family_score(
    p_family_id text,
    p_player_id text,
    p_name text,
    p_score integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    leaderboard_row public.family_leaderboard%rowtype;
    score_improved boolean := false;
begin
    if p_family_id is null or trim(p_family_id) = '' then
        raise exception 'Family id is required.';
    end if;

    if p_player_id is null or trim(p_player_id) = '' then
        raise exception 'Player id is required.';
    end if;

    p_name := trim(coalesce(p_name, ''));
    if char_length(p_name) < 1 or char_length(p_name) > 12 then
        raise exception 'Player name must be between 1 and 12 characters.';
    end if;

    if p_score is null or p_score < 0 then
        raise exception 'Score must be zero or higher.';
    end if;

    insert into public.family_leaderboard (
        family_id,
        player_id,
        name,
        score
    )
    values (
        p_family_id,
        p_player_id,
        p_name,
        p_score
    )
    on conflict (family_id, player_id) do update
    set score = excluded.score
    where excluded.score > public.family_leaderboard.score
    returning *
    into leaderboard_row;

    if found then
        score_improved := true;
    else
        select *
        into leaderboard_row
        from public.family_leaderboard
        where family_id = p_family_id
          and player_id = p_player_id
        limit 1;
    end if;

    return jsonb_build_object(
        'player_id', leaderboard_row.player_id,
        'name', leaderboard_row.name,
        'best_score', leaderboard_row.score,
        'score_improved', score_improved,
        'created_at', leaderboard_row.created_at,
        'updated_at', leaderboard_row.updated_at
    );
end;
$$;

grant execute on function public.submit_family_score(text, text, text, integer) to anon, authenticated;

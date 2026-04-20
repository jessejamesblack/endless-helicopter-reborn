create table if not exists public.player_account_links (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  family_id text not null,
  player_id text not null,
  email text,
  created_at timestamptz not null default timezone('utc', now()),
  linked_at timestamptz not null default timezone('utc', now()),
  last_sign_in_at timestamptz not null default timezone('utc', now())
);

alter table public.player_account_links
  add column if not exists family_id text,
  add column if not exists player_id text,
  add column if not exists email text,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists linked_at timestamptz not null default timezone('utc', now()),
  add column if not exists last_sign_in_at timestamptz not null default timezone('utc', now());

update public.player_account_links
set family_id = coalesce(nullif(family_id, ''), 'global')
where family_id is null or family_id = '';

alter table public.player_account_links
  alter column family_id set not null,
  alter column player_id set not null,
  alter column created_at set not null,
  alter column linked_at set not null,
  alter column last_sign_in_at set not null;

create unique index if not exists player_account_links_family_player_id_key
  on public.player_account_links (family_id, player_id);

create index if not exists player_account_links_player_id_idx
  on public.player_account_links (player_id);

alter table public.player_account_links enable row level security;

revoke all on table public.player_account_links from public;
revoke all on table public.player_account_links from anon;
revoke all on table public.player_account_links from authenticated;

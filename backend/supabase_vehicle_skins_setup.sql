alter table public.family_player_profiles
add column if not exists unlocked_vehicles jsonb not null default '["default_scout"]'::jsonb,
add column if not exists equipped_vehicle_id text not null default 'default_scout',
add column if not exists unlocked_vehicle_skins jsonb not null default '{}'::jsonb,
add column if not exists equipped_vehicle_skins jsonb not null default '{}'::jsonb,
add column if not exists vehicle_skin_progress jsonb not null default '{}'::jsonb,
add column if not exists global_skin_unlocks jsonb not null default '[]'::jsonb,
add column if not exists best_score_milestones jsonb not null default '{}'::jsonb,
add column if not exists seen_vehicle_lore jsonb not null default '[]'::jsonb,
add column if not exists seen_skin_lore jsonb not null default '[]'::jsonb,
add column if not exists vehicle_catalog_version integer not null default 1;

alter table public.family_leaderboard
add column if not exists equipped_vehicle_id text,
add column if not exists equipped_vehicle_skin_id text;

alter table public.family_run_history
add column if not exists equipped_vehicle_id text,
add column if not exists equipped_vehicle_skin_id text;

update public.family_player_profiles
set
	unlocked_vehicles = coalesce(profile_summary->'unlocked_vehicles', unlocked_skins, '["default_scout"]'::jsonb),
	equipped_vehicle_id = coalesce(nullif(profile_summary->>'equipped_vehicle_id', ''), equipped_skin_id, 'default_scout'),
	unlocked_vehicle_skins = coalesce(profile_summary->'unlocked_vehicle_skins', '{}'::jsonb),
	equipped_vehicle_skins = coalesce(profile_summary->'equipped_vehicle_skins', '{}'::jsonb),
	vehicle_skin_progress = coalesce(profile_summary->'vehicle_skin_progress', '{}'::jsonb),
	global_skin_unlocks = coalesce(profile_summary->'global_skin_unlocks', '[]'::jsonb),
	best_score_milestones = coalesce(profile_summary->'best_score_milestones', '{}'::jsonb),
	seen_vehicle_lore = coalesce(profile_summary->'seen_vehicle_lore', '[]'::jsonb),
	seen_skin_lore = coalesce(profile_summary->'seen_skin_lore', '[]'::jsonb),
	vehicle_catalog_version = greatest(coalesce((profile_summary->>'vehicle_catalog_version')::integer, 1), 1)
where profile_summary <> '{}'::jsonb;

update public.family_leaderboard
set
	equipped_vehicle_id = coalesce(nullif(run_summary->>'equipped_vehicle_id', ''), equipped_skin_id, equipped_vehicle_id),
	equipped_vehicle_skin_id = coalesce(nullif(run_summary->>'equipped_vehicle_skin_id', ''), equipped_vehicle_skin_id, 'factory')
where run_summary <> '{}'::jsonb;

update public.family_run_history
set
	equipped_vehicle_id = coalesce(nullif(run_summary->>'equipped_vehicle_id', ''), equipped_skin_id, equipped_vehicle_id),
	equipped_vehicle_skin_id = coalesce(nullif(run_summary->>'equipped_vehicle_skin_id', ''), equipped_vehicle_skin_id, 'factory')
where run_summary <> '{}'::jsonb;

create or replace function public.submit_family_score_v2(
	p_family_id text,
	p_player_id text,
	p_name text,
	p_score integer,
	p_run_summary jsonb default '{}'::jsonb,
	p_equipped_skin_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	leaderboard_row public.family_leaderboard%rowtype;
	resolved_vehicle_id text := coalesce(
		nullif(trim(coalesce(p_run_summary->>'equipped_vehicle_id', '')), ''),
		nullif(trim(coalesce(p_equipped_skin_id, '')), ''),
		'default_scout'
	);
	resolved_vehicle_skin_id text := coalesce(
		nullif(trim(coalesce(p_run_summary->>'equipped_vehicle_skin_id', '')), ''),
		'factory'
	);
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
		score,
		run_summary,
		equipped_skin_id,
		equipped_vehicle_id,
		equipped_vehicle_skin_id,
		time_survived,
		missiles_fired,
		hostiles_destroyed,
		ammo_pickups_collected,
		glowing_rocks_triggered,
		boundary_bounces,
		near_misses,
		hostile_near_misses,
		projectile_near_misses,
		skill_score,
		max_combo_multiplier,
		max_combo_events,
		missile_hits,
		missile_misses,
		max_missile_hit_streak,
		projectile_intercepts
	)
	values (
		p_family_id,
		p_player_id,
		p_name,
		p_score,
		coalesce(p_run_summary, '{}'::jsonb),
		p_equipped_skin_id,
		resolved_vehicle_id,
		resolved_vehicle_skin_id,
		coalesce((p_run_summary->>'time_survived_seconds')::numeric, coalesce((p_run_summary->>'time_survived')::numeric, 0)),
		coalesce((p_run_summary->>'missiles_fired')::integer, 0),
		coalesce((p_run_summary->>'hostiles_destroyed')::integer, 0),
		coalesce((p_run_summary->>'ammo_pickups_collected')::integer, 0),
		coalesce((p_run_summary->>'glowing_rocks_triggered')::integer, 0),
		coalesce((p_run_summary->>'boundary_bounces')::integer, 0),
		coalesce((p_run_summary->>'near_misses')::integer, 0),
		coalesce((p_run_summary->>'hostile_near_misses')::integer, 0),
		coalesce((p_run_summary->>'projectile_near_misses')::integer, 0),
		coalesce((p_run_summary->>'skill_score')::integer, 0),
		coalesce((p_run_summary->>'max_combo_multiplier')::numeric, 1),
		coalesce((p_run_summary->>'max_combo_events')::integer, 0),
		coalesce((p_run_summary->>'missile_hits')::integer, 0),
		coalesce((p_run_summary->>'missile_misses')::integer, 0),
		coalesce((p_run_summary->>'max_missile_hit_streak')::integer, 0),
		coalesce((p_run_summary->>'projectile_intercepts')::integer, 0)
	)
	on conflict (family_id, player_id)
	do update set
		name = excluded.name,
		score = excluded.score,
		run_summary = excluded.run_summary,
		equipped_skin_id = excluded.equipped_skin_id,
		equipped_vehicle_id = excluded.equipped_vehicle_id,
		equipped_vehicle_skin_id = excluded.equipped_vehicle_skin_id,
		time_survived = excluded.time_survived,
		missiles_fired = excluded.missiles_fired,
		hostiles_destroyed = excluded.hostiles_destroyed,
		ammo_pickups_collected = excluded.ammo_pickups_collected,
		glowing_rocks_triggered = excluded.glowing_rocks_triggered,
		boundary_bounces = excluded.boundary_bounces,
		near_misses = excluded.near_misses,
		hostile_near_misses = excluded.hostile_near_misses,
		projectile_near_misses = excluded.projectile_near_misses,
		skill_score = excluded.skill_score,
		max_combo_multiplier = excluded.max_combo_multiplier,
		max_combo_events = excluded.max_combo_events,
		missile_hits = excluded.missile_hits,
		missile_misses = excluded.missile_misses,
		max_missile_hit_streak = excluded.max_missile_hit_streak,
		projectile_intercepts = excluded.projectile_intercepts,
		updated_at = now()
	where excluded.score > public.family_leaderboard.score
	returning *
	into leaderboard_row;

	if leaderboard_row.id is null then
		select *
		into leaderboard_row
		from public.family_leaderboard
		where family_id = p_family_id and player_id = p_player_id;
	end if;

	insert into public.family_run_history (
		family_id,
		player_id,
		name,
		score,
		run_summary,
		equipped_skin_id,
		equipped_vehicle_id,
		equipped_vehicle_skin_id
	)
	values (
		p_family_id,
		p_player_id,
		p_name,
		p_score,
		coalesce(p_run_summary, '{}'::jsonb),
		p_equipped_skin_id,
		resolved_vehicle_id,
		resolved_vehicle_skin_id
	);

	return jsonb_build_object(
		'name', leaderboard_row.name,
		'best_score', leaderboard_row.score,
		'run_summary', leaderboard_row.run_summary,
		'equipped_skin_id', leaderboard_row.equipped_skin_id,
		'equipped_vehicle_id', leaderboard_row.equipped_vehicle_id,
		'equipped_vehicle_skin_id', leaderboard_row.equipped_vehicle_skin_id
	);
end;
$$;

create or replace function public.sync_player_profile(
	p_family_id text,
	p_player_id text,
	p_name text default null,
	p_equipped_skin_id text default 'default_scout',
	p_unlocked_skins jsonb default '["default_scout"]'::jsonb,
	p_total_daily_missions_completed integer default 0,
	p_daily_streak integer default 0,
	p_last_completed_daily_date text default null,
	p_daily_reminders_enabled boolean default true,
	p_profile_summary jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	profile_row public.family_player_profiles%rowtype;
	resolved_unlocked_vehicles jsonb := coalesce(p_profile_summary->'unlocked_vehicles', p_unlocked_skins, '["default_scout"]'::jsonb);
	resolved_equipped_vehicle_id text := coalesce(
		nullif(trim(coalesce(p_profile_summary->>'equipped_vehicle_id', '')), ''),
		nullif(trim(coalesce(p_equipped_skin_id, '')), ''),
		'default_scout'
	);
	resolved_unlocked_vehicle_skins jsonb := coalesce(p_profile_summary->'unlocked_vehicle_skins', '{}'::jsonb);
	resolved_equipped_vehicle_skins jsonb := coalesce(p_profile_summary->'equipped_vehicle_skins', '{}'::jsonb);
	resolved_vehicle_skin_progress jsonb := coalesce(p_profile_summary->'vehicle_skin_progress', '{}'::jsonb);
	resolved_global_skin_unlocks jsonb := coalesce(p_profile_summary->'global_skin_unlocks', '[]'::jsonb);
	resolved_best_score_milestones jsonb := coalesce(p_profile_summary->'best_score_milestones', '{}'::jsonb);
	resolved_seen_vehicle_lore jsonb := coalesce(p_profile_summary->'seen_vehicle_lore', '[]'::jsonb);
	resolved_seen_skin_lore jsonb := coalesce(p_profile_summary->'seen_skin_lore', '[]'::jsonb);
	resolved_vehicle_catalog_version integer := greatest(coalesce((p_profile_summary->>'vehicle_catalog_version')::integer, 1), 1);
begin
	if p_family_id is null or trim(p_family_id) = '' then
		raise exception 'Family id is required.';
	end if;

	if p_player_id is null or trim(p_player_id) = '' then
		raise exception 'Player id is required.';
	end if;

	insert into public.family_player_profiles (
		family_id,
		player_id,
		name,
		equipped_skin_id,
		unlocked_skins,
		equipped_vehicle_id,
		unlocked_vehicles,
		unlocked_vehicle_skins,
		equipped_vehicle_skins,
		vehicle_skin_progress,
		global_skin_unlocks,
		best_score_milestones,
		seen_vehicle_lore,
		seen_skin_lore,
		vehicle_catalog_version,
		total_daily_missions_completed,
		daily_streak,
		last_completed_daily_date,
		daily_reminders_enabled,
		profile_summary
	)
	values (
		p_family_id,
		p_player_id,
		nullif(trim(coalesce(p_name, '')), ''),
		coalesce(nullif(p_equipped_skin_id, ''), 'default_scout'),
		coalesce(p_unlocked_skins, '["default_scout"]'::jsonb),
		resolved_equipped_vehicle_id,
		resolved_unlocked_vehicles,
		resolved_unlocked_vehicle_skins,
		resolved_equipped_vehicle_skins,
		resolved_vehicle_skin_progress,
		resolved_global_skin_unlocks,
		resolved_best_score_milestones,
		resolved_seen_vehicle_lore,
		resolved_seen_skin_lore,
		resolved_vehicle_catalog_version,
		greatest(coalesce(p_total_daily_missions_completed, 0), 0),
		greatest(coalesce(p_daily_streak, 0), 0),
		p_last_completed_daily_date,
		coalesce(p_daily_reminders_enabled, true),
		coalesce(p_profile_summary, '{}'::jsonb)
	)
	on conflict (family_id, player_id)
	do update set
		name = coalesce(excluded.name, public.family_player_profiles.name),
		equipped_skin_id = excluded.equipped_skin_id,
		unlocked_skins = excluded.unlocked_skins,
		equipped_vehicle_id = excluded.equipped_vehicle_id,
		unlocked_vehicles = excluded.unlocked_vehicles,
		unlocked_vehicle_skins = excluded.unlocked_vehicle_skins,
		equipped_vehicle_skins = excluded.equipped_vehicle_skins,
		vehicle_skin_progress = excluded.vehicle_skin_progress,
		global_skin_unlocks = excluded.global_skin_unlocks,
		best_score_milestones = excluded.best_score_milestones,
		seen_vehicle_lore = excluded.seen_vehicle_lore,
		seen_skin_lore = excluded.seen_skin_lore,
		vehicle_catalog_version = greatest(public.family_player_profiles.vehicle_catalog_version, excluded.vehicle_catalog_version),
		total_daily_missions_completed = greatest(
			public.family_player_profiles.total_daily_missions_completed,
			excluded.total_daily_missions_completed
		),
		daily_streak = greatest(
			public.family_player_profiles.daily_streak,
			excluded.daily_streak
		),
		last_completed_daily_date = coalesce(
			excluded.last_completed_daily_date,
			public.family_player_profiles.last_completed_daily_date
		),
		daily_reminders_enabled = excluded.daily_reminders_enabled,
		profile_summary = excluded.profile_summary,
		updated_at = now()
	returning *
	into profile_row;

	return jsonb_build_object(
		'player_id', profile_row.player_id,
		'equipped_skin_id', profile_row.equipped_skin_id,
		'unlocked_skins', profile_row.unlocked_skins,
		'equipped_vehicle_id', profile_row.equipped_vehicle_id,
		'unlocked_vehicles', profile_row.unlocked_vehicles,
		'unlocked_vehicle_skins', profile_row.unlocked_vehicle_skins,
		'equipped_vehicle_skins', profile_row.equipped_vehicle_skins,
		'vehicle_skin_progress', profile_row.vehicle_skin_progress,
		'global_skin_unlocks', profile_row.global_skin_unlocks,
		'best_score_milestones', profile_row.best_score_milestones,
		'seen_vehicle_lore', profile_row.seen_vehicle_lore,
		'seen_skin_lore', profile_row.seen_skin_lore,
		'vehicle_catalog_version', profile_row.vehicle_catalog_version,
		'total_daily_missions_completed', profile_row.total_daily_missions_completed,
		'daily_streak', profile_row.daily_streak,
		'last_completed_daily_date', profile_row.last_completed_daily_date,
		'daily_reminders_enabled', profile_row.daily_reminders_enabled,
		'profile_summary', profile_row.profile_summary,
		'updated_at', profile_row.updated_at
	);
end;
$$;

-- Cloud restore still depends on recovering the same stable player identity.
-- Future: add optional recovery code or lightweight account binding.

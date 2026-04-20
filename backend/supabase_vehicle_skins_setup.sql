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

create or replace function public.jsonb_text_array_union(
	first_value jsonb,
	second_value jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
	result jsonb := '[]'::jsonb;
	entry text;
begin
	for entry in
		select distinct value
		from (
			select jsonb_array_elements_text(coalesce(first_value, '[]'::jsonb)) as value
			union all
			select jsonb_array_elements_text(coalesce(second_value, '[]'::jsonb)) as value
		) unioned
		where trim(value) <> ''
		order by value
	loop
		result := result || jsonb_build_array(entry);
	end loop;
	return result;
end;
$$;

create or replace function public.jsonb_object_array_union(
	first_value jsonb,
	second_value jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
	result jsonb := '{}'::jsonb;
	object_key text;
begin
	for object_key in
		select key
		from (
			select jsonb_object_keys(coalesce(first_value, '{}'::jsonb)) as key
			union
			select jsonb_object_keys(coalesce(second_value, '{}'::jsonb)) as key
		) keys
		order by key
	loop
		result := jsonb_set(
			result,
			array[object_key],
			public.jsonb_text_array_union(first_value -> object_key, second_value -> object_key),
			true
		);
	end loop;
	return result;
end;
$$;

create or replace function public.jsonb_bool_dictionary_or(
	first_value jsonb,
	second_value jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
	result jsonb := '{}'::jsonb;
	object_key text;
	merged_value boolean;
begin
	for object_key in
		select key
		from (
			select jsonb_object_keys(coalesce(first_value, '{}'::jsonb)) as key
			union
			select jsonb_object_keys(coalesce(second_value, '{}'::jsonb)) as key
		) keys
		order by key
	loop
		merged_value := coalesce((first_value ->> object_key)::boolean, false) or coalesce((second_value ->> object_key)::boolean, false);
		result := jsonb_set(result, array[object_key], to_jsonb(merged_value), true);
	end loop;
	return result;
end;
$$;

create or replace function public.merge_vehicle_skin_progress(
	primary_value jsonb,
	secondary_value jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
	result jsonb := '{}'::jsonb;
	vehicle_key text;
	primary_entry jsonb;
	secondary_entry jsonb;
	merged_entry jsonb;
begin
	for vehicle_key in
		select key
		from (
			select jsonb_object_keys(coalesce(primary_value, '{}'::jsonb)) as key
			union
			select jsonb_object_keys(coalesce(secondary_value, '{}'::jsonb)) as key
		) keys
		order by key
	loop
		primary_entry := coalesce(primary_value -> vehicle_key, '{}'::jsonb);
		secondary_entry := coalesce(secondary_value -> vehicle_key, '{}'::jsonb);
		merged_entry := secondary_entry || primary_entry;
		merged_entry := jsonb_set(merged_entry, '{runs_completed}', to_jsonb(greatest(coalesce((primary_entry ->> 'runs_completed')::integer, 0), coalesce((secondary_entry ->> 'runs_completed')::integer, 0))), true);
		merged_entry := jsonb_set(merged_entry, '{daily_missions_completed}', to_jsonb(greatest(coalesce((primary_entry ->> 'daily_missions_completed')::integer, 0), coalesce((secondary_entry ->> 'daily_missions_completed')::integer, 0))), true);
		merged_entry := jsonb_set(merged_entry, '{near_misses}', to_jsonb(greatest(coalesce((primary_entry ->> 'near_misses')::integer, 0), coalesce((secondary_entry ->> 'near_misses')::integer, 0))), true);
		merged_entry := jsonb_set(merged_entry, '{projectile_intercepts}', to_jsonb(greatest(coalesce((primary_entry ->> 'projectile_intercepts')::integer, 0), coalesce((secondary_entry ->> 'projectile_intercepts')::integer, 0))), true);
		merged_entry := jsonb_set(merged_entry, '{best_score}', to_jsonb(greatest(coalesce((primary_entry ->> 'best_score')::integer, 0), coalesce((secondary_entry ->> 'best_score')::integer, 0))), true);
		result := jsonb_set(result, array[vehicle_key], merged_entry, true);
	end loop;
	return result;
end;
$$;

create or replace function public.migrate_player_identity(
	p_family_id text,
	p_old_player_id text,
	p_new_player_id text,
	p_old_device_id text default null,
	p_new_device_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	old_profile public.family_player_profiles%rowtype;
	new_profile public.family_player_profiles%rowtype;
	old_profile_found boolean := false;
	new_profile_found boolean := false;
	old_profile_has_meaningful_progress boolean := false;
	new_profile_has_meaningful_progress boolean := false;
	profile_base_is_new boolean := true;
	merged_name text;
	merged_equipped_skin_id text;
	merged_equipped_vehicle_id text;
	merged_equipped_vehicle_skin_id text;
	merged_unlocked_vehicles jsonb := '["default_scout"]'::jsonb;
	merged_unlocked_vehicle_skins jsonb := '{}'::jsonb;
	merged_equipped_vehicle_skins jsonb := '{}'::jsonb;
	merged_vehicle_skin_progress jsonb := '{}'::jsonb;
	merged_global_skin_unlocks jsonb := '[]'::jsonb;
	merged_best_score_milestones jsonb := '{}'::jsonb;
	merged_seen_vehicle_lore jsonb := '[]'::jsonb;
	merged_seen_skin_lore jsonb := '[]'::jsonb;
	merged_vehicle_catalog_version integer := 1;
	merged_total_daily_missions_completed integer := 0;
	merged_daily_streak integer := 0;
	merged_last_completed_daily_date text;
	merged_daily_reminders_enabled boolean := true;
	merged_missions_intro_seen boolean := false;
	merged_profile_summary jsonb := '{}'::jsonb;
	old_leaderboard public.family_leaderboard%rowtype;
	new_leaderboard public.family_leaderboard%rowtype;
	old_leaderboard_found boolean := false;
	new_leaderboard_found boolean := false;
	leaderboard_choice text := '';
	merged_missions jsonb;
	merged_completed_count integer;
	merged_total_count integer;
	progress_key record;
	device_row record;
	resolved_player_id text;
	resolved_device_id text;
	merged_device_row_id bigint;
	merged_device_token text;
	merged_device_platform text;
	merged_device_label text;
	merged_notifications_enabled boolean := false;
	merged_daily_missions_enabled boolean := false;
	merged_device_last_seen_at timestamptz;
begin
	p_family_id := trim(coalesce(p_family_id, ''));
	p_old_player_id := trim(coalesce(p_old_player_id, ''));
	p_new_player_id := trim(coalesce(p_new_player_id, ''));
	p_old_device_id := trim(coalesce(p_old_device_id, ''));
	p_new_device_id := trim(coalesce(p_new_device_id, ''));

	if p_family_id = '' then
		raise exception 'Family id is required.';
	end if;

	if p_new_player_id = '' then
		raise exception 'New player id is required.';
	end if;

	if p_old_player_id = '' and p_old_device_id = '' then
		return jsonb_build_object(
			'migrated', false,
			'reason', 'nothing_to_migrate'
		);
	end if;

	select * into old_profile
	from public.family_player_profiles
	where family_id = p_family_id
	  and player_id = p_old_player_id
	limit 1;
	old_profile_found := found;

	select * into new_profile
	from public.family_player_profiles
	where family_id = p_family_id
	  and player_id = p_new_player_id
	limit 1;
	new_profile_found := found;

	if old_profile_found or new_profile_found then
		if old_profile_found then
			old_profile_has_meaningful_progress := coalesce(nullif(old_profile.name, ''), '') <> ''
				or coalesce(old_profile.total_daily_missions_completed, 0) > 0
				or coalesce(old_profile.daily_streak, 0) > 0
				or coalesce(nullif(old_profile.last_completed_daily_date, ''), '') <> ''
				or coalesce(jsonb_array_length(coalesce(old_profile.unlocked_vehicles, old_profile.unlocked_skins, '["default_scout"]'::jsonb)), 0) > 1
				or exists (
					select 1
					from jsonb_each(coalesce(old_profile.vehicle_skin_progress, '{}'::jsonb)) as progress(vehicle_id, entry)
					where coalesce((entry ->> 'runs_completed')::integer, 0) > 0
					   or coalesce((entry ->> 'daily_missions_completed')::integer, 0) > 0
					   or coalesce((entry ->> 'near_misses')::integer, 0) > 0
					   or coalesce((entry ->> 'projectile_intercepts')::integer, 0) > 0
					   or coalesce((entry ->> 'best_score')::integer, 0) > 0
				)
				or coalesce(jsonb_array_length(coalesce(old_profile.global_skin_unlocks, '[]'::jsonb)), 0) > 0
				or coalesce(jsonb_array_length(coalesce(old_profile.seen_vehicle_lore, '[]'::jsonb)), 0) > 0
				or coalesce(jsonb_array_length(coalesce(old_profile.seen_skin_lore, '[]'::jsonb)), 0) > 0
				or coalesce(old_profile.equipped_vehicle_id, old_profile.equipped_skin_id, 'default_scout') <> 'default_scout';
		end if;
		if new_profile_found then
			new_profile_has_meaningful_progress := coalesce(nullif(new_profile.name, ''), '') <> ''
				or coalesce(new_profile.total_daily_missions_completed, 0) > 0
				or coalesce(new_profile.daily_streak, 0) > 0
				or coalesce(nullif(new_profile.last_completed_daily_date, ''), '') <> ''
				or coalesce(jsonb_array_length(coalesce(new_profile.unlocked_vehicles, new_profile.unlocked_skins, '["default_scout"]'::jsonb)), 0) > 1
				or exists (
					select 1
					from jsonb_each(coalesce(new_profile.vehicle_skin_progress, '{}'::jsonb)) as progress(vehicle_id, entry)
					where coalesce((entry ->> 'runs_completed')::integer, 0) > 0
					   or coalesce((entry ->> 'daily_missions_completed')::integer, 0) > 0
					   or coalesce((entry ->> 'near_misses')::integer, 0) > 0
					   or coalesce((entry ->> 'projectile_intercepts')::integer, 0) > 0
					   or coalesce((entry ->> 'best_score')::integer, 0) > 0
				)
				or coalesce(jsonb_array_length(coalesce(new_profile.global_skin_unlocks, '[]'::jsonb)), 0) > 0
				or coalesce(jsonb_array_length(coalesce(new_profile.seen_vehicle_lore, '[]'::jsonb)), 0) > 0
				or coalesce(jsonb_array_length(coalesce(new_profile.seen_skin_lore, '[]'::jsonb)), 0) > 0
				or coalesce(new_profile.equipped_vehicle_id, new_profile.equipped_skin_id, 'default_scout') <> 'default_scout';
		end if;
		if old_profile_found and new_profile_found then
			if old_profile_has_meaningful_progress and not new_profile_has_meaningful_progress then
				profile_base_is_new := false;
			elsif new_profile_has_meaningful_progress and not old_profile_has_meaningful_progress then
				profile_base_is_new := true;
			else
				profile_base_is_new := coalesce(new_profile.updated_at, new_profile.created_at, now()) >= coalesce(old_profile.updated_at, old_profile.created_at, now());
			end if;
		else
			profile_base_is_new := new_profile_found;
		end if;

		merged_name := coalesce(
			case when profile_base_is_new then nullif(new_profile.name, '') else nullif(old_profile.name, '') end,
			case when profile_base_is_new then nullif(old_profile.name, '') else nullif(new_profile.name, '') end
		);
		merged_equipped_skin_id := coalesce(
			nullif(case when profile_base_is_new then coalesce(new_profile.equipped_skin_id, '') else coalesce(old_profile.equipped_skin_id, '') end, ''),
			nullif(case when profile_base_is_new then coalesce(old_profile.equipped_skin_id, '') else coalesce(new_profile.equipped_skin_id, '') end, ''),
			'default_scout'
		);
		merged_equipped_vehicle_id := coalesce(
			nullif(case when profile_base_is_new then coalesce(new_profile.equipped_vehicle_id, '') else coalesce(old_profile.equipped_vehicle_id, '') end, ''),
			nullif(case when profile_base_is_new then coalesce(old_profile.equipped_vehicle_id, '') else coalesce(new_profile.equipped_vehicle_id, '') end, ''),
			merged_equipped_skin_id
		);
		merged_unlocked_vehicles := public.jsonb_text_array_union(
			coalesce(old_profile.unlocked_vehicles, old_profile.unlocked_skins, '["default_scout"]'::jsonb),
			coalesce(new_profile.unlocked_vehicles, new_profile.unlocked_skins, '["default_scout"]'::jsonb)
		);
		merged_unlocked_vehicle_skins := public.jsonb_object_array_union(old_profile.unlocked_vehicle_skins, new_profile.unlocked_vehicle_skins);
		merged_equipped_vehicle_skins := coalesce(case when profile_base_is_new then old_profile.equipped_vehicle_skins else new_profile.equipped_vehicle_skins end, '{}'::jsonb)
			|| coalesce(case when profile_base_is_new then new_profile.equipped_vehicle_skins else old_profile.equipped_vehicle_skins end, '{}'::jsonb);
		merged_vehicle_skin_progress := public.merge_vehicle_skin_progress(
			case when profile_base_is_new then new_profile.vehicle_skin_progress else old_profile.vehicle_skin_progress end,
			case when profile_base_is_new then old_profile.vehicle_skin_progress else new_profile.vehicle_skin_progress end
		);
		merged_global_skin_unlocks := public.jsonb_text_array_union(old_profile.global_skin_unlocks, new_profile.global_skin_unlocks);
		merged_best_score_milestones := public.jsonb_bool_dictionary_or(old_profile.best_score_milestones, new_profile.best_score_milestones);
		merged_seen_vehicle_lore := public.jsonb_text_array_union(old_profile.seen_vehicle_lore, new_profile.seen_vehicle_lore);
		merged_seen_skin_lore := public.jsonb_text_array_union(old_profile.seen_skin_lore, new_profile.seen_skin_lore);
		merged_vehicle_catalog_version := greatest(coalesce(old_profile.vehicle_catalog_version, 1), coalesce(new_profile.vehicle_catalog_version, 1), 1);
		merged_total_daily_missions_completed := greatest(coalesce(old_profile.total_daily_missions_completed, 0), coalesce(new_profile.total_daily_missions_completed, 0));
		merged_daily_streak := greatest(coalesce(old_profile.daily_streak, 0), coalesce(new_profile.daily_streak, 0));
		merged_last_completed_daily_date := nullif(greatest(coalesce(old_profile.last_completed_daily_date, ''), coalesce(new_profile.last_completed_daily_date, '')), '');
		merged_daily_reminders_enabled := coalesce(
			case when profile_base_is_new then new_profile.daily_reminders_enabled else old_profile.daily_reminders_enabled end,
			case when profile_base_is_new then old_profile.daily_reminders_enabled else new_profile.daily_reminders_enabled end,
			true
		);
		merged_missions_intro_seen := coalesce((old_profile.profile_summary ->> 'missions_intro_seen')::boolean, false)
			or coalesce((new_profile.profile_summary ->> 'missions_intro_seen')::boolean, false);
		merged_equipped_vehicle_skin_id := coalesce(
			nullif(coalesce(merged_equipped_vehicle_skins ->> merged_equipped_vehicle_id, ''), ''),
			'factory'
		);
		merged_profile_summary := jsonb_build_object(
			'equipped_skin_id', merged_equipped_vehicle_id,
			'unlocked_skins', merged_unlocked_vehicles,
			'equipped_vehicle_id', merged_equipped_vehicle_id,
			'equipped_vehicle_skin_id', merged_equipped_vehicle_skin_id,
			'unlocked_vehicles', merged_unlocked_vehicles,
			'unlocked_vehicle_skins', merged_unlocked_vehicle_skins,
			'equipped_vehicle_skins', merged_equipped_vehicle_skins,
			'vehicle_skin_progress', merged_vehicle_skin_progress,
			'global_skin_unlocks', merged_global_skin_unlocks,
			'best_score_milestones', merged_best_score_milestones,
			'seen_vehicle_lore', merged_seen_vehicle_lore,
			'seen_skin_lore', merged_seen_skin_lore,
			'vehicle_catalog_version', merged_vehicle_catalog_version,
			'total_daily_missions_completed', merged_total_daily_missions_completed,
			'daily_streak', merged_daily_streak,
			'last_completed_daily_date', merged_last_completed_daily_date,
			'daily_reminders_enabled', merged_daily_reminders_enabled,
			'missions_intro_seen', merged_missions_intro_seen
		);

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
			p_new_player_id,
			merged_name,
			merged_equipped_skin_id,
			merged_unlocked_vehicles,
			merged_equipped_vehicle_id,
			merged_unlocked_vehicles,
			merged_unlocked_vehicle_skins,
			merged_equipped_vehicle_skins,
			merged_vehicle_skin_progress,
			merged_global_skin_unlocks,
			merged_best_score_milestones,
			merged_seen_vehicle_lore,
			merged_seen_skin_lore,
			merged_vehicle_catalog_version,
			merged_total_daily_missions_completed,
			merged_daily_streak,
			merged_last_completed_daily_date,
			merged_daily_reminders_enabled,
			merged_profile_summary
		)
		on conflict (family_id, player_id)
		do update set
			name = excluded.name,
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
			vehicle_catalog_version = excluded.vehicle_catalog_version,
			total_daily_missions_completed = excluded.total_daily_missions_completed,
			daily_streak = excluded.daily_streak,
			last_completed_daily_date = excluded.last_completed_daily_date,
			daily_reminders_enabled = excluded.daily_reminders_enabled,
			profile_summary = excluded.profile_summary,
			updated_at = now();
	end if;

	for progress_key in
		select mission_date
		from (
			select mission_date from public.family_daily_mission_progress where family_id = p_family_id and player_id = p_old_player_id
			union
			select mission_date from public.family_daily_mission_progress where family_id = p_family_id and player_id = p_new_player_id
		) dates
	loop
		select
			case
				when coalesce(jsonb_array_length(coalesce(new_row.missions, '[]'::jsonb)), 0) >= coalesce(jsonb_array_length(coalesce(old_row.missions, '[]'::jsonb)), 0)
					then coalesce(new_row.missions, old_row.missions, '[]'::jsonb)
				else coalesce(old_row.missions, new_row.missions, '[]'::jsonb)
			end,
			greatest(coalesce(old_row.completed_count, 0), coalesce(new_row.completed_count, 0)),
			greatest(coalesce(old_row.total_count, 0), coalesce(new_row.total_count, 0))
		into merged_missions, merged_completed_count, merged_total_count
		from (
			select * from public.family_daily_mission_progress
			where family_id = p_family_id and player_id = p_old_player_id and mission_date = progress_key.mission_date
			limit 1
		) old_row
		full outer join (
			select * from public.family_daily_mission_progress
			where family_id = p_family_id and player_id = p_new_player_id and mission_date = progress_key.mission_date
			limit 1
		) new_row on true;

		insert into public.family_daily_mission_progress (
			family_id,
			player_id,
			mission_date,
			missions,
			completed_count,
			total_count
		)
		values (
			p_family_id,
			p_new_player_id,
			progress_key.mission_date,
			coalesce(merged_missions, '[]'::jsonb),
			coalesce(merged_completed_count, 0),
			greatest(coalesce(merged_total_count, 0), 3)
		)
		on conflict (family_id, player_id, mission_date)
		do update set
			missions = case
				when jsonb_array_length(coalesce(excluded.missions, '[]'::jsonb)) >= jsonb_array_length(coalesce(public.family_daily_mission_progress.missions, '[]'::jsonb))
					then excluded.missions
				else public.family_daily_mission_progress.missions
			end,
			completed_count = greatest(public.family_daily_mission_progress.completed_count, excluded.completed_count),
			total_count = greatest(public.family_daily_mission_progress.total_count, excluded.total_count),
			updated_at = now();
	end loop;

	select * into old_leaderboard
	from public.family_leaderboard
	where family_id = p_family_id
	  and player_id = p_old_player_id
	limit 1;
	old_leaderboard_found := found;

	select * into new_leaderboard
	from public.family_leaderboard
	where family_id = p_family_id
	  and player_id = p_new_player_id
	limit 1;
	new_leaderboard_found := found;

	if old_leaderboard_found and new_leaderboard_found then
		if coalesce(old_leaderboard.score, 0) > coalesce(new_leaderboard.score, 0) then
			leaderboard_choice := 'old';
		elsif coalesce(new_leaderboard.score, 0) > coalesce(old_leaderboard.score, 0) then
			leaderboard_choice := 'new';
		elsif coalesce(old_leaderboard.updated_at, old_leaderboard.created_at, now()) > coalesce(new_leaderboard.updated_at, new_leaderboard.created_at, now()) then
			leaderboard_choice := 'old';
		else
			leaderboard_choice := 'new';
		end if;
	elsif old_leaderboard_found then
		leaderboard_choice := 'old';
	elsif new_leaderboard_found then
		leaderboard_choice := 'new';
	end if;

	if leaderboard_choice <> '' then
		if leaderboard_choice = 'old' then
			if p_old_player_id <> '' and p_old_player_id <> p_new_player_id then
				delete from public.family_leaderboard
				where family_id = p_family_id
				  and player_id = p_new_player_id;
			end if;

			update public.family_leaderboard
			set player_id = p_new_player_id,
				score = old_leaderboard.score,
				run_summary = old_leaderboard.run_summary,
				equipped_skin_id = old_leaderboard.equipped_skin_id,
				time_survived = old_leaderboard.time_survived,
				missiles_fired = old_leaderboard.missiles_fired,
				hostiles_destroyed = old_leaderboard.hostiles_destroyed,
				ammo_pickups_collected = old_leaderboard.ammo_pickups_collected,
				glowing_rocks_triggered = old_leaderboard.glowing_rocks_triggered,
				boundary_bounces = old_leaderboard.boundary_bounces,
				near_misses = old_leaderboard.near_misses,
				hostile_near_misses = old_leaderboard.hostile_near_misses,
				projectile_near_misses = old_leaderboard.projectile_near_misses,
				skill_score = old_leaderboard.skill_score,
				max_combo_multiplier = old_leaderboard.max_combo_multiplier,
				max_combo_events = old_leaderboard.max_combo_events,
				missile_hits = old_leaderboard.missile_hits,
				missile_misses = old_leaderboard.missile_misses,
				max_missile_hit_streak = old_leaderboard.max_missile_hit_streak,
				projectile_intercepts = old_leaderboard.projectile_intercepts,
				equipped_vehicle_id = old_leaderboard.equipped_vehicle_id,
				equipped_vehicle_skin_id = old_leaderboard.equipped_vehicle_skin_id,
				updated_at = now()
			where family_id = p_family_id
			  and player_id = p_old_player_id;
		else
			if p_old_player_id <> '' and p_old_player_id <> p_new_player_id then
				delete from public.family_leaderboard
				where family_id = p_family_id
				  and player_id = p_old_player_id;
			end if;

			update public.family_leaderboard
			set score = new_leaderboard.score,
				run_summary = new_leaderboard.run_summary,
				equipped_skin_id = new_leaderboard.equipped_skin_id,
				time_survived = new_leaderboard.time_survived,
				missiles_fired = new_leaderboard.missiles_fired,
				hostiles_destroyed = new_leaderboard.hostiles_destroyed,
				ammo_pickups_collected = new_leaderboard.ammo_pickups_collected,
				glowing_rocks_triggered = new_leaderboard.glowing_rocks_triggered,
				boundary_bounces = new_leaderboard.boundary_bounces,
				near_misses = new_leaderboard.near_misses,
				hostile_near_misses = new_leaderboard.hostile_near_misses,
				projectile_near_misses = new_leaderboard.projectile_near_misses,
				skill_score = new_leaderboard.skill_score,
				max_combo_multiplier = new_leaderboard.max_combo_multiplier,
				max_combo_events = new_leaderboard.max_combo_events,
				missile_hits = new_leaderboard.missile_hits,
				missile_misses = new_leaderboard.missile_misses,
				max_missile_hit_streak = new_leaderboard.max_missile_hit_streak,
				projectile_intercepts = new_leaderboard.projectile_intercepts,
				equipped_vehicle_id = new_leaderboard.equipped_vehicle_id,
				equipped_vehicle_skin_id = new_leaderboard.equipped_vehicle_skin_id,
				updated_at = now()
			where family_id = p_family_id
			  and player_id = p_new_player_id;
		end if;
	end if;

	if p_old_player_id <> '' and p_old_player_id <> p_new_player_id then
		update public.family_run_history
		set player_id = p_new_player_id
		where family_id = p_family_id
		  and player_id = p_old_player_id;

		update public.family_notifications
		set target_player_id = p_new_player_id
		where family_id = p_family_id
		  and target_player_id = p_old_player_id;

		update public.family_push_delivery_log
		set target_player_id = p_new_player_id
		where family_id = p_family_id
		  and target_player_id = p_old_player_id;
	end if;

	if p_old_device_id <> '' and p_new_device_id <> '' and p_old_device_id <> p_new_device_id then
		update public.family_push_delivery_log
		set device_id = p_new_device_id
		where family_id = p_family_id
		  and device_id = p_old_device_id;
	end if;

	if to_regclass('public.app_update_push_history') is not null then
		if p_old_device_id <> '' and p_new_device_id <> '' and p_old_device_id <> p_new_device_id then
			execute $migration$
				delete from public.app_update_push_history as old_rows
				using public.app_update_push_history as new_rows
				where old_rows.id <> new_rows.id
				  and old_rows.family_id = $1
				  and new_rows.family_id = $1
				  and old_rows.channel = new_rows.channel
				  and old_rows.version_code = new_rows.version_code
				  and old_rows.device_id = $2
				  and new_rows.device_id = $3
			$migration$
			using p_family_id, p_old_device_id, p_new_device_id;

			execute $migration$
				update public.app_update_push_history
				set device_id = $1
				where family_id = $2
				  and device_id = $3
			$migration$
			using p_new_device_id, p_family_id, p_old_device_id;
		end if;

		if p_old_player_id <> '' and p_old_player_id <> p_new_player_id then
			execute $migration$
				update public.app_update_push_history
				set player_id = $1
				where family_id = $2
				  and player_id = $3
			$migration$
			using p_new_player_id, p_family_id, p_old_player_id;
		end if;
	end if;

	for device_row in
		select distinct
			case
				when p_old_player_id <> '' and player_id = p_old_player_id then p_new_player_id
				else player_id
			end as resolved_player_id,
			case
				when p_old_device_id <> '' and p_new_device_id <> '' and device_id = p_old_device_id then p_new_device_id
				else device_id
			end as resolved_device_id
		from public.family_push_devices
		where family_id = p_family_id
		  and (
			(p_old_player_id <> '' and player_id = p_old_player_id)
			or (p_new_player_id <> '' and player_id = p_new_player_id)
			or (p_old_device_id <> '' and device_id = p_old_device_id)
			or (p_new_device_id <> '' and device_id = p_new_device_id)
		  )
	loop
		resolved_player_id := trim(coalesce(device_row.resolved_player_id, ''));
		resolved_device_id := trim(coalesce(device_row.resolved_device_id, ''));
		if resolved_player_id = '' or resolved_device_id = '' then
			continue;
		end if;

		select
			(array_agg(id order by coalesce(last_seen_at, updated_at, created_at, now()) desc, coalesce(updated_at, created_at, now()) desc, id desc))[1],
			coalesce((array_agg(nullif(fcm_token, '') order by (nullif(fcm_token, '') is not null) desc, coalesce(last_seen_at, updated_at, created_at, now()) desc, id desc))[1], ''),
			coalesce((array_agg(nullif(platform, '') order by (nullif(platform, '') is not null) desc, coalesce(last_seen_at, updated_at, created_at, now()) desc, id desc))[1], ''),
			coalesce((array_agg(nullif(device_label, '') order by (nullif(device_label, '') is not null) desc, coalesce(last_seen_at, updated_at, created_at, now()) desc, id desc))[1], ''),
			coalesce(bool_or(coalesce(notifications_enabled, false)), false),
			coalesce(bool_or(coalesce(daily_missions_enabled, false)), false),
			max(last_seen_at)
		into
			merged_device_row_id,
			merged_device_token,
			merged_device_platform,
			merged_device_label,
			merged_notifications_enabled,
			merged_daily_missions_enabled,
			merged_device_last_seen_at
		from public.family_push_devices
		where family_id = p_family_id
		  and (
			case
				when p_old_player_id <> '' and player_id = p_old_player_id then p_new_player_id
				else player_id
			end
		  ) = resolved_player_id
		  and (
			case
				when p_old_device_id <> '' and p_new_device_id <> '' and device_id = p_old_device_id then p_new_device_id
				else device_id
			end
		  ) = resolved_device_id;

		if merged_device_row_id is null then
			continue;
		end if;

		if merged_device_token <> '' then
			delete from public.family_push_devices
			where fcm_token = merged_device_token
			  and id <> merged_device_row_id
			  and (
				family_id <> p_family_id
				or player_id <> resolved_player_id
				or device_id <> resolved_device_id
			  );
		end if;

		delete from public.family_push_devices
		where family_id = p_family_id
		  and (
			case
				when p_old_player_id <> '' and player_id = p_old_player_id then p_new_player_id
				else player_id
			end
		  ) = resolved_player_id
		  and (
			case
				when p_old_device_id <> '' and p_new_device_id <> '' and device_id = p_old_device_id then p_new_device_id
				else device_id
			end
		  ) = resolved_device_id
		  and id <> merged_device_row_id;

		update public.family_push_devices
		set family_id = p_family_id,
			player_id = resolved_player_id,
			device_id = resolved_device_id,
			fcm_token = nullif(merged_device_token, ''),
			platform = coalesce(nullif(merged_device_platform, ''), public.family_push_devices.platform),
			device_label = coalesce(nullif(merged_device_label, ''), public.family_push_devices.device_label),
			notifications_enabled = merged_notifications_enabled,
			daily_missions_enabled = merged_daily_missions_enabled,
			last_seen_at = coalesce(
				greatest(
					coalesce(public.family_push_devices.last_seen_at, merged_device_last_seen_at),
					coalesce(merged_device_last_seen_at, public.family_push_devices.last_seen_at)
				),
				public.family_push_devices.last_seen_at,
				merged_device_last_seen_at
			),
			updated_at = now()
		where id = merged_device_row_id;
	end loop;

	if p_old_player_id <> '' and p_old_player_id <> p_new_player_id then
		delete from public.family_player_profiles
		where family_id = p_family_id
		  and player_id = p_old_player_id;

		delete from public.family_daily_mission_progress
		where family_id = p_family_id
		  and player_id = p_old_player_id;

		delete from public.family_leaderboard
		where family_id = p_family_id
		  and player_id = p_old_player_id;

		delete from public.family_push_devices
		where family_id = p_family_id
		  and player_id = p_old_player_id;
	end if;

	if p_old_device_id <> '' and p_new_device_id <> '' and p_old_device_id <> p_new_device_id then
		delete from public.family_push_devices
		where family_id = p_family_id
		  and device_id = p_old_device_id;
	end if;

	return jsonb_build_object(
		'migrated', true,
		'family_id', p_family_id,
		'player_id', p_new_player_id,
		'device_id', coalesce(nullif(p_new_device_id, ''), nullif(p_old_device_id, ''), ''),
		'profile_migrated', old_profile_found or new_profile_found,
		'leaderboard_migrated', leaderboard_choice <> ''
	);
end;
$$;

grant execute on function public.migrate_player_identity(text, text, text, text, text)
to anon, authenticated;

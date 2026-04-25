extends Node

signal missions_changed(summary: Dictionary)

const EasternTimeScript = preload("res://systems/eastern_time.gd")
const SAVE_PATH := "user://daily_missions.cfg"
const SAVE_SECTION := "daily_missions"
const CORE_MISSION_COUNT := 3
const BONUS_MISSION_COUNT := 2
const TOTAL_MISSION_COUNT := CORE_MISSION_COUNT + BONUS_MISSION_COUNT
const BONUS_BADGE_TEXT := "BONUS"

var validation_mode_enabled: bool = false

const CORE_EASY_MISSIONS := [
	{
		"type": "play_runs",
		"title": "Fly 3 Runs",
		"description": "Complete 3 runs today.",
		"target": 3,
		"category": "core_easy",
		"progress_mode": "sum",
	},
	{
		"type": "survive_seconds_total",
		"title": "Survive 90 Seconds",
		"description": "Stay airborne for 90 total seconds today.",
		"target": 90,
		"category": "core_easy",
		"progress_mode": "sum",
	},
	{
		"type": "ammo_pickups",
		"title": "Collect 5 Ammo Pickups",
		"description": "Collect 5 ammo pickups today.",
		"target": 5,
		"category": "core_easy",
		"progress_mode": "sum",
	},
	{
		"type": "hostiles_destroyed",
		"title": "Destroy 10 Hostiles",
		"description": "Destroy 10 hostiles today.",
		"target": 10,
		"category": "core_easy",
		"progress_mode": "sum",
	},
]

const CORE_COMBAT_MISSIONS := [
	{
		"type": "missiles_fired",
		"title": "Fire 12 Missiles",
		"description": "Fire 12 missiles today.",
		"target": 12,
		"category": "core_combat",
		"progress_mode": "sum",
	},
	{
		"type": "score_total",
		"title": "Earn 2,000 Score",
		"description": "Earn 2,000 total score today.",
		"target": 2000,
		"category": "core_combat",
		"progress_mode": "sum",
	},
	{
		"type": "projectile_intercepts",
		"title": "Intercept 2 Projectiles",
		"description": "Blow up 2 enemy projectiles today.",
		"target": 2,
		"category": "core_combat",
		"progress_mode": "sum",
	},
	{
		"type": "glowing_clears",
		"title": "Trigger 1 Glowing Clear",
		"description": "Set off 1 glowing-rock clear today.",
		"target": 1,
		"category": "core_combat",
		"progress_mode": "sum",
	},
	{
		"type": "powerups_collected",
		"title": "Collect 2 Powerups",
		"description": "Collect 2 powerups today.",
		"target": 2,
		"category": "core_combat",
		"progress_mode": "sum",
	},
	{
		"type": "elite_kills",
		"title": "Defeat 2 Elite Enemies",
		"description": "Take down 2 elite enemies today.",
		"target": 2,
		"category": "core_combat",
		"progress_mode": "sum",
		"rare_group": "enemy_depth",
	},
	{
		"type": "special_enemy_kills",
		"title": "Defeat 3 Modified Enemies",
		"description": "Take down 3 special enemies today.",
		"target": 3,
		"category": "core_combat",
		"progress_mode": "sum",
		"rare_group": "enemy_depth",
	},
]

const CORE_SKILL_MISSIONS := [
	{
		"type": "near_misses",
		"title": "Get 8 Near Misses",
		"description": "Thread the needle 8 times today.",
		"target": 8,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "max_combo",
		"title": "Reach Combo x1.50",
		"description": "Push your combo to x1.50 today.",
		"target": 150,
		"category": "core_skill",
		"progress_mode": "best",
	},
	{
		"type": "skill_score",
		"title": "Earn 800 Skill Score",
		"description": "Stack up 800 skill score today.",
		"target": 800,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "boundary_recoveries",
		"title": "Recover 2 Boundary Saves",
		"description": "Bounce back from the bounds twice today.",
		"target": 2,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "run_upgrades_chosen",
		"title": "Pick 2 Upgrades",
		"description": "Choose 2 run upgrades today.",
		"target": 2,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "score_rush_seconds",
		"title": "Spend 10s In Score Rush",
		"description": "Keep Score Rush active for 10 seconds.",
		"target": 10,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "shield_hits_absorbed",
		"title": "Absorb 1 Hit",
		"description": "Let a shield save you once today.",
		"target": 1,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "overdrive_seconds",
		"title": "Spend 8s In Overdrive",
		"description": "Keep Missile Overdrive active for 8 seconds.",
		"target": 8,
		"category": "core_skill",
		"progress_mode": "sum",
	},
	{
		"type": "emp_activations",
		"title": "Trigger 1 EMP",
		"description": "Set off 1 EMP Burst today.",
		"target": 1,
		"category": "core_skill",
		"progress_mode": "sum",
	},
]

const BONUS_VEHICLE_OR_STRETCH_MISSIONS := [
	{
		"type": "vehicle_runs",
		"title": "Fly 3 Runs with {vehicle}",
		"description": "Take {vehicle} out for 3 runs today.",
		"target": 3,
		"category": "bonus_vehicle",
		"progress_mode": "sum",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "vehicle_best_score",
		"title": "Score 3,500 with {vehicle}",
		"description": "Set a 3,500-point run with {vehicle}.",
		"target": 3500,
		"category": "bonus_vehicle",
		"progress_mode": "best",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "vehicle_near_misses",
		"title": "Get 10 Near Misses with {vehicle}",
		"description": "Cut it close 10 times while flying {vehicle}.",
		"target": 10,
		"category": "bonus_vehicle",
		"progress_mode": "sum",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "vehicle_intercepts",
		"title": "Intercept 4 Projectiles with {vehicle}",
		"description": "Knock out 4 projectiles while flying {vehicle}.",
		"target": 4,
		"category": "bonus_vehicle",
		"progress_mode": "sum",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "vehicle_glowing_clears",
		"title": "Trigger 2 Glowing Clears with {vehicle}",
		"description": "Set off 2 glowing-rock clears while flying {vehicle}.",
		"target": 2,
		"category": "bonus_vehicle",
		"progress_mode": "sum",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "vehicle_skill_score",
		"title": "Earn 1,000 Skill Score with {vehicle}",
		"description": "Stack 1,000 skill score while flying {vehicle}.",
		"target": 1000,
		"category": "bonus_vehicle",
		"progress_mode": "sum",
		"bonus": true,
		"requires_vehicle": true,
	},
	{
		"type": "score_single_run",
		"title": "Score 3,500 in One Run",
		"description": "Break 3,500 in a single run today.",
		"target": 3500,
		"category": "bonus_stretch",
		"progress_mode": "best",
		"bonus": true,
	},
	{
		"type": "run_upgrades_single_run",
		"title": "Choose 4 Upgrades In One Run",
		"description": "Choose 4 upgrades before a run ends.",
		"target": 4,
		"category": "bonus_stretch",
		"progress_mode": "best",
		"bonus": true,
	},
	{
		"type": "objective_events_completed",
		"title": "Complete 1 Objective",
		"description": "Complete 1 run objective today.",
		"target": 1,
		"category": "bonus_stretch",
		"progress_mode": "sum",
		"bonus": true,
		"rare_group": "objective",
	},
	{
		"type": "objective_rewards_claimed",
		"title": "Claim 2 Objective Rewards",
		"description": "Finish objectives and claim 2 rewards.",
		"target": 2,
		"category": "bonus_stretch",
		"progress_mode": "sum",
		"bonus": true,
		"rare_group": "objective",
	},
	{
		"type": "powerups_used",
		"title": "Use 3 Powerups",
		"description": "Trigger 3 powerups today.",
		"target": 3,
		"category": "bonus_stretch",
		"progress_mode": "sum",
		"bonus": true,
	},
]

const BONUS_PRESTIGE_MISSIONS := [
	{
		"type": "no_boundary_recovery_run",
		"title": "Finish Clean",
		"description": "Complete a run with no boundary recoveries.",
		"target": 1,
		"category": "bonus_prestige",
		"progress_mode": "sum",
		"bonus": true,
	},
	{
		"type": "no_missile_run_score",
		"title": "Score 2,500 Without Missiles",
		"description": "Reach 2,500 in one run without firing missiles.",
		"target": 2500,
		"category": "bonus_prestige",
		"progress_mode": "best",
		"bonus": true,
	},
	{
		"type": "score_single_run",
		"title": "Score 5,000 in One Run",
		"description": "Crack 5,000 in a single run today.",
		"target": 5000,
		"category": "bonus_prestige",
		"progress_mode": "best",
		"bonus": true,
	},
	{
		"type": "gold_progress",
		"title": "Push {vehicle} Toward Gold",
		"description": "Raise {vehicle}'s best score toward its 5,000 gold target.",
		"target": 5000,
		"category": "bonus_prestige",
		"progress_mode": "best",
		"bonus": true,
		"requires_vehicle": true,
		"requires_gold_locked": true,
	},
	{
		"type": "original_icon_progress",
		"title": "Push Toward Original Icon",
		"description": "Raise your best score toward the 10,000 Original Icon milestone.",
		"target": 10000,
		"category": "bonus_prestige",
		"progress_mode": "best",
		"bonus": true,
	},
]

var _today_key: String = ""
var _missions: Array[Dictionary] = []
var _recent_run_result: Dictionary = {}
var _live_run_progress_applied: Dictionary = {}
var _live_run_completed_titles: Array[String] = []
var _live_run_core_completed_titles: Array[String] = []
var _live_run_bonus_completed_titles: Array[String] = []
var _live_run_unlocked_vehicles: Array[String] = []

func _ready() -> void:
	refresh_daily_missions()

func begin_run_tracking() -> void:
	_live_run_progress_applied.clear()
	_live_run_completed_titles.clear()
	_live_run_core_completed_titles.clear()
	_live_run_bonus_completed_titles.clear()
	_live_run_unlocked_vehicles.clear()

func get_today_key() -> String:
	return EasternTimeScript.get_current_business_day_key()

func refresh_daily_missions() -> void:
	if validation_mode_enabled:
		return
	var loaded_state := _load_state()
	var current_key := get_today_key()
	if loaded_state.is_empty():
		_today_key = current_key
		_missions = build_daily_missions_for_key(current_key)
		_save_state()
		_emit_missions_changed()
		return

	_today_key = str(loaded_state.get("today_key", current_key))
	_missions = _sanitize_missions(loaded_state.get("missions", []), _today_key)
	if _today_key != current_key or _missions.size() != TOTAL_MISSION_COUNT:
		_today_key = current_key
		_missions = build_daily_missions_for_key(current_key)
		_save_state()
		_queue_daily_sync()
		_emit_missions_changed()
		return

func build_daily_missions_for_key(date_key: String) -> Array[Dictionary]:
	var used_types: Dictionary = {}
	return [
		_pick_mission_for_slot(date_key, "core_easy", CORE_EASY_MISSIONS, used_types),
		_pick_mission_for_slot(date_key, "core_combat", CORE_COMBAT_MISSIONS, used_types),
		_pick_mission_for_slot(date_key, "core_skill", CORE_SKILL_MISSIONS, used_types),
		_pick_mission_for_slot(date_key, "bonus_vehicle_or_stretch", BONUS_VEHICLE_OR_STRETCH_MISSIONS, used_types),
		_pick_mission_for_slot(date_key, "bonus_prestige", BONUS_PRESTIGE_MISSIONS, used_types),
	]

func get_daily_missions() -> Array[Dictionary]:
	refresh_daily_missions()
	return _missions.duplicate(true)

func get_completed_count_today() -> int:
	refresh_daily_missions()
	return _count_completed_missions(false)

func get_total_count_today() -> int:
	refresh_daily_missions()
	return _missions.size()

func get_core_completed_count_today() -> int:
	refresh_daily_missions()
	return _count_completed_missions(false, true)

func get_bonus_completed_count_today() -> int:
	refresh_daily_missions()
	return _count_completed_missions(true)

func get_daily_progress_summary() -> Dictionary:
	refresh_daily_missions()
	var profile: Node = _get_player_profile()
	return {
		"mission_date": _today_key,
		"completed": get_completed_count_today(),
		"total": get_total_count_today(),
		"core_completed": get_core_completed_count_today(),
		"core_total": CORE_MISSION_COUNT,
		"bonus_completed": get_bonus_completed_count_today(),
		"bonus_total": BONUS_MISSION_COUNT,
		"perfect_day": get_completed_count_today() >= TOTAL_MISSION_COUNT,
		"missions": get_daily_missions(),
		"next_unlock": get_next_unlock_progress(),
		"time_until_reset": get_time_until_next_reset_text(),
		"daily_streak": profile.get_daily_streak() if profile != null and profile.has_method("get_daily_streak") else 0,
	}

func get_daily_sync_summary() -> Dictionary:
	refresh_daily_missions()
	return {
		"mission_date": _today_key,
		"missions": get_daily_missions(),
		"completed_count": get_completed_count_today(),
		"total_count": get_total_count_today(),
		"core_completed_count": get_core_completed_count_today(),
		"core_total_count": CORE_MISSION_COUNT,
		"bonus_completed_count": get_bonus_completed_count_today(),
		"bonus_total_count": BONUS_MISSION_COUNT,
	}

func apply_run_summary(summary: Dictionary) -> Dictionary:
	refresh_daily_missions()
	var missions_completed_this_run: Array[String] = []
	var core_missions_completed_this_run: Array[String] = []
	var bonus_missions_completed_this_run: Array[String] = []
	var newly_unlocked_vehicles: Array[String] = []
	missions_completed_this_run.append_array(_live_run_completed_titles)
	core_missions_completed_this_run.append_array(_live_run_core_completed_titles)
	bonus_missions_completed_this_run.append_array(_live_run_bonus_completed_titles)
	newly_unlocked_vehicles.append_array(_live_run_unlocked_vehicles)
	var had_completion_before_run := get_completed_count_today() > 0
	var profile: Node = _get_player_profile()
	var helicopter_skins: Node = _get_helicopter_skins()

	for index in range(_missions.size()):
		var mission := _missions[index].duplicate(true)
		var previous_completed := bool(mission.get("completed", false))
		var progress_variant = _get_progress_increment_for_mission(mission, summary)
		progress_variant = _subtract_live_run_progress(mission, progress_variant)
		var new_progress = _calculate_new_progress(mission, progress_variant)
		mission["progress"] = new_progress
		mission["completed"] = new_progress >= _get_target_value(mission)
		_missions[index] = mission

		if not previous_completed and bool(mission.get("completed", false)):
			_record_completed_mission(mission, missions_completed_this_run, core_missions_completed_this_run, bonus_missions_completed_this_run, newly_unlocked_vehicles, profile, helicopter_skins)

	if not missions_completed_this_run.is_empty() and not had_completion_before_run and profile != null and profile.has_method("update_daily_streak"):
		profile.update_daily_streak(_today_key)

	_save_state()
	_queue_daily_sync()
	_recent_run_result = {
		"missions_completed_this_run": missions_completed_this_run,
		"core_missions_completed_this_run": core_missions_completed_this_run,
		"bonus_missions_completed_this_run": bonus_missions_completed_this_run,
		"newly_unlocked_skins": newly_unlocked_vehicles,
		"newly_unlocked_vehicles": newly_unlocked_vehicles,
		"total_completed_today": get_completed_count_today(),
		"total_missions_today": get_total_count_today(),
		"core_completed_today": get_core_completed_count_today(),
		"core_total_today": CORE_MISSION_COUNT,
		"bonus_completed_today": get_bonus_completed_count_today(),
		"bonus_total_today": BONUS_MISSION_COUNT,
		"next_unlock": get_next_unlock_progress(),
	}
	begin_run_tracking()
	_emit_missions_changed()
	return _recent_run_result.duplicate(true)

func record_live_mission_progress(mission_type: String, amount: float = 1.0, summary: Dictionary = {}) -> Dictionary:
	var clean_type := mission_type.strip_edges()
	if clean_type.is_empty() or amount <= 0.0:
		return {}
	refresh_daily_missions()

	var missions_completed_this_event: Array[String] = []
	var core_missions_completed_this_event: Array[String] = []
	var bonus_missions_completed_this_event: Array[String] = []
	var newly_unlocked_vehicles: Array[String] = []
	var had_completion_before_event := get_completed_count_today() > 0
	var profile: Node = _get_player_profile()
	var helicopter_skins: Node = _get_helicopter_skins()
	var matched_mission := false
	var changed := false

	for index in range(_missions.size()):
		var mission := _missions[index].duplicate(true)
		if str(mission.get("type", "")) != clean_type:
			continue
		if not _live_summary_matches_mission(mission, summary):
			continue
		matched_mission = true
		var previous_progress := float(mission.get("progress", 0.0))
		var previous_completed := bool(mission.get("completed", false))
		var new_progress = _calculate_new_progress(mission, amount)
		mission["progress"] = new_progress
		mission["completed"] = new_progress >= _get_target_value(mission)
		_missions[index] = mission
		changed = changed or absf(previous_progress - float(new_progress)) > 0.001 or previous_completed != bool(mission.get("completed", false))

		if not previous_completed and bool(mission.get("completed", false)):
			_record_completed_mission(mission, missions_completed_this_event, core_missions_completed_this_event, bonus_missions_completed_this_event, newly_unlocked_vehicles, profile, helicopter_skins)

	if not matched_mission:
		return {}

	_live_run_progress_applied[clean_type] = float(_live_run_progress_applied.get(clean_type, 0.0)) + amount
	_live_run_completed_titles.append_array(missions_completed_this_event)
	_live_run_core_completed_titles.append_array(core_missions_completed_this_event)
	_live_run_bonus_completed_titles.append_array(bonus_missions_completed_this_event)
	_live_run_unlocked_vehicles.append_array(newly_unlocked_vehicles)

	if not missions_completed_this_event.is_empty() and not had_completion_before_event and profile != null and profile.has_method("update_daily_streak"):
		profile.update_daily_streak(_today_key)

	if changed:
		_save_state()
		_queue_daily_sync()
		_emit_missions_changed()

	return {
		"missions_completed_this_event": missions_completed_this_event,
		"core_missions_completed_this_event": core_missions_completed_this_event,
		"bonus_missions_completed_this_event": bonus_missions_completed_this_event,
		"newly_unlocked_vehicles": newly_unlocked_vehicles,
		"total_completed_today": get_completed_count_today(),
		"total_missions_today": get_total_count_today(),
	}

func consume_recent_run_result() -> Dictionary:
	var result := _recent_run_result.duplicate(true)
	_recent_run_result = {}
	return result

func merge_remote_daily_progress(summary: Dictionary) -> bool:
	refresh_daily_missions()
	var mission_date := str(summary.get("mission_date", ""))
	if mission_date != _today_key:
		return false

	var remote_missions_variant = summary.get("missions", [])
	if remote_missions_variant is not Array:
		return false

	var remote_by_id: Dictionary = {}
	for remote_mission_variant in remote_missions_variant:
		if remote_mission_variant is not Dictionary:
			return false
		var remote_mission := remote_mission_variant as Dictionary
		remote_by_id[str(remote_mission.get("id", ""))] = remote_mission

	for local_mission in _missions:
		var mission_id := str(local_mission.get("id", ""))
		if mission_id.is_empty() or not remote_by_id.has(mission_id):
			return false

	var merged_changed := false
	for index in range(_missions.size()):
		var local_mission := _missions[index].duplicate(true)
		var remote_mission: Dictionary = remote_by_id.get(str(local_mission.get("id", "")), {})
		var merged_progress = maxf(float(local_mission.get("progress", 0.0)), float(remote_mission.get("progress", 0.0)))
		var target_value := _get_target_value(local_mission)
		var merged_completed := bool(local_mission.get("completed", false)) or bool(remote_mission.get("completed", false)) or merged_progress >= target_value
		if absf(float(local_mission.get("progress", 0.0)) - merged_progress) > 0.001 or bool(local_mission.get("completed", false)) != merged_completed:
			local_mission["progress"] = merged_progress
			local_mission["completed"] = merged_completed
			_missions[index] = local_mission
			merged_changed = true

	if not merged_changed:
		return false

	_save_state()
	_emit_missions_changed()
	return true

func replace_remote_daily_progress(summary: Dictionary) -> bool:
	refresh_daily_missions()
	return _replace_daily_progress_with_summary(summary)

func reset_current_daily_progress() -> bool:
	refresh_daily_missions()
	return _replace_daily_progress_with_summary({})

func get_next_unlock_progress() -> Dictionary:
	var profile: Node = _get_player_profile()
	var total_completed: int = profile.get_total_daily_missions_completed() if profile != null and profile.has_method("get_total_daily_missions_completed") else 0
	var helicopter_skins: Node = _get_helicopter_skins()
	if helicopter_skins == null:
		return {}

	var next_vehicle: Dictionary = {}
	if helicopter_skins.has_method("get_next_locked_vehicle"):
		next_vehicle = helicopter_skins.get_next_locked_vehicle(total_completed)
	if next_vehicle.is_empty():
		return {
			"display_name": "All Vehicles Unlocked",
			"completed": total_completed,
			"required": total_completed,
			"progress_text": "Vehicle collection complete",
		}

	return {
		"vehicle_id": str(next_vehicle.get("vehicle_id", "")),
		"display_name": str(next_vehicle.get("display_name", "Next Unlock")),
		"completed": total_completed,
		"required": int(next_vehicle.get("required_completed_missions", total_completed)),
		"progress_text": "%d / %d" % [total_completed, int(next_vehicle.get("required_completed_missions", total_completed))],
	}

func merge_recent_run_details(extra: Dictionary) -> void:
	for key in extra.keys():
		_recent_run_result[str(key)] = extra[key]

func get_time_until_next_reset_text() -> String:
	return EasternTimeScript.get_time_until_next_reset_text()

func get_reset_label() -> String:
	return EasternTimeScript.get_reset_label()

func apply_validation_state(date_key: String, missions: Array[Dictionary]) -> void:
	validation_mode_enabled = true
	_today_key = date_key
	_missions = _sanitize_missions(missions, date_key)
	_recent_run_result = {}

func _pick_mission_for_slot(date_key: String, slot_name: String, pool: Array, used_types: Dictionary) -> Dictionary:
	var start_index: int = abs(hash("%s|%s" % [date_key, slot_name])) % maxi(pool.size(), 1)
	for offset in range(pool.size()):
		var definition := (pool[(start_index + offset) % pool.size()] as Dictionary).duplicate(true)
		var mission_type := str(definition.get("type", ""))
		if used_types.has(mission_type):
			continue
		var rare_group := str(definition.get("rare_group", ""))
		if not rare_group.is_empty() and used_types.has("rare_group:%s" % rare_group):
			continue
		if (rare_group == "objective" or rare_group == "enemy_depth") and used_types.has("rare_depth_mission"):
			continue
		var vehicle_id := _resolve_vehicle_for_definition(definition, date_key, slot_name)
		if bool(definition.get("requires_vehicle", false)) and vehicle_id.is_empty():
			continue
		used_types[mission_type] = true
		if not rare_group.is_empty():
			used_types["rare_group:%s" % rare_group] = true
		if rare_group == "objective" or rare_group == "enemy_depth":
			used_types["rare_depth_mission"] = true
		return _build_mission_entry(date_key, slot_name, definition, vehicle_id)
	var fallback := (pool[0] as Dictionary).duplicate(true)
	var fallback_vehicle_id := _resolve_vehicle_for_definition(fallback, date_key, slot_name)
	return _build_mission_entry(date_key, slot_name, fallback, fallback_vehicle_id)

func _build_mission_entry(date_key: String, slot_name: String, definition: Dictionary, vehicle_id: String = "") -> Dictionary:
	var title := str(definition.get("title", "Daily Mission"))
	var description := str(definition.get("description", ""))
	if not vehicle_id.is_empty():
		var vehicle_name := _get_vehicle_display_name(vehicle_id)
		title = title.replace("{vehicle}", vehicle_name)
		description = description.replace("{vehicle}", vehicle_name)
	return {
		"id": "daily_%s_%s_%s" % [date_key, slot_name, str(definition.get("type", "mission"))],
		"slot": slot_name,
		"type": str(definition.get("type", "")),
		"category": str(definition.get("category", slot_name)),
		"bonus": bool(definition.get("bonus", slot_name.begins_with("bonus"))),
		"badge_text": BONUS_BADGE_TEXT if bool(definition.get("bonus", slot_name.begins_with("bonus"))) else "",
		"title": title,
		"description": description,
		"target": definition.get("target", 1),
		"progress": 0.0,
		"completed": false,
		"progress_mode": str(definition.get("progress_mode", "sum")),
		"reward_text": "Bonus hangar credit" if bool(definition.get("bonus", slot_name.begins_with("bonus"))) else "Core unlock progress",
		"vehicle_id": vehicle_id,
	}

func _resolve_vehicle_for_definition(definition: Dictionary, date_key: String, slot_name: String) -> String:
	if not bool(definition.get("requires_vehicle", false)):
		return ""
	var candidates := _get_valid_vehicle_targets(bool(definition.get("requires_gold_locked", false)))
	if candidates.is_empty():
		return ""
	var start_index: int = abs(hash("%s|%s|%s" % [date_key, slot_name, str(definition.get("type", ""))])) % candidates.size()
	return candidates[start_index]

func _get_valid_vehicle_targets(require_gold_locked: bool = false) -> Array[String]:
	var helicopter_skins: Node = _get_helicopter_skins()
	var player_profile: Node = _get_player_profile()
	var candidates: Array[String] = []
	if helicopter_skins == null or player_profile == null or not helicopter_skins.has_method("get_vehicle_ids"):
		return candidates
	for vehicle_id in helicopter_skins.get_vehicle_ids():
		if not player_profile.has_vehicle_access(vehicle_id):
			continue
		if vehicle_id == "pottercar":
			continue
		if helicopter_skins.has_method("is_dynamic_vehicle") and helicopter_skins.is_dynamic_vehicle(vehicle_id):
			continue
		if require_gold_locked and player_profile.is_vehicle_skin_unlocked(vehicle_id, "gold"):
			continue
		candidates.append(vehicle_id)
	return candidates

func _record_completed_mission(mission: Dictionary, missions_completed: Array[String], core_missions_completed: Array[String], bonus_missions_completed: Array[String], newly_unlocked_vehicles: Array[String], profile: Node, helicopter_skins: Node) -> void:
	var title := str(mission.get("title", "Mission Complete"))
	missions_completed.append(title)
	if bool(mission.get("bonus", false)):
		bonus_missions_completed.append(title)
		return

	core_missions_completed.append(title)
	if profile == null or not profile.has_method("increment_total_daily_missions_completed"):
		return
	profile.increment_total_daily_missions_completed(1)
	if helicopter_skins == null or not helicopter_skins.has_method("get_vehicle_unlocks_for_completed_missions"):
		return
	for vehicle_id in helicopter_skins.get_vehicle_unlocks_for_completed_missions(profile.get_total_daily_missions_completed()):
		if profile.unlock_vehicle(vehicle_id):
			newly_unlocked_vehicles.append(vehicle_id)

func _subtract_live_run_progress(mission: Dictionary, progress_variant):
	if str(mission.get("progress_mode", "sum")) != "sum":
		return progress_variant
	var mission_type := str(mission.get("type", ""))
	var already_applied := float(_live_run_progress_applied.get(mission_type, 0.0))
	if already_applied <= 0.0:
		return progress_variant
	return maxf(float(progress_variant) - already_applied, 0.0)

func _live_summary_matches_mission(mission: Dictionary, summary: Dictionary) -> bool:
	var mission_vehicle_id := str(mission.get("vehicle_id", ""))
	if mission_vehicle_id.is_empty():
		return true
	var run_vehicle_id := str(summary.get("equipped_vehicle_id", summary.get("equipped_skin_id", "")))
	return mission_vehicle_id == run_vehicle_id

func _get_progress_increment_for_mission(mission: Dictionary, summary: Dictionary):
	var mission_type := str(mission.get("type", ""))
	var mission_vehicle_id := str(mission.get("vehicle_id", ""))
	var run_vehicle_id := str(summary.get("equipped_vehicle_id", summary.get("equipped_skin_id", "")))
	var vehicle_matches := mission_vehicle_id.is_empty() or mission_vehicle_id == run_vehicle_id
	var player_profile: Node = _get_player_profile()
	var run_stats: Node = get_node_or_null("/root/RunStats")
	match mission_type:
		"play_runs":
			return 1
		"survive_seconds_total":
			return float(summary.get("time_survived_seconds", 0.0))
		"score_total":
			return int(summary.get("score", 0))
		"score_single_run":
			return int(summary.get("score", 0))
		"hostiles_destroyed":
			return int(summary.get("hostiles_destroyed", 0))
		"missiles_fired":
			return int(summary.get("missiles_fired", 0))
		"ammo_pickups":
			return int(summary.get("ammo_pickups_collected", 0))
		"glowing_clears":
			return int(summary.get("glowing_rocks_triggered", 0))
		"boundary_recoveries":
			return int(summary.get("boundary_bounces", 0))
		"near_misses":
			return int(summary.get("near_misses", 0))
		"projectile_intercepts":
			return int(summary.get("projectile_intercepts", 0))
		"max_combo":
			return int(round(float(summary.get("max_combo_multiplier", 1.0)) * 100.0))
		"skill_score":
			return int(summary.get("skill_score", 0))
		"run_upgrades_chosen":
			return int(summary.get("upgrades_chosen", summary.get("run_upgrades_chosen", 0)))
		"run_upgrades_single_run":
			return int(summary.get("upgrades_chosen", summary.get("run_upgrades_chosen", 0)))
		"powerups_collected":
			return int(summary.get("powerups_collected", 0))
		"powerups_used":
			return int(summary.get("powerups_used", 0))
		"shield_hits_absorbed":
			return int(summary.get("shield_hits_absorbed", 0))
		"score_rush_seconds":
			return float(summary.get("score_rush_seconds", 0.0))
		"overdrive_seconds":
			return float(summary.get("overdrive_seconds", 0.0))
		"emp_activations":
			return int(summary.get("emp_activations", 0))
		"objective_events_completed":
			return int(summary.get("objective_events_completed", 0))
		"objective_rewards_claimed":
			return int(summary.get("objective_rewards_claimed", 0))
		"elite_kills":
			return int(summary.get("elite_kills", 0))
		"special_enemy_kills":
			return int(summary.get("special_enemy_kills", 0))
		"armored_enemy_kills":
			return int(summary.get("armored_enemy_kills", 0))
		"shielded_enemy_kills":
			return int(summary.get("shielded_enemy_kills", 0))
		"vehicle_runs":
			return 1 if vehicle_matches else 0
		"vehicle_best_score":
			return int(summary.get("score", 0)) if vehicle_matches else 0
		"vehicle_near_misses":
			return int(summary.get("near_misses", 0)) if vehicle_matches else 0
		"vehicle_intercepts":
			return int(summary.get("projectile_intercepts", 0)) if vehicle_matches else 0
		"vehicle_glowing_clears":
			return int(summary.get("glowing_rocks_triggered", 0)) if vehicle_matches else 0
		"vehicle_skill_score":
			return int(summary.get("skill_score", 0)) if vehicle_matches else 0
		"no_boundary_recovery_run":
			return 1 if int(summary.get("boundary_bounces", 0)) <= 0 and float(summary.get("time_survived_seconds", 0.0)) > 0.0 else 0
		"no_missile_run_score":
			return int(summary.get("score", 0)) if int(summary.get("missiles_fired", 0)) <= 0 else 0
		"gold_progress":
			if not vehicle_matches or player_profile == null or not player_profile.has_method("get_vehicle_skin_progress"):
				return 0
			var progress: Dictionary = player_profile.get_vehicle_skin_progress(mission_vehicle_id)
			return maxi(int(progress.get("best_score", 0)), int(summary.get("score", 0)))
		"original_icon_progress":
			var local_best := 0
			if run_stats != null and run_stats.has_method("get_local_best_score"):
				local_best = int(run_stats.get_local_best_score())
			return maxi(local_best, int(summary.get("score", 0)))
	return 0

func _calculate_new_progress(mission: Dictionary, progress_variant):
	var existing_progress := float(mission.get("progress", 0.0))
	match str(mission.get("progress_mode", "sum")):
		"best":
			return maxf(existing_progress, float(progress_variant))
		_:
			return existing_progress + float(progress_variant)

func _get_target_value(mission: Dictionary) -> float:
	return float(mission.get("target", 1))

func _count_completed_missions(only_bonus: bool, only_core: bool = false) -> int:
	var count := 0
	for mission in _missions:
		if not bool(mission.get("completed", false)):
			continue
		var is_bonus := bool(mission.get("bonus", false))
		if only_core and is_bonus:
			continue
		if only_bonus and not is_bonus:
			continue
		count += 1
	return count

func _load_state() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	return {
		"today_key": str(config.get_value(SAVE_SECTION, "today_key", "")),
		"missions": config.get_value(SAVE_SECTION, "missions", []),
	}

func _save_state() -> void:
	if validation_mode_enabled:
		return
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "today_key", _today_key)
	config.set_value(SAVE_SECTION, "missions", _missions.duplicate(true))
	config.save(SAVE_PATH)

func _sanitize_missions(raw_value, date_key: String) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if raw_value is not Array:
		return sanitized
	for mission_variant in raw_value:
		if mission_variant is not Dictionary:
			continue
		var mission := (mission_variant as Dictionary).duplicate(true)
		var mission_id := str(mission.get("id", ""))
		if mission_id.is_empty() or not mission_id.begins_with("daily_%s_" % date_key):
			continue
		mission["slot"] = str(mission.get("slot", "core_easy"))
		mission["type"] = str(mission.get("type", ""))
		mission["category"] = str(mission.get("category", mission.get("slot", "core_easy")))
		mission["bonus"] = bool(mission.get("bonus", str(mission.get("slot", "")).begins_with("bonus")))
		mission["badge_text"] = str(mission.get("badge_text", BONUS_BADGE_TEXT if bool(mission.get("bonus", false)) else ""))
		mission["title"] = str(mission.get("title", "Daily Mission"))
		mission["description"] = str(mission.get("description", ""))
		mission["target"] = mission.get("target", 1)
		mission["progress"] = float(mission.get("progress", 0.0))
		mission["completed"] = bool(mission.get("completed", false))
		mission["progress_mode"] = str(mission.get("progress_mode", "sum"))
		mission["reward_text"] = str(mission.get("reward_text", "Core unlock progress"))
		mission["vehicle_id"] = str(mission.get("vehicle_id", ""))
		sanitized.append(mission)
	return sanitized

func _queue_daily_sync() -> void:
	if validation_mode_enabled:
		return
	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("enqueue_sync_daily_mission_progress"):
		sync_queue.enqueue_sync_daily_mission_progress(get_daily_sync_summary())

func _emit_missions_changed() -> void:
	missions_changed.emit(get_daily_progress_summary())

func _replace_daily_progress_with_summary(summary: Dictionary) -> bool:
	var previous_summary_json := JSON.stringify(get_daily_sync_summary())
	var replacement_missions := build_daily_missions_for_key(_today_key)
	var mission_date := str(summary.get("mission_date", ""))
	var remote_missions_variant = summary.get("missions", [])
	if mission_date == _today_key and remote_missions_variant is Array:
		var sanitized_remote := _sanitize_missions(remote_missions_variant, _today_key)
		if sanitized_remote.size() == TOTAL_MISSION_COUNT:
			replacement_missions = sanitized_remote
	_missions = replacement_missions
	_recent_run_result = {}
	var changed := previous_summary_json != JSON.stringify(get_daily_sync_summary())
	if not changed:
		return false
	_save_state()
	_emit_missions_changed()
	return true

func _get_vehicle_display_name(vehicle_id: String) -> String:
	var helicopter_skins: Node = _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("get_display_name"):
		return str(helicopter_skins.get_display_name(vehicle_id))
	return vehicle_id

func _get_player_profile():
	return get_node_or_null("/root/PlayerProfile")

func _get_helicopter_skins():
	return get_node_or_null("/root/HelicopterSkins")

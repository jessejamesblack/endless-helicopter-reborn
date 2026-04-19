extends Node

signal missions_changed(summary: Dictionary)

const EasternTimeScript = preload("res://systems/eastern_time.gd")
const SAVE_PATH := "user://daily_missions.cfg"
const SAVE_SECTION := "daily_missions"

var validation_mode_enabled: bool = false

const EASY_MISSIONS := [
	{"type": "play_runs", "title": "Fly 3 Runs", "description": "Complete 3 runs today.", "target": 3},
	{"type": "survive_seconds_total", "title": "Survive 90 Seconds", "description": "Stay airborne for 90 total seconds today.", "target": 90},
	{"type": "ammo_pickups", "title": "Collect 5 Ammo Pickups", "description": "Collect 5 ammo pickups today.", "target": 5},
]

const MEDIUM_MISSIONS := [
	{"type": "hostiles_destroyed", "title": "Destroy 10 Hostiles", "description": "Destroy 10 hostiles today.", "target": 10},
	{"type": "missiles_fired", "title": "Fire 12 Missiles", "description": "Fire 12 missiles today.", "target": 12},
	{"type": "score_total", "title": "Earn 2,000 Score", "description": "Earn 2,000 total score today.", "target": 2000},
]

const SKILL_MISSIONS := [
	{"type": "near_misses", "title": "Get 8 Near Misses", "description": "Thread the needle 8 times today.", "target": 8},
	{"type": "projectile_intercepts", "title": "Intercept 2 Projectiles", "description": "Blow up 2 enemy projectiles today.", "target": 2},
	{"type": "max_combo", "title": "Reach Combo x1.50", "description": "Push your combo to x1.50 today.", "target": 150},
	{"type": "glowing_clears", "title": "Trigger 1 Glowing Clear", "description": "Set off 1 glowing-rock clear today.", "target": 1},
]

var _today_key: String = ""
var _missions: Array[Dictionary] = []
var _recent_run_result: Dictionary = {}

func _ready() -> void:
	refresh_daily_missions()

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
	if _today_key != current_key or _missions.size() != 3:
		_today_key = current_key
		_missions = build_daily_missions_for_key(current_key)
		_save_state()
		_queue_daily_sync()
		_emit_missions_changed()
		return

func build_daily_missions_for_key(date_key: String) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var used_types: Dictionary = {}
	selected.append(_pick_mission_from_pool(date_key, "easy", EASY_MISSIONS, used_types))
	selected.append(_pick_mission_from_pool(date_key, "medium", MEDIUM_MISSIONS, used_types))
	selected.append(_pick_mission_from_pool(date_key, "skill", SKILL_MISSIONS, used_types))
	return selected

func get_daily_missions() -> Array[Dictionary]:
	refresh_daily_missions()
	return _missions.duplicate(true)

func get_completed_count_today() -> int:
	refresh_daily_missions()
	var count := 0
	for mission in _missions:
		if bool(mission.get("completed", false)):
			count += 1
	return count

func get_total_count_today() -> int:
	refresh_daily_missions()
	return _missions.size()

func get_daily_progress_summary() -> Dictionary:
	refresh_daily_missions()
	var profile: Node = _get_player_profile()
	return {
		"mission_date": _today_key,
		"completed": get_completed_count_today(),
		"total": get_total_count_today(),
		"missions": get_daily_missions(),
		"next_unlock": get_next_unlock_progress(),
		"time_until_reset": get_time_until_next_reset_text(),
		"daily_streak": profile.get_daily_streak() if profile != null else 0,
	}

func get_daily_sync_summary() -> Dictionary:
	refresh_daily_missions()
	return {
		"mission_date": _today_key,
		"missions": get_daily_missions(),
		"completed_count": get_completed_count_today(),
		"total_count": get_total_count_today(),
	}

func apply_run_summary(summary: Dictionary) -> Dictionary:
	refresh_daily_missions()
	var missions_completed_this_run: Array[String] = []
	var newly_unlocked_vehicles: Array[String] = []
	var had_completion_before_run := get_completed_count_today() > 0
	var profile: Node = _get_player_profile()
	var helicopter_skins: Node = _get_helicopter_skins()

	for index in range(_missions.size()):
		var mission := _missions[index].duplicate(true)
		var previous_completed := bool(mission.get("completed", false))
		var progress_variant = _get_progress_increment_for_mission(mission, summary)
		var new_progress = _calculate_new_progress(mission, progress_variant)
		mission["progress"] = new_progress
		mission["completed"] = new_progress >= _get_target_value(mission)
		_missions[index] = mission

		if not previous_completed and bool(mission.get("completed", false)):
			missions_completed_this_run.append(str(mission.get("title", "Mission Complete")))
			if profile != null:
				profile.increment_total_daily_missions_completed(1)
				if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_unlocks_for_completed_missions"):
					for vehicle_id in helicopter_skins.get_vehicle_unlocks_for_completed_missions(profile.get_total_daily_missions_completed()):
						if profile.unlock_vehicle(vehicle_id):
							newly_unlocked_vehicles.append(vehicle_id)
				elif helicopter_skins != null and helicopter_skins.has_method("get_unlocks_for_completed_missions"):
					for legacy_vehicle_id in helicopter_skins.get_unlocks_for_completed_missions(profile.get_total_daily_missions_completed()):
						if profile.unlock_vehicle(legacy_vehicle_id):
							newly_unlocked_vehicles.append(legacy_vehicle_id)

	if not missions_completed_this_run.is_empty() and not had_completion_before_run and profile != null:
		profile.update_daily_streak(_today_key)

	_save_state()
	_queue_daily_sync()
	_recent_run_result = {
		"missions_completed_this_run": missions_completed_this_run,
		"newly_unlocked_skins": newly_unlocked_vehicles,
		"newly_unlocked_vehicles": newly_unlocked_vehicles,
		"total_completed_today": get_completed_count_today(),
		"total_missions_today": get_total_count_today(),
		"next_unlock": get_next_unlock_progress(),
	}
	_emit_missions_changed()
	return _recent_run_result.duplicate(true)

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

func get_next_unlock_progress() -> Dictionary:
	var profile: Node = _get_player_profile()
	var total_completed: int = profile.get_total_daily_missions_completed() if profile != null else 0
	var helicopter_skins: Node = _get_helicopter_skins()
	if helicopter_skins == null:
		return {}

	var next_vehicle: Dictionary = {}
	if helicopter_skins.has_method("get_next_locked_vehicle"):
		next_vehicle = helicopter_skins.get_next_locked_vehicle(total_completed)
	elif helicopter_skins.has_method("get_next_locked_skin"):
		next_vehicle = helicopter_skins.get_next_locked_skin(total_completed)
	if next_vehicle.is_empty():
		return {
			"display_name": "All Vehicles Unlocked",
			"completed": total_completed,
			"required": total_completed,
			"progress_text": "Vehicle collection complete",
		}

	return {
		"vehicle_id": str(next_vehicle.get("vehicle_id", next_vehicle.get("skin_id", ""))),
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

func _pick_mission_from_pool(date_key: String, slot_name: String, pool: Array, used_types: Dictionary) -> Dictionary:
	var start_index: int = abs(hash("%s|%s" % [date_key, slot_name])) % pool.size()
	for offset in range(pool.size()):
		var candidate := (pool[(start_index + offset) % pool.size()] as Dictionary).duplicate(true)
		var mission_type := str(candidate.get("type", ""))
		if used_types.has(mission_type):
			continue
		used_types[mission_type] = true
		return _build_mission_entry(date_key, candidate)
	return _build_mission_entry(date_key, (pool[0] as Dictionary).duplicate(true))

func _build_mission_entry(date_key: String, definition: Dictionary) -> Dictionary:
	return {
		"id": "daily_%s_%s" % [date_key, str(definition.get("type", "mission"))],
		"type": str(definition.get("type", "")),
		"title": str(definition.get("title", "Daily Mission")),
		"description": str(definition.get("description", "")),
		"target": definition.get("target", 1),
		"progress": 0.0,
		"completed": false,
		"reward_text": "Daily progress",
	}

func _get_progress_increment_for_mission(mission: Dictionary, summary: Dictionary):
	match str(mission.get("type", "")):
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
	return 0

func _calculate_new_progress(mission: Dictionary, progress_variant):
	var mission_type := str(mission.get("type", ""))
	var existing_progress := float(mission.get("progress", 0.0))
	match mission_type:
		"score_single_run", "max_combo":
			return maxf(existing_progress, float(progress_variant))
		_:
			return existing_progress + float(progress_variant)

func _get_target_value(mission: Dictionary) -> float:
	return float(mission.get("target", 1))

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
		if mission_id.is_empty():
			continue
		if not mission_id.begins_with("daily_%s_" % date_key):
			continue
		mission["type"] = str(mission.get("type", ""))
		mission["title"] = str(mission.get("title", "Daily Mission"))
		mission["description"] = str(mission.get("description", ""))
		mission["target"] = mission.get("target", 1)
		mission["progress"] = float(mission.get("progress", 0.0))
		mission["completed"] = bool(mission.get("completed", false))
		mission["reward_text"] = str(mission.get("reward_text", "Daily progress"))
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

func _get_player_profile():
	return get_node_or_null("/root/PlayerProfile")

func _get_helicopter_skins():
	return get_node_or_null("/root/HelicopterSkins")

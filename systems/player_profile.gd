extends Node

signal profile_changed(summary: Dictionary)

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const PROFILE_PATH := "user://player_profile.cfg"
const PROFILE_SECTION := "player_profile"
const DEFAULT_VEHICLE_ID := "default_scout"
const DEFAULT_SKIN_ID := "factory"
const GOLD_MASTERY_BONUS_VEHICLE_ID := "crazytaxi"
const LEADERBOARD_BONUS_VEHICLE_ID := "pottercar"
const SCORE_MILESTONE_ORIGINAL_ICON := "score_10000"
const DEFAULT_UNLOCKED_UPGRADES: Array[String] = [
	"twin_missiles",
	"bigger_magazine",
	"temporary_shield",
	"near_miss_amplifier",
	"combo_battery",
	"interceptor_bonus",
]
const DEFAULT_UNLOCKED_POWERUPS: Array[String] = ["shield_bubble", "score_rush", "ammo_magnet"]
const DEFAULT_UNLOCKED_OBJECTIVES: Array[String] = ["rescue_pickup"]
const ALL_DEPTH_UPGRADES: Array[String] = [
	"twin_missiles",
	"homing_missiles",
	"bigger_magazine",
	"faster_fire_rate",
	"bigger_blast",
	"refund_chamber",
	"temporary_shield",
	"stronger_recovery",
	"stabilizers",
	"rotor_wash",
	"near_miss_amplifier",
	"combo_battery",
	"interceptor_bonus",
	"precision_payoff",
]
const ALL_DEPTH_POWERUPS: Array[String] = ["shield_bubble", "score_rush", "missile_overdrive", "ammo_magnet", "emp_burst", "afterburner_burst"]
const ALL_DEPTH_OBJECTIVES: Array[String] = ["rescue_pickup", "reactor_chain"]

var validation_mode_enabled: bool = false

var _unlocked_vehicles: Array[String] = [DEFAULT_VEHICLE_ID]
var _equipped_vehicle_id: String = DEFAULT_VEHICLE_ID
var _unlocked_vehicle_skins: Dictionary = {DEFAULT_VEHICLE_ID: [DEFAULT_SKIN_ID]}
var _equipped_vehicle_skins: Dictionary = {DEFAULT_VEHICLE_ID: DEFAULT_SKIN_ID}
var _vehicle_skin_progress: Dictionary = {}
var _global_skin_unlocks: Array[String] = []
var _best_score_milestones: Dictionary = {SCORE_MILESTONE_ORIGINAL_ICON: false}
var _unlocked_upgrade_ids: Array[String] = DEFAULT_UNLOCKED_UPGRADES.duplicate()
var _unlocked_powerup_ids: Array[String] = DEFAULT_UNLOCKED_POWERUPS.duplicate()
var _unlocked_objective_ids: Array[String] = DEFAULT_UNLOCKED_OBJECTIVES.duplicate()
var _depth_unlock_progress: Dictionary = {}
var _seen_vehicle_lore: Array[String] = []
var _seen_skin_lore: Array[String] = []
var _vehicle_catalog_version_seen: int = 1
var _total_daily_missions_completed: int = 0
var _daily_streak: int = 0
var _last_completed_daily_date: String = ""
var _missions_intro_seen: bool = false
var _daily_reminders_enabled: bool = true
var _leaderboard_bonus_vehicle_access: bool = false
var _top_skin_request: HTTPRequest
var _top_skin_request_in_flight: bool = false

func _ready() -> void:
	_ensure_top_skin_request()
	load_profile()
	if not validation_mode_enabled and OnlineLeaderboardScript.is_configured() and not OnlineLeaderboardScript.is_validation_run():
		call_deferred("refresh_top_player_skin_access")

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		_apply_defaults()
		save_profile()
		return

	_unlocked_vehicles = _sanitize_vehicle_ids(config.get_value(PROFILE_SECTION, "unlocked_vehicles", config.get_value(PROFILE_SECTION, "unlocked_skins", [DEFAULT_VEHICLE_ID])))
	_equipped_vehicle_id = _resolve_vehicle_id(str(config.get_value(PROFILE_SECTION, "equipped_vehicle_id", config.get_value(PROFILE_SECTION, "equipped_skin_id", DEFAULT_VEHICLE_ID))))
	_unlocked_vehicle_skins = _sanitize_vehicle_skin_unlocks(config.get_value(PROFILE_SECTION, "unlocked_vehicle_skins", {}))
	_equipped_vehicle_skins = _sanitize_equipped_vehicle_skins(config.get_value(PROFILE_SECTION, "equipped_vehicle_skins", {}))
	_vehicle_skin_progress = _sanitize_vehicle_skin_progress(config.get_value(PROFILE_SECTION, "vehicle_skin_progress", {}))
	_global_skin_unlocks = _sanitize_string_array(config.get_value(PROFILE_SECTION, "global_skin_unlocks", []))
	_best_score_milestones = _sanitize_bool_dictionary(config.get_value(PROFILE_SECTION, "best_score_milestones", {SCORE_MILESTONE_ORIGINAL_ICON: false}))
	_unlocked_upgrade_ids = _sanitize_depth_ids(config.get_value(PROFILE_SECTION, "unlocked_upgrade_ids", DEFAULT_UNLOCKED_UPGRADES), ALL_DEPTH_UPGRADES, DEFAULT_UNLOCKED_UPGRADES)
	_unlocked_powerup_ids = _sanitize_depth_ids(config.get_value(PROFILE_SECTION, "unlocked_powerup_ids", DEFAULT_UNLOCKED_POWERUPS), ALL_DEPTH_POWERUPS, DEFAULT_UNLOCKED_POWERUPS)
	_unlocked_objective_ids = _sanitize_depth_ids(config.get_value(PROFILE_SECTION, "unlocked_objective_ids", DEFAULT_UNLOCKED_OBJECTIVES), ALL_DEPTH_OBJECTIVES, DEFAULT_UNLOCKED_OBJECTIVES)
	_depth_unlock_progress = _sanitize_depth_unlock_progress(config.get_value(PROFILE_SECTION, "depth_unlock_progress", {}))
	_seen_vehicle_lore = _sanitize_string_array(config.get_value(PROFILE_SECTION, "seen_vehicle_lore", []))
	_seen_skin_lore = _sanitize_string_array(config.get_value(PROFILE_SECTION, "seen_skin_lore", []))
	_vehicle_catalog_version_seen = maxi(int(config.get_value(PROFILE_SECTION, "vehicle_catalog_version_seen", 1)), 1)
	_total_daily_missions_completed = maxi(int(config.get_value(PROFILE_SECTION, "total_daily_missions_completed", 0)), 0)
	_daily_streak = maxi(int(config.get_value(PROFILE_SECTION, "daily_streak", 0)), 0)
	_last_completed_daily_date = str(config.get_value(PROFILE_SECTION, "last_completed_daily_date", ""))
	_missions_intro_seen = bool(config.get_value(PROFILE_SECTION, "missions_intro_seen", false))
	_daily_reminders_enabled = bool(config.get_value(PROFILE_SECTION, "daily_reminders_enabled", true))
	_leaderboard_bonus_vehicle_access = bool(config.get_value(PROFILE_SECTION, "leaderboard_bonus_skin_access", false))
	_validate_profile_state()
	_emit_profile_changed()

func save_profile() -> void:
	if validation_mode_enabled:
		return
	var config := ConfigFile.new()
	config.set_value(PROFILE_SECTION, "unlocked_skins", _unlocked_vehicles.duplicate())
	config.set_value(PROFILE_SECTION, "equipped_skin_id", get_equipped_vehicle_id())
	config.set_value(PROFILE_SECTION, "unlocked_vehicles", _unlocked_vehicles.duplicate())
	config.set_value(PROFILE_SECTION, "equipped_vehicle_id", get_equipped_vehicle_id())
	config.set_value(PROFILE_SECTION, "unlocked_vehicle_skins", _unlocked_vehicle_skins.duplicate(true))
	config.set_value(PROFILE_SECTION, "equipped_vehicle_skins", _equipped_vehicle_skins.duplicate(true))
	config.set_value(PROFILE_SECTION, "vehicle_skin_progress", _vehicle_skin_progress.duplicate(true))
	config.set_value(PROFILE_SECTION, "global_skin_unlocks", _global_skin_unlocks.duplicate())
	config.set_value(PROFILE_SECTION, "best_score_milestones", _best_score_milestones.duplicate(true))
	config.set_value(PROFILE_SECTION, "unlocked_upgrade_ids", _unlocked_upgrade_ids.duplicate())
	config.set_value(PROFILE_SECTION, "unlocked_powerup_ids", _unlocked_powerup_ids.duplicate())
	config.set_value(PROFILE_SECTION, "unlocked_objective_ids", _unlocked_objective_ids.duplicate())
	config.set_value(PROFILE_SECTION, "depth_unlock_progress", _depth_unlock_progress.duplicate(true))
	config.set_value(PROFILE_SECTION, "seen_vehicle_lore", _seen_vehicle_lore.duplicate())
	config.set_value(PROFILE_SECTION, "seen_skin_lore", _seen_skin_lore.duplicate())
	config.set_value(PROFILE_SECTION, "vehicle_catalog_version_seen", _vehicle_catalog_version_seen)
	config.set_value(PROFILE_SECTION, "total_daily_missions_completed", _total_daily_missions_completed)
	config.set_value(PROFILE_SECTION, "daily_streak", _daily_streak)
	config.set_value(PROFILE_SECTION, "last_completed_daily_date", _last_completed_daily_date)
	config.set_value(PROFILE_SECTION, "missions_intro_seen", _missions_intro_seen)
	config.set_value(PROFILE_SECTION, "daily_reminders_enabled", _daily_reminders_enabled)
	config.set_value(PROFILE_SECTION, "leaderboard_bonus_skin_access", _leaderboard_bonus_vehicle_access)
	config.save(PROFILE_PATH)

func is_vehicle_unlocked(vehicle_id: String) -> bool:
	return has_vehicle_access(vehicle_id)

func has_vehicle_access(vehicle_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty():
		return false
	if _is_dynamic_vehicle_id(resolved_vehicle_id):
		return _leaderboard_bonus_vehicle_access if resolved_vehicle_id == LEADERBOARD_BONUS_VEHICLE_ID else false
	return _unlocked_vehicles.has(resolved_vehicle_id)

func is_skin_unlocked(skin_id: String) -> bool:
	return has_vehicle_access(skin_id)

func has_skin_access(skin_id: String) -> bool:
	return has_vehicle_access(skin_id)

func unlock_vehicle(vehicle_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty() or _is_dynamic_vehicle_id(resolved_vehicle_id) or _unlocked_vehicles.has(resolved_vehicle_id):
		return false
	_unlocked_vehicles.append(resolved_vehicle_id)
	_sort_vehicle_ids(_unlocked_vehicles)
	_ensure_vehicle_records(resolved_vehicle_id)
	_persist_and_signal(true)
	return true

func unlock_skin(skin_id: String) -> bool:
	return unlock_vehicle(skin_id)

func get_unlocked_upgrade_ids() -> Array[String]:
	return _unlocked_upgrade_ids.duplicate()

func get_unlocked_powerup_ids() -> Array[String]:
	return _unlocked_powerup_ids.duplicate()

func get_unlocked_objective_ids() -> Array[String]:
	return _unlocked_objective_ids.duplicate()

func get_depth_unlock_progress() -> Dictionary:
	return _depth_unlock_progress.duplicate(true)

func apply_depth_run_progress(summary: Dictionary) -> Array[Dictionary]:
	var unlocks: Array[Dictionary] = []
	var previous_json := JSON.stringify({
		"upgrades": _unlocked_upgrade_ids,
		"powerups": _unlocked_powerup_ids,
		"objectives": _unlocked_objective_ids,
		"progress": _depth_unlock_progress,
	})

	_depth_unlock_progress["run_upgrades_chosen"] = int(_depth_unlock_progress.get("run_upgrades_chosen", 0)) + int(summary.get("upgrades_chosen", 0))
	_depth_unlock_progress["powerups_collected"] = int(_depth_unlock_progress.get("powerups_collected", 0)) + int(summary.get("powerups_collected", 0))
	_depth_unlock_progress["objectives_completed"] = int(_depth_unlock_progress.get("objectives_completed", 0)) + int(summary.get("objective_events_completed", 0))
	_depth_unlock_progress["elite_kills"] = int(_depth_unlock_progress.get("elite_kills", 0)) + int(summary.get("elite_kills", 0))
	_depth_unlock_progress["best_run_power"] = maxi(int(_depth_unlock_progress.get("best_run_power", 0)), int(summary.get("upgrades_chosen", 0)) + int(summary.get("powerups_collected", 0)))

	if int(_depth_unlock_progress.get("run_upgrades_chosen", 0)) >= 2:
		_add_depth_unlock(_unlocked_upgrade_ids, "faster_fire_rate", "upgrade", unlocks)
	if int(_depth_unlock_progress.get("run_upgrades_chosen", 0)) >= 4:
		_add_depth_unlock(_unlocked_upgrade_ids, "homing_missiles", "upgrade", unlocks)
	if int(_depth_unlock_progress.get("run_upgrades_chosen", 0)) >= 7:
		_add_depth_unlock(_unlocked_upgrade_ids, "refund_chamber", "upgrade", unlocks)
	if int(_depth_unlock_progress.get("powerups_collected", 0)) >= 2:
		_add_depth_unlock(_unlocked_powerup_ids, "missile_overdrive", "powerup", unlocks)
	if int(_depth_unlock_progress.get("powerups_collected", 0)) >= 4:
		_add_depth_unlock(_unlocked_powerup_ids, "emp_burst", "powerup", unlocks)
	if int(_depth_unlock_progress.get("powerups_collected", 0)) >= 6:
		_add_depth_unlock(_unlocked_powerup_ids, "afterburner_burst", "powerup", unlocks)
	if int(_depth_unlock_progress.get("objectives_completed", 0)) >= 1:
		_add_depth_unlock(_unlocked_objective_ids, "reactor_chain", "objective", unlocks)
	if int(_depth_unlock_progress.get("elite_kills", 0)) >= 1:
		_add_depth_unlock(_unlocked_upgrade_ids, "bigger_blast", "upgrade", unlocks)
		_add_depth_unlock(_unlocked_upgrade_ids, "stronger_recovery", "upgrade", unlocks)
	if int(_depth_unlock_progress.get("best_run_power", 0)) >= 5:
		_add_depth_unlock(_unlocked_upgrade_ids, "stabilizers", "upgrade", unlocks)
		_add_depth_unlock(_unlocked_upgrade_ids, "rotor_wash", "upgrade", unlocks)
		_add_depth_unlock(_unlocked_upgrade_ids, "precision_payoff", "upgrade", unlocks)

	var changed := previous_json != JSON.stringify({
		"upgrades": _unlocked_upgrade_ids,
		"powerups": _unlocked_powerup_ids,
		"objectives": _unlocked_objective_ids,
		"progress": _depth_unlock_progress,
	})
	if changed:
		save_profile()
		_emit_profile_changed()
	return unlocks

func get_unlocked_vehicles() -> Array[String]:
	return _unlocked_vehicles.duplicate()

func get_unlocked_skins() -> Array[String]:
	return get_unlocked_vehicles()

func get_equipped_vehicle_id() -> String:
	if has_vehicle_access(_equipped_vehicle_id):
		return _equipped_vehicle_id
	return DEFAULT_VEHICLE_ID

func get_equipped_skin_id() -> String:
	return get_equipped_vehicle_id()

func equip_vehicle(vehicle_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty() or not has_vehicle_access(resolved_vehicle_id):
		return false
	if _equipped_vehicle_id == resolved_vehicle_id:
		return false
	_equipped_vehicle_id = resolved_vehicle_id
	_ensure_vehicle_records(resolved_vehicle_id)
	_persist_and_signal(true)
	return true

func equip_skin(skin_id: String) -> bool:
	return equip_vehicle(skin_id)

func is_vehicle_skin_unlocked(vehicle_id: String, skin_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty() or not has_vehicle_access(resolved_vehicle_id):
		return false
	var resolved_skin_id := _resolve_vehicle_skin_id(resolved_vehicle_id, skin_id)
	if resolved_skin_id.is_empty():
		return false
	if resolved_skin_id == DEFAULT_SKIN_ID:
		return true
	if resolved_skin_id == "original_icon":
		return _global_skin_unlocks.has("original_icon") and _is_original_icon_available(resolved_vehicle_id)
	var unlocked_for_vehicle := _get_unlocked_skin_array(resolved_vehicle_id)
	return unlocked_for_vehicle.has(resolved_skin_id)

func unlock_vehicle_skin(vehicle_id: String, skin_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	var resolved_skin_id := _resolve_vehicle_skin_id(resolved_vehicle_id, skin_id)
	if resolved_vehicle_id.is_empty() or resolved_skin_id.is_empty():
		return false
	if not has_vehicle_access(resolved_vehicle_id):
		return false
	if resolved_skin_id == DEFAULT_SKIN_ID:
		return false
	if resolved_skin_id == "original_icon":
		return false
	var unlocked_for_vehicle := _get_unlocked_skin_array(resolved_vehicle_id)
	if unlocked_for_vehicle.has(resolved_skin_id):
		return false
	unlocked_for_vehicle.append(resolved_skin_id)
	_sort_skin_ids_for_vehicle(resolved_vehicle_id, unlocked_for_vehicle)
	_unlocked_vehicle_skins[resolved_vehicle_id] = unlocked_for_vehicle
	_persist_and_signal(true)
	return true

func unlock_skin_for_all_available_original_icons(skin_id: String = "original_icon") -> Array[Dictionary]:
	if skin_id != "original_icon":
		return []
	if not _global_skin_unlocks.has("original_icon"):
		_global_skin_unlocks.append("original_icon")
	_best_score_milestones[SCORE_MILESTONE_ORIGINAL_ICON] = true
	var unlocked: Array[Dictionary] = []
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_ids"):
		for vehicle_id in helicopter_skins.get_vehicle_ids():
			if helicopter_skins.has_method("is_original_icon_available") and helicopter_skins.is_original_icon_available(vehicle_id):
				unlocked.append({
					"unlock_type": "global_skin_set",
					"vehicle_id": vehicle_id,
					"skin_id": "original_icon",
				})
	_persist_and_signal(true)
	return unlocked

func get_equipped_vehicle_skin_id(vehicle_id: String) -> String:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty():
		return DEFAULT_SKIN_ID
	_ensure_vehicle_records(resolved_vehicle_id)
	var equipped_skin_id := str(_equipped_vehicle_skins.get(resolved_vehicle_id, DEFAULT_SKIN_ID))
	return equipped_skin_id if is_vehicle_skin_unlocked(resolved_vehicle_id, equipped_skin_id) else DEFAULT_SKIN_ID

func equip_vehicle_skin(vehicle_id: String, skin_id: String) -> bool:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	var resolved_skin_id := _resolve_vehicle_skin_id(resolved_vehicle_id, skin_id)
	if resolved_vehicle_id.is_empty() or resolved_skin_id.is_empty():
		return false
	if not is_vehicle_skin_unlocked(resolved_vehicle_id, resolved_skin_id):
		return false
	if get_equipped_vehicle_skin_id(resolved_vehicle_id) == resolved_skin_id:
		return false
	_equipped_vehicle_skins[resolved_vehicle_id] = resolved_skin_id
	_persist_and_signal(true)
	return true

func get_vehicle_skin_progress(vehicle_id: String) -> Dictionary:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty():
		return _default_vehicle_skin_progress()
	_ensure_vehicle_records(resolved_vehicle_id)
	return (_vehicle_skin_progress.get(resolved_vehicle_id, _default_vehicle_skin_progress()) as Dictionary).duplicate(true)

func apply_run_skin_progress(vehicle_id: String, summary: Dictionary) -> Array[Dictionary]:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty() or not has_vehicle_access(resolved_vehicle_id):
		return []
	_ensure_vehicle_records(resolved_vehicle_id)
	var had_gold_mastery_bonus_vehicle := has_vehicle_access(GOLD_MASTERY_BONUS_VEHICLE_ID)

	var progress := get_vehicle_skin_progress(resolved_vehicle_id)
	progress["runs_completed"] = int(progress.get("runs_completed", 0)) + 1
	progress["near_misses"] = int(progress.get("near_misses", 0)) + int(summary.get("near_misses", 0))
	progress["projectile_intercepts"] = int(progress.get("projectile_intercepts", 0)) + int(summary.get("projectile_intercepts", 0))
	progress["best_score"] = maxi(int(progress.get("best_score", 0)), int(summary.get("score", 0)))
	_vehicle_skin_progress[resolved_vehicle_id] = progress

	var unlocked: Array[Dictionary] = []
	if int(progress.get("runs_completed", 0)) >= 5 and unlock_vehicle_skin(resolved_vehicle_id, "desert"):
		unlocked.append(_build_skin_unlock_entry(resolved_vehicle_id, "desert"))
	if int(progress.get("near_misses", 0)) >= 25 and unlock_vehicle_skin(resolved_vehicle_id, "neon"):
		unlocked.append(_build_skin_unlock_entry(resolved_vehicle_id, "neon"))
	if int(progress.get("projectile_intercepts", 0)) >= 10 and unlock_vehicle_skin(resolved_vehicle_id, "prototype"):
		unlocked.append(_build_skin_unlock_entry(resolved_vehicle_id, "prototype"))
	if int(progress.get("best_score", 0)) >= 5000 and unlock_vehicle_skin(resolved_vehicle_id, "gold"):
		unlocked.append(_build_skin_unlock_entry(resolved_vehicle_id, "gold"))
	if not had_gold_mastery_bonus_vehicle and has_vehicle_access(GOLD_MASTERY_BONUS_VEHICLE_ID):
		unlocked.append(_build_vehicle_unlock_entry(GOLD_MASTERY_BONUS_VEHICLE_ID))

	if int(summary.get("score", 0)) >= 10000 and not has_score_milestone(SCORE_MILESTONE_ORIGINAL_ICON):
		mark_score_milestone(SCORE_MILESTONE_ORIGINAL_ICON)
		if not _global_skin_unlocks.has("original_icon"):
			unlocked.append({
				"unlock_type": "global_skin_set",
				"skin_id": "original_icon",
				"title": "Original Icon",
			})
		unlock_skin_for_all_available_original_icons("original_icon")
	else:
		_persist_and_signal(true)

	return unlocked

func apply_daily_mission_vehicle_credit(vehicle_id: String, completed_count: int) -> Array[Dictionary]:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	var safe_completed_count := maxi(completed_count, 0)
	if resolved_vehicle_id.is_empty() or safe_completed_count <= 0 or not has_vehicle_access(resolved_vehicle_id):
		return []
	_ensure_vehicle_records(resolved_vehicle_id)

	var progress := get_vehicle_skin_progress(resolved_vehicle_id)
	progress["daily_missions_completed"] = int(progress.get("daily_missions_completed", 0)) + safe_completed_count
	_vehicle_skin_progress[resolved_vehicle_id] = progress

	var unlocked: Array[Dictionary] = []
	if int(progress.get("daily_missions_completed", 0)) >= 3 and unlock_vehicle_skin(resolved_vehicle_id, "arctic"):
		unlocked.append(_build_skin_unlock_entry(resolved_vehicle_id, "arctic"))

	_persist_and_signal(true)
	return unlocked

func has_score_milestone(milestone_id: String) -> bool:
	return bool(_best_score_milestones.get(milestone_id, false))

func mark_score_milestone(milestone_id: String) -> bool:
	if has_score_milestone(milestone_id):
		return false
	_best_score_milestones[milestone_id] = true
	_persist_and_signal(true)
	return true

func has_seen_vehicle_lore(vehicle_id: String) -> bool:
	return _seen_vehicle_lore.has(_resolve_vehicle_id(vehicle_id))

func mark_vehicle_lore_seen(vehicle_id: String) -> void:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty() or _seen_vehicle_lore.has(resolved_vehicle_id):
		return
	_seen_vehicle_lore.append(resolved_vehicle_id)
	_persist_and_signal(true)

func has_seen_skin_lore(vehicle_id: String, skin_id: String) -> bool:
	return _seen_skin_lore.has("%s:%s" % [_resolve_vehicle_id(vehicle_id), _resolve_vehicle_skin_id(_resolve_vehicle_id(vehicle_id), skin_id)])

func mark_skin_lore_seen(vehicle_id: String, skin_id: String) -> void:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	var resolved_skin_id := _resolve_vehicle_skin_id(resolved_vehicle_id, skin_id)
	if resolved_vehicle_id.is_empty() or resolved_skin_id.is_empty():
		return
	var key := "%s:%s" % [resolved_vehicle_id, resolved_skin_id]
	if _seen_skin_lore.has(key):
		return
	_seen_skin_lore.append(key)
	_persist_and_signal(true)

func get_profile_sync_summary() -> Dictionary:
	return {
		"equipped_skin_id": get_equipped_vehicle_id(),
		"unlocked_skins": get_unlocked_vehicles(),
		"equipped_vehicle_id": get_equipped_vehicle_id(),
		"equipped_vehicle_skin_id": get_equipped_vehicle_skin_id(get_equipped_vehicle_id()),
		"unlocked_vehicles": get_unlocked_vehicles(),
		"unlocked_vehicle_skins": _unlocked_vehicle_skins.duplicate(true),
		"equipped_vehicle_skins": _equipped_vehicle_skins.duplicate(true),
		"vehicle_skin_progress": _vehicle_skin_progress.duplicate(true),
		"global_skin_unlocks": _global_skin_unlocks.duplicate(),
		"best_score_milestones": _best_score_milestones.duplicate(true),
		"unlocked_upgrade_ids": _unlocked_upgrade_ids.duplicate(),
		"unlocked_powerup_ids": _unlocked_powerup_ids.duplicate(),
		"unlocked_objective_ids": _unlocked_objective_ids.duplicate(),
		"depth_unlock_progress": _depth_unlock_progress.duplicate(true),
		"seen_vehicle_lore": _seen_vehicle_lore.duplicate(),
		"seen_skin_lore": _seen_skin_lore.duplicate(),
		"vehicle_catalog_version": _vehicle_catalog_version_seen,
		"total_daily_missions_completed": _total_daily_missions_completed,
		"daily_streak": _daily_streak,
		"last_completed_daily_date": _last_completed_daily_date,
		"daily_reminders_enabled": _daily_reminders_enabled,
		"missions_intro_seen": _missions_intro_seen,
	}

func get_profile_summary() -> Dictionary:
	return get_profile_sync_summary()

func merge_remote_profile(summary: Dictionary) -> bool:
	return apply_remote_profile_summary(summary)

func replace_remote_profile(summary: Dictionary) -> bool:
	if summary.is_empty():
		return false
	var previous_summary_json := JSON.stringify(get_profile_sync_summary())
	var previous_bonus_access := _leaderboard_bonus_vehicle_access
	_unlocked_vehicles = _sanitize_vehicle_ids(summary.get("unlocked_vehicles", summary.get("unlocked_skins", [DEFAULT_VEHICLE_ID])))
	_equipped_vehicle_id = _resolve_vehicle_id(str(summary.get("equipped_vehicle_id", summary.get("equipped_skin_id", DEFAULT_VEHICLE_ID))))
	_unlocked_vehicle_skins = _sanitize_vehicle_skin_unlocks(summary.get("unlocked_vehicle_skins", {}))
	_equipped_vehicle_skins = _sanitize_equipped_vehicle_skins(summary.get("equipped_vehicle_skins", {}))
	_vehicle_skin_progress = _sanitize_vehicle_skin_progress(summary.get("vehicle_skin_progress", {}))
	_global_skin_unlocks = _sanitize_string_array(summary.get("global_skin_unlocks", []))
	_best_score_milestones = _sanitize_bool_dictionary(summary.get("best_score_milestones", {SCORE_MILESTONE_ORIGINAL_ICON: false}))
	_unlocked_upgrade_ids = _sanitize_depth_ids(summary.get("unlocked_upgrade_ids", DEFAULT_UNLOCKED_UPGRADES), ALL_DEPTH_UPGRADES, DEFAULT_UNLOCKED_UPGRADES)
	_unlocked_powerup_ids = _sanitize_depth_ids(summary.get("unlocked_powerup_ids", DEFAULT_UNLOCKED_POWERUPS), ALL_DEPTH_POWERUPS, DEFAULT_UNLOCKED_POWERUPS)
	_unlocked_objective_ids = _sanitize_depth_ids(summary.get("unlocked_objective_ids", DEFAULT_UNLOCKED_OBJECTIVES), ALL_DEPTH_OBJECTIVES, DEFAULT_UNLOCKED_OBJECTIVES)
	_depth_unlock_progress = _sanitize_depth_unlock_progress(summary.get("depth_unlock_progress", {}))
	_seen_vehicle_lore = _sanitize_string_array(summary.get("seen_vehicle_lore", []))
	_seen_skin_lore = _sanitize_string_array(summary.get("seen_skin_lore", []))
	_vehicle_catalog_version_seen = maxi(int(summary.get("vehicle_catalog_version", 1)), 1)
	_total_daily_missions_completed = maxi(int(summary.get("total_daily_missions_completed", 0)), 0)
	_daily_streak = maxi(int(summary.get("daily_streak", 0)), 0)
	_last_completed_daily_date = str(summary.get("last_completed_daily_date", ""))
	_missions_intro_seen = bool(summary.get("missions_intro_seen", false))
	_daily_reminders_enabled = bool(summary.get("daily_reminders_enabled", true))
	_leaderboard_bonus_vehicle_access = false
	_validate_profile_state()
	var changed := previous_summary_json != JSON.stringify(get_profile_sync_summary()) or previous_bonus_access != _leaderboard_bonus_vehicle_access
	if not changed:
		return false
	save_profile()
	_emit_profile_changed()
	if not validation_mode_enabled and OnlineLeaderboardScript.is_configured() and not OnlineLeaderboardScript.is_validation_run():
		call_deferred("refresh_top_player_skin_access")
	return true

func apply_remote_profile_summary(summary: Dictionary) -> bool:
	var remote_unlocked_vehicles := _sanitize_vehicle_ids(summary.get("unlocked_vehicles", summary.get("unlocked_skins", _unlocked_vehicles)))
	var merged_unlocked_vehicles := _unlocked_vehicles.duplicate()
	for vehicle_id in remote_unlocked_vehicles:
		if not merged_unlocked_vehicles.has(vehicle_id) and not _is_dynamic_vehicle_id(vehicle_id):
			merged_unlocked_vehicles.append(vehicle_id)
	_sort_vehicle_ids(merged_unlocked_vehicles)

	var remote_unlocked_vehicle_skins := _sanitize_vehicle_skin_unlocks(summary.get("unlocked_vehicle_skins", {}))
	var remote_equipped_vehicle_skins := _sanitize_equipped_vehicle_skins(summary.get("equipped_vehicle_skins", {}))
	var remote_progress := _sanitize_vehicle_skin_progress(summary.get("vehicle_skin_progress", {}))
	var remote_global_unlocks := _sanitize_string_array(summary.get("global_skin_unlocks", []))
	var remote_milestones := _sanitize_bool_dictionary(summary.get("best_score_milestones", {}))
	var remote_upgrade_ids := _sanitize_depth_ids(summary.get("unlocked_upgrade_ids", DEFAULT_UNLOCKED_UPGRADES), ALL_DEPTH_UPGRADES, DEFAULT_UNLOCKED_UPGRADES)
	var remote_powerup_ids := _sanitize_depth_ids(summary.get("unlocked_powerup_ids", DEFAULT_UNLOCKED_POWERUPS), ALL_DEPTH_POWERUPS, DEFAULT_UNLOCKED_POWERUPS)
	var remote_objective_ids := _sanitize_depth_ids(summary.get("unlocked_objective_ids", DEFAULT_UNLOCKED_OBJECTIVES), ALL_DEPTH_OBJECTIVES, DEFAULT_UNLOCKED_OBJECTIVES)
	var remote_depth_progress := _sanitize_depth_unlock_progress(summary.get("depth_unlock_progress", {}))
	var remote_seen_vehicle_lore := _sanitize_string_array(summary.get("seen_vehicle_lore", []))
	var remote_seen_skin_lore := _sanitize_string_array(summary.get("seen_skin_lore", []))

	var merged_skin_unlocks := _merge_vehicle_skin_unlocks(_unlocked_vehicle_skins, remote_unlocked_vehicle_skins, merged_unlocked_vehicles)
	var merged_equipped_vehicle_skins := _merge_equipped_vehicle_skins(_equipped_vehicle_skins, remote_equipped_vehicle_skins, merged_unlocked_vehicles, merged_skin_unlocks, remote_global_unlocks)
	var merged_progress := _merge_vehicle_skin_progress(_vehicle_skin_progress, remote_progress)
	var merged_global_unlocks := _merge_string_arrays(_global_skin_unlocks, remote_global_unlocks)
	var merged_milestones := _merge_bool_dictionaries(_best_score_milestones, remote_milestones)
	var merged_upgrade_ids := _merge_string_arrays(_unlocked_upgrade_ids, remote_upgrade_ids)
	var merged_powerup_ids := _merge_string_arrays(_unlocked_powerup_ids, remote_powerup_ids)
	var merged_objective_ids := _merge_string_arrays(_unlocked_objective_ids, remote_objective_ids)
	var merged_depth_progress := _merge_counter_dictionary(_depth_unlock_progress, remote_depth_progress)
	var merged_seen_vehicle_lore := _merge_string_arrays(_seen_vehicle_lore, remote_seen_vehicle_lore)
	var merged_seen_skin_lore := _merge_string_arrays(_seen_skin_lore, remote_seen_skin_lore)
	var merged_total := maxi(_total_daily_missions_completed, int(summary.get("total_daily_missions_completed", _total_daily_missions_completed)))
	var merged_streak := maxi(_daily_streak, int(summary.get("daily_streak", _daily_streak)))
	var merged_date := _pick_later_date(_last_completed_daily_date, str(summary.get("last_completed_daily_date", "")))
	var merged_intro_seen := _missions_intro_seen or bool(summary.get("missions_intro_seen", false))
	var merged_catalog_version := maxi(_vehicle_catalog_version_seen, int(summary.get("vehicle_catalog_version", _vehicle_catalog_version_seen)))
	var merged_daily_reminders_enabled := bool(summary.get("daily_reminders_enabled", _daily_reminders_enabled))

	var remote_equipped_vehicle_id := _resolve_vehicle_id(str(summary.get("equipped_vehicle_id", summary.get("equipped_skin_id", _equipped_vehicle_id))))
	var merged_equipped_vehicle_id := _equipped_vehicle_id
	if not _is_vehicle_accessible_with_unlocks(merged_equipped_vehicle_id, merged_unlocked_vehicles):
		merged_equipped_vehicle_id = remote_equipped_vehicle_id if _is_vehicle_accessible_with_unlocks(remote_equipped_vehicle_id, merged_unlocked_vehicles) else DEFAULT_VEHICLE_ID

	var changed := merged_unlocked_vehicles != _unlocked_vehicles \
		or merged_equipped_vehicle_id != _equipped_vehicle_id \
		or JSON.stringify(merged_skin_unlocks) != JSON.stringify(_unlocked_vehicle_skins) \
		or JSON.stringify(merged_equipped_vehicle_skins) != JSON.stringify(_equipped_vehicle_skins) \
		or JSON.stringify(merged_progress) != JSON.stringify(_vehicle_skin_progress) \
		or merged_global_unlocks != _global_skin_unlocks \
		or JSON.stringify(merged_milestones) != JSON.stringify(_best_score_milestones) \
		or merged_upgrade_ids != _unlocked_upgrade_ids \
		or merged_powerup_ids != _unlocked_powerup_ids \
		or merged_objective_ids != _unlocked_objective_ids \
		or JSON.stringify(merged_depth_progress) != JSON.stringify(_depth_unlock_progress) \
		or merged_seen_vehicle_lore != _seen_vehicle_lore \
		or merged_seen_skin_lore != _seen_skin_lore \
		or merged_total != _total_daily_missions_completed \
		or merged_streak != _daily_streak \
		or merged_date != _last_completed_daily_date \
		or merged_intro_seen != _missions_intro_seen \
		or merged_daily_reminders_enabled != _daily_reminders_enabled \
		or merged_catalog_version != _vehicle_catalog_version_seen

	if not changed:
		return false

	_unlocked_vehicles = merged_unlocked_vehicles
	_equipped_vehicle_id = merged_equipped_vehicle_id
	_unlocked_vehicle_skins = merged_skin_unlocks
	_equipped_vehicle_skins = merged_equipped_vehicle_skins
	_vehicle_skin_progress = merged_progress
	_global_skin_unlocks = merged_global_unlocks
	_best_score_milestones = merged_milestones
	_unlocked_upgrade_ids = merged_upgrade_ids
	_unlocked_powerup_ids = merged_powerup_ids
	_unlocked_objective_ids = merged_objective_ids
	_depth_unlock_progress = merged_depth_progress
	_seen_vehicle_lore = merged_seen_vehicle_lore
	_seen_skin_lore = merged_seen_skin_lore
	_total_daily_missions_completed = merged_total
	_daily_streak = merged_streak
	_last_completed_daily_date = merged_date
	_missions_intro_seen = merged_intro_seen
	_daily_reminders_enabled = merged_daily_reminders_enabled
	_vehicle_catalog_version_seen = merged_catalog_version
	_validate_profile_state()
	save_profile()
	_emit_profile_changed()
	return true

func restore_profile_from_cloud() -> void:
	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("pull_remote_profile_state"):
		sync_queue.pull_remote_profile_state()
	elif sync_queue != null and sync_queue.has_method("flush"):
		sync_queue.flush()

func apply_validation_state(summary: Dictionary) -> void:
	validation_mode_enabled = true
	_unlocked_vehicles = _sanitize_vehicle_ids(summary.get("unlocked_vehicles", summary.get("unlocked_skins", [DEFAULT_VEHICLE_ID])))
	_equipped_vehicle_id = _resolve_vehicle_id(str(summary.get("equipped_vehicle_id", summary.get("equipped_skin_id", DEFAULT_VEHICLE_ID))))
	_unlocked_vehicle_skins = _sanitize_vehicle_skin_unlocks(summary.get("unlocked_vehicle_skins", {}))
	_equipped_vehicle_skins = _sanitize_equipped_vehicle_skins(summary.get("equipped_vehicle_skins", {}))
	_vehicle_skin_progress = _sanitize_vehicle_skin_progress(summary.get("vehicle_skin_progress", {}))
	_global_skin_unlocks = _sanitize_string_array(summary.get("global_skin_unlocks", []))
	_best_score_milestones = _sanitize_bool_dictionary(summary.get("best_score_milestones", {SCORE_MILESTONE_ORIGINAL_ICON: false}))
	_unlocked_upgrade_ids = _sanitize_depth_ids(summary.get("unlocked_upgrade_ids", DEFAULT_UNLOCKED_UPGRADES), ALL_DEPTH_UPGRADES, DEFAULT_UNLOCKED_UPGRADES)
	_unlocked_powerup_ids = _sanitize_depth_ids(summary.get("unlocked_powerup_ids", DEFAULT_UNLOCKED_POWERUPS), ALL_DEPTH_POWERUPS, DEFAULT_UNLOCKED_POWERUPS)
	_unlocked_objective_ids = _sanitize_depth_ids(summary.get("unlocked_objective_ids", DEFAULT_UNLOCKED_OBJECTIVES), ALL_DEPTH_OBJECTIVES, DEFAULT_UNLOCKED_OBJECTIVES)
	_depth_unlock_progress = _sanitize_depth_unlock_progress(summary.get("depth_unlock_progress", {}))
	_seen_vehicle_lore = _sanitize_string_array(summary.get("seen_vehicle_lore", []))
	_seen_skin_lore = _sanitize_string_array(summary.get("seen_skin_lore", []))
	_vehicle_catalog_version_seen = maxi(int(summary.get("vehicle_catalog_version", 1)), 1)
	_total_daily_missions_completed = maxi(int(summary.get("total_daily_missions_completed", 0)), 0)
	_daily_streak = maxi(int(summary.get("daily_streak", 0)), 0)
	_last_completed_daily_date = str(summary.get("last_completed_daily_date", ""))
	_missions_intro_seen = bool(summary.get("missions_intro_seen", false))
	_daily_reminders_enabled = bool(summary.get("daily_reminders_enabled", true))
	_leaderboard_bonus_vehicle_access = bool(summary.get("leaderboard_bonus_skin_access", summary.get("pottercar_access", false)))
	_validate_profile_state()
	_emit_profile_changed()

func get_total_daily_missions_completed() -> int:
	return _total_daily_missions_completed

func increment_total_daily_missions_completed(amount: int = 1) -> void:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return
	_total_daily_missions_completed += safe_amount
	_persist_and_signal(true)

func get_daily_streak() -> int:
	return _daily_streak

func update_daily_streak(completed_date_key: String) -> void:
	var normalized_date := completed_date_key.strip_edges()
	if normalized_date.is_empty() or _last_completed_daily_date == normalized_date:
		return
	var previous_streak := _daily_streak
	if _last_completed_daily_date.is_empty():
		_daily_streak = 1
	else:
		var previous_unix := Time.get_unix_time_from_datetime_string("%sT00:00:00Z" % _last_completed_daily_date)
		var current_unix := Time.get_unix_time_from_datetime_string("%sT00:00:00Z" % normalized_date)
		var day_difference := int(round((current_unix - previous_unix) / 86400.0))
		_daily_streak = _daily_streak + 1 if day_difference == 1 else 1
	_last_completed_daily_date = normalized_date
	_persist_and_signal(true)
	if _daily_streak != previous_streak and (_daily_streak == 7 or _daily_streak == 14 or _daily_streak == 30):
		_queue_streak_achievement_screenshot()

func _queue_streak_achievement_screenshot() -> void:
	var screenshot_manager = get_node_or_null("/root/AchievementScreenshotManager")
	if screenshot_manager == null or not screenshot_manager.has_method("queue_event"):
		return
	screenshot_manager.queue_event(
		"daily_streak_%d" % _daily_streak,
		"Daily streak milestone",
		"Reached a %d-day daily mission streak." % _daily_streak,
		{"daily_streak": _daily_streak},
		true
	)

func are_daily_reminders_enabled() -> bool:
	return _daily_reminders_enabled

func set_daily_reminders_enabled(enabled: bool) -> void:
	if _daily_reminders_enabled == enabled:
		return
	_daily_reminders_enabled = enabled
	_persist_and_signal(true)

func has_seen_missions_intro() -> bool:
	return _missions_intro_seen

func mark_missions_intro_seen() -> void:
	if _missions_intro_seen:
		return
	_missions_intro_seen = true
	_persist_and_signal(true)

func has_unseen_vehicle_content() -> bool:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins == null or not helicopter_skins.has_method("get_vehicle_ids"):
		return false
	for vehicle_id in helicopter_skins.get_vehicle_ids():
		if not has_vehicle_access(vehicle_id):
			continue
		if not has_seen_vehicle_lore(vehicle_id):
			return true
	return false

func has_unseen_skin_content() -> bool:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins == null or not helicopter_skins.has_method("get_vehicle_ids") or not helicopter_skins.has_method("get_vehicle_skin_ids"):
		return false
	for vehicle_id in helicopter_skins.get_vehicle_ids():
		if not has_vehicle_access(vehicle_id):
			continue
		for skin_id in helicopter_skins.get_vehicle_skin_ids(vehicle_id):
			if not is_vehicle_skin_unlocked(vehicle_id, skin_id):
				continue
			if not has_seen_skin_lore(vehicle_id, skin_id):
				return true
	return false

func has_unseen_hangar_content() -> bool:
	return has_unseen_vehicle_content() or has_unseen_skin_content()

func get_next_unlock_preview() -> Dictionary:
	var helicopter_skins: Node = _get_helicopter_skins()
	if helicopter_skins == null:
		return {}

	if helicopter_skins.has_method("get_next_locked_vehicle"):
		var next_vehicle: Dictionary = helicopter_skins.get_next_locked_vehicle(_total_daily_missions_completed)
		if not next_vehicle.is_empty():
			var required := int(next_vehicle.get("required_completed_missions", _total_daily_missions_completed))
			return {
				"kind": "vehicle",
				"title": str(next_vehicle.get("display_name", "Next Unlock")),
				"detail": "Unlock with daily missions",
				"progress_text": "%d / %d daily missions" % [_total_daily_missions_completed, required],
				"completed": _total_daily_missions_completed,
				"required": required,
			}

	if not has_unlocked_gold_mastery_bonus_vehicle():
		var gold_count := get_gold_mastery_vehicle_count()
		return {
			"kind": "vehicle",
			"title": get_display_vehicle_name(GOLD_MASTERY_BONUS_VEHICLE_ID),
			"detail": "Unlock by earning gold skins",
			"progress_text": "Gold skins unlocked: %d / 3" % gold_count,
			"completed": gold_count,
			"required": 3,
		}

	if not has_score_milestone(SCORE_MILESTONE_ORIGINAL_ICON):
		var run_stats := get_node_or_null("/root/RunStats")
		var local_best := 0
		if run_stats != null and run_stats.has_method("get_local_best_score"):
			local_best = int(run_stats.get_local_best_score())
		return {
			"kind": "global_skin",
			"title": "Original Icon",
			"detail": "Reach 10,000 in one run",
			"progress_text": "Best: %d / 10000" % local_best,
			"completed": local_best,
			"required": 10000,
		}

	var equipped_vehicle_id := get_equipped_vehicle_id()
	if not is_vehicle_skin_unlocked(equipped_vehicle_id, "gold"):
		var progress: Dictionary = get_vehicle_skin_progress(equipped_vehicle_id)
		var best_score := int(progress.get("best_score", 0))
		return {
			"kind": "vehicle_skin",
			"title": "%s / Gold" % get_display_vehicle_name(equipped_vehicle_id),
			"detail": "Master this vehicle",
			"progress_text": "Best: %d / 5000" % best_score,
			"completed": best_score,
			"required": 5000,
		}

	return {
		"kind": "complete",
		"title": "Hangar Collection",
		"detail": "Everything in this build is unlocked",
		"progress_text": "Collection complete",
		"completed": 1,
		"required": 1,
	}

func refresh_top_player_skin_access() -> void:
	if validation_mode_enabled or not OnlineLeaderboardScript.is_configured() or _top_skin_request_in_flight:
		return
	_ensure_top_skin_request()
	if _top_skin_request == null:
		return
	var request_error := _top_skin_request.request(
		OnlineLeaderboardScript.get_top_entry_url(),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_GET
	)
	if request_error == OK:
		_top_skin_request_in_flight = true

func apply_leaderboard_entries(entries: Array) -> bool:
	var typed_entries: Array[Dictionary] = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			typed_entries.append(entry_variant)
	var best_entries := OnlineLeaderboardScript.get_best_entries(typed_entries)
	var local_player_id := OnlineLeaderboardScript.load_or_create_player_id()
	var is_top_player := false
	if not best_entries.is_empty():
		is_top_player = str(best_entries[0].get("player_id", "")) == local_player_id
	return apply_leaderboard_top_status(is_top_player)

func apply_leaderboard_top_status(is_top_player: bool) -> bool:
	return _apply_verified_bonus_vehicle_access(is_top_player)

func _apply_defaults() -> void:
	_unlocked_vehicles = [DEFAULT_VEHICLE_ID]
	_equipped_vehicle_id = DEFAULT_VEHICLE_ID
	_unlocked_vehicle_skins = {DEFAULT_VEHICLE_ID: [DEFAULT_SKIN_ID]}
	_equipped_vehicle_skins = {DEFAULT_VEHICLE_ID: DEFAULT_SKIN_ID}
	_vehicle_skin_progress = {DEFAULT_VEHICLE_ID: _default_vehicle_skin_progress()}
	_global_skin_unlocks = []
	_best_score_milestones = {SCORE_MILESTONE_ORIGINAL_ICON: false}
	_unlocked_upgrade_ids = DEFAULT_UNLOCKED_UPGRADES.duplicate()
	_unlocked_powerup_ids = DEFAULT_UNLOCKED_POWERUPS.duplicate()
	_unlocked_objective_ids = DEFAULT_UNLOCKED_OBJECTIVES.duplicate()
	_depth_unlock_progress = {}
	_seen_vehicle_lore = []
	_seen_skin_lore = []
	_vehicle_catalog_version_seen = 1
	_total_daily_missions_completed = 0
	_daily_streak = 0
	_last_completed_daily_date = ""
	_missions_intro_seen = false
	_daily_reminders_enabled = true
	_leaderboard_bonus_vehicle_access = false
	_validate_profile_state()

func _validate_profile_state() -> void:
	_unlocked_vehicles = _sanitize_vehicle_ids(_unlocked_vehicles)
	_apply_derived_vehicle_unlocks()
	for vehicle_id in _unlocked_vehicles:
		_ensure_vehicle_records(vehicle_id)
	if not has_vehicle_access(_equipped_vehicle_id):
		_equipped_vehicle_id = DEFAULT_VEHICLE_ID
	_ensure_vehicle_records(_equipped_vehicle_id)
	for vehicle_id in _unlocked_vehicles:
		var equipped_skin_id := str(_equipped_vehicle_skins.get(vehicle_id, DEFAULT_SKIN_ID))
		if not is_vehicle_skin_unlocked(vehicle_id, equipped_skin_id):
			_equipped_vehicle_skins[vehicle_id] = DEFAULT_SKIN_ID
	if _global_skin_unlocks.has("original_icon"):
		_best_score_milestones[SCORE_MILESTONE_ORIGINAL_ICON] = true
	_unlocked_upgrade_ids = _sanitize_depth_ids(_unlocked_upgrade_ids, ALL_DEPTH_UPGRADES, DEFAULT_UNLOCKED_UPGRADES)
	_unlocked_powerup_ids = _sanitize_depth_ids(_unlocked_powerup_ids, ALL_DEPTH_POWERUPS, DEFAULT_UNLOCKED_POWERUPS)
	_unlocked_objective_ids = _sanitize_depth_ids(_unlocked_objective_ids, ALL_DEPTH_OBJECTIVES, DEFAULT_UNLOCKED_OBJECTIVES)
	_depth_unlock_progress = _sanitize_depth_unlock_progress(_depth_unlock_progress)

func _ensure_vehicle_records(vehicle_id: String) -> void:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty():
		return
	if not _unlocked_vehicle_skins.has(resolved_vehicle_id):
		_unlocked_vehicle_skins[resolved_vehicle_id] = [DEFAULT_SKIN_ID]
	else:
		var unlocked_for_vehicle := _get_unlocked_skin_array(resolved_vehicle_id)
		if not unlocked_for_vehicle.has(DEFAULT_SKIN_ID):
			unlocked_for_vehicle.append(DEFAULT_SKIN_ID)
			_sort_skin_ids_for_vehicle(resolved_vehicle_id, unlocked_for_vehicle)
			_unlocked_vehicle_skins[resolved_vehicle_id] = unlocked_for_vehicle
	if not _equipped_vehicle_skins.has(resolved_vehicle_id):
		_equipped_vehicle_skins[resolved_vehicle_id] = DEFAULT_SKIN_ID
	if not _vehicle_skin_progress.has(resolved_vehicle_id):
		_vehicle_skin_progress[resolved_vehicle_id] = _default_vehicle_skin_progress()

func _sanitize_vehicle_ids(raw_value) -> Array[String]:
	var sanitized: Array[String] = [DEFAULT_VEHICLE_ID]
	if raw_value is Array:
		for vehicle_id_variant in raw_value:
			var resolved_vehicle_id := _resolve_vehicle_id(str(vehicle_id_variant))
			if resolved_vehicle_id.is_empty() or _is_dynamic_vehicle_id(resolved_vehicle_id) or sanitized.has(resolved_vehicle_id):
				continue
			sanitized.append(resolved_vehicle_id)
	_sort_vehicle_ids(sanitized)
	return sanitized

func _sanitize_vehicle_skin_unlocks(raw_value) -> Dictionary:
	var sanitized := {}
	if raw_value is Dictionary:
		for vehicle_id_variant in raw_value.keys():
			var resolved_vehicle_id := _resolve_vehicle_id(str(vehicle_id_variant))
			if resolved_vehicle_id.is_empty():
				continue
			var unlocked_for_vehicle: Array[String] = [DEFAULT_SKIN_ID]
			var raw_skin_array = raw_value[vehicle_id_variant]
			if raw_skin_array is Array:
				for skin_id_variant in raw_skin_array:
					var resolved_skin_id := _resolve_vehicle_skin_id(resolved_vehicle_id, str(skin_id_variant))
					if resolved_skin_id.is_empty() or resolved_skin_id == "original_icon" or unlocked_for_vehicle.has(resolved_skin_id):
						continue
					unlocked_for_vehicle.append(resolved_skin_id)
			_sort_skin_ids_for_vehicle(resolved_vehicle_id, unlocked_for_vehicle)
			sanitized[resolved_vehicle_id] = unlocked_for_vehicle
	for vehicle_id in _sanitize_vehicle_ids(_unlocked_vehicles):
		if not sanitized.has(vehicle_id):
			var default_unlocks: Array[String] = [DEFAULT_SKIN_ID]
			sanitized[vehicle_id] = default_unlocks
	return sanitized

func _sanitize_equipped_vehicle_skins(raw_value) -> Dictionary:
	var sanitized := {}
	if raw_value is Dictionary:
		for vehicle_id_variant in raw_value.keys():
			var resolved_vehicle_id := _resolve_vehicle_id(str(vehicle_id_variant))
			if resolved_vehicle_id.is_empty():
				continue
			sanitized[resolved_vehicle_id] = _resolve_vehicle_skin_id(resolved_vehicle_id, str(raw_value[vehicle_id_variant]))
	return sanitized

func _sanitize_vehicle_skin_progress(raw_value) -> Dictionary:
	var sanitized := {}
	if raw_value is Dictionary:
		for vehicle_id_variant in raw_value.keys():
			var resolved_vehicle_id := _resolve_vehicle_id(str(vehicle_id_variant))
			if resolved_vehicle_id.is_empty():
				continue
			if raw_value[vehicle_id_variant] is not Dictionary:
				continue
			var raw_progress: Dictionary = raw_value[vehicle_id_variant]
			var progress := _default_vehicle_skin_progress()
			progress["runs_completed"] = maxi(int(raw_progress.get("runs_completed", 0)), 0)
			progress["daily_missions_completed"] = maxi(int(raw_progress.get("daily_missions_completed", 0)), 0)
			progress["near_misses"] = maxi(int(raw_progress.get("near_misses", 0)), 0)
			progress["projectile_intercepts"] = maxi(int(raw_progress.get("projectile_intercepts", 0)), 0)
			progress["best_score"] = maxi(int(raw_progress.get("best_score", 0)), 0)
			sanitized[resolved_vehicle_id] = progress
	return sanitized

func _sanitize_bool_dictionary(raw_value) -> Dictionary:
	var sanitized := {SCORE_MILESTONE_ORIGINAL_ICON: false}
	if raw_value is Dictionary:
		for key in raw_value.keys():
			sanitized[str(key)] = bool(raw_value[key])
	return sanitized

func _sanitize_string_array(raw_value) -> Array[String]:
	var sanitized: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var clean_value := str(value).strip_edges()
			if clean_value.is_empty() or sanitized.has(clean_value):
				continue
			sanitized.append(clean_value)
	return sanitized

func _sanitize_depth_ids(raw_value, allowed_ids: Array, default_ids: Array) -> Array[String]:
	var allowed: Array[String] = []
	for id_variant in allowed_ids:
		allowed.append(str(id_variant))
	var sanitized: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var clean_value := str(value).strip_edges()
			if clean_value.is_empty() or sanitized.has(clean_value) or not allowed.has(clean_value):
				continue
			sanitized.append(clean_value)
	for default_variant in default_ids:
		var default_id := str(default_variant)
		if allowed.has(default_id) and not sanitized.has(default_id):
			sanitized.append(default_id)
	return sanitized

func _sanitize_depth_unlock_progress(raw_value) -> Dictionary:
	var sanitized := {}
	if raw_value is Dictionary:
		for key in raw_value.keys():
			sanitized[str(key)] = maxi(int(raw_value[key]), 0)
	return sanitized

func _default_vehicle_skin_progress() -> Dictionary:
	return {
		"runs_completed": 0,
		"daily_missions_completed": 0,
		"near_misses": 0,
		"projectile_intercepts": 0,
		"best_score": 0,
	}

func _resolve_vehicle_id(vehicle_id: String) -> String:
	if vehicle_id.strip_edges().is_empty():
		return ""
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("has_vehicle"):
		return vehicle_id if helicopter_skins.has_vehicle(vehicle_id) else ""
	if helicopter_skins != null and helicopter_skins.has_method("has_skin"):
		return vehicle_id if helicopter_skins.has_skin(vehicle_id) else ""
	return DEFAULT_VEHICLE_ID if vehicle_id == DEFAULT_VEHICLE_ID else vehicle_id

func _resolve_vehicle_skin_id(vehicle_id: String, skin_id: String) -> String:
	var resolved_vehicle_id := _resolve_vehicle_id(vehicle_id)
	if resolved_vehicle_id.is_empty():
		return ""
	if skin_id.strip_edges().is_empty():
		return DEFAULT_SKIN_ID
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_skin_ids"):
		return skin_id if helicopter_skins.get_vehicle_skin_ids(resolved_vehicle_id).has(skin_id) else ""
	return DEFAULT_SKIN_ID if skin_id == DEFAULT_SKIN_ID else ""

func _is_dynamic_vehicle_id(vehicle_id: String) -> bool:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("is_dynamic_vehicle"):
		return bool(helicopter_skins.is_dynamic_vehicle(vehicle_id))
	if helicopter_skins != null and helicopter_skins.has_method("is_dynamic_skin"):
		return bool(helicopter_skins.is_dynamic_skin(vehicle_id))
	return vehicle_id == LEADERBOARD_BONUS_VEHICLE_ID

func _is_original_icon_available(vehicle_id: String) -> bool:
	var helicopter_skins := _get_helicopter_skins()
	return helicopter_skins != null and helicopter_skins.has_method("is_original_icon_available") and bool(helicopter_skins.is_original_icon_available(vehicle_id))

func _get_unlocked_skin_array(vehicle_id: String) -> Array[String]:
	var unlocked_for_vehicle: Array[String] = []
	var stored_unlocks: Array = _unlocked_vehicle_skins.get(vehicle_id, [DEFAULT_SKIN_ID])
	for skin_id_variant in stored_unlocks:
		unlocked_for_vehicle.append(str(skin_id_variant))
	if not unlocked_for_vehicle.has(DEFAULT_SKIN_ID):
		unlocked_for_vehicle.append(DEFAULT_SKIN_ID)
	return unlocked_for_vehicle

func _apply_derived_vehicle_unlocks() -> void:
	if _unlocked_vehicles.has(GOLD_MASTERY_BONUS_VEHICLE_ID):
		return
	if _count_gold_vehicle_unlocks() < 3:
		return
	_unlocked_vehicles.append(GOLD_MASTERY_BONUS_VEHICLE_ID)
	_sort_vehicle_ids(_unlocked_vehicles)

func _count_gold_vehicle_unlocks() -> int:
	var helicopter_skins := _get_helicopter_skins()
	var count := 0
	for vehicle_id in _unlocked_vehicles:
		if vehicle_id == GOLD_MASTERY_BONUS_VEHICLE_ID or _is_dynamic_vehicle_id(vehicle_id):
			continue
		if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_skin_ids") and not helicopter_skins.get_vehicle_skin_ids(vehicle_id).has("gold"):
			continue
		if is_vehicle_skin_unlocked(vehicle_id, "gold"):
			count += 1
	return count

func get_gold_mastery_vehicle_count() -> int:
	return _count_gold_vehicle_unlocks()

func has_unlocked_gold_mastery_bonus_vehicle() -> bool:
	return _unlocked_vehicles.has(GOLD_MASTERY_BONUS_VEHICLE_ID)

func _build_vehicle_unlock_entry(vehicle_id: String) -> Dictionary:
	return {
		"unlock_type": "vehicle",
		"vehicle_id": vehicle_id,
		"title": get_display_vehicle_name(vehicle_id),
	}

func _build_skin_unlock_entry(vehicle_id: String, skin_id: String) -> Dictionary:
	return {
		"unlock_type": "vehicle_skin",
		"vehicle_id": vehicle_id,
		"skin_id": skin_id,
		"title": "%s / %s" % [get_display_vehicle_name(vehicle_id), get_display_skin_name(vehicle_id, skin_id)],
	}

func _build_depth_unlock_entry(unlock_type: String, unlock_id: String) -> Dictionary:
	return {
		"unlock_type": "depth_%s" % unlock_type,
		"id": unlock_id,
		"title": unlock_id.capitalize(),
	}

func _add_depth_unlock(target: Array[String], unlock_id: String, unlock_type: String, unlocks: Array[Dictionary]) -> void:
	if target.has(unlock_id):
		return
	target.append(unlock_id)
	unlocks.append(_build_depth_unlock_entry(unlock_type, unlock_id))

func get_display_vehicle_name(vehicle_id: String) -> String:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("get_display_name"):
		return str(helicopter_skins.get_display_name(vehicle_id))
	return vehicle_id

func get_display_skin_name(vehicle_id: String, skin_id: String) -> String:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_skin_data"):
		return str(helicopter_skins.get_vehicle_skin_data(vehicle_id, skin_id).get("display_name", skin_id))
	return skin_id

func _pick_later_date(a: String, b: String) -> String:
	var clean_a := a.strip_edges()
	var clean_b := b.strip_edges()
	if clean_a.is_empty():
		return clean_b
	if clean_b.is_empty():
		return clean_a
	return clean_b if clean_b > clean_a else clean_a

func _merge_string_arrays(a: Array[String], b: Array[String]) -> Array[String]:
	var merged := a.duplicate()
	for value in b:
		if not merged.has(value):
			merged.append(value)
	return merged

func _merge_bool_dictionaries(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged := a.duplicate(true)
	for key in b.keys():
		merged[str(key)] = bool(merged.get(str(key), false)) or bool(b[key])
	return merged

func _merge_counter_dictionary(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged := a.duplicate(true)
	for key in b.keys():
		var clean_key := str(key)
		merged[clean_key] = maxi(int(merged.get(clean_key, 0)), int(b[key]))
	return merged

func _merge_vehicle_skin_unlocks(local_unlocks: Dictionary, remote_unlocks: Dictionary, unlocked_vehicles: Array[String]) -> Dictionary:
	var merged := local_unlocks.duplicate(true)
	for vehicle_id in unlocked_vehicles:
		var local_array := _get_unlocked_skin_array(vehicle_id)
		var remote_array: Array[String] = []
		for skin_id_variant in remote_unlocks.get(vehicle_id, []):
			var resolved_skin_id := _resolve_vehicle_skin_id(vehicle_id, str(skin_id_variant))
			if resolved_skin_id.is_empty() or resolved_skin_id == "original_icon":
				continue
			remote_array.append(resolved_skin_id)
		for skin_id in remote_array:
			if not local_array.has(skin_id):
				local_array.append(skin_id)
		_sort_skin_ids_for_vehicle(vehicle_id, local_array)
		merged[vehicle_id] = local_array
	return merged

func _merge_equipped_vehicle_skins(local_equipped: Dictionary, remote_equipped: Dictionary, unlocked_vehicles: Array[String], unlocked_vehicle_skins: Dictionary, global_unlocks: Array[String]) -> Dictionary:
	var merged := local_equipped.duplicate(true)
	for vehicle_id in unlocked_vehicles:
		var candidate_skin_id := _resolve_vehicle_skin_id(vehicle_id, str(merged.get(vehicle_id, DEFAULT_SKIN_ID)))
		if _is_skin_accessible_with_state(vehicle_id, candidate_skin_id, unlocked_vehicle_skins, global_unlocks):
			merged[vehicle_id] = candidate_skin_id
			continue
		var remote_skin_id := _resolve_vehicle_skin_id(vehicle_id, str(remote_equipped.get(vehicle_id, DEFAULT_SKIN_ID)))
		merged[vehicle_id] = remote_skin_id if _is_skin_accessible_with_state(vehicle_id, remote_skin_id, unlocked_vehicle_skins, global_unlocks) else DEFAULT_SKIN_ID
	return merged

func _merge_vehicle_skin_progress(local_progress: Dictionary, remote_progress: Dictionary) -> Dictionary:
	var merged := local_progress.duplicate(true)
	for vehicle_id in remote_progress.keys():
		var local_entry: Dictionary = merged.get(vehicle_id, _default_vehicle_skin_progress())
		var remote_entry: Dictionary = remote_progress.get(vehicle_id, _default_vehicle_skin_progress())
		merged[vehicle_id] = {
			"runs_completed": maxi(int(local_entry.get("runs_completed", 0)), int(remote_entry.get("runs_completed", 0))),
			"daily_missions_completed": maxi(int(local_entry.get("daily_missions_completed", 0)), int(remote_entry.get("daily_missions_completed", 0))),
			"near_misses": maxi(int(local_entry.get("near_misses", 0)), int(remote_entry.get("near_misses", 0))),
			"projectile_intercepts": maxi(int(local_entry.get("projectile_intercepts", 0)), int(remote_entry.get("projectile_intercepts", 0))),
			"best_score": maxi(int(local_entry.get("best_score", 0)), int(remote_entry.get("best_score", 0))),
		}
	return merged

func _is_vehicle_accessible_with_unlocks(vehicle_id: String, unlocked_vehicles: Array[String]) -> bool:
	if vehicle_id.is_empty():
		return false
	if _is_dynamic_vehicle_id(vehicle_id):
		return _leaderboard_bonus_vehicle_access if vehicle_id == LEADERBOARD_BONUS_VEHICLE_ID else false
	return unlocked_vehicles.has(vehicle_id)

func _is_skin_accessible_with_state(vehicle_id: String, skin_id: String, unlocked_vehicle_skins: Dictionary, global_unlocks: Array[String]) -> bool:
	if vehicle_id.is_empty() or skin_id.is_empty():
		return false
	if skin_id == DEFAULT_SKIN_ID:
		return true
	if skin_id == "original_icon":
		return global_unlocks.has("original_icon") and _is_original_icon_available(vehicle_id)
	var unlocked_for_vehicle: Array = unlocked_vehicle_skins.get(vehicle_id, [DEFAULT_SKIN_ID])
	return unlocked_for_vehicle.has(skin_id)

func _sort_vehicle_ids(ids: Array[String]) -> void:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins == null or not helicopter_skins.has_method("get_vehicle_ids"):
		return
	var ordered_ids: Array[String] = helicopter_skins.get_vehicle_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ordered_ids.find(a) < ordered_ids.find(b)
	)

func _sort_skin_ids_for_vehicle(vehicle_id: String, ids: Array[String]) -> void:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins == null or not helicopter_skins.has_method("get_vehicle_skin_ids"):
		return
	var ordered_ids: Array[String] = helicopter_skins.get_vehicle_skin_ids(vehicle_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ordered_ids.find(a) < ordered_ids.find(b)
	)

func _ensure_top_skin_request() -> void:
	if _top_skin_request != null:
		return
	_top_skin_request = HTTPRequest.new()
	add_child(_top_skin_request)
	_top_skin_request.request_completed.connect(_on_top_skin_request_completed)

func _on_top_skin_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_top_skin_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	apply_leaderboard_entries(OnlineLeaderboardScript.parse_entries(body))

func _apply_verified_bonus_vehicle_access(is_top_player: bool) -> bool:
	var previous_access := _leaderboard_bonus_vehicle_access
	var previous_equipped_vehicle_id := _equipped_vehicle_id
	_leaderboard_bonus_vehicle_access = is_top_player
	_validate_profile_state()
	var access_changed := previous_access != _leaderboard_bonus_vehicle_access
	var equipped_vehicle_changed := previous_equipped_vehicle_id != _equipped_vehicle_id
	if not access_changed and not equipped_vehicle_changed:
		return false
	save_profile()
	if equipped_vehicle_changed:
		_queue_profile_sync()
	_emit_profile_changed()
	return true

func _persist_and_signal(sync_profile: bool) -> void:
	_validate_profile_state()
	save_profile()
	if sync_profile:
		_queue_profile_sync()
	_emit_profile_changed()

func _queue_profile_sync() -> void:
	if validation_mode_enabled:
		return
	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("enqueue_sync_player_profile"):
		sync_queue.enqueue_sync_player_profile(get_profile_sync_summary())
		if sync_queue.has_method("flush"):
			sync_queue.flush()

func _emit_profile_changed() -> void:
	profile_changed.emit(get_profile_sync_summary())

func _get_helicopter_skins() -> Node:
	return get_node_or_null("/root/HelicopterSkins")

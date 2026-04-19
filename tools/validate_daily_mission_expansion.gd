extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var mission_manager := get_root().get_node_or_null("MissionManager")
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	_assert(mission_manager != null, "MissionManager autoload should exist for Sprint 7 validation.")
	_assert(player_profile != null, "PlayerProfile autoload should exist for Sprint 7 validation.")
	if mission_manager == null or player_profile == null:
		Helper.finish(self, _failures, "Sprint 7 daily mission validation completed successfully.")
		return

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout", "bubble_chopper", "huey_runner"],
		"equipped_vehicle_id": "default_scout",
		"unlocked_vehicle_skins": {
			"default_scout": ["factory"],
			"bubble_chopper": ["factory"],
			"huey_runner": ["factory"],
		},
		"equipped_vehicle_skins": {
			"default_scout": "factory",
			"bubble_chopper": "factory",
			"huey_runner": "factory",
		},
	})

	var first_set: Array[Dictionary] = mission_manager.build_daily_missions_for_key("2026-04-19")
	var second_set: Array[Dictionary] = mission_manager.build_daily_missions_for_key("2026-04-19")
	_assert(first_set.size() == 5, "Daily mission generation should create 5 missions.")
	_assert(JSON.stringify(first_set) == JSON.stringify(second_set), "Daily mission generation should be deterministic for the same date key.")

	var core_count := 0
	var bonus_count := 0
	var seen_types: Dictionary = {}
	for mission in first_set:
		var mission_type := str(mission.get("type", ""))
		_assert(not seen_types.has(mission_type), "Daily mission generation should avoid duplicate mission types.")
		seen_types[mission_type] = true
		if bool(mission.get("bonus", false)):
			bonus_count += 1
		else:
			core_count += 1
		var mission_vehicle_id := str(mission.get("vehicle_id", "")).strip_edges()
		if not mission_vehicle_id.is_empty():
			_assert(player_profile.has_vehicle_access(mission_vehicle_id), "Vehicle-specific missions should only target unlocked vehicles.")
			_assert(mission_vehicle_id != "pottercar", "Vehicle-specific missions should never target Pottercar.")
	_assert(core_count == 3, "Daily missions should include 3 core missions.")
	_assert(bonus_count == 2, "Daily missions should include 2 bonus missions.")

	var summary: Dictionary = mission_manager.get_daily_progress_summary()
	_assert(int(summary.get("total", 0)) == 5, "Daily mission summary should report a total of 5 missions.")
	_assert(int(summary.get("core_total", 0)) == 3, "Daily mission summary should report 3 core mission slots.")
	_assert(int(summary.get("bonus_total", 0)) == 2, "Daily mission summary should report 2 bonus mission slots.")

	Helper.assert_file_exists(_failures, "res://scenes/ui/missions/mission_screen.gd")
	Helper.assert_file_exists(_failures, "res://scenes/ui/missions/mission_screen.tscn")
	var mission_screen_text := Helper.read_text("res://scenes/ui/missions/mission_screen.gd")
	_assert(mission_screen_text.contains("Core Missions"), "Mission screen should clearly label Core Missions.")
	_assert(mission_screen_text.contains("Bonus Missions"), "Mission screen should clearly label Bonus Missions.")
	_assert(mission_screen_text.contains("Complete missions to unlock"), "Mission screen should explain mission rewards.")
	var mission_screen_scene_text := Helper.read_text("res://scenes/ui/missions/mission_screen.tscn")
	_assert(mission_screen_scene_text.contains("RewardHelpLabel"), "Mission screen scene should include a reward helper label.")

	Helper.finish(self, _failures, "Sprint 7 daily mission validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

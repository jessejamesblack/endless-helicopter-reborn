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
	var rare_depth_count := 0
	var seen_types: Dictionary = {}
	for mission in first_set:
		var mission_type := str(mission.get("type", ""))
		_assert(not seen_types.has(mission_type), "Daily mission generation should avoid duplicate mission types.")
		seen_types[mission_type] = true
		if ["elite_kills", "special_enemy_kills", "objective_events_completed", "objective_rewards_claimed"].has(mission_type):
			rare_depth_count += 1
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
	_assert(rare_depth_count <= 1, "Daily missions should include at most one rare objective/elite mission.")

	var mission_manager_text := Helper.read_text("res://systems/mission_manager.gd")
	for mission_type in [
		"run_upgrades_chosen",
		"run_upgrades_single_run",
		"powerups_collected",
		"powerups_used",
		"shield_hits_absorbed",
		"score_rush_seconds",
		"overdrive_seconds",
		"emp_activations",
		"objective_events_completed",
		"objective_rewards_claimed",
		"elite_kills",
		"special_enemy_kills",
	]:
		_assert(mission_manager_text.contains('"%s"' % mission_type), "MissionManager should support %s missions." % mission_type)
	_assert(mission_manager_text.contains("rare_depth_mission"), "MissionManager should gate rare objective/elite missions to one per day.")

	var summary: Dictionary = mission_manager.get_daily_progress_summary()
	_assert(int(summary.get("total", 0)) == 5, "Daily mission summary should report a total of 5 missions.")
	_assert(int(summary.get("core_total", 0)) == 3, "Daily mission summary should report 3 core mission slots.")
	_assert(int(summary.get("bonus_total", 0)) == 2, "Daily mission summary should report 2 bonus mission slots.")

	var depth_missions: Array[Dictionary] = [
		{"id": "daily_2026-04-20_core_upgrades", "slot": "core_easy", "type": "run_upgrades_chosen", "category": "core_skill", "title": "Pick 2 Upgrades", "description": "", "target": 2, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-20_core_powerups", "slot": "core_combat", "type": "powerups_collected", "category": "core_combat", "title": "Collect 2 Powerups", "description": "", "target": 2, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-20_core_score_rush", "slot": "core_skill", "type": "score_rush_seconds", "category": "core_skill", "title": "Spend 10s In Score Rush", "description": "", "target": 10, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-20_bonus_objective", "slot": "bonus_vehicle_or_stretch", "type": "objective_events_completed", "category": "bonus_stretch", "title": "Complete 1 Objective", "description": "", "target": 1, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
		{"id": "daily_2026-04-20_bonus_elite", "slot": "bonus_prestige", "type": "elite_kills", "category": "bonus_stretch", "title": "Defeat 2 Elite Enemies", "description": "", "target": 2, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
	]
	mission_manager.apply_validation_state("2026-04-20", depth_missions)
	mission_manager.apply_run_summary({
		"upgrades_chosen": 2,
		"powerups_collected": 2,
		"score_rush_seconds": 10.0,
		"objective_events_completed": 1,
		"elite_kills": 2,
	})
	var depth_summary: Dictionary = mission_manager.get_daily_progress_summary()
	_assert(int(depth_summary.get("completed", 0)) == 5, "Depth mission types should progress from run summaries.")

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

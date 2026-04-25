extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen/start_screen.tscn")
const LEADERBOARD_SCREEN_SCENE := preload("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

const ALL_RUN_SUMMARY_MISSION_TYPES := [
	"play_runs",
	"survive_seconds_total",
	"ammo_pickups",
	"hostiles_destroyed",
	"missiles_fired",
	"score_total",
	"projectile_intercepts",
	"glowing_clears",
	"powerups_collected",
	"elite_kills",
	"special_enemy_kills",
	"near_misses",
	"max_combo",
	"skill_score",
	"boundary_recoveries",
	"run_upgrades_chosen",
	"score_rush_seconds",
	"shield_hits_absorbed",
	"overdrive_seconds",
	"emp_activations",
	"vehicle_runs",
	"vehicle_best_score",
	"vehicle_near_misses",
	"vehicle_intercepts",
	"vehicle_glowing_clears",
	"vehicle_skill_score",
	"score_single_run",
	"run_upgrades_single_run",
	"objective_events_completed",
	"objective_rewards_claimed",
	"powerups_used",
	"no_boundary_recovery_run",
	"no_missile_run_score",
	"gold_progress",
	"original_icon_progress",
	"armored_enemy_kills",
	"shielded_enemy_kills",
]

const LIVE_PROGRESS_MISSION_TYPES := [
	"ammo_pickups",
	"powerups_collected",
	"powerups_used",
	"emp_activations",
	"shield_hits_absorbed",
]

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
	_assert(mission_manager_text.contains("record_live_mission_progress"), "MissionManager should support live mission progress for in-run mission screens.")
	_assert(mission_manager_text.contains("begin_run_tracking"), "MissionManager should reset live progress tracking at run start.")
	_assert(mission_manager_text.contains("has_local_daily_progress"), "MissionManager should expose local daily progress detection for cloud restore safety.")
	_assert(mission_manager_text.contains("has_daily_progress_ahead_of_remote"), "MissionManager should detect when local mission progress is ahead of cloud progress.")
	_assert(mission_manager_text.contains("_mission_state_mutation_depth"), "MissionManager should block disk refresh rollback while mission state is mutating.")
	var sync_queue_text := Helper.read_text("res://systems/supabase_sync_queue.gd")
	_assert(sync_queue_text.contains("_get_current_mission_date_key"), "Supabase startup restore should use the MissionManager daily mission date key.")
	_assert(sync_queue_text.contains("has_daily_progress_ahead_of_remote"), "Supabase startup restore should not replace local daily progress with stale cloud rows.")
	_assert(sync_queue_text.contains("_merge_daily_sync_payload"), "Supabase sync queue should merge pending daily mission payloads instead of replacing newer progress.")
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

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout"],
		"equipped_vehicle_id": "default_scout",
		"total_daily_missions_completed": 0,
		"daily_streak": 0,
	})
	var live_missions: Array[Dictionary] = [
		{"id": "daily_2026-04-21_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "category": "core_easy", "title": "Collect 5 Ammo Pickups", "description": "", "target": 5, "progress": 4.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-21_core_runs", "slot": "core_combat", "type": "play_runs", "category": "core_combat", "title": "Fly 99 Runs", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-21_core_score", "slot": "core_skill", "type": "score_total", "category": "core_skill", "title": "Earn Score", "description": "", "target": 999999, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-04-21_bonus_powerups", "slot": "bonus_vehicle_or_stretch", "type": "powerups_collected", "category": "bonus_stretch", "title": "Collect Powerups", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
		{"id": "daily_2026-04-21_bonus_elite", "slot": "bonus_prestige", "type": "elite_kills", "category": "bonus_stretch", "title": "Defeat Elites", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
	]
	mission_manager.apply_validation_state("2026-04-21", live_missions)
	mission_manager.begin_run_tracking()
	mission_manager.record_live_mission_progress("ammo_pickups", 1.0)
	var live_summary: Dictionary = mission_manager.get_daily_progress_summary()
	var live_ammo_mission := _find_mission_by_type(live_summary.get("missions", []), "ammo_pickups")
	_assert(not live_ammo_mission.is_empty(), "Validation ammo mission should exist.")
	_assert(float(live_ammo_mission.get("progress", 0.0)) == 5.0, "Ammo pickup missions should complete immediately when the fifth pickup is collected.")
	_assert(bool(live_ammo_mission.get("completed", false)), "Ammo pickup missions should unlock immediately from live pickup progress.")
	_assert(player_profile.get_total_daily_missions_completed() == 1, "Live core mission completion should advance daily unlock credit.")
	mission_manager.apply_run_summary({"ammo_pickups_collected": 1})
	var after_run_summary: Dictionary = mission_manager.get_daily_progress_summary()
	var after_run_ammo_mission := _find_mission_by_type(after_run_summary.get("missions", []), "ammo_pickups")
	_assert(float(after_run_ammo_mission.get("progress", 0.0)) == 5.0, "End-of-run summaries should not double-count pickups already applied live.")
	_validate_stale_remote_daily_restore(mission_manager)
	_validate_live_completion_survives_midrun_restore(mission_manager, player_profile)
	_validate_daily_sync_queue_payload_merge()

	_validate_all_run_summary_mission_types(mission_manager, player_profile)
	_validate_all_live_progress_mission_types(mission_manager, player_profile)
	await _validate_end_run_and_main_screen_refresh(mission_manager, player_profile)

	Helper.assert_file_exists(_failures, "res://scenes/ui/missions/mission_screen.gd")
	Helper.assert_file_exists(_failures, "res://scenes/ui/missions/mission_screen.tscn")
	var mission_screen_text := Helper.read_text("res://scenes/ui/missions/mission_screen.gd")
	_assert(mission_screen_text.contains("Core Missions"), "Mission screen should clearly label Core Missions.")
	_assert(mission_screen_text.contains("Bonus Missions"), "Mission screen should clearly label Bonus Missions.")
	_assert(mission_screen_text.contains("Complete missions to unlock"), "Mission screen should explain mission rewards.")
	var mission_screen_scene_text := Helper.read_text("res://scenes/ui/missions/mission_screen.tscn")
	_assert(mission_screen_scene_text.contains("RewardHelpLabel"), "Mission screen scene should include a reward helper label.")

	Helper.finish(self, _failures, "Sprint 7 daily mission validation completed successfully.")

func _validate_all_run_summary_mission_types(mission_manager: Node, player_profile: Node) -> void:
	for batch_start in range(0, ALL_RUN_SUMMARY_MISSION_TYPES.size(), 5):
		var date_key := "2026-05-%02d" % (1 + int(batch_start / 5))
		var mission_types: Array[String] = []
		var missions: Array[Dictionary] = []
		var batch_end: int = mini(batch_start + 5, ALL_RUN_SUMMARY_MISSION_TYPES.size())
		for index in range(batch_start, batch_end):
			var mission_type := str(ALL_RUN_SUMMARY_MISSION_TYPES[index])
			mission_types.append(mission_type)
			missions.append(_make_validation_mission(date_key, missions.size(), mission_type))

		player_profile.apply_validation_state(_base_profile_summary())
		mission_manager.apply_validation_state(date_key, missions)
		var result: Dictionary = mission_manager.apply_run_summary(_completion_summary_for_types(mission_types))
		var daily_summary: Dictionary = mission_manager.get_daily_progress_summary()
		var completed_titles: Array = result.get("missions_completed_this_run", [])
		_assert(completed_titles.size() == missions.size(), "End-of-run result should list every newly completed mission for batch %s." % date_key)
		_assert(int(daily_summary.get("completed", 0)) == missions.size(), "Daily summary should show every mission completed for batch %s." % date_key)
		for mission_type in mission_types:
			var mission := _find_mission_by_type(daily_summary.get("missions", []), mission_type)
			_assert(not mission.is_empty(), "Validation mission should exist for %s." % mission_type)
			_assert(bool(mission.get("completed", false)), "%s should complete from the run summary path." % mission_type)
		var consumed_result: Dictionary = mission_manager.consume_recent_run_result()
		_assert((consumed_result.get("missions_completed_this_run", []) as Array).size() == missions.size(), "Results-screen handoff should preserve completed mission titles for batch %s." % date_key)

	player_profile.apply_validation_state(_base_profile_summary())
	var vehicle_mission := _make_validation_mission("2026-05-20", 0, "vehicle_runs")
	vehicle_mission["vehicle_id"] = "bubble_chopper"
	var vehicle_missions: Array[Dictionary] = [vehicle_mission]
	mission_manager.apply_validation_state("2026-05-20", vehicle_missions)
	mission_manager.apply_run_summary({
		"equipped_vehicle_id": "default_scout",
		"equipped_skin_id": "default_scout",
		"time_survived_seconds": 3.0,
	})
	var mismatch_summary: Dictionary = mission_manager.get_daily_progress_summary()
	var mismatch_mission := _find_mission_by_type(mismatch_summary.get("missions", []), "vehicle_runs")
	_assert(float(mismatch_mission.get("progress", 0.0)) == 0.0, "Vehicle missions should not progress when the run used a different vehicle.")

func _validate_all_live_progress_mission_types(mission_manager: Node, player_profile: Node) -> void:
	player_profile.apply_validation_state(_base_profile_summary())
	var date_key := "2026-05-21"
	var missions: Array[Dictionary] = []
	for index in range(LIVE_PROGRESS_MISSION_TYPES.size()):
		missions.append(_make_validation_mission(date_key, index, str(LIVE_PROGRESS_MISSION_TYPES[index])))

	mission_manager.apply_validation_state(date_key, missions)
	mission_manager.begin_run_tracking()
	for mission_type in LIVE_PROGRESS_MISSION_TYPES:
		mission_manager.record_live_mission_progress(str(mission_type), 1.0)

	var live_summary: Dictionary = mission_manager.get_daily_progress_summary()
	_assert(int(live_summary.get("completed", 0)) == LIVE_PROGRESS_MISSION_TYPES.size(), "All visible live mission counters should complete before the run ends.")
	for mission_type in LIVE_PROGRESS_MISSION_TYPES:
		var mission := _find_mission_by_type(live_summary.get("missions", []), str(mission_type))
		_assert(float(mission.get("progress", 0.0)) == 1.0, "%s should show exactly one live progress point." % mission_type)
		_assert(bool(mission.get("completed", false)), "%s should complete from live progress." % mission_type)

	var result: Dictionary = mission_manager.apply_run_summary(_single_live_event_summary())
	var after_run_summary: Dictionary = mission_manager.get_daily_progress_summary()
	_assert((result.get("missions_completed_this_run", []) as Array).size() == LIVE_PROGRESS_MISSION_TYPES.size(), "End-of-run result should include missions completed live during the run.")
	for mission_type in LIVE_PROGRESS_MISSION_TYPES:
		var mission := _find_mission_by_type(after_run_summary.get("missions", []), str(mission_type))
		_assert(float(mission.get("progress", 0.0)) == 1.0, "%s should not double-count after final run summary." % mission_type)

func _validate_stale_remote_daily_restore(mission_manager: Node) -> void:
	var date_key := "2026-05-23"
	var local_missions: Array[Dictionary] = [
		{"id": "daily_2026-05-23_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "category": "core_easy", "title": "Collect 5 Ammo Pickups", "description": "", "target": 5, "progress": 5.0, "completed": true, "progress_mode": "sum"},
		{"id": "daily_2026-05-23_core_runs", "slot": "core_combat", "type": "play_runs", "category": "core_combat", "title": "Fly 99 Runs", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-05-23_core_score", "slot": "core_skill", "type": "score_total", "category": "core_skill", "title": "Earn Score", "description": "", "target": 999999, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-05-23_bonus_powerups", "slot": "bonus_vehicle_or_stretch", "type": "powerups_collected", "category": "bonus_stretch", "title": "Collect Powerups", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
		{"id": "daily_2026-05-23_bonus_elite", "slot": "bonus_prestige", "type": "elite_kills", "category": "bonus_stretch", "title": "Defeat Elites", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
	]
	var stale_remote := {
		"mission_date": date_key,
		"completed_count": 0,
		"total_count": 5,
		"missions": [
			{"id": "daily_2026-05-23_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "category": "core_easy", "title": "Collect 5 Ammo Pickups", "description": "", "target": 5, "progress": 4.0, "completed": false, "progress_mode": "sum"},
			{"id": "daily_2026-05-23_core_runs", "slot": "core_combat", "type": "play_runs", "category": "core_combat", "title": "Fly 99 Runs", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum"},
			{"id": "daily_2026-05-23_core_score", "slot": "core_skill", "type": "score_total", "category": "core_skill", "title": "Earn Score", "description": "", "target": 999999, "progress": 0.0, "completed": false, "progress_mode": "sum"},
			{"id": "daily_2026-05-23_bonus_powerups", "slot": "bonus_vehicle_or_stretch", "type": "powerups_collected", "category": "bonus_stretch", "title": "Collect Powerups", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
			{"id": "daily_2026-05-23_bonus_elite", "slot": "bonus_prestige", "type": "elite_kills", "category": "bonus_stretch", "title": "Defeat Elites", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
		],
	}
	mission_manager.apply_validation_state(date_key, local_missions)
	_assert(bool(mission_manager.has_local_daily_progress()), "MissionManager should detect completed local mission progress before startup restore.")
	_assert(bool(mission_manager.has_daily_progress_ahead_of_remote(stale_remote)), "MissionManager should detect stale remote progress before replacing local missions.")
	mission_manager.merge_remote_daily_progress(stale_remote)
	var restored_summary: Dictionary = mission_manager.get_daily_progress_summary()
	var ammo_mission := _find_mission_by_type(restored_summary.get("missions", []), "ammo_pickups")
	_assert(float(ammo_mission.get("progress", 0.0)) == 5.0, "Stale remote mission rows should not downgrade local ammo progress.")
	_assert(bool(ammo_mission.get("completed", false)), "Stale remote mission rows should not clear local mission completion.")

func _validate_live_completion_survives_midrun_restore(mission_manager: Node, player_profile: Node) -> void:
	player_profile.apply_validation_state(_base_profile_summary())
	var date_key := "2026-05-24"
	var local_missions: Array[Dictionary] = [
		{"id": "daily_2026-05-24_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "category": "core_easy", "title": "Collect 5 Ammo Pickups", "description": "", "target": 5, "progress": 4.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-05-24_core_runs", "slot": "core_combat", "type": "play_runs", "category": "core_combat", "title": "Fly 99 Runs", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-05-24_core_score", "slot": "core_skill", "type": "score_total", "category": "core_skill", "title": "Earn Score", "description": "", "target": 999999, "progress": 0.0, "completed": false, "progress_mode": "sum"},
		{"id": "daily_2026-05-24_bonus_powerups", "slot": "bonus_vehicle_or_stretch", "type": "powerups_collected", "category": "bonus_stretch", "title": "Collect Powerups", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
		{"id": "daily_2026-05-24_bonus_elite", "slot": "bonus_prestige", "type": "elite_kills", "category": "bonus_stretch", "title": "Defeat Elites", "description": "", "target": 99, "progress": 0.0, "completed": false, "progress_mode": "sum", "bonus": true, "badge_text": "BONUS"},
	]
	var stale_remote := {
		"mission_date": date_key,
		"completed_count": 0,
		"total_count": 5,
		"missions": local_missions.duplicate(true),
	}
	mission_manager.apply_validation_state(date_key, local_missions)
	mission_manager.begin_run_tracking()
	mission_manager.record_live_mission_progress("ammo_pickups", 1.0)
	player_profile.apply_validation_state(_base_profile_summary())
	mission_manager.replace_remote_daily_progress(stale_remote)
	var result: Dictionary = mission_manager.apply_run_summary({"ammo_pickups_collected": 1})
	var summary: Dictionary = mission_manager.get_daily_progress_summary()
	var ammo_mission := _find_mission_by_type(summary.get("missions", []), "ammo_pickups")
	_assert(float(ammo_mission.get("progress", 0.0)) == 5.0, "Live mission completion should survive a mid-run stale cloud restore.")
	_assert(bool(ammo_mission.get("completed", false)), "Live mission completion should stay complete after a mid-run stale cloud restore.")
	_assert((result.get("missions_completed_this_run", []) as Array).size() == 1, "End screen should report the restored live completion once.")
	_assert(player_profile.get_total_daily_missions_completed() == 1, "Live core completion credit should be restored if profile sync rolls it back mid-run.")

func _validate_daily_sync_queue_payload_merge() -> void:
	var queue = load("res://systems/supabase_sync_queue.gd").new()
	var stale_payload := {
		"mission_date": "2026-05-25",
		"completed_count": 0,
		"total_count": 5,
		"missions": [
			{"id": "daily_2026-05-25_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "target": 5, "progress": 4.0, "completed": false},
			{"id": "daily_2026-05-25_core_runs", "slot": "core_combat", "type": "play_runs", "target": 99, "progress": 0.0, "completed": false},
		],
	}
	var completed_payload := {
		"mission_date": "2026-05-25",
		"completed_count": 1,
		"total_count": 5,
		"missions": [
			{"id": "daily_2026-05-25_core_ammo", "slot": "core_easy", "type": "ammo_pickups", "target": 5, "progress": 5.0, "completed": true},
			{"id": "daily_2026-05-25_core_runs", "slot": "core_combat", "type": "play_runs", "target": 99, "progress": 0.0, "completed": false},
		],
	}
	var merged_forward: Dictionary = queue.call("_merge_daily_sync_payload", stale_payload, completed_payload)
	var merged_backward: Dictionary = queue.call("_merge_daily_sync_payload", completed_payload, stale_payload)
	var forward_ammo := _find_mission_by_type(merged_forward.get("missions", []), "ammo_pickups")
	var backward_ammo := _find_mission_by_type(merged_backward.get("missions", []), "ammo_pickups")
	_assert(int(merged_forward.get("completed_count", 0)) == 1, "Daily sync queue should keep completed_count when newer progress arrives.")
	_assert(bool(forward_ammo.get("completed", false)) and float(forward_ammo.get("progress", 0.0)) == 5.0, "Daily sync queue should merge stale then completed mission payloads upward.")
	_assert(int(merged_backward.get("completed_count", 0)) == 1, "Daily sync queue should keep completed_count when a stale payload arrives second.")
	_assert(bool(backward_ammo.get("completed", false)) and float(backward_ammo.get("progress", 0.0)) == 5.0, "Daily sync queue should not let a stale payload replace completed mission progress.")
	queue.free()

func _validate_end_run_and_main_screen_refresh(mission_manager: Node, player_profile: Node) -> void:
	player_profile.apply_validation_state(_base_profile_summary())
	var date_key := "2026-05-22"
	var missions: Array[Dictionary] = [
		_make_validation_mission(date_key, 0, "play_runs"),
		_make_validation_mission(date_key, 1, "ammo_pickups"),
		_make_validation_mission(date_key, 2, "score_total"),
		_make_validation_mission(date_key, 3, "powerups_collected"),
		_make_validation_mission(date_key, 4, "run_upgrades_chosen"),
	]
	mission_manager.apply_validation_state(date_key, missions)
	var result: Dictionary = mission_manager.apply_run_summary(_completion_summary_for_types([
		"play_runs",
		"ammo_pickups",
		"score_total",
		"powerups_collected",
		"run_upgrades_chosen",
	]))
	_assert((result.get("missions_completed_this_run", []) as Array).size() == 5, "End-of-run mission result should carry all five completed mission titles.")

	var leaderboard := LEADERBOARD_SCREEN_SCENE.instantiate() as Control
	leaderboard.set("validation_mode_enabled", true)
	get_root().add_child(leaderboard)
	await process_frame
	leaderboard.set("current_mission_result", result.duplicate(true))
	leaderboard.call("apply_validation_state", 0, {"score": 600, "time_survived_seconds": 3.0}, false, false, false)
	await process_frame
	var mission_progress_label := leaderboard.get("mission_progress_label") as Label
	var mission_line_one_label := leaderboard.get("mission_line_one_label") as Label
	_assert(mission_progress_label != null and mission_progress_label.text == "5 / 5 COMPLETE", "Results screen should read fresh completed mission totals after a run.")
	_assert(mission_line_one_label != null and mission_line_one_label.text.contains("complete"), "Results screen should show a completed mission title from the end-of-run handoff.")
	leaderboard.free()
	await process_frame

	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(start_screen)
	await process_frame
	var missions_button := start_screen.get_node_or_null("MissionsButton") as Button
	_assert(missions_button != null and missions_button.text == "Missions 5/5", "Main screen Missions button should read fresh completed mission totals.")
	start_screen.free()
	await process_frame

func _base_profile_summary() -> Dictionary:
	return {
		"unlocked_vehicles": ["default_scout", "bubble_chopper", "huey_runner"],
		"equipped_vehicle_id": "default_scout",
		"total_daily_missions_completed": 0,
		"daily_streak": 0,
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
		"vehicle_skin_progress": {
			"default_scout": {"runs_completed": 0, "daily_missions_completed": 0, "near_misses": 0, "projectile_intercepts": 0, "best_score": 0},
			"bubble_chopper": {"runs_completed": 0, "daily_missions_completed": 0, "near_misses": 0, "projectile_intercepts": 0, "best_score": 0},
			"huey_runner": {"runs_completed": 0, "daily_missions_completed": 0, "near_misses": 0, "projectile_intercepts": 0, "best_score": 0},
		},
	}

func _make_validation_mission(date_key: String, index: int, mission_type: String) -> Dictionary:
	var slots := ["core_easy", "core_combat", "core_skill", "bonus_vehicle_or_stretch", "bonus_prestige"]
	var slot := str(slots[index % slots.size()])
	var bonus := index >= 3
	var vehicle_id := "default_scout" if mission_type.begins_with("vehicle_") or mission_type == "gold_progress" else ""
	return {
		"id": "daily_%s_%s_%s_%d" % [date_key, slot, mission_type, index],
		"slot": slot,
		"type": mission_type,
		"category": "bonus_validation" if bonus else "core_validation",
		"title": "%s Validation" % mission_type.capitalize(),
		"description": "Validation mission for %s." % mission_type,
		"target": _target_for_mission_type(mission_type),
		"progress": 0.0,
		"completed": false,
		"bonus": bonus,
		"badge_text": "BONUS" if bonus else "",
		"progress_mode": _progress_mode_for_mission_type(mission_type),
		"reward_text": "Bonus hangar credit" if bonus else "Core unlock progress",
		"vehicle_id": vehicle_id,
	}

func _target_for_mission_type(mission_type: String):
	match mission_type:
		"max_combo":
			return 150
		"score_total", "score_single_run", "vehicle_best_score", "vehicle_skill_score", "skill_score", "no_missile_run_score", "gold_progress", "original_icon_progress":
			return 100
		_:
			return 1

func _progress_mode_for_mission_type(mission_type: String) -> String:
	if [
		"max_combo",
		"score_single_run",
		"vehicle_best_score",
		"run_upgrades_single_run",
		"no_missile_run_score",
		"gold_progress",
		"original_icon_progress",
	].has(mission_type):
		return "best"
	return "sum"

func _completion_summary_for_types(mission_types: Array) -> Dictionary:
	var summary := {
		"score": 600,
		"time_survived_seconds": 3.0,
		"hostiles_destroyed": 3,
		"ammo_pickups_collected": 3,
		"glowing_rocks_triggered": 3,
		"near_misses": 3,
		"projectile_intercepts": 3,
		"max_combo_multiplier": 1.5,
		"skill_score": 600,
		"upgrades_chosen": 4,
		"powerups_collected": 3,
		"powerups_used": 3,
		"shield_hits_absorbed": 3,
		"score_rush_seconds": 3.0,
		"overdrive_seconds": 3.0,
		"emp_activations": 3,
		"objective_events_completed": 3,
		"objective_rewards_claimed": 3,
		"elite_kills": 3,
		"special_enemy_kills": 3,
		"armored_enemy_kills": 3,
		"shielded_enemy_kills": 3,
		"equipped_vehicle_id": "default_scout",
		"equipped_skin_id": "default_scout",
	}
	summary["missiles_fired"] = 3 if mission_types.has("missiles_fired") else 0
	summary["boundary_bounces"] = 3 if mission_types.has("boundary_recoveries") else 0
	return summary

func _single_live_event_summary() -> Dictionary:
	return {
		"ammo_pickups_collected": 1,
		"powerups_collected": 1,
		"powerups_used": 1,
		"emp_activations": 1,
		"shield_hits_absorbed": 1,
		"equipped_vehicle_id": "default_scout",
		"equipped_skin_id": "default_scout",
	}

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

func _find_mission_by_type(missions_variant, mission_type: String) -> Dictionary:
	if missions_variant is not Array:
		return {}
	for mission_variant in missions_variant:
		if mission_variant is not Dictionary:
			continue
		var mission := mission_variant as Dictionary
		if str(mission.get("type", "")) == mission_type:
			return mission
	return {}

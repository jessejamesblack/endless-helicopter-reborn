extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

const CANONICAL_NAMES := {
	"default_scout": "Scout",
	"bubble_chopper": "Bubble Chopper",
	"huey_runner": "Huey Runner",
	"blackhawk_shadow": "Blackhawk Shadow",
	"apache_strike": "Hind Strike",
	"chinook_lift": "Chinook Lift",
	"crazytaxi": "Crazy Taxi",
	"pottercar": "Pottercar",
}

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_canonical_vehicle_names()
	_validate_ui_uses_backend_names()
	_validate_saved_vehicle_mission_names_are_repaired()
	Helper.finish(self, _failures, "UI naming consistency validation completed successfully.")

func _validate_canonical_vehicle_names() -> void:
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist.")
	if helicopter_skins == null:
		return
	for vehicle_id in CANONICAL_NAMES.keys():
		_assert(str(helicopter_skins.call("get_display_name", vehicle_id)) == str(CANONICAL_NAMES[vehicle_id]), "%s should use canonical display name %s." % [vehicle_id, CANONICAL_NAMES[vehicle_id]])
		var profile: Dictionary = helicopter_skins.call("get_vehicle_profile", vehicle_id)
		_assert(not str(profile.get("passive_id", "")).is_empty(), "%s should expose a passive_id in backend profile data." % vehicle_id)

func _validate_ui_uses_backend_names() -> void:
	var hangar_text := Helper.read_text("res://scenes/ui/hangar/hangar_screen.gd")
	var mission_text := Helper.read_text("res://scenes/ui/missions/mission_screen.gd")
	var leaderboard_text := Helper.read_text("res://scenes/ui/leaderboard/leaderboard_screen.gd")
	_assert(hangar_text.contains("get_display_name"), "Hangar screen should use backend display names.")
	_assert(leaderboard_text.contains("get_display_name"), "Leaderboard/results screen should use backend display names.")
	_assert(mission_text.contains("display_name"), "Mission screen should surface backend next-unlock display names.")
	for old_primary_name in ["Little Bird", "Shadow Hawk", "Apache Strike", "Twin-Lift"]:
		_assert(not hangar_text.contains(old_primary_name), "Hangar UI should not hard-code old primary name %s." % old_primary_name)
		_assert(not leaderboard_text.contains(old_primary_name), "Leaderboard UI should not hard-code old primary name %s." % old_primary_name)
		_assert(not mission_text.contains(old_primary_name), "Mission UI should not hard-code old primary name %s." % old_primary_name)

func _validate_saved_vehicle_mission_names_are_repaired() -> void:
	var mission_manager := get_root().get_node_or_null("MissionManager")
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	_assert(mission_manager != null, "MissionManager autoload should exist.")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist.")
	_assert(player_profile != null, "PlayerProfile autoload should exist.")
	if mission_manager == null or helicopter_skins == null or player_profile == null:
		return

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout", "apache_strike"],
		"equipped_vehicle_id": "apache_strike",
		"unlocked_vehicle_skins": {
			"default_scout": ["factory"],
			"apache_strike": ["factory"],
		},
		"equipped_vehicle_skins": {
			"default_scout": "factory",
			"apache_strike": "factory",
		},
	})

	var date_key := "2026-06-01"
	var saved_missions: Array[Dictionary] = [
		{
			"id": "daily_%s_bonus_prestige_gold_progress" % date_key,
			"slot": "bonus_prestige",
			"type": "gold_progress",
			"category": "bonus_prestige",
			"title": "Push Apache Strike Toward Gold",
			"description": "Raise Apache Strike's best score toward its 5,000 gold target.",
			"target": 5000,
			"progress": 0.0,
			"completed": false,
			"progress_mode": "best",
			"bonus": true,
			"badge_text": "BONUS",
			"vehicle_id": "apache_strike",
		},
	]
	mission_manager.apply_validation_state(date_key, saved_missions)
	var missions: Array[Dictionary] = mission_manager.get_daily_missions()
	_assert(missions.size() == 1, "Validation should keep the saved vehicle mission.")
	if missions.is_empty():
		return
	var mission := missions[0]
	var vehicle_name := str(helicopter_skins.call("get_display_name", "apache_strike"))
	_assert(vehicle_name == "Hind Strike", "apache_strike should display as Hind Strike.")
	_assert(str(mission.get("title", "")).contains(vehicle_name), "Saved vehicle mission titles should be repaired to the canonical vehicle name.")
	_assert(str(mission.get("description", "")).contains(vehicle_name), "Saved vehicle mission descriptions should be repaired to the canonical vehicle name.")
	_assert(not str(mission.get("title", "")).contains("Apache Strike"), "Saved vehicle mission titles should not keep stale Apache Strike copy.")
	_assert(not str(mission.get("description", "")).contains("Apache Strike"), "Saved vehicle mission descriptions should not keep stale Apache Strike copy.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

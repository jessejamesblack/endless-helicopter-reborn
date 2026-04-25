extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

const CANONICAL_NAMES := {
	"default_scout": "Scout",
	"bubble_chopper": "Bubble Chopper",
	"huey_runner": "Huey Runner",
	"blackhawk_shadow": "Blackhawk Shadow",
	"apache_strike": "Apache Strike",
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
	for old_primary_name in ["Little Bird", "Shadow Hawk", "Hind Strike", "Twin-Lift"]:
		_assert(not hangar_text.contains(old_primary_name), "Hangar UI should not hard-code old primary name %s." % old_primary_name)
		_assert(not leaderboard_text.contains(old_primary_name), "Leaderboard UI should not hard-code old primary name %s." % old_primary_name)
		_assert(not mission_text.contains(old_primary_name), "Mission UI should not hard-code old primary name %s." % old_primary_name)

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

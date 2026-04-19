extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const HANGAR_SCENE := preload("res://scenes/ui/hangar/hangar_screen.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	_assert(player_profile != null, "PlayerProfile autoload should exist for hangar validation.")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist for hangar validation.")
	if player_profile == null or helicopter_skins == null:
		Helper.finish(self, _failures, "Sprint 7 hangar UI validation completed successfully.")
		return

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout", "bubble_chopper"],
		"equipped_vehicle_id": "default_scout",
		"unlocked_vehicle_skins": {
			"default_scout": ["factory"],
			"bubble_chopper": ["factory"],
		},
		"equipped_vehicle_skins": {
			"default_scout": "gold",
			"bubble_chopper": "factory",
		},
		"seen_vehicle_lore": [],
		"seen_skin_lore": [],
	})
	_assert(player_profile.get_equipped_vehicle_skin_id("default_scout") == "factory", "Invalid equipped skin state should fall back to Factory.")

	var hangar := HANGAR_SCENE.instantiate() as Control
	get_root().add_child(hangar)
	await process_frame
	await process_frame

	var locked_skin_text := str(hangar.call("_build_skin_button_text", "default_scout", "gold", player_profile, helicopter_skins))
	_assert(locked_skin_text.contains("Locked"), "Locked skins should show Locked state in Hangar.")
	_assert(not locked_skin_text.contains("Equipped"), "Locked skins should never show Equipped in Hangar.")

	var new_vehicle_text := str(hangar.call("_build_vehicle_button_text", "bubble_chopper", player_profile, helicopter_skins))
	_assert(new_vehicle_text.contains("NEW"), "Unseen vehicles should show NEW in Hangar.")
	hangar.set("_selected_vehicle_id", "bubble_chopper")
	hangar.set("_selected_skin_id", "factory")
	hangar.call("_mark_lore_seen")
	_assert(player_profile.has_seen_vehicle_lore("bubble_chopper"), "Selecting a NEW vehicle should clear its NEW state in one interaction.")
	_assert(player_profile.has_seen_skin_lore("bubble_chopper", "factory"), "Selecting a NEW skin should clear its NEW state in one interaction.")

	hangar.free()
	await process_frame

	var hangar_text := Helper.read_text("res://scenes/ui/hangar/hangar_screen.gd")
	_assert(hangar_text.contains("return \"%s  -  Locked\" % label"), "Hangar should prioritize Locked state text.")
	_assert(hangar_text.contains("return \"%s  -  Equipped\" % label"), "Hangar should still show Equipped only for unlocked selections.")

	Helper.finish(self, _failures, "Sprint 7 hangar UI validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

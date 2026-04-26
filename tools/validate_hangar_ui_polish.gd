extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const HANGAR_SCENE := preload("res://scenes/ui/hangar/hangar_screen.tscn")
const HANGAR_VIEWPORT_SIZE := Vector2i(1100, 619)

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	get_root().size = HANGAR_VIEWPORT_SIZE
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	var run_upgrade_manager := get_root().get_node_or_null("RunUpgradeManager")
	_assert(player_profile != null, "PlayerProfile autoload should exist for hangar validation.")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist for hangar validation.")
	_assert(run_upgrade_manager != null, "RunUpgradeManager autoload should exist for hangar vehicle stats.")
	if player_profile == null or helicopter_skins == null or run_upgrade_manager == null:
		Helper.finish(self, _failures, "Sprint 7 hangar UI validation completed successfully.")
		return
	_assert(run_upgrade_manager.has_method("get_vehicle_passive_data"), "RunUpgradeManager should expose passive data for hangar stats.")

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
	_assert_hangar_layout_fits(hangar)

	var stats_label := hangar.get_node_or_null("Panel/MarginContainer/VBoxContainer/VehicleStatsCard/VehicleStatsMargin/VehicleStatsLabel") as Label
	_assert(stats_label != null, "Hangar should include a selected-vehicle stats area.")
	if stats_label != null:
		var default_stats := str(hangar.call("get_vehicle_stats_text"))
		_assert(default_stats.contains("AMMO 2"), "Scout stats should show the baseline ammo capacity.")
		_assert(default_stats.contains("PASSIVE Reliable Frame"), "Scout stats should show the Reliable Frame passive name.")
		_assert(default_stats.contains("+1 first choice card"), "Scout stats should explain the visible first-choice card bonus.")
		var huey_stats := str(hangar.call("_build_vehicle_stats_text", "huey_runner", helicopter_skins.get_vehicle_data("huey_runner")))
		_assert(huey_stats.contains("AMMO 3"), "Huey Runner stats should include the ammo utility passive capacity.")
		_assert(huey_stats.contains("refund chance"), "Huey Runner stats should show the ammo refund passive.")

	var locked_skin_text := str(hangar.call("_build_skin_button_text", "default_scout", "gold", player_profile, helicopter_skins))
	_assert(locked_skin_text.contains("Locked"), "Locked skins should show Locked state in Hangar.")
	_assert(not locked_skin_text.contains("Equipped"), "Locked skins should never show Equipped in Hangar.")

	var vehicle_text := str(hangar.call("_build_vehicle_button_text", "bubble_chopper", player_profile, helicopter_skins))
	_assert(not vehicle_text.contains("NEW"), "Hangar should not show NEW badges for vehicles.")
	var skin_text := str(hangar.call("_build_skin_button_text", "bubble_chopper", "factory", player_profile, helicopter_skins))
	_assert(not skin_text.contains("NEW"), "Hangar should not show NEW badges for skins.")

	hangar.free()
	await process_frame

	var hangar_text := Helper.read_text("res://scenes/ui/hangar/hangar_screen.gd")
	_assert(hangar_text.contains("return \"%s  -  Locked\" % label"), "Hangar should prioritize Locked state text.")
	_assert(hangar_text.contains("return \"%s  -  Equipped\" % label"), "Hangar should still show Equipped only for unlocked selections.")

	Helper.finish(self, _failures, "Sprint 7 hangar UI validation completed successfully.")

func _assert_hangar_layout_fits(hangar: Control) -> void:
	var panel := hangar.get_node_or_null("Panel") as Control
	var button_row := hangar.get_node_or_null("Panel/MarginContainer/VBoxContainer/ButtonRow") as Control
	var stats_card := hangar.get_node_or_null("Panel/MarginContainer/VBoxContainer/VehicleStatsCard") as Control
	_assert(panel != null, "Hangar should expose the main panel for layout validation.")
	_assert(button_row != null, "Hangar should expose the action button row for layout validation.")
	_assert(stats_card != null, "Hangar should expose the stats card for layout validation.")
	if panel == null:
		return
	var panel_rect := panel.get_global_rect().grow(1.0)
	for control in [button_row, stats_card]:
		if control == null:
			continue
		var checked_control := control as Control
		var control_rect: Rect2 = checked_control.get_global_rect()
		_assert(panel_rect.encloses(control_rect), "%s should fit inside the hangar panel at %dx%d." % [checked_control.name, HANGAR_VIEWPORT_SIZE.x, HANGAR_VIEWPORT_SIZE.y])

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

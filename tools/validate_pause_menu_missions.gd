extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause/pause_menu.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_scene_text()
	await _validate_pause_menu_runtime()
	Helper.finish(self, _failures, "Pause menu missions validation completed successfully.")

func _validate_scene_text() -> void:
	var scene_text := Helper.read_text("res://scenes/ui/pause/pause_menu.tscn")
	var script_text := Helper.read_text("res://scenes/ui/pause/pause_menu.gd")
	var mission_screen_text := Helper.read_text("res://scenes/ui/missions/mission_screen.gd")
	_assert(scene_text.contains("MissionsButton"), "Pause menu scene should include a Missions button.")
	_assert(scene_text.contains("MissionScreen"), "Pause menu scene should embed a MissionScreen.")
	_assert(script_text.contains("_on_missions_pressed"), "Pause menu script should open missions.")
	_assert(mission_screen_text.contains("embedded_mode"), "MissionScreen should support embedded pause mode.")
	_assert(mission_screen_text.contains("close_requested"), "MissionScreen should emit close_requested in embedded mode.")

func _validate_pause_menu_runtime() -> void:
	get_root().size = Vector2i(1152, 648)
	paused = true
	await process_frame
	var menu := PAUSE_MENU_SCENE.instantiate()
	get_root().add_child(menu)
	await process_frame

	menu.call("open_menu")
	await process_frame
	var menu_panel := menu.get("menu_panel") as Control
	var missions_button := menu.get("missions_button") as Button
	var mission_screen := menu.get("mission_screen") as Control
	_assert(menu.visible, "Pause menu should be visible after open_menu().")
	_assert(menu_panel != null and menu_panel.visible, "Pause menu panel should be visible after open_menu().")
	_assert(missions_button != null and missions_button.visible, "Missions button should be visible in the pause menu.")

	menu.call("_on_missions_pressed")
	await process_frame
	_assert(paused, "Opening pause missions should preserve the paused tree state.")
	_assert(menu_panel != null and not menu_panel.visible, "Opening pause missions should hide the pause button panel.")
	_assert(mission_screen != null and mission_screen.visible, "Mission screen should be visible from pause menu.")
	if mission_screen != null and "embedded_mode" in mission_screen:
		_assert(bool(mission_screen.get("embedded_mode")), "Embedded mission screen should run in embedded mode.")

	menu.call("_on_missions_closed")
	await process_frame
	_assert(menu_panel != null and menu_panel.visible, "Closing pause missions should return to pause menu panel.")
	_assert(paused, "Closing pause missions should preserve the paused tree state.")

	menu.free()
	paused = false
	await process_frame

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

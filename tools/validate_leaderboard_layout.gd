extends SceneTree

const DEBUG_MENU_SCENE := preload("res://scenes/ui/debug/debug_menu.tscn")
const LEADERBOARD_SCREEN_SCENE := preload("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(960, 540),
]
const RESULTS_SUMMARY := {
	"score": 9876,
	"best_score_before_run": 9999,
	"best_score_after_run": 9999,
	"distance_to_best_before_run": 123,
	"is_new_best": false,
	"time_survived_seconds": 123.4,
	"missiles_fired": 27,
	"hostiles_destroyed": 19,
	"ammo_pickups_collected": 4,
	"glowing_rocks_triggered": 3,
	"boundary_bounces": 7,
}

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _validate_results_mode(viewport_size)
		await _validate_setup_mode(viewport_size)
		await _validate_leaderboard_mode(viewport_size)
		await _validate_debug_menu(viewport_size)

	if _failures.is_empty():
		print("UI layout validation completed successfully.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _validate_results_mode(viewport_size: Vector2i) -> void:
	var screen: Control = await _create_screen(viewport_size)
	screen.call("apply_validation_state", 0, RESULTS_SUMMARY, true, false, false)
	await process_frame
	await process_frame
	_assert_visible((screen.get("results_card") as Control).visible, "Results card should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("try_again_button") as Control).visible, "Try Again should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("results_button_row") as Control).visible, "Results actions should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_within_panel(screen, "results", viewport_size)
	await _destroy_screen(screen)

func _validate_setup_mode(viewport_size: Vector2i) -> void:
	var screen: Control = await _create_screen(viewport_size)
	screen.call("apply_validation_state", 1, RESULTS_SUMMARY, true, false, false)
	await process_frame
	await process_frame
	_assert_visible((screen.get("setup_card") as Control).visible, "Setup card should be visible in setup mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("name_entry") as Control).visible, "Name entry should be visible in setup mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("save_button") as Control).visible, "Save button should be visible in setup mode at %s." % _format_viewport_size(viewport_size))
	_assert_within_panel(screen, "setup", viewport_size)
	await _destroy_screen(screen)

func _validate_leaderboard_mode(viewport_size: Vector2i) -> void:
	var screen: Control = await _create_screen(viewport_size)
	screen.call("apply_validation_state", 1, {}, true, true, true)
	await process_frame
	await process_frame
	_assert_visible((screen.get("leaderboard_card") as Control).visible, "Leaderboard card should be visible in leaderboard mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("button_row") as Control).visible, "Leaderboard buttons should be visible in leaderboard mode at %s." % _format_viewport_size(viewport_size))
	_assert_within_panel(screen, "leaderboard", viewport_size)
	await _destroy_screen(screen)

func _validate_debug_menu(viewport_size: Vector2i) -> void:
	var screen: Control = await _create_debug_menu(viewport_size)
	screen.call("open_menu")
	await process_frame
	((screen.get("push_status_label") as Label)).text = "Push unavailable here: Android APK only. This validation message intentionally wraps across multiple lines to catch layout regressions."
	((screen.get("last_message_value_label") as Label)).text = "Push unavailable here: Android APK only. This validation message intentionally wraps across multiple lines to catch layout regressions."
	screen.call("_fit_panel_to_viewport")
	await process_frame
	await process_frame
	_assert_visible(screen.visible, "Debug menu should be visible at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("close_button") as Control).visible, "Debug close button should be visible at %s." % _format_viewport_size(viewport_size))
	_assert_within_panel(screen, "debug menu", viewport_size)
	await _destroy_screen(screen)

func _create_screen(viewport_size: Vector2i) -> Control:
	var root_window := get_root()
	root_window.size = viewport_size
	await process_frame
	var screen: Control = LEADERBOARD_SCREEN_SCENE.instantiate() as Control
	screen.set("validation_mode_enabled", true)
	root_window.add_child(screen)
	await process_frame
	await process_frame
	return screen

func _create_debug_menu(viewport_size: Vector2i) -> Control:
	var root_window := get_root()
	root_window.size = viewport_size
	await process_frame
	var screen: Control = DEBUG_MENU_SCENE.instantiate() as Control
	root_window.add_child(screen)
	await process_frame
	await process_frame
	return screen

func _destroy_screen(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.free()
	await process_frame

func _assert_within_panel(screen: Control, mode_name: String, viewport_size: Vector2i) -> void:
	var panel := screen.get("panel") as Control
	var panel_rect: Rect2 = panel.get_global_rect()
	var tolerance := 1.0
	var allowed_rect := Rect2(
		panel_rect.position - Vector2.ONE * tolerance,
		panel_rect.size + Vector2.ONE * tolerance * 2.0
	)

	for control in _collect_visible_controls(panel):
		if control == panel or not _should_check_control(control):
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not allowed_rect.encloses(rect):
			_failures.append(
				"%s mode overflow at %s: %s escaped panel bounds. Control rect=%s panel rect=%s" % [
					mode_name,
					_format_viewport_size(viewport_size),
					control.get_path(),
					rect,
					panel_rect,
				]
			)

func _collect_visible_controls(root_control: Control) -> Array[Control]:
	var controls: Array[Control] = []
	controls.append(root_control)
	for child in root_control.get_children():
		if child is not Control:
			continue
		var control := child as Control
		if not control.visible:
			continue
		controls.append_array(_collect_visible_controls(control))
	return controls

func _assert_visible(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _should_check_control(control: Control) -> bool:
	return control is not MarginContainer \
		and control is not VBoxContainer \
		and control is not HBoxContainer \
		and control is not GridContainer

func _format_viewport_size(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]

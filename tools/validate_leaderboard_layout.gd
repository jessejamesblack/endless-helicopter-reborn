extends SceneTree

const DEBUG_MENU_SCENE := preload("res://scenes/ui/debug/debug_menu.tscn")
const LEADERBOARD_SCREEN_SCENE := preload("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")
const MISSION_SCREEN_SCENE := preload("res://scenes/ui/missions/mission_screen.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(960, 540),
]
const MISSION_SUMMARY := {
	"completed": 0,
	"total": 3,
	"time_until_reset": "02h 17m until new missions",
	"daily_streak": 0,
	"next_unlock": {
		"display_name": "Bubble Chopper",
		"progress_text": "0 / 1",
	},
	"missions": [
		{
			"id": "daily_2026-04-18_survive_seconds_total",
			"type": "survive_seconds_total",
			"title": "Survive 90 Seconds",
			"description": "Stay airborne for 90 total seconds today.",
			"target": 90,
			"progress": 0,
			"completed": false,
		},
		{
			"id": "daily_2026-04-18_missiles_fired",
			"type": "missiles_fired",
			"title": "Fire 12 Missiles",
			"description": "Fire 12 missiles today.",
			"target": 12,
			"progress": 0,
			"completed": false,
		},
		{
			"id": "daily_2026-04-18_projectile_intercepts",
			"type": "projectile_intercepts",
			"title": "Intercept 2 Projectiles",
			"description": "Knock down two enemy projectiles in one day.",
			"target": 2,
			"progress": 0,
			"completed": false,
		},
	],
}
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
	"near_misses": 12,
	"hostile_near_misses": 5,
	"projectile_near_misses": 7,
	"skill_score": 1640,
	"max_combo_multiplier": 3.0,
	"max_combo_events": 24,
	"missile_hits": 18,
	"missile_misses": 4,
	"max_missile_hit_streak": 6,
	"projectile_intercepts": 8,
}

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _validate_results_mode(viewport_size)
		await _validate_setup_mode(viewport_size)
		await _validate_leaderboard_mode(viewport_size)
		await _validate_mission_screen(viewport_size)
		await _validate_debug_menu(viewport_size)
		await _validate_main_hud(viewport_size)

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
	_assert_visible((screen.get("mission_card") as Control).visible, "Mission card should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("try_again_button") as Control).visible, "Try Again should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("results_button_row") as Control).visible, "Results actions should be visible in results mode at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("missions_button") as Control).visible, "Missions button should be visible in results mode at %s." % _format_viewport_size(viewport_size))
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

func _validate_mission_screen(viewport_size: Vector2i) -> void:
	var screen: Control = await _create_mission_screen(viewport_size)
	screen.call("apply_validation_state", MISSION_SUMMARY)
	await process_frame
	await process_frame
	_assert_visible((screen.get("mission_scroll") as Control).visible, "Mission scroll should be visible at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("button_row") as Control).visible, "Mission buttons should be visible at %s." % _format_viewport_size(viewport_size))
	_assert_visible((screen.get("reminder_button") as Control).visible, "Reminder button should be visible at %s." % _format_viewport_size(viewport_size))
	_assert_within_panel(screen, "mission screen", viewport_size)
	await _destroy_screen(screen)

func _validate_main_hud(viewport_size: Vector2i) -> void:
	var screen: Node = await _create_main_scene(viewport_size)
	for hud_side in ["left", "right"]:
		screen.set("combo_events", 3)
		screen.set("combo_multiplier", 1.25)
		screen.set("combo_timer", 3.0)
		screen.call("_update_combo_ui")
		screen.call("_apply_hud_layout", hud_side)
		await process_frame

		var combo_panel := screen.get("combo_panel") as Control
		var score_panel := screen.get("score_panel") as Control
		var ammo_panel := screen.get("ammo_panel") as Control
		var pause_button := screen.get("pause_button") as Control
		var fire_button := screen.get("fire_button") as Control

		_assert_visible(combo_panel.visible, "Combo panel should be visible in HUD validation at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])
		_assert_inside_viewport(combo_panel, "Combo panel should stay onscreen at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])
		_assert_no_overlap(combo_panel, score_panel, "Combo panel should not overlap score panel at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])
		_assert_no_overlap(combo_panel, ammo_panel, "Combo panel should not overlap ammo panel at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])
		_assert_no_overlap(combo_panel, pause_button, "Combo panel should not overlap pause button at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])
		_assert_no_overlap(combo_panel, fire_button, "Combo panel should not overlap fire button at %s on %s side." % [_format_viewport_size(viewport_size), hud_side])

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

func _create_mission_screen(viewport_size: Vector2i) -> Control:
	var root_window := get_root()
	root_window.size = viewport_size
	await process_frame
	var screen: Control = MISSION_SCREEN_SCENE.instantiate() as Control
	screen.set("validation_mode_enabled", true)
	root_window.add_child(screen)
	await process_frame
	await process_frame
	return screen

func _create_main_scene(viewport_size: Vector2i) -> Node:
	var root_window := get_root()
	root_window.size = viewport_size
	await process_frame
	var screen := MAIN_SCENE.instantiate()
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

func _assert_inside_viewport(control: Control, message: String) -> void:
	if control == null or not control.visible:
		_failures.append(message)
		return

	var tolerance := 2.0
	var viewport_size := control.get_viewport_rect().size
	var viewport_rect := Rect2(
		Vector2(-tolerance, -tolerance),
		viewport_size + Vector2.ONE * tolerance * 2.0
	)
	if not viewport_rect.encloses(control.get_global_rect()):
		_failures.append(message)

func _assert_no_overlap(a: Control, b: Control, message: String) -> void:
	if a == null or b == null or not a.visible or not b.visible:
		return
	if a.get_global_rect().intersects(b.get_global_rect()):
		_failures.append(message)

func _should_check_control(control: Control) -> bool:
	return control is not MarginContainer \
		and control is not VBoxContainer \
		and control is not HBoxContainer \
		and control is not GridContainer

func _format_viewport_size(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]

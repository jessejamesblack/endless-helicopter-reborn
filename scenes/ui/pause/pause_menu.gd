extends Control

signal resume_requested
signal quit_to_menu_requested

const PANEL_DESIRED_SIZE := Vector2(400.0, 440.0)
const PANEL_MARGIN := 24.0

@onready var menu_panel: Panel = $Overlay/Panel
@onready var resume_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var missions_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/MissionsButton
@onready var settings_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsButton
@onready var director_debug_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/DirectorDebugButton
@onready var quit_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/QuitButton
@onready var settings_menu = $SettingsMenu
@onready var mission_screen = $MissionScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)

	resume_button.pressed.connect(_on_resume_pressed)
	missions_button.pressed.connect(_on_missions_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	director_debug_button.pressed.connect(_on_director_debug_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_menu.closed.connect(_on_settings_closed)
	if mission_screen.has_signal("close_requested"):
		mission_screen.close_requested.connect(_on_missions_closed)
	_refresh_director_debug_button()

func open_menu() -> void:
	menu_panel.visible = true
	settings_menu.close_menu(false)
	mission_screen.visible = false
	visible = true
	_refresh_director_debug_button()
	resume_button.grab_focus()

func close_menu() -> void:
	settings_menu.close_menu(false)
	mission_screen.visible = false
	visible = false

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_menu.open_menu()

func _on_missions_pressed() -> void:
	menu_panel.visible = false
	if mission_screen.has_method("open_embedded"):
		mission_screen.open_embedded()
	else:
		mission_screen.visible = true

func _on_director_debug_pressed() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if not main.has_method("is_director_debug_enabled"):
		return
	if not main.has_method("set_director_debug_enabled"):
		return

	var is_enabled := bool(main.is_director_debug_enabled())
	main.set_director_debug_enabled(not is_enabled)
	_refresh_director_debug_button()

func _on_quit_pressed() -> void:
	quit_to_menu_requested.emit()

func _on_settings_closed() -> void:
	menu_panel.visible = true
	_refresh_director_debug_button()
	resume_button.grab_focus()

func _on_missions_closed() -> void:
	menu_panel.visible = true
	_refresh_director_debug_button()
	resume_button.grab_focus()

func _refresh_director_debug_button() -> void:
	if director_debug_button == null:
		return

	var main := get_tree().current_scene
	var can_toggle := OS.is_debug_build() and main != null and main.has_method("is_director_debug_enabled") and main.has_method("set_director_debug_enabled")
	director_debug_button.visible = can_toggle
	if not can_toggle:
		return

	var is_enabled := bool(main.is_director_debug_enabled())
	director_debug_button.text = "Director Debug: %s" % ("On" if is_enabled else "Off")

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(menu_panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(220.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(220.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(PANEL_DESIRED_SIZE.x, max_size.x),
		min(PANEL_DESIRED_SIZE.y, max_size.y)
	)
	menu_panel.offset_left = -target_size.x * 0.5
	menu_panel.offset_top = -target_size.y * 0.5
	menu_panel.offset_right = target_size.x * 0.5
	menu_panel.offset_bottom = target_size.y * 0.5

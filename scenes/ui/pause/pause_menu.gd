extends Control

signal resume_requested
signal quit_to_menu_requested

const PANEL_DESIRED_SIZE := Vector2(400.0, 320.0)
const PANEL_MARGIN := 24.0

@onready var menu_panel: Panel = $Overlay/Panel
@onready var resume_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/QuitButton
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_menu.closed.connect(_on_settings_closed)

func open_menu() -> void:
	menu_panel.visible = true
	settings_menu.close_menu(false)
	visible = true
	resume_button.grab_focus()

func close_menu() -> void:
	settings_menu.close_menu(false)
	visible = false

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	settings_menu.open_menu()

func _on_quit_pressed() -> void:
	quit_to_menu_requested.emit()

func _on_settings_closed() -> void:
	menu_panel.visible = true
	resume_button.grab_focus()

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

extends Control

signal resume_requested
signal quit_to_menu_requested

@onready var menu_panel: Panel = $Overlay/Panel
@onready var resume_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/QuitButton
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

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

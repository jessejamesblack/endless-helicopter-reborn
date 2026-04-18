extends Control

signal closed

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const PANEL_DESIRED_SIZE := Vector2(680.0, 496.0)
const PANEL_MARGIN := 24.0

@onready var panel: Panel = $Overlay/Panel
@onready var content_scroll: ScrollContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll
@onready var master_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/MasterRow/MasterValueRow/MasterSlider
@onready var master_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/MasterRow/MasterValueRow/MasterValueLabel
@onready var music_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/MusicRow/MusicValueRow/MusicSlider
@onready var music_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/MusicRow/MusicValueRow/MusicValueLabel
@onready var sfx_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/SfxRow/SfxValueRow/SfxSlider
@onready var sfx_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/AudioColumn/SfxRow/SfxValueRow/SfxValueLabel
@onready var fire_side_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/SystemColumn/FireSideRow/FireSideOption
@onready var hud_side_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/SystemColumn/HudSideValueLabel
@onready var haptics_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/SystemColumn/HapticsToggle
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/SystemColumn/PushSection/PushStatusLabel
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/SettingsCard/SettingsColumns/SystemColumn/PushSection/EnablePushButton
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_populate_side_options()

	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fire_side_option.item_selected.connect(_on_fire_side_selected)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	enable_push_button.pressed.connect(_on_enable_push_pressed)
	close_button.pressed.connect(_on_close_pressed)

	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_signal("diagnostics_changed"):
		var diagnostics_callback := Callable(self, "_on_push_diagnostics_changed")
		if not push_notifications.is_connected("diagnostics_changed", diagnostics_callback):
			push_notifications.connect("diagnostics_changed", diagnostics_callback)

	_sync_from_settings()

func open_menu() -> void:
	_fit_panel_to_viewport()
	_sync_from_settings()
	content_scroll.scroll_vertical = 0
	visible = true
	close_button.grab_focus()

func close_menu(emit_closed_signal: bool = true) -> void:
	visible = false
	if emit_closed_signal:
		closed.emit()

func _populate_side_options() -> void:
	if fire_side_option.item_count > 0:
		return

	fire_side_option.add_item("Left")
	fire_side_option.add_item("Right")

func _sync_from_settings() -> void:
	var game_settings = _get_game_settings()
	if game_settings == null:
		return

	master_slider.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	fire_side_option.set_block_signals(true)
	haptics_toggle.set_block_signals(true)

	master_slider.value = float(game_settings.get_master_volume())
	music_slider.value = float(game_settings.get_music_volume())
	sfx_slider.value = float(game_settings.get_sfx_volume())
	fire_side_option.select(0 if str(game_settings.get_fire_button_side()) == SIDE_LEFT else 1)
	haptics_toggle.button_pressed = bool(game_settings.is_haptics_enabled())

	master_slider.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	fire_side_option.set_block_signals(false)
	haptics_toggle.set_block_signals(false)

	_update_audio_labels()
	_update_layout_labels()
	_update_push_status()

func _update_audio_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value * 100.0))
	music_value_label.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value_label.text = "%d%%" % int(round(sfx_slider.value * 100.0))

func _update_layout_labels() -> void:
	var game_settings = _get_game_settings()
	var hud_side_text := "Left"
	if game_settings != null and str(game_settings.get_hud_side()) == SIDE_RIGHT:
		hud_side_text = "Right"
	hud_side_value_label.text = "HUD mirrors to: %s" % hud_side_text

func _on_master_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_master_volume(value)
	_update_audio_labels()

func _on_music_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_music_volume(value)
	_update_audio_labels()

func _on_sfx_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_sfx_volume(value)
	_update_audio_labels()

func _on_fire_side_selected(index: int) -> void:
	var side := SIDE_LEFT if index == 0 else SIDE_RIGHT
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_fire_button_side(side)
	_update_layout_labels()

func _on_haptics_toggled(enabled: bool) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_haptics_enabled(enabled)

func _on_enable_push_pressed() -> void:
	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_method("enable_notifications"):
		push_notifications.enable_notifications()
	_update_push_status()

func _on_push_diagnostics_changed(_status: Dictionary) -> void:
	_update_push_status()

func _update_push_status() -> void:
	var push_notifications = _get_push_notifications()
	if push_notifications == null or not push_notifications.has_method("get_diagnostics_text"):
		push_status_label.text = "Push unavailable: runtime service not loaded."
		enable_push_button.disabled = true
		return

	push_status_label.text = push_notifications.get_diagnostics_text()
	enable_push_button.disabled = OS.get_name() != "Android"

func _on_close_pressed() -> void:
	close_menu()

func _get_game_settings():
	return get_node_or_null("/root/GameSettings")

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(240.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(260.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(PANEL_DESIRED_SIZE.x, max_size.x),
		min(PANEL_DESIRED_SIZE.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

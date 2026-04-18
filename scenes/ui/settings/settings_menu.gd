extends Control

signal closed

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"

@onready var master_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/MasterRow/MasterValueRow/MasterSlider
@onready var master_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/MasterRow/MasterValueRow/MasterValueLabel
@onready var sfx_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/SfxRow/SfxValueRow/SfxSlider
@onready var sfx_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/SfxRow/SfxValueRow/SfxValueLabel
@onready var fire_side_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/FireSideRow/FireSideOption
@onready var hud_side_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/HudSideValueLabel
@onready var haptics_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/SettingsCard/SettingsVBox/HapticsToggle
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_populate_side_options()

	master_slider.value_changed.connect(_on_master_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fire_side_option.item_selected.connect(_on_fire_side_selected)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	close_button.pressed.connect(_on_close_pressed)

	_sync_from_settings()

func open_menu() -> void:
	_sync_from_settings()
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
	sfx_slider.set_block_signals(true)
	fire_side_option.set_block_signals(true)
	haptics_toggle.set_block_signals(true)

	master_slider.value = float(game_settings.get_master_volume())
	sfx_slider.value = float(game_settings.get_sfx_volume())
	fire_side_option.select(0 if str(game_settings.get_fire_button_side()) == SIDE_LEFT else 1)
	haptics_toggle.button_pressed = bool(game_settings.is_haptics_enabled())

	master_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	fire_side_option.set_block_signals(false)
	haptics_toggle.set_block_signals(false)

	_update_audio_labels()
	_update_layout_labels()

func _update_audio_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value * 100.0))
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

func _on_close_pressed() -> void:
	close_menu()

func _get_game_settings():
	return get_node_or_null("/root/GameSettings")

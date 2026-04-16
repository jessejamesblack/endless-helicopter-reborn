extends Node

signal audio_settings_changed(master_volume: float, sfx_volume: float)
signal layout_settings_changed(fire_button_side: String, hud_side: String)
signal haptics_settings_changed(haptics_enabled: bool)

const SETTINGS_PATH := "user://game_settings.cfg"
const SETTINGS_SECTION := "settings"
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const SFX_BUS_NAME := "SFX"
const MIN_VOLUME_LINEAR := 0.0001

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fire_button_side: String = SIDE_RIGHT
var hud_side: String = SIDE_LEFT
var haptics_enabled: bool = true

func _ready() -> void:
	load_settings()
	apply_settings(false)

func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		_apply_defaults()
		return

	master_volume = clampf(float(config.get_value(SETTINGS_SECTION, "master_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SETTINGS_SECTION, "sfx_volume", 1.0)), 0.0, 1.0)
	fire_button_side = _sanitize_side(str(config.get_value(SETTINGS_SECTION, "fire_button_side", SIDE_RIGHT)))
	hud_side = _mirror_side(fire_button_side)
	haptics_enabled = bool(config.get_value(SETTINGS_SECTION, "haptics_enabled", true))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)
	config.set_value(SETTINGS_SECTION, "fire_button_side", fire_button_side)
	config.set_value(SETTINGS_SECTION, "hud_side", hud_side)
	config.set_value(SETTINGS_SECTION, "haptics_enabled", haptics_enabled)
	config.save(SETTINGS_PATH)

func apply_settings(emit_signals: bool = true) -> void:
	hud_side = _mirror_side(fire_button_side)
	_ensure_sfx_bus()
	_apply_audio_bus_volumes()
	if emit_signals:
		audio_settings_changed.emit(master_volume, sfx_volume)
		layout_settings_changed.emit(fire_button_side, hud_side)
		haptics_settings_changed.emit(haptics_enabled)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_audio_bus_volumes()
	audio_settings_changed.emit(master_volume, sfx_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_audio_bus_volumes()
	audio_settings_changed.emit(master_volume, sfx_volume)

func set_fire_button_side(side: String) -> void:
	fire_button_side = _sanitize_side(side)
	hud_side = _mirror_side(fire_button_side)
	save_settings()
	layout_settings_changed.emit(fire_button_side, hud_side)

func set_hud_side(side: String) -> void:
	set_fire_button_side(_mirror_side(_sanitize_side(side)))

func set_haptics_enabled(enabled: bool) -> void:
	haptics_enabled = enabled
	save_settings()
	haptics_settings_changed.emit(haptics_enabled)

func get_master_volume() -> float:
	return master_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_fire_button_side() -> String:
	return fire_button_side

func get_hud_side() -> String:
	return hud_side

func is_haptics_enabled() -> bool:
	return haptics_enabled

func vibrate(duration_ms: int) -> void:
	if not haptics_enabled:
		return
	Input.vibrate_handheld(duration_ms)

func reset_to_defaults() -> void:
	_apply_defaults()
	save_settings()
	apply_settings()

func _apply_defaults() -> void:
	master_volume = 1.0
	sfx_volume = 1.0
	fire_button_side = SIDE_RIGHT
	hud_side = SIDE_LEFT
	haptics_enabled = true

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) != -1:
		return

	var bus_position := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_position)
	AudioServer.set_bus_name(bus_position, SFX_BUS_NAME)
	AudioServer.set_bus_send(bus_position, "Master")

func _apply_audio_bus_volumes() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index != -1:
		AudioServer.set_bus_volume_db(master_index, _linear_to_db(master_volume))

	var sfx_index := AudioServer.get_bus_index(SFX_BUS_NAME)
	if sfx_index != -1:
		AudioServer.set_bus_volume_db(sfx_index, _linear_to_db(sfx_volume))

func _linear_to_db(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return linear_to_db(maxf(value, MIN_VOLUME_LINEAR))

func _sanitize_side(side: String) -> String:
	if side == SIDE_LEFT:
		return SIDE_LEFT
	return SIDE_RIGHT

func _mirror_side(side: String) -> String:
	if _sanitize_side(side) == SIDE_LEFT:
		return SIDE_RIGHT
	return SIDE_LEFT

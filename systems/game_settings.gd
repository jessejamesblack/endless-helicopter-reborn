extends Node

signal audio_settings_changed(master_volume: float, music_volume: float, sfx_volume: float)
signal layout_settings_changed(fire_button_side: String, hud_side: String)
signal haptics_settings_changed(haptics_enabled: bool, haptics_intensity: float)
signal performance_settings_changed(frame_rate_setting: String, max_fps: int)
signal screenshot_settings_changed(achievement_screenshot_sharing_enabled: bool)
signal release_channel_override_changed(channel_override: String)

const SETTINGS_PATH := "user://game_settings.cfg"
const SETTINGS_SECTION := "settings"
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const MIN_VOLUME_LINEAR := 0.0001
const FRAME_RATE_BATTERY_SAVER := "battery_saver"
const FRAME_RATE_SMOOTH := "smooth"
const FRAME_RATE_ULTRA := "ultra"
const FRAME_RATE_DEVICE_DEFAULT := "device_default"

var master_volume: float = 1.0
var music_volume: float = 0.85
var sfx_volume: float = 1.0
var fire_button_side: String = SIDE_RIGHT
var hud_side: String = SIDE_LEFT
var haptics_enabled: bool = true
var haptics_intensity: float = 0.75
var frame_rate_setting: String = FRAME_RATE_DEVICE_DEFAULT
var achievement_screenshot_sharing_enabled: bool = true
var debug_release_channel_override: String = ""

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
	music_volume = clampf(float(config.get_value(SETTINGS_SECTION, "music_volume", 0.85)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SETTINGS_SECTION, "sfx_volume", 1.0)), 0.0, 1.0)
	fire_button_side = _sanitize_side(str(config.get_value(SETTINGS_SECTION, "fire_button_side", SIDE_RIGHT)))
	hud_side = _mirror_side(fire_button_side)
	haptics_enabled = bool(config.get_value(SETTINGS_SECTION, "haptics_enabled", true))
	haptics_intensity = clampf(float(config.get_value(SETTINGS_SECTION, "haptics_intensity", 0.75)), 0.0, 1.0)
	frame_rate_setting = _sanitize_frame_rate_setting(str(config.get_value(SETTINGS_SECTION, "frame_rate_setting", FRAME_RATE_DEVICE_DEFAULT)))
	achievement_screenshot_sharing_enabled = bool(config.get_value(SETTINGS_SECTION, "achievement_screenshot_sharing_enabled", true))
	debug_release_channel_override = _sanitize_release_channel_override(str(config.get_value(SETTINGS_SECTION, "debug_release_channel_override", "")))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION, "music_volume", music_volume)
	config.set_value(SETTINGS_SECTION, "sfx_volume", sfx_volume)
	config.set_value(SETTINGS_SECTION, "fire_button_side", fire_button_side)
	config.set_value(SETTINGS_SECTION, "hud_side", hud_side)
	config.set_value(SETTINGS_SECTION, "haptics_enabled", haptics_enabled)
	config.set_value(SETTINGS_SECTION, "haptics_intensity", haptics_intensity)
	config.set_value(SETTINGS_SECTION, "frame_rate_setting", frame_rate_setting)
	config.set_value(SETTINGS_SECTION, "achievement_screenshot_sharing_enabled", achievement_screenshot_sharing_enabled)
	config.set_value(SETTINGS_SECTION, "debug_release_channel_override", debug_release_channel_override)
	config.save(SETTINGS_PATH)

func apply_settings(emit_signals: bool = true) -> void:
	hud_side = _mirror_side(fire_button_side)
	_ensure_audio_buses()
	_apply_audio_bus_volumes()
	_apply_frame_rate_cap()
	if emit_signals:
		audio_settings_changed.emit(master_volume, music_volume, sfx_volume)
		layout_settings_changed.emit(fire_button_side, hud_side)
		haptics_settings_changed.emit(haptics_enabled, haptics_intensity)
		performance_settings_changed.emit(frame_rate_setting, get_target_max_fps())
		screenshot_settings_changed.emit(achievement_screenshot_sharing_enabled)
		release_channel_override_changed.emit(debug_release_channel_override)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_audio_bus_volumes()
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_audio_bus_volumes()
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply_audio_bus_volumes()
	audio_settings_changed.emit(master_volume, music_volume, sfx_volume)

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
	haptics_settings_changed.emit(haptics_enabled, haptics_intensity)

func set_haptics_intensity(value: float) -> void:
	haptics_intensity = clampf(value, 0.0, 1.0)
	save_settings()
	haptics_settings_changed.emit(haptics_enabled, haptics_intensity)

func set_frame_rate_setting(value: String) -> void:
	frame_rate_setting = _sanitize_frame_rate_setting(value)
	save_settings()
	_apply_frame_rate_cap()
	performance_settings_changed.emit(frame_rate_setting, get_target_max_fps())

func set_achievement_screenshot_sharing_enabled(enabled: bool) -> void:
	achievement_screenshot_sharing_enabled = enabled
	save_settings()
	screenshot_settings_changed.emit(achievement_screenshot_sharing_enabled)

func set_debug_release_channel_override(value: String) -> void:
	debug_release_channel_override = _sanitize_release_channel_override(value)
	save_settings()
	release_channel_override_changed.emit(debug_release_channel_override)

func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_fire_button_side() -> String:
	return fire_button_side

func get_hud_side() -> String:
	return hud_side

func is_haptics_enabled() -> bool:
	return haptics_enabled

func get_haptics_intensity() -> float:
	return haptics_intensity

func get_frame_rate_setting() -> String:
	return frame_rate_setting

func is_achievement_screenshot_sharing_enabled() -> bool:
	return achievement_screenshot_sharing_enabled

func get_debug_release_channel_override() -> String:
	return debug_release_channel_override

func get_target_max_fps() -> int:
	match frame_rate_setting:
		FRAME_RATE_BATTERY_SAVER:
			return 60
		FRAME_RATE_SMOOTH:
			return 90
		FRAME_RATE_ULTRA:
			return 120
	return 0

func vibrate(duration_ms: int) -> void:
	if not haptics_enabled:
		return
	var haptics_manager = get_node_or_null("/root/HapticsManager")
	if haptics_manager != null and haptics_manager.has_method("vibrate_legacy"):
		haptics_manager.vibrate_legacy(duration_ms)
		return
	Input.vibrate_handheld(duration_ms)

func reset_to_defaults() -> void:
	_apply_defaults()
	save_settings()
	apply_settings()

func _apply_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.85
	sfx_volume = 1.0
	fire_button_side = SIDE_RIGHT
	hud_side = SIDE_LEFT
	haptics_enabled = true
	haptics_intensity = 0.75
	frame_rate_setting = FRAME_RATE_DEVICE_DEFAULT
	achievement_screenshot_sharing_enabled = true
	debug_release_channel_override = ""

func _ensure_audio_buses() -> void:
	_ensure_bus(MUSIC_BUS_NAME)
	_ensure_bus(SFX_BUS_NAME)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_position := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_position)
	AudioServer.set_bus_name(bus_position, bus_name)
	AudioServer.set_bus_send(bus_position, "Master")

func _apply_audio_bus_volumes() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index != -1:
		AudioServer.set_bus_volume_db(master_index, _linear_to_db(master_volume))

	var music_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_index != -1:
		AudioServer.set_bus_volume_db(music_index, _linear_to_db(music_volume))

	var sfx_index := AudioServer.get_bus_index(SFX_BUS_NAME)
	if sfx_index != -1:
		AudioServer.set_bus_volume_db(sfx_index, _linear_to_db(sfx_volume))

func _apply_frame_rate_cap() -> void:
	Engine.max_fps = get_target_max_fps()

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

func _sanitize_frame_rate_setting(value: String) -> String:
	match value:
		FRAME_RATE_BATTERY_SAVER, FRAME_RATE_SMOOTH, FRAME_RATE_ULTRA, FRAME_RATE_DEVICE_DEFAULT:
			return value
	return FRAME_RATE_DEVICE_DEFAULT

func _sanitize_release_channel_override(value: String) -> String:
	match value:
		"", "stable", "beta", "dev":
			return value
	return ""

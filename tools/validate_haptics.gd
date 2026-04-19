extends SceneTree

const HapticsManagerScript = preload("res://systems/haptics_manager.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var haptics_manager := get_root().get_node_or_null("HapticsManager")
	var game_settings := get_root().get_node_or_null("GameSettings")
	_assert(haptics_manager != null, "HapticsManager autoload should exist.")
	_assert(game_settings != null, "GameSettings autoload should exist for haptics validation.")

	for preset_id in HapticsManagerScript.PRESETS.keys():
		var preset: Dictionary = HapticsManagerScript.PRESETS[preset_id]
		_assert(preset.has("duration_ms"), "Haptics preset %s should define duration_ms." % preset_id)
		_assert(preset.has("amplitude"), "Haptics preset %s should define amplitude." % preset_id)
		_assert(preset.has("cooldown_ms"), "Haptics preset %s should define cooldown_ms." % preset_id)
		_assert(int(preset.get("duration_ms", 0)) <= 120, "Haptics preset %s should stay under 120ms." % preset_id)
		_assert(float(preset.get("amplitude", 0.0)) <= 1.0, "Haptics preset %s amplitude should stay at or below 1.0." % preset_id)

	_assert(game_settings.has_method("is_haptics_enabled"), "GameSettings should expose is_haptics_enabled().")
	_assert(game_settings.has_method("set_haptics_enabled"), "GameSettings should expose set_haptics_enabled().")
	_assert(game_settings.has_method("get_haptics_intensity"), "GameSettings should expose get_haptics_intensity().")
	_assert(game_settings.has_method("set_haptics_intensity"), "GameSettings should expose set_haptics_intensity().")

	var settings_scene := load("res://scenes/ui/settings/settings_menu.tscn") as PackedScene
	_assert(settings_scene != null, "Settings menu should load for haptics validation.")
	if settings_scene != null:
		var settings_menu := settings_scene.instantiate() as Control
		get_root().add_child(settings_menu)
		await process_frame
		_assert(settings_menu.get_node_or_null("Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HapticsToggle") != null, "Settings menu should include the haptics toggle.")
		_assert(settings_menu.get_node_or_null("Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HapticsIntensityRow/HapticsIntensityValueRow/HapticsIntensitySlider") != null, "Settings menu should include the haptics intensity slider.")
		settings_menu.free()
		await process_frame

	var game_settings_source := FileAccess.get_file_as_string("res://systems/game_settings.gd")
	_assert(game_settings_source.contains("haptics_intensity"), "GameSettings should persist haptics_intensity.")
	_assert(game_settings_source.contains("haptics_enabled"), "GameSettings should persist haptics_enabled.")

	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_assert(export_presets.contains("permissions/vibrate=true"), "Android export preset should enable the VIBRATE permission.")

	var direct_vibrate_matches := _find_unapproved_vibrate_calls("res://")
	_assert(direct_vibrate_matches.is_empty(), "Only HapticsManager and the GameSettings legacy wrapper should call Input.vibrate_handheld directly. Found: %s" % ", ".join(direct_vibrate_matches))

	_finish()

func _find_unapproved_vibrate_calls(root_path: String) -> Array[String]:
	var matches: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return matches
	_scan_for_direct_vibrate_calls(dir, root_path, matches)
	return matches

func _scan_for_direct_vibrate_calls(dir: DirAccess, current_path: String, matches: Array[String]) -> void:
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var entry_path := "%s%s" % [current_path, entry]
		if dir.current_is_dir():
			var child_dir := DirAccess.open(entry_path + "/")
			if child_dir != null:
				_scan_for_direct_vibrate_calls(child_dir, entry_path + "/", matches)
			continue
		if not entry.ends_with(".gd"):
			continue
		if (
			entry_path == "res://systems/haptics_manager.gd"
			or entry_path == "res://systems/game_settings.gd"
			or entry_path == "res://tools/validate_haptics.gd"
			or entry_path.ends_with("/validate_haptics.gd")
		):
			continue
		var source := FileAccess.get_file_as_string(entry_path)
		if source.contains("Input.vibrate_handheld"):
			matches.append(entry_path)
	dir.list_dir_end()

func _finish() -> void:
	if _failures.is_empty():
		print("Haptics validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

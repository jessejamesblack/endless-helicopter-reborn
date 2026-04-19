extends SceneTree

const BackgroundCatalogScript = preload("res://systems/background_catalog.gd")

const DISALLOWED_NAME_PARTS := ["placeholder", "temp", "draft", "test", "copy", "screenshot", "generated_raw"]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist for art-quality validation.")
	if helicopter_skins != null:
		for vehicle_id in helicopter_skins.get_vehicle_ids():
			var vehicle_data: Dictionary = helicopter_skins.get_vehicle_data(vehicle_id)
			_assert(str(vehicle_data.get("art_quality_status", "")) == "final", "Vehicle %s should be final-quality art." % vehicle_id)
			_validate_path(str(vehicle_data.get("texture", "")), "vehicle %s texture" % vehicle_id)
			if helicopter_skins.is_original_icon_available(vehicle_id):
				var icon_skin: Dictionary = helicopter_skins.get_vehicle_skin_data(vehicle_id, "original_icon")
				_validate_path(str(icon_skin.get("texture", "")), "%s original icon texture" % vehicle_id)

	var biome_count := 0
	for biome in BackgroundCatalogScript.get_visible_biomes():
		biome_count += 1
		_assert(str(biome.get("art_quality_status", "")) == "final", "Background biome %s should be final-quality." % str(biome.get("id", "")))
		_assert((biome.get("layers", []) as Array).size() >= 3, "Background biome %s should define layered presentation." % str(biome.get("id", "")))
		_validate_path(str(biome.get("sky_texture", "")), "background biome %s sky texture" % str(biome.get("id", "")))
		_validate_path(str(biome.get("far_texture", "")), "background biome %s far texture" % str(biome.get("id", "")))
		_validate_path(str(biome.get("mid_texture", "")), "background biome %s mid texture" % str(biome.get("id", "")))
		_validate_path(str(biome.get("near_texture", "")), "background biome %s near texture" % str(biome.get("id", "")))
	_assert(biome_count >= 3, "At least three visible final background biomes should exist.")

	var hangar_scene := load("res://scenes/ui/hangar/hangar_screen.tscn") as PackedScene
	_assert(hangar_scene != null, "Hangar scene should load for art-quality preview checks.")
	if hangar_scene != null:
		var hangar := hangar_scene.instantiate() as Control
		get_root().add_child(hangar)
		await process_frame
		if hangar.has_method("get_preview_state"):
			var preview_state: Dictionary = hangar.get_preview_state()
			_assert((preview_state.get("scale", Vector2.ZERO) as Vector2).length() > 0.0, "Hangar preview should provide a usable preview scale.")
		hangar.free()
		await process_frame

	var helicopter_skins_source := FileAccess.get_file_as_string("res://systems/helicopter_skins.gd")
	_assert(not helicopter_skins_source.contains("\"use_background_key\": true"), "Visible production vehicle art should not rely on background-key transparency hacks.")

	_finish()

func _validate_path(path: String, label: String) -> void:
	_assert(not path.is_empty(), "%s should not be empty." % label)
	if path.is_empty():
		return
	_assert(ResourceLoader.exists(path), "%s should exist." % label)
	var lower_path := path.to_lower()
	for token in DISALLOWED_NAME_PARTS:
		_assert(not lower_path.contains(token), "%s should not reference %s content." % [label, token])

func _finish() -> void:
	if _failures.is_empty():
		print("Art quality validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

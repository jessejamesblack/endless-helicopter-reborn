extends SceneTree

const BackgroundCatalogScript = preload("res://systems/background_catalog.gd")
const BACKGROUND_MANAGER_SCENE := preload("res://scenes/background/background_manager.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var visible_biomes := BackgroundCatalogScript.get_visible_biomes()
	_assert(visible_biomes.size() >= 3, "BackgroundCatalog should expose at least three visible biomes.")
	for biome in visible_biomes:
		_assert(str(biome.get("art_quality_status", "")) == "final", "Visible biome %s should be final quality." % str(biome.get("id", "")))
		var layers := biome.get("layers", []) as Array
		_assert(layers.has("sky"), "Biome %s should include a sky layer." % str(biome.get("id", "")))
		_assert(layers.has("far"), "Biome %s should include a far layer." % str(biome.get("id", "")))
		_assert(layers.has("mid"), "Biome %s should include a mid layer." % str(biome.get("id", "")))
		_assert(layers.has("near"), "Biome %s should include a near layer." % str(biome.get("id", "")))
		_assert(ResourceLoader.exists(str(biome.get("sky_texture", ""))), "Biome %s should provide a sky texture asset." % str(biome.get("id", "")))
		_assert(ResourceLoader.exists(str(biome.get("far_texture", ""))), "Biome %s should provide a far texture asset." % str(biome.get("id", "")))
		_assert(ResourceLoader.exists(str(biome.get("mid_texture", ""))), "Biome %s should provide a mid texture asset." % str(biome.get("id", "")))
		_assert(ResourceLoader.exists(str(biome.get("near_texture", ""))), "Biome %s should provide a near texture asset." % str(biome.get("id", "")))

	var background_manager := BACKGROUND_MANAGER_SCENE.instantiate()
	get_root().add_child(background_manager)
	await process_frame
	await process_frame
	_assert(background_manager.has_method("get_current_biome_id"), "BackgroundManager should expose get_current_biome_id().")
	if background_manager.has_method("get_current_biome_id"):
		_assert(not str(background_manager.get_current_biome_id()).is_empty(), "BackgroundManager should select a starting biome.")
	_assert(background_manager.get_child_count() >= 6, "BackgroundManager should build layered runtime children.")
	background_manager.free()
	await process_frame

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Background quality validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

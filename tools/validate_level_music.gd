extends SceneTree

const BackgroundCatalogScript = preload("res://systems/background_catalog.gd")
const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	for biome in BackgroundCatalogScript.get_visible_biomes():
		var track_path := str(biome.get("music_track", ""))
		Helper.assert_condition(_failures, not track_path.is_empty(), "Visible biome %s should have a music track." % str(biome.get("id", "")))
		Helper.assert_condition(_failures, ResourceLoader.exists(track_path), "Music track should exist for biome %s." % str(biome.get("id", "")))
	var music_text := Helper.read_text("res://systems/music_player.gd")
	Helper.assert_condition(_failures, music_text.contains("play_biome_music"), "MusicPlayer should expose biome music playback.")
	Helper.finish(self, _failures, "Level music validation completed successfully.")

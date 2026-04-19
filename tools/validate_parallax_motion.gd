extends SceneTree

const BackgroundCatalogScript = preload("res://systems/background_catalog.gd")
const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	for biome in BackgroundCatalogScript.get_visible_biomes():
		Helper.assert_condition(_failures, float(biome.get("far_speed_factor", 0.0)) >= 0.08, "Far parallax speed should stay above the new minimum.")
		Helper.assert_condition(_failures, float(biome.get("mid_speed_factor", 0.0)) >= 0.25, "Mid parallax speed should stay above the new minimum.")
		Helper.assert_condition(_failures, float(biome.get("near_speed_factor", 0.0)) >= 0.55, "Near parallax speed should stay above the new minimum.")
		Helper.assert_condition(_failures, int(biome.get("accent_count", 0)) >= 1, "Visible biomes should include accent motion for Sprint 6.")
	var manager_text := Helper.read_text("res://scenes/background/background_manager.gd")
	Helper.assert_condition(_failures, manager_text.contains("_accent_layer"), "BackgroundManager should build an accent layer.")
	Helper.assert_condition(_failures, manager_text.contains("_get_intensity_scale"), "BackgroundManager should scale background motion with intensity.")
	Helper.assert_condition(_failures, manager_text.contains("_biome_travel_progress"), "BackgroundManager should track shared biome travel progress.")
	Helper.assert_condition(_failures, manager_text.contains("_apply_forward_parallax_layer"), "BackgroundManager should use forward-only parallax layers.")
	Helper.assert_condition(_failures, not manager_text.contains("_pan_dynamic_layer"), "BackgroundManager should not use ping-pong parallax any more.")
	Helper.finish(self, _failures, "Parallax motion validation completed successfully.")

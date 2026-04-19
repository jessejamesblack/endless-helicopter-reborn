extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://systems/achievement_screenshot_manager.gd")
	Helper.assert_file_exists(_failures, "res://scenes/ui/share/achievement_share_card.tscn")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/post-achievement-screenshot/index.ts")
	var project_text := Helper.read_text("res://project.godot")
	Helper.assert_condition(_failures, project_text.contains("AchievementScreenshotManager"), "AchievementScreenshotManager should be autoloaded in project.godot.")
	var settings_text := Helper.read_text("res://systems/game_settings.gd")
	Helper.assert_condition(_failures, settings_text.contains("achievement_screenshot_sharing_enabled"), "Game settings should expose screenshot sharing.")
	Helper.finish(self, _failures, "Achievement screenshot validation completed successfully.")

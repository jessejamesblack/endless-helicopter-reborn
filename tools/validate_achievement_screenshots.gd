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
	var manager_text := Helper.read_text("res://systems/achievement_screenshot_manager.gd")
	Helper.assert_condition(_failures, manager_text.contains("CAPTURE_MODE_RESULTS_SCREEN"), "Achievement screenshot manager should support results-screen capture mode.")
	Helper.assert_condition(_failures, manager_text.contains("is_ready_for_achievement_screenshot"), "Achievement screenshot manager should wait for results-screen readiness before capture.")
	var leaderboard_text := Helper.read_text("res://scenes/ui/leaderboard/leaderboard_screen.gd")
	Helper.assert_condition(_failures, leaderboard_text.contains("func is_ready_for_achievement_screenshot()"), "Leaderboard screen should expose achievement screenshot readiness.")
	Helper.finish(self, _failures, "Achievement screenshot validation completed successfully.")

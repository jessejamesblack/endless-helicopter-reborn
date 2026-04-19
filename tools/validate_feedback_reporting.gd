extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://scenes/ui/feedback/feedback_screen.tscn")
	Helper.assert_file_exists(_failures, "res://scenes/ui/feedback/feedback_screen.gd")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/report-feedback/index.ts")
	var debug_menu_text := Helper.read_text("res://scenes/ui/debug/debug_menu.tscn")
	Helper.assert_condition(_failures, debug_menu_text.contains("Send Feedback"), "Debug menu should expose Send Feedback.")
	Helper.assert_condition(_failures, debug_menu_text.contains("Copy Bug Report"), "Debug menu should expose Copy Bug Report.")
	var settings_text := Helper.read_text("res://scenes/ui/settings/settings_menu.tscn")
	Helper.assert_condition(_failures, not settings_text.contains("Send Feedback"), "Settings menu should keep feedback actions out of the player-facing panel.")
	Helper.finish(self, _failures, "Feedback reporting validation completed successfully.")

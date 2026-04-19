extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://scenes/ui/feedback/feedback_screen.tscn")
	Helper.assert_file_exists(_failures, "res://scenes/ui/feedback/feedback_screen.gd")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/report-feedback/index.ts")
	var settings_text := Helper.read_text("res://scenes/ui/settings/settings_menu.tscn")
	Helper.assert_condition(_failures, settings_text.contains("Send Feedback"), "Settings menu should expose Send Feedback.")
	Helper.assert_condition(_failures, settings_text.contains("Copy Bug Report"), "Settings menu should expose Copy Bug Report.")
	Helper.finish(self, _failures, "Feedback reporting validation completed successfully.")

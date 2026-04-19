extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://systems/error_reporter.gd")
	Helper.assert_file_exists(_failures, "res://backend/supabase_error_logging_setup.sql")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/report-client-error/index.ts")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/_shared/email_alert.ts")
	var project_text := Helper.read_text("res://project.godot")
	Helper.assert_condition(_failures, project_text.contains("ErrorReporter"), "ErrorReporter should be autoloaded in project.godot.")
	var error_reporter_text := Helper.read_text("res://systems/error_reporter.gd")
	Helper.assert_condition(_failures, error_reporter_text.contains("client_error_queue"), "ErrorReporter should persist an offline queue.")
	Helper.assert_condition(_failures, error_reporter_text.contains("sanitize"), "ErrorReporter should sanitize sensitive diagnostics.")
	Helper.finish(self, _failures, "Error logging validation completed successfully.")

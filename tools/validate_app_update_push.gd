extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/publish-app-release-info/index.ts")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/send-app-update-push/index.ts")
	var workflow_text := Helper.read_text("res://.github/workflows/android-apk.yml")
	Helper.assert_condition(_failures, workflow_text.contains("publish-app-release-info"), "Workflow should publish app release metadata.")
	Helper.assert_condition(_failures, workflow_text.contains("send-app-update-push"), "Workflow should trigger the app update push function.")
	Helper.assert_condition(_failures, workflow_text.contains("RELEASE_WEBHOOK_SECRET"), "Workflow should use RELEASE_WEBHOOK_SECRET for release webhooks.")
	Helper.finish(self, _failures, "App update push validation completed successfully.")

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

	var service_text := Helper.read_text("res://android/plugins/fcm_push_bridge/src/main/java/com/endlesshelicopter/push/ScoreBeatenFirebaseMessagingService.kt")
	Helper.assert_condition(_failures, service_text.contains("resolveNotificationTitle"), "Android push service should resolve notification titles by payload type.")
	Helper.assert_condition(_failures, service_text.contains("resolveNotificationBody"), "Android push service should resolve notification bodies by payload type.")
	Helper.assert_condition(_failures, service_text.contains("\"app_update\" -> \"Update Available\""), "App-update pushes should get an update-specific fallback title.")
	Helper.assert_condition(_failures, service_text.contains("\"app_update\" -> buildAppUpdateFallbackBody(payload)"), "App-update pushes should get an update-specific fallback body.")
	Helper.assert_condition(_failures, service_text.contains("\"score_beaten\" -> buildScoreBeatenFallbackBody(payload)"), "Score-beaten fallback copy should only be used for score-beaten payloads.")
	Helper.assert_condition(_failures, service_text.contains("toLongOrNull() ?: return null"), "Score-beaten fallback should require valid numeric score fields.")
	Helper.assert_condition(_failures, not service_text.contains("payload[\"title\"] ?: \"Score Beaten\""), "Generic missing-title fallback must not default every push to Score Beaten.")
	Helper.assert_condition(_failures, not service_text.contains("payload[\"beaten_score\"] ?: \"0\""), "Score-beaten fallback must not invent a 0 beaten score.")

	var app_update_push_text := Helper.read_text("res://backend/supabase/functions/send-app-update-push/index.ts")
	Helper.assert_condition(_failures, app_update_push_text.contains("makeUpdateNotificationBody"), "App-update Edge Function should build explicit update notification copy.")
	Helper.assert_condition(_failures, app_update_push_text.contains("title: notificationTitle"), "App-update FCM payload should include a title for older clients.")
	Helper.assert_condition(_failures, app_update_push_text.contains("body: notificationBody"), "App-update FCM payload should include a body for older clients.")
	Helper.finish(self, _failures, "App update push validation completed successfully.")

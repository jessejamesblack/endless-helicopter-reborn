extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/_shared/discord_webhook.ts")
	var score_push_text := Helper.read_text("res://backend/supabase/functions/send-score-beaten-push/index.ts")
	var daily_push_text := Helper.read_text("res://backend/supabase/functions/send-daily-mission-push/index.ts")
	Helper.assert_condition(_failures, score_push_text.contains("postDiscordWebhook"), "Score-beaten push should post to Discord.")
	Helper.assert_condition(_failures, daily_push_text.contains("postDiscordWebhook"), "Daily mission push should post to Discord.")
	Helper.assert_condition(_failures, score_push_text.contains("family_push_delivery_log"), "Score-beaten push should still log delivery attempts.")
	Helper.assert_condition(_failures, not score_push_text.contains("allowed_mentions.parse = ['"), "Discord helper should disable mentions through the shared webhook helper.")
	Helper.finish(self, _failures, "Discord integration validation completed successfully.")

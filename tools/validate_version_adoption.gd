extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var sql_text := Helper.read_text("res://backend/supabase_app_release_setup.sql")
	Helper.assert_condition(_failures, sql_text.contains("app_version_code"), "Version adoption SQL should store app_version_code.")
	Helper.assert_condition(_failures, sql_text.contains("app_version_name"), "Version adoption SQL should store app_version_name.")
	Helper.assert_condition(_failures, sql_text.contains("build_sha"), "Version adoption SQL should store build_sha.")
	Helper.assert_condition(_failures, sql_text.contains("release_channel"), "Version adoption SQL should store release_channel.")
	Helper.assert_condition(_failures, sql_text.contains("family_app_version_adoption"), "Version adoption SQL should expose a version adoption view.")
	var push_text := Helper.read_text("res://systems/push_notifications.gd")
	Helper.assert_condition(_failures, push_text.contains("release_channel"), "Push registration should include the release channel.")
	var leaderboard_text := Helper.read_text("res://systems/online_leaderboard.gd")
	Helper.assert_condition(_failures, leaderboard_text.contains("app_version_code"), "Leaderboard helpers should include build metadata in device registration.")
	Helper.finish(self, _failures, "Version adoption validation completed successfully.")

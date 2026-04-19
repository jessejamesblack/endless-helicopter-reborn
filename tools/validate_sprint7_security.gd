extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

const PROTECTED_FUNCTIONS := [
	"res://backend/supabase/functions/submit-score/index.ts",
	"res://backend/supabase/functions/sync-player-profile/index.ts",
	"res://backend/supabase/functions/sync-daily-mission-progress/index.ts",
	"res://backend/supabase/functions/get-player-profile/index.ts",
	"res://backend/supabase/functions/get-daily-mission-progress/index.ts",
	"res://backend/supabase/functions/get-notifications/index.ts",
	"res://backend/supabase/functions/mark-notifications-read/index.ts",
	"res://backend/supabase/functions/report-feedback/index.ts",
	"res://backend/supabase/functions/post-achievement-screenshot/index.ts",
]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/_shared/version_gate.ts")
	Helper.assert_file_exists(_failures, "res://backend/supabase_sprint7_security_setup.sql")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/register-push-device/index.ts")

	var version_gate_text := Helper.read_text("res://backend/supabase/functions/_shared/version_gate.ts")
	_assert(version_gate_text.contains("426"), "Version gate helper should return HTTP 426 for outdated builds.")
	_assert(version_gate_text.contains("upgrade_required"), "Version gate helper should return upgrade_required errors.")
	_assert(version_gate_text.contains("This build is too old"), "Version gate helper should explain the upgrade requirement.")

	for path in PROTECTED_FUNCTIONS:
		var function_text := Helper.read_text(path)
		_assert(function_text.contains("getCurrentVersionCode"), "%s should read current_version_code." % path)
		_assert(function_text.contains("getReleaseConfig"), "%s should read the release config." % path)
		_assert(function_text.contains("isVersionSupported"), "%s should enforce minimum supported version checks." % path)
		_assert(function_text.contains("versionGateResponse"), "%s should return versionGateResponse() for stale builds." % path)

	var push_registration_text := Helper.read_text("res://backend/supabase/functions/register-push-device/index.ts")
	_assert(not push_registration_text.contains("versionGateResponse"), "register-push-device should stay available for outdated builds.")
	_assert(push_registration_text.contains("family_push_devices"), "register-push-device should still target family_push_devices.")

	var security_sql := Helper.read_text("res://backend/supabase_sprint7_security_setup.sql")
	_assert(security_sql.contains("enable row level security"), "Sprint 7 security SQL should keep RLS enabled.")
	_assert(security_sql.contains("drop policy if exists \"family_push_devices_insert\""), "Sprint 7 security SQL should remove direct push-device writes.")
	_assert(security_sql.contains("drop policy if exists \"family_player_profiles_read\""), "Sprint 7 security SQL should remove direct profile table access.")
	_assert(security_sql.contains("revoke execute on function public.submit_family_score_v2"), "Sprint 7 security SQL should revoke direct score RPC access.")
	_assert(security_sql.contains("revoke execute on function public.sync_player_profile"), "Sprint 7 security SQL should revoke direct profile sync RPC access.")
	_assert(security_sql.contains("revoke execute on function public.sync_daily_mission_progress"), "Sprint 7 security SQL should revoke direct mission sync RPC access.")
	_assert(security_sql.contains("revoke execute on function public.get_player_profile"), "Sprint 7 security SQL should revoke direct profile restore RPC access.")
	_assert(security_sql.contains("revoke execute on function public.get_daily_mission_progress"), "Sprint 7 security SQL should revoke direct mission restore RPC access.")

	var leaderboard_text := Helper.read_text("res://systems/online_leaderboard.gd")
	_assert(leaderboard_text.contains("submit-score"), "OnlineLeaderboard should target the submit-score Edge Function.")
	_assert(leaderboard_text.contains("sync-player-profile"), "OnlineLeaderboard should target the sync-player-profile Edge Function.")
	_assert(leaderboard_text.contains("sync-daily-mission-progress"), "OnlineLeaderboard should target the sync-daily-mission-progress Edge Function.")
	_assert(leaderboard_text.contains("get-player-profile"), "OnlineLeaderboard should target the get-player-profile Edge Function.")
	_assert(leaderboard_text.contains("get-daily-mission-progress"), "OnlineLeaderboard should target the get-daily-mission-progress Edge Function.")
	_assert(leaderboard_text.contains("get-notifications"), "OnlineLeaderboard should target the get-notifications Edge Function.")
	_assert(leaderboard_text.contains("mark-notifications-read"), "OnlineLeaderboard should target the mark-notifications-read Edge Function.")
	_assert(leaderboard_text.contains("is_upgrade_required_response"), "OnlineLeaderboard should expose upgrade-required response handling.")

	var queue_text := Helper.read_text("res://systems/supabase_sync_queue.gd")
	_assert(queue_text.contains("_handle_upgrade_required_response"), "SupabaseSyncQueue should treat 426 responses as upgrade-required state.")
	_assert(queue_text.contains("_drop_all_jobs_for_upgrade_required"), "SupabaseSyncQueue should drop or pause blocked jobs cleanly.")

	var feedback_text := Helper.read_text("res://scenes/ui/feedback/feedback_screen.gd")
	_assert(feedback_text.contains("handle_upgrade_required"), "Feedback screen should route 426 responses into the update flow.")

	var screenshot_text := Helper.read_text("res://systems/achievement_screenshot_manager.gd")
	_assert(screenshot_text.contains("handle_upgrade_required"), "Achievement screenshots should stop retrying when a build is too old.")

	Helper.finish(self, _failures, "Sprint 7 security validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

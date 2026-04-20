extends SceneTree

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const RUN_STATS_PATH := "user://run_stats.cfg"

var _failures: Array[String] = []
var _backups: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_backup_user_file(OnlineLeaderboardScript.NAME_CACHE_PATH)
	_backup_user_file(OnlineLeaderboardScript.CLOUD_PROFILE_CACHE_PATH)
	_backup_user_file(RUN_STATS_PATH)

	var sync_queue := get_root().get_node_or_null("SupabaseSyncQueue")
	var run_stats := get_root().get_node_or_null("RunStats")
	_assert(sync_queue != null, "SupabaseSyncQueue autoload should exist for restore resume validation.")
	_assert(run_stats != null, "RunStats autoload should exist for restore resume validation.")
	if sync_queue == null or run_stats == null:
		_restore_user_files()
		_finish()
		return

	OnlineLeaderboardScript.clear_cached_name()
	OnlineLeaderboardScript.clear_cloud_profile_presence()

	_assert(not OnlineLeaderboardScript.has_saved_player_name(), "Fresh startup should not report a saved public player name.")
	_assert(not OnlineLeaderboardScript.has_cloud_profile(), "Fresh startup should not report a cloud profile before restore.")
	_assert(not OnlineLeaderboardScript.has_saved_profile(), "Legacy saved-profile helper should still be name-based.")
	_assert(bool(sync_queue.call("_should_replace_local_state_on_startup")), "Startup should replace local state when no cloud profile marker exists.")

	OnlineLeaderboardScript.mark_cloud_profile_present()
	_assert(OnlineLeaderboardScript.has_cloud_profile(), "Cloud profile marker should count as a restored cloud profile.")
	_assert(not OnlineLeaderboardScript.has_saved_player_name(), "Cloud profile marker alone should not invent a public leaderboard name.")
	_assert(not OnlineLeaderboardScript.has_saved_profile(), "Legacy saved-profile helper should stay false until a public name is cached.")
	_assert(not bool(sync_queue.call("_should_replace_local_state_on_startup")), "Startup should merge instead of replace once a cloud profile marker exists.")

	OnlineLeaderboardScript.save_cached_name("  Pilot  ")
	_assert(OnlineLeaderboardScript.load_cached_name() == "Pilot", "Saved player names should be sanitized before caching.")
	_assert(OnlineLeaderboardScript.has_saved_player_name(), "Caching a public name should mark the player name as saved.")
	_assert(OnlineLeaderboardScript.has_cloud_profile(), "A saved public name should also count as a cloud profile for UI flows.")
	_assert(OnlineLeaderboardScript.has_saved_profile(), "Legacy saved-profile helper should remain true for name-based leaderboard flows.")

	OnlineLeaderboardScript.clear_cached_name()
	_assert(not OnlineLeaderboardScript.has_saved_player_name(), "Clearing the cached name should remove the public-name marker.")
	_assert(OnlineLeaderboardScript.has_cloud_profile(), "Clearing the cached name should not erase the cloud-profile marker.")
	_assert(not OnlineLeaderboardScript.has_saved_profile(), "Legacy saved-profile helper should fall back to false after clearing the name.")
	_assert(not bool(sync_queue.call("_should_replace_local_state_on_startup")), "Startup should still preserve restored cloud state after the public name is cleared.")

	OnlineLeaderboardScript.clear_cloud_profile_presence()
	_assert(not OnlineLeaderboardScript.has_cloud_profile(), "Clearing the cloud-profile marker should restore fresh-install behavior.")
	_assert(bool(sync_queue.call("_should_replace_local_state_on_startup")), "Fresh-install behavior should return once the cloud-profile marker is cleared.")

	if FileAccess.file_exists(RUN_STATS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_STATS_PATH))
	run_stats.call("_load_local_best_score")
	_assert(int(run_stats.get_local_best_score()) == 0, "Restore validation should start with an empty local best score.")
	var restored_entries: Array[Dictionary] = [{"player_id": "restored-player", "score": 4032, "name": "Jesse"}]
	var lower_entries: Array[Dictionary] = [{"player_id": "restored-player", "score": 60, "name": "Jesse"}]
	_assert(bool(sync_queue.call("_apply_restored_personal_best", restored_entries)), "Restore helper should accept a synced leaderboard best.")
	_assert(int(run_stats.get_local_best_score()) == 4032, "Restored synced leaderboard best should seed the local best score.")
	_assert(not bool(sync_queue.call("_apply_restored_personal_best", lower_entries)), "Restore helper should ignore lower synced scores once the local best is seeded.")
	_assert(int(run_stats.get_local_best_score()) == 4032, "Lower restored scores should not replace the seeded local best score.")

	_restore_user_files()
	_finish()

func _backup_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			_backups[path] = file.get_as_text()
			return
	_backups[path] = null

func _restore_user_files() -> void:
	for path in _backups.keys():
		var saved_value = _backups[path]
		if saved_value == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(str(saved_value))

func _finish() -> void:
	if _failures.is_empty():
		print("Restore resume validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

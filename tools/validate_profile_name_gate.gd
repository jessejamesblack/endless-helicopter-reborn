extends SceneTree

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen/start_screen.tscn")
const QUEUE_PATH := "user://supabase_sync_queue.cfg"

var _failures: Array[String] = []
var _backups: Dictionary = {}
var _sync_queue_original_jobs: Array = []
var _sync_queue_original_startup_completed := false

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_backup_user_file(OnlineLeaderboardScript.NAME_CACHE_PATH)
	_backup_user_file(OnlineLeaderboardScript.CLOUD_PROFILE_CACHE_PATH)
	_backup_user_file(QUEUE_PATH)

	var sync_queue := get_root().get_node_or_null("SupabaseSyncQueue")
	_assert(sync_queue != null, "SupabaseSyncQueue autoload should exist for profile name gate validation.")
	if sync_queue != null:
		var original_jobs_value = sync_queue.get("_jobs")
		if original_jobs_value is Array:
			_sync_queue_original_jobs = (original_jobs_value as Array).duplicate(true)
		_sync_queue_original_startup_completed = bool(sync_queue.get("_startup_sync_completed"))
		sync_queue.set("_jobs", [])

	_validate_strict_cached_name()
	_validate_profile_sync_queue(sync_queue)
	await _validate_start_screen_gate(sync_queue)
	_validate_backend_and_sql_guards()

	if sync_queue != null:
		sync_queue.set("_jobs", _sync_queue_original_jobs)
		sync_queue.set("_startup_sync_completed", _sync_queue_original_startup_completed)
		if sync_queue.has_method("_save_queue"):
			sync_queue.call("_save_queue")
	_restore_user_files()
	_finish()

func _validate_strict_cached_name() -> void:
	OnlineLeaderboardScript.clear_cached_name()
	_write_user_file(OnlineLeaderboardScript.NAME_CACHE_PATH, "   ")
	_assert(OnlineLeaderboardScript.get_valid_cached_name().is_empty(), "Blank cached names should be invalid.")
	_assert(not FileAccess.file_exists(OnlineLeaderboardScript.NAME_CACHE_PATH), "Blank cached names should be cleared instead of becoming Player.")
	_assert(not OnlineLeaderboardScript.has_saved_player_name(), "Blank cached names should not count as saved player names.")
	_assert(not OnlineLeaderboardScript.has_saved_profile(), "Blank cached names should not count as saved profiles.")

	_write_user_file(OnlineLeaderboardScript.NAME_CACHE_PATH, "DebugSave")
	_assert(OnlineLeaderboardScript.get_valid_cached_name().is_empty(), "Blocked cached names should be invalid and cleared.")
	_assert(not FileAccess.file_exists(OnlineLeaderboardScript.NAME_CACHE_PATH), "Blocked cached names should be removed from user storage.")

	OnlineLeaderboardScript.save_cached_name("  GatePilot  ")
	_assert(OnlineLeaderboardScript.get_valid_cached_name() == "GatePilot", "Valid cached names should round-trip through the strict helper.")
	_assert(OnlineLeaderboardScript.has_saved_player_name(), "Valid cached names should count as saved player names.")
	var profile_body := OnlineLeaderboardScript.make_sync_player_profile_body({})
	_assert(profile_body.contains("\"p_name\":\"GatePilot\""), "Profile sync bodies should use the strict cached name.")

func _validate_profile_sync_queue(sync_queue: Node) -> void:
	if sync_queue == null:
		return
	sync_queue.set("_jobs", [])
	OnlineLeaderboardScript.clear_cached_name()
	sync_queue.enqueue_sync_player_profile({"equipped_vehicle_id": "default_scout"})
	_assert(int(sync_queue.get_pending_count()) == 0, "Profile sync jobs should not queue without a valid cached name.")

	OnlineLeaderboardScript.save_cached_name("Pilot")
	sync_queue.enqueue_sync_player_profile({"equipped_vehicle_id": "default_scout"})
	_assert(int(sync_queue.get_pending_count()) == 1, "Profile sync jobs should queue after a valid cached name is saved.")

	var queue_text := FileAccess.get_file_as_string("res://systems/supabase_sync_queue.gd")
	_assert(queue_text.contains("get_valid_cached_name().is_empty()"), "SupabaseSyncQueue should guard profile sync with the strict cached-name helper.")
	_assert(queue_text.contains("return \"drop\""), "SupabaseSyncQueue should drop stale nameless profile sync jobs before flushing.")

func _validate_start_screen_gate(sync_queue: Node) -> void:
	OnlineLeaderboardScript.clear_cached_name()
	if sync_queue != null:
		sync_queue.set("_jobs", [])
		sync_queue.set("_startup_sync_completed", true)

	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(start_screen)
	await process_frame
	await process_frame
	start_screen.set("validation_force_online_name_gate", true)
	start_screen.call("_refresh_name_gate_state")
	await process_frame

	var overlay := start_screen.get_node_or_null("NameGateOverlay") as CanvasItem
	var entry := start_screen.get_node_or_null("NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateEntry") as LineEdit
	var error_label := start_screen.get_node_or_null("NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateErrorLabel") as Label
	var play_button := start_screen.get_node_or_null("PlayButton") as Button
	var scores_button := start_screen.get_node_or_null("ScoresButton") as Button
	var missions_button := start_screen.get_node_or_null("MissionsButton") as Button
	var hangar_button := start_screen.get_node_or_null("HangarButton") as Button
	var settings_button := start_screen.get_node_or_null("SettingsButton") as Button
	var credits_button := start_screen.get_node_or_null("CreditsButton") as Button
	_assert(overlay != null and overlay.visible, "Configured nameless builds should show the Start Screen name gate after startup sync.")
	_assert(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The name gate overlay should leave Settings, Debug, and Credits reachable behind the modal.")
	_assert(play_button != null and play_button.disabled, "Play should be blocked while the configured build is nameless.")
	_assert(scores_button != null and scores_button.disabled, "Scores should be blocked while the configured build is nameless.")
	_assert(missions_button != null and missions_button.disabled, "Missions should be blocked while the configured build is nameless.")
	_assert(hangar_button != null and hangar_button.disabled, "Hangar should be blocked while the configured build is nameless.")
	_assert(settings_button != null and not settings_button.disabled, "Settings should remain accessible while the configured build is nameless.")
	_assert(credits_button != null and not credits_button.disabled, "Credits should remain accessible while the configured build is nameless.")

	if entry != null:
		entry.text = ""
	start_screen.call("_on_name_gate_save_pressed")
	_assert(error_label != null and error_label.text.contains("Enter a player name."), "Blank names should show the validation error in the name gate.")

	if entry != null:
		entry.text = "GatePilot"
	start_screen.call("_on_name_gate_save_pressed")
	await process_frame
	_assert(OnlineLeaderboardScript.get_valid_cached_name() == "GatePilot", "Saving a valid gate name should write the strict cached name.")
	_assert(overlay != null and not overlay.visible, "Saving a valid gate name should close the name gate.")
	_assert(scores_button != null and not scores_button.disabled, "Protected buttons should unlock after a valid name is saved.")
	if sync_queue != null:
		_assert(int(sync_queue.get_pending_count()) == 1, "Saving a valid name should enqueue one current profile sync.")

	start_screen.free()
	await process_frame

	OnlineLeaderboardScript.clear_cached_name()
	if sync_queue != null:
		sync_queue.set("_jobs", [])

	var validation_start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(validation_start_screen)
	await process_frame
	await process_frame
	validation_start_screen.set("validation_force_online_name_gate", false)
	validation_start_screen.call("_refresh_name_gate_state")
	await process_frame
	var validation_overlay := validation_start_screen.get_node_or_null("NameGateOverlay") as CanvasItem
	var validation_scores_button := validation_start_screen.get_node_or_null("ScoresButton") as Button
	_assert(validation_overlay != null and not validation_overlay.visible, "Unconfigured validation/dev builds should not show the name gate.")
	_assert(validation_scores_button != null and not validation_scores_button.disabled, "Unconfigured validation/dev builds should not block protected menu buttons.")
	validation_start_screen.free()
	await process_frame

func _validate_backend_and_sql_guards() -> void:
	var start_screen_text := FileAccess.get_file_as_string("res://scenes/ui/start_screen/start_screen.gd")
	_assert(start_screen_text.contains("_should_require_name_setup"), "Start Screen should include the configured-build name gate decision.")
	_assert(start_screen_text.contains("_request_protected_navigation"), "Start Screen protected routes should use shared gate navigation.")
	_assert(start_screen_text.contains("get_profile_sync_summary"), "Saving a name should queue the current PlayerProfile sync summary.")

	var sync_function_text := FileAccess.get_file_as_string("res://backend/supabase/functions/sync-player-profile/index.ts")
	_assert(sync_function_text.contains("cleanPlayerName"), "sync-player-profile Edge Function should clean player names before RPC.")
	_assert(sync_function_text.contains("422"), "sync-player-profile Edge Function should reject missing names with HTTP 422.")
	_assert(sync_function_text.contains("Choose a player name before syncing your cloud profile."), "sync-player-profile Edge Function should explain missing-name failures.")
	_assert(sync_function_text.contains("p_name: cleanName"), "sync-player-profile Edge Function should pass the cleaned name to the RPC.")

	var restore_function_text := FileAccess.get_file_as_string("res://backend/supabase/functions/get-player-profile/index.ts")
	_assert(not restore_function_text.contains(".from(\"family_player_profiles\")"), "get-player-profile should rely on the RPC returning name directly.")

	var sql_text := FileAccess.get_file_as_string("res://backend/supabase_player_progress_setup.sql")
	_assert(sql_text.contains("family_player_profiles_name_required"), "Profile SQL should add the required-name check constraint.")
	_assert(sql_text.contains("alter column name set not null"), "Profile SQL should make profile names non-null after cleanup.")
	_assert(sql_text.contains("family_player_profiles_family_normalized_name_uidx"), "Profile SQL should enforce family-scoped normalized profile-name uniqueness.")
	_assert(sql_text.contains("public.normalize_leaderboard_name(name)"), "Profile SQL should reuse leaderboard name normalization for profile-name uniqueness.")
	_assert(sql_text.contains("Duplicate family player profile names remain"), "Profile SQL should abort if duplicate normalized profile names remain after cleanup.")
	_assert(sql_text.contains("p_name := trim(coalesce(p_name, ''));"), "sync_player_profile SQL should require a cleaned player name.")
	_assert(sql_text.contains("char_length(p_name) < 1 or char_length(p_name) > 12"), "sync_player_profile SQL should enforce 1-12 character names.")
	_assert(sql_text.contains("name = excluded.name"), "sync_player_profile SQL should write the submitted valid name on conflict.")
	_assert(sql_text.contains("'name', profile_row.name"), "Profile sync and restore RPCs should return name.")
	_assert(not sql_text.contains("nullif(trim(coalesce(p_name, '')), '')"), "Profile SQL should no longer convert missing names to NULL.")

	var vehicle_sql_text := FileAccess.get_file_as_string("res://backend/supabase_vehicle_skins_setup.sql")
	_assert(vehicle_sql_text.contains("p_name := trim(coalesce(p_name, ''));"), "Vehicle skin profile sync SQL should also require cleaned player names.")
	_assert(vehicle_sql_text.contains("'name', profile_row.name"), "Vehicle skin profile sync SQL should return profile name.")
	_assert(not vehicle_sql_text.contains("nullif(trim(coalesce(p_name, '')), '')"), "Vehicle skin profile sync SQL should not allow NULL profile names.")

	var reinstall_validator_text := FileAccess.get_file_as_string("res://tools/validate_supabase_reinstall_restore.ps1")
	_assert(reinstall_validator_text.contains("'$oldPlayerName',"), "Live restore validator should seed old synthetic profile rows with valid names.")
	_assert(reinstall_validator_text.contains("'$newPlayerName',"), "Live restore validator should seed new synthetic profile rows with valid names.")

	var readme_text := FileAccess.get_file_as_string("res://README.md")
	var leaderboard_doc_text := FileAccess.get_file_as_string("res://docs/ONLINE_LEADERBOARD_SETUP.md")
	_assert(not readme_text.contains("Cloud profile restore and progression sync can exist before the player picks a public leaderboard name."), "README should not describe nameless cloud profile sync.")
	_assert(not leaderboard_doc_text.contains("Cloud profile restore and progression sync do not require a public name"), "Leaderboard docs should not describe nameless cloud profile sync.")

func _backup_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			_backups[path] = file.get_as_text()
			return
	_backups[path] = null

func _write_user_file(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)

func _restore_user_files() -> void:
	for path in _backups.keys():
		var saved_value = _backups[path]
		if saved_value == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		_write_user_file(path, str(saved_value))

func _finish() -> void:
	if _failures.is_empty():
		print("Profile name gate validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

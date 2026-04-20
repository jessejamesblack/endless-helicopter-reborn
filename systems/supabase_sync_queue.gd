extends Node

signal queue_changed(pending_count: int)
signal startup_sync_state_changed()

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const AndroidIdentityScript = preload("res://systems/android_identity.gd")
const QUEUE_PATH := "user://supabase_sync_queue.cfg"
const QUEUE_SECTION := "supabase_sync_queue"
const MAX_QUEUE_SIZE := 50
const IDENTITY_RETRY_SECONDS := 1.5
const IDENTITY_RETRY_ATTEMPTS := 8

const JOB_SUBMIT_SCORE_V2 := "submit_score_v2"
const JOB_SYNC_PLAYER_PROFILE := "sync_player_profile"
const JOB_SYNC_DAILY_MISSION_PROGRESS := "sync_daily_mission_progress"

var _jobs: Array[Dictionary] = []
var _flush_request: HTTPRequest
var _pull_request: HTTPRequest
var _identity_retry_timer: Timer
var _is_flushing: bool = false
var _startup_sync_in_progress: bool = false
var _startup_sync_completed: bool = false
var _identity_retry_attempts_remaining: int = 0
var _cloud_access_blocked_reason: String = ""
var _last_identity_snapshot: String = ""
var _force_replace_local_state_once: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flush_request = HTTPRequest.new()
	add_child(_flush_request)
	_pull_request = HTTPRequest.new()
	add_child(_pull_request)
	_identity_retry_timer = Timer.new()
	_identity_retry_timer.one_shot = true
	_identity_retry_timer.timeout.connect(_on_identity_retry_timeout)
	add_child(_identity_retry_timer)
	_load_queue()
	_last_identity_snapshot = _get_identity_snapshot()
	call_deferred("_startup_sync")

func enqueue_submit_score_v2(name: String, score: int, run_summary: Dictionary, equipped_skin_id: String) -> void:
	if name.strip_edges().is_empty():
		return
	_jobs.append({
		"type": JOB_SUBMIT_SCORE_V2,
		"payload": {
			"name": OnlineLeaderboardScript.sanitize_name(name),
			"score": maxi(score, 0),
			"run_summary": run_summary.duplicate(true),
			"equipped_skin_id": equipped_skin_id,
		},
	})
	_trim_queue()
	_save_queue()
	_emit_queue_changed()

func enqueue_sync_player_profile(profile_summary: Dictionary) -> void:
	_replace_or_append_job(JOB_SYNC_PLAYER_PROFILE, profile_summary.duplicate(true))

func enqueue_sync_daily_mission_progress(mission_summary: Dictionary) -> void:
	var mission_date := str(mission_summary.get("mission_date", ""))
	if mission_date.is_empty():
		return
	_replace_or_append_job(JOB_SYNC_DAILY_MISSION_PROGRESS, mission_summary.duplicate(true), mission_date)

func flush() -> void:
	if _is_flushing or not OnlineLeaderboardScript.is_configured():
		return
	call_deferred("_flush_async")

func pull_remote_profile_state(replace_existing_state: bool = false) -> void:
	call_deferred("_pull_remote_state", replace_existing_state)

func pull_remote_profile_state_async(replace_existing_state: bool = false) -> Dictionary:
	return await _pull_remote_state(replace_existing_state)

func get_pending_count() -> int:
	return _jobs.size()

func has_completed_startup_sync() -> bool:
	return _startup_sync_completed

func is_startup_sync_in_progress() -> bool:
	return _startup_sync_in_progress

func notify_identity_state_changed(force_replace_existing_state: bool = false) -> void:
	if not OnlineLeaderboardScript.is_configured() or _is_cloud_access_blocked():
		return
	var current_snapshot := _get_identity_snapshot()
	if current_snapshot == _last_identity_snapshot:
		if force_replace_existing_state:
			_force_replace_local_state_once = true
		return
	if force_replace_existing_state:
		_force_replace_local_state_once = true
	clear_pending_jobs()
	_last_identity_snapshot = current_snapshot
	_reset_startup_sync_for_identity_change()
	call_deferred("_startup_sync")

func _startup_sync() -> void:
	if _startup_sync_completed or _startup_sync_in_progress:
		return
	if _identity_retry_attempts_remaining <= 0:
		_identity_retry_attempts_remaining = IDENTITY_RETRY_ATTEMPTS
	call_deferred("_run_startup_sync")

func _run_startup_sync() -> void:
	if _startup_sync_completed or _startup_sync_in_progress:
		return
	_startup_sync_in_progress = true
	startup_sync_state_changed.emit()
	if _is_cloud_access_blocked():
		_finish_startup_sync()
		return
	var identity_ready := await _ensure_remote_identity_ready()
	if identity_ready:
		var replace_existing_state := _consume_force_replace_local_state() or _should_replace_local_state_on_startup()
		await _pull_remote_state(replace_existing_state)
		await _flush_async()
		_finish_startup_sync()
	else:
		_handle_startup_identity_retry()

func _pull_remote_state(replace_existing_state: bool = false) -> Dictionary:
	var outcome := {
		"ok": false,
		"profile_restored": false,
		"mission_restored": false,
		"error_message": "",
	}
	if not OnlineLeaderboardScript.is_configured():
		outcome["error_message"] = "Online profile sync is not configured."
		return outcome
	if _is_cloud_access_blocked():
		outcome["error_message"] = _cloud_access_blocked_reason
		return outcome
	if not await _ensure_remote_identity_ready():
		if _is_cloud_access_blocked():
			outcome["error_message"] = _cloud_access_blocked_reason
			return outcome
		_schedule_identity_retry()
		outcome["error_message"] = "A cloud identity is still required before cloud restore can run."
		return outcome
	outcome["ok"] = true

	var profile_body := OnlineLeaderboardScript.make_get_player_profile_body()
	var mission_body := OnlineLeaderboardScript.make_get_daily_mission_progress_body(Time.get_date_string_from_system(true))
	var request_failures: Array[String] = []

	var profile_response := await _request_json(
		_pull_request,
		OnlineLeaderboardScript.get_get_player_profile_url(),
		HTTPClient.METHOD_POST,
		profile_body
	)
	if _handle_upgrade_required_response("get_player_profile", profile_response):
		outcome["ok"] = false
		outcome["error_message"] = _cloud_access_blocked_reason
		return outcome
	if _is_success_response(profile_response):
		var remote_profile := OnlineLeaderboardScript.parse_profile_sync_result(profile_response.body)
		var player_profile := get_node_or_null("/root/PlayerProfile")
		outcome["profile_restored"] = not remote_profile.is_empty()
		if outcome["profile_restored"]:
			var remote_name := str(remote_profile.get("name", "")).strip_edges()
			if not remote_name.is_empty():
				OnlineLeaderboardScript.save_cached_name(remote_name)
			if replace_existing_state and player_profile != null and player_profile.has_method("replace_remote_profile"):
				player_profile.replace_remote_profile(remote_profile)
			elif player_profile != null and player_profile.has_method("merge_remote_profile"):
				player_profile.merge_remote_profile(remote_profile)
	else:
		request_failures.append(_response_error_text(profile_response))

	var mission_response := await _request_json(
		_pull_request,
		OnlineLeaderboardScript.get_get_daily_mission_progress_url(),
		HTTPClient.METHOD_POST,
		mission_body
	)
	if _handle_upgrade_required_response("get_daily_mission_progress", mission_response):
		outcome["ok"] = false
		outcome["error_message"] = _cloud_access_blocked_reason
		return outcome
	if _is_success_response(mission_response):
		var remote_progress := OnlineLeaderboardScript.parse_daily_mission_sync_result(mission_response.body)
		var mission_manager := get_node_or_null("/root/MissionManager")
		outcome["mission_restored"] = not remote_progress.is_empty()
		if replace_existing_state:
			if outcome["mission_restored"] and mission_manager != null and mission_manager.has_method("replace_remote_daily_progress"):
				mission_manager.replace_remote_daily_progress(remote_progress)
			elif not outcome["mission_restored"] and mission_manager != null and mission_manager.has_method("reset_current_daily_progress"):
				mission_manager.reset_current_daily_progress()
		elif mission_manager != null and mission_manager.has_method("merge_remote_daily_progress"):
			mission_manager.merge_remote_daily_progress(remote_progress)
	else:
		request_failures.append(_response_error_text(mission_response))

	if not request_failures.is_empty() and not bool(outcome.get("profile_restored", false)) and not bool(outcome.get("mission_restored", false)):
		outcome["ok"] = false
		outcome["error_message"] = request_failures[0]
	return outcome

func clear_pending_jobs() -> void:
	if _jobs.is_empty():
		return
	_jobs.clear()
	_save_queue()
	_emit_queue_changed()

func _flush_async() -> void:
	if _is_flushing or not OnlineLeaderboardScript.is_configured():
		return
	if _is_cloud_access_blocked():
		_drop_all_jobs_for_upgrade_required()
		return
	if not await _ensure_remote_identity_ready():
		if _is_cloud_access_blocked():
			_drop_all_jobs_for_upgrade_required()
			return
		_schedule_identity_retry()
		return
	_is_flushing = true

	while not _jobs.is_empty():
		var job := _jobs[0]
		var outcome := await _process_job(job)
		if outcome == "success" or outcome == "drop":
			_jobs.remove_at(0)
			_save_queue()
			_emit_queue_changed()
			continue
		break

	_is_flushing = false

func _ensure_remote_identity_ready() -> bool:
	if not OnlineLeaderboardScript.is_configured():
		return false
	if _is_cloud_access_blocked():
		return false
	var account_manager := get_node_or_null("/root/AccountManager")
	if account_manager != null:
		if account_manager.has_method("is_bootstrap_in_progress") and bool(account_manager.is_bootstrap_in_progress()):
			return false
		if account_manager.has_method("has_linked_profile") and bool(account_manager.has_linked_profile()):
			return not str(account_manager.get_linked_player_id()).strip_edges().is_empty()
	if OnlineLeaderboardScript.has_pending_remote_identity_migration():
		var migration := OnlineLeaderboardScript.get_pending_remote_identity_migration()
		var old_player_id := str(migration.get("old_player_id", "")).strip_edges()
		var new_player_id := str(migration.get("new_player_id", "")).strip_edges()
		var old_device_id := str(migration.get("old_device_id", "")).strip_edges()
		var new_device_id := str(migration.get("new_device_id", "")).strip_edges()
		if new_player_id.is_empty():
			return false
		if old_player_id.is_empty() and old_device_id.is_empty():
			OnlineLeaderboardScript.finalize_remote_identity_migration()
			return OnlineLeaderboardScript.is_remote_profile_identity_ready()
		var response := await _request_json(
			_pull_request,
			OnlineLeaderboardScript.get_migrate_player_identity_url(),
			HTTPClient.METHOD_POST,
			OnlineLeaderboardScript.make_migrate_player_identity_body()
		)
		if _handle_upgrade_required_response("migrate_player_identity", response):
			return false
		if _is_success_response(response):
			OnlineLeaderboardScript.finalize_remote_identity_migration()
			_last_identity_snapshot = _get_identity_snapshot()
			return OnlineLeaderboardScript.is_remote_profile_identity_ready()
		_report_identity_issue("identity_migration", "Remote identity migration did not complete.", {
			"old_player_id_present": not old_player_id.is_empty(),
			"new_player_id_present": not new_player_id.is_empty(),
			"old_device_id_present": not old_device_id.is_empty(),
			"new_device_id_present": not new_device_id.is_empty(),
			"response_code": int(response.get("response_code", 0)),
			"result": int(response.get("result", HTTPRequest.RESULT_CANT_CONNECT)),
		})
		return false
	if not OnlineLeaderboardScript.is_remote_profile_identity_ready():
		return false
	OnlineLeaderboardScript.finalize_remote_identity_migration()
	return true

func _schedule_identity_retry() -> void:
	if _identity_retry_timer == null:
		return
	if _identity_retry_attempts_remaining <= 0:
		return
	if _identity_retry_timer.is_stopped():
		_identity_retry_timer.start(IDENTITY_RETRY_SECONDS)

func _on_identity_retry_timeout() -> void:
	if _identity_retry_attempts_remaining <= 0:
		return
	_identity_retry_attempts_remaining -= 1
	if _startup_sync_completed:
		return
	call_deferred("_run_startup_sync")

func _handle_startup_identity_retry() -> void:
	if _identity_retry_attempts_remaining <= 0:
		_finish_startup_sync()
		return
	_startup_sync_in_progress = false
	_schedule_identity_retry()
	startup_sync_state_changed.emit()

func _finish_startup_sync() -> void:
	_startup_sync_completed = true
	_startup_sync_in_progress = false
	_identity_retry_attempts_remaining = 0
	if _identity_retry_timer != null:
		_identity_retry_timer.stop()
	startup_sync_state_changed.emit()

func _reset_startup_sync_for_identity_change() -> void:
	_startup_sync_completed = false
	_startup_sync_in_progress = false
	_identity_retry_attempts_remaining = IDENTITY_RETRY_ATTEMPTS
	if _identity_retry_timer != null:
		_identity_retry_timer.stop()
	startup_sync_state_changed.emit()

func _process_job(job: Dictionary) -> String:
	match str(job.get("type", "")):
		JOB_SUBMIT_SCORE_V2:
			return await _process_submit_score_job(job)
		JOB_SYNC_PLAYER_PROFILE:
			return await _process_profile_sync_job(job)
		JOB_SYNC_DAILY_MISSION_PROGRESS:
			return await _process_daily_sync_job(job)
	return "drop"

func _process_submit_score_job(job: Dictionary) -> String:
	var payload := job.get("payload", {}) as Dictionary
	var player_name := str(payload.get("name", ""))
	if player_name.is_empty():
		return "drop"
	var response := await _request_json(
		_flush_request,
		OnlineLeaderboardScript.get_submit_v2_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_submit_v2_body(
			player_name,
			int(payload.get("score", 0)),
			payload.get("run_summary", {}) as Dictionary,
			str(payload.get("equipped_skin_id", "default_scout"))
		)
	)
	if _handle_upgrade_required_response("submit_score", response):
		return "drop"
	if _is_success_response(response):
		_refresh_bonus_skin_access()
		return "success"
	return "retry" if _is_retryable_response(response) else "drop"

func _process_profile_sync_job(job: Dictionary) -> String:
	var payload := job.get("payload", {}) as Dictionary
	var response := await _request_json(
		_flush_request,
		OnlineLeaderboardScript.get_sync_player_profile_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_sync_player_profile_body(payload)
	)
	if _handle_upgrade_required_response("sync_player_profile", response):
		return "drop"
	if _is_success_response(response):
		return "success"
	return "retry" if _is_retryable_response(response) else "drop"

func _process_daily_sync_job(job: Dictionary) -> String:
	var payload := job.get("payload", {}) as Dictionary
	var response := await _request_json(
		_flush_request,
		OnlineLeaderboardScript.get_sync_daily_mission_progress_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_sync_daily_mission_progress_body(payload)
	)
	if _handle_upgrade_required_response("sync_daily_mission_progress", response):
		return "drop"
	if _is_success_response(response):
		return "success"
	return "retry" if _is_retryable_response(response) else "drop"

func _request_json(request: HTTPRequest, url: String, method: int, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var request_headers := headers if not headers.is_empty() else OnlineLeaderboardScript.get_headers()
	var start_error := request.request(url, request_headers, method, body)
	if start_error != OK:
		return {
			"result": start_error,
			"response_code": 0,
			"headers": PackedStringArray(),
			"body": PackedByteArray(),
		}
	var completed = await request.request_completed
	return {
		"result": int(completed[0]),
		"response_code": int(completed[1]),
		"headers": completed[2],
		"body": completed[3],
	}

func _load_queue() -> void:
	var config := ConfigFile.new()
	if config.load(QUEUE_PATH) != OK:
		_jobs = []
		return
	var jobs_variant = config.get_value(QUEUE_SECTION, "jobs", [])
	_jobs = jobs_variant.duplicate(true) if jobs_variant is Array else []
	_trim_queue()

func _save_queue() -> void:
	var config := ConfigFile.new()
	config.set_value(QUEUE_SECTION, "jobs", _jobs.duplicate(true))
	config.save(QUEUE_PATH)

func _replace_or_append_job(job_type: String, payload: Dictionary, mission_date: String = "") -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		var existing_job := _jobs[index] as Dictionary
		if str(existing_job.get("type", "")) != job_type:
			continue
		if mission_date.is_empty() or str((existing_job.get("payload", {}) as Dictionary).get("mission_date", "")) == mission_date:
			_jobs[index] = {"type": job_type, "payload": payload}
			_save_queue()
			_emit_queue_changed()
			return
	_jobs.append({"type": job_type, "payload": payload})
	_trim_queue()
	_save_queue()
	_emit_queue_changed()

func _trim_queue() -> void:
	while _jobs.size() > MAX_QUEUE_SIZE:
		var removed := false
		for index in range(_jobs.size()):
			if str((_jobs[index] as Dictionary).get("type", "")) == JOB_SUBMIT_SCORE_V2:
				_jobs.remove_at(index)
				removed = true
				break
		if not removed:
			_jobs.remove_at(0)

func _emit_queue_changed() -> void:
	queue_changed.emit(get_pending_count())

func _is_success_response(response: Dictionary) -> bool:
	return int(response.get("result", HTTPRequest.RESULT_CANT_CONNECT)) == HTTPRequest.RESULT_SUCCESS \
		and int(response.get("response_code", 0)) >= 200 \
		and int(response.get("response_code", 0)) < 300

func _is_retryable_response(response: Dictionary) -> bool:
	var result := int(response.get("result", HTTPRequest.RESULT_CANT_CONNECT))
	var response_code := int(response.get("response_code", 0))
	if result != HTTPRequest.RESULT_SUCCESS:
		return true
	return response_code >= 500 or response_code == 0 or response_code == 429

func _response_error_text(response: Dictionary) -> String:
	return OnlineLeaderboardScript.parse_api_error(response.get("body", PackedByteArray()) as PackedByteArray, "")

func _refresh_bonus_skin_access() -> void:
	var player_profile := get_node_or_null("/root/PlayerProfile")
	if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
		player_profile.refresh_top_player_skin_access()

func _report_identity_issue(category: String, message: String, context: Dictionary = {}) -> void:
	var reporter := get_node_or_null("/root/ErrorReporter")
	if reporter != null and reporter.has_method("report_warning"):
		reporter.report_warning(category, message, context)

func _handle_upgrade_required_response(operation: String, response: Dictionary) -> bool:
	var response_code := int(response.get("response_code", 0))
	var body := response.get("body", PackedByteArray()) as PackedByteArray
	if not OnlineLeaderboardScript.is_upgrade_required_response(response_code, body):
		return false
	var message := OnlineLeaderboardScript.parse_api_error(body, "This build is too old. Please update to continue.")
	_block_cloud_access(message)
	OnlineLeaderboardScript.handle_upgrade_required(operation, body, {
		"queue_pending_count": _jobs.size(),
	})
	return true

func _block_cloud_access(reason: String) -> void:
	_cloud_access_blocked_reason = reason
	_finish_startup_sync()

func _is_cloud_access_blocked() -> bool:
	return not _cloud_access_blocked_reason.is_empty()

func _drop_all_jobs_for_upgrade_required() -> void:
	if _jobs.is_empty():
		return
	_jobs.clear()
	_save_queue()
	_emit_queue_changed()

func _should_replace_local_state_on_startup() -> bool:
	var account_manager := get_node_or_null("/root/AccountManager")
	if account_manager != null and account_manager.has_method("has_linked_profile") and bool(account_manager.has_linked_profile()):
		return true
	return not OnlineLeaderboardScript.has_saved_profile()

func _consume_force_replace_local_state() -> bool:
	var should_replace := _force_replace_local_state_once
	_force_replace_local_state_once = false
	return should_replace

func _get_identity_snapshot() -> String:
	var player_info := AndroidIdentityScript.get_player_identity_info()
	var device_info := AndroidIdentityScript.get_device_identity_info()
	var account_manager := get_node_or_null("/root/AccountManager")
	var account_summary := {}
	if account_manager != null and account_manager.has_method("get_state_summary"):
		account_summary = account_manager.get_state_summary()
	return JSON.stringify({
		"player_id": str(OnlineLeaderboardScript.load_or_create_player_id()).strip_edges(),
		"player_source": str(player_info.get("source", "")),
		"player_remote_ready": bool(player_info.get("remote_ready", false)),
		"player_needs_migration": bool(player_info.get("needs_migration", false)),
		"stable_player_id": str(player_info.get("stable_value", "")),
		"device_id": str(device_info.get("value", "")),
		"device_source": str(device_info.get("source", "")),
		"device_remote_ready": bool(device_info.get("remote_ready", false)),
		"device_needs_migration": bool(device_info.get("needs_migration", false)),
		"stable_device_id": str(device_info.get("stable_value", "")),
		"manual_override": OnlineLeaderboardScript.has_manual_player_id_override(),
		"account_signed_in": bool(account_summary.get("signed_in", false)),
		"account_linked": bool(account_summary.get("linked", false)),
		"account_email": str(account_summary.get("email", "")),
		"account_player_id": str(account_summary.get("linked_player_id", "")),
	})

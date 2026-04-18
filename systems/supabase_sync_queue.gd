extends Node

signal queue_changed(pending_count: int)

const QUEUE_PATH := "user://supabase_sync_queue.cfg"
const QUEUE_SECTION := "supabase_sync_queue"
const MAX_QUEUE_SIZE := 50

const JOB_SUBMIT_SCORE_V2 := "submit_score_v2"
const JOB_SYNC_PLAYER_PROFILE := "sync_player_profile"
const JOB_SYNC_DAILY_MISSION_PROGRESS := "sync_daily_mission_progress"

var _jobs: Array[Dictionary] = []
var _flush_request: HTTPRequest
var _pull_request: HTTPRequest
var _is_flushing: bool = false
var _startup_pull_attempted: bool = false
var _submit_v2_available: bool = true
var _sync_profile_available: bool = true
var _sync_daily_available: bool = true
var _get_profile_available: bool = true
var _get_daily_available: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flush_request = HTTPRequest.new()
	add_child(_flush_request)
	_pull_request = HTTPRequest.new()
	add_child(_pull_request)
	_load_queue()
	call_deferred("_startup_sync")

func enqueue_submit_score_v2(name: String, score: int, run_summary: Dictionary, equipped_skin_id: String) -> void:
	if name.strip_edges().is_empty():
		return
	_jobs.append({
		"type": JOB_SUBMIT_SCORE_V2,
		"payload": {
			"name": OnlineLeaderboard.sanitize_name(name),
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
	if _is_flushing or not OnlineLeaderboard.is_configured():
		return
	call_deferred("_flush_async")

func get_pending_count() -> int:
	return _jobs.size()

func _startup_sync() -> void:
	if _startup_pull_attempted:
		return
	_startup_pull_attempted = true
	await _pull_remote_state()
	await _flush_async()

func _pull_remote_state() -> void:
	if not OnlineLeaderboard.is_configured():
		return

	var profile_body := OnlineLeaderboard.make_get_player_profile_body()
	var mission_body := OnlineLeaderboard.make_get_daily_mission_progress_body(Time.get_date_string_from_system(true))

	if _get_profile_available:
		var profile_response := await _request_json(_pull_request, OnlineLeaderboard.get_get_player_profile_url(), HTTPClient.METHOD_POST, profile_body)
		if _is_success_response(profile_response):
			var remote_profile := OnlineLeaderboard.parse_profile_sync_result(profile_response.body)
			var player_profile := get_node_or_null("/root/PlayerProfile")
			if player_profile != null and player_profile.has_method("merge_remote_profile"):
				player_profile.merge_remote_profile(remote_profile)
		else:
			_get_profile_available = not _should_disable_rpc(profile_response, "get_player_profile")

	if _get_daily_available:
		var mission_response := await _request_json(_pull_request, OnlineLeaderboard.get_get_daily_mission_progress_url(), HTTPClient.METHOD_POST, mission_body)
		if _is_success_response(mission_response):
			var remote_progress := OnlineLeaderboard.parse_daily_mission_sync_result(mission_response.body)
			var mission_manager := get_node_or_null("/root/MissionManager")
			if mission_manager != null and mission_manager.has_method("merge_remote_daily_progress"):
				mission_manager.merge_remote_daily_progress(remote_progress)
		else:
			_get_daily_available = not _should_disable_rpc(mission_response, "get_daily_mission_progress")

func _flush_async() -> void:
	if _is_flushing or not OnlineLeaderboard.is_configured():
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

	if _submit_v2_available:
		var response := await _request_json(
			_flush_request,
			OnlineLeaderboard.get_submit_v2_url(),
			HTTPClient.METHOD_POST,
			OnlineLeaderboard.make_submit_v2_body(
				player_name,
				int(payload.get("score", 0)),
				payload.get("run_summary", {}) as Dictionary,
				str(payload.get("equipped_skin_id", "default_scout"))
			),
			OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=representation"])
		)
		if _is_success_response(response):
			_refresh_bonus_skin_access()
			return "success"
		if _should_disable_rpc(response, "submit_family_score_v2"):
			_submit_v2_available = false
		elif _is_retryable_response(response):
			return "retry"

	var legacy_response := await _request_json(
		_flush_request,
		OnlineLeaderboard.get_submit_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboard.make_submit_body(player_name, int(payload.get("score", 0))),
		OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=representation"])
	)
	if _is_success_response(legacy_response):
		_refresh_bonus_skin_access()
		return "success"
	if OnlineLeaderboard.should_fallback_to_legacy_submit(_response_error_text(legacy_response)):
		var table_response := await _request_json(
			_flush_request,
			OnlineLeaderboard.get_legacy_submit_url(),
			HTTPClient.METHOD_POST,
			OnlineLeaderboard.make_legacy_submit_body(player_name, int(payload.get("score", 0))),
			OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=representation"])
		)
		if _is_success_response(table_response):
			_refresh_bonus_skin_access()
			return "success"
		return "retry" if _is_retryable_response(table_response) else "drop"
	return "retry" if _is_retryable_response(legacy_response) else "drop"

func _process_profile_sync_job(job: Dictionary) -> String:
	if not _sync_profile_available:
		return "drop"

	var payload := job.get("payload", {}) as Dictionary
	var response := await _request_json(
		_flush_request,
		OnlineLeaderboard.get_sync_player_profile_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboard.make_sync_player_profile_body(payload)
	)
	if _is_success_response(response):
		return "success"
	if _should_disable_rpc(response, "sync_player_profile"):
		_sync_profile_available = false
		return "drop"
	return "retry" if _is_retryable_response(response) else "drop"

func _process_daily_sync_job(job: Dictionary) -> String:
	if not _sync_daily_available:
		return "drop"

	var payload := job.get("payload", {}) as Dictionary
	var response := await _request_json(
		_flush_request,
		OnlineLeaderboard.get_sync_daily_mission_progress_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboard.make_sync_daily_mission_progress_body(payload)
	)
	if _is_success_response(response):
		return "success"
	if _should_disable_rpc(response, "sync_daily_mission_progress"):
		_sync_daily_available = false
		return "drop"
	return "retry" if _is_retryable_response(response) else "drop"

func _request_json(request: HTTPRequest, url: String, method: int, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var request_headers := headers if not headers.is_empty() else OnlineLeaderboard.get_headers()
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
	return OnlineLeaderboard.parse_api_error(response.get("body", PackedByteArray()) as PackedByteArray, "")

func _should_disable_rpc(response: Dictionary, rpc_name: String) -> bool:
	var error_text := _response_error_text(response).to_lower()
	return error_text.contains(rpc_name.to_lower()) and (
		error_text.contains("could not find the function")
		or error_text.contains("schema cache")
		or error_text.contains("function")
	)

func _refresh_bonus_skin_access() -> void:
	var player_profile := get_node_or_null("/root/PlayerProfile")
	if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
		player_profile.refresh_top_player_skin_access()

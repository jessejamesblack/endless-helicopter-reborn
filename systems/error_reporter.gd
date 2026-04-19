extends Node

signal queue_changed(pending_count: int)

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const BuildInfoScript = preload("res://systems/build_info.gd")
const QUEUE_PATH := "user://client_error_queue.cfg"
const QUEUE_SECTION := "client_error_queue"
const MAX_QUEUE_SIZE := 50
const RETRY_SECONDS := 12.0
const SEVERITY_DEBUG := "debug"
const SEVERITY_INFO := "info"
const SEVERITY_WARNING := "warning"
const SEVERITY_ERROR := "error"
const SEVERITY_FATAL := "fatal"

var _queue: Array[Dictionary] = []
var _request: HTTPRequest
var _retry_timer: Timer
var _in_flight: bool = false
var _recent_session_fingerprints: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_on_retry_timeout)
	add_child(_retry_timer)
	_load_queue()
	call_deferred("flush")

func report_debug(category: String, message: String, context: Dictionary = {}) -> void:
	report_event(category, message, SEVERITY_DEBUG, context)

func report_info(category: String, message: String, context: Dictionary = {}) -> void:
	report_event(category, message, SEVERITY_INFO, context)

func report_warning(category: String, message: String, context: Dictionary = {}) -> void:
	report_event(category, message, SEVERITY_WARNING, context)

func report_error(category: String, message: String, context: Dictionary = {}) -> void:
	report_event(category, message, SEVERITY_ERROR, context)

func report_fatal(category: String, message: String, context: Dictionary = {}) -> void:
	report_event(category, message, SEVERITY_FATAL, context)

func report_event(category: String, message: String, severity: String = SEVERITY_ERROR, context: Dictionary = {}) -> void:
	var clean_category := category.strip_edges()
	var clean_message := message.strip_edges()
	if clean_category.is_empty() or clean_message.is_empty():
		return
	var safe_context := _sanitize_dictionary(context)
	var fingerprint := str(hash("%s|%s|%s|%s" % [severity, clean_category, clean_message, JSON.stringify(safe_context)]))
	var now_unix := int(Time.get_unix_time_from_system())
	var last_seen := int(_recent_session_fingerprints.get(fingerprint, -999999))
	if now_unix - last_seen < 30 and (severity == SEVERITY_ERROR or severity == SEVERITY_FATAL):
		return
	_recent_session_fingerprints[fingerprint] = now_unix
	_queue.append({
		"timestamp": Time.get_datetime_string_from_system(true),
		"severity": severity,
		"category": clean_category,
		"message": clean_message,
		"fingerprint": fingerprint,
		"context": safe_context,
		"build": BuildInfoScript.get_summary(),
		"runtime": _build_runtime_context(),
	})
	_trim_queue()
	_save_queue()
	queue_changed.emit(_queue.size())
	flush()

func build_bug_report_text(category: String = "manual_feedback") -> String:
	var build: Dictionary = BuildInfoScript.get_summary()
	var runtime: Dictionary = _build_runtime_context()
	var settings: Node = _get_game_settings()
	var player_profile: Node = get_node_or_null("/root/PlayerProfile")
	var run_stats: Node = get_node_or_null("/root/RunStats")
	var last_run: Dictionary = run_stats.get_last_run_summary() if run_stats != null and run_stats.has_method("get_last_run_summary") else {}
	var update_manager: Node = get_node_or_null("/root/AppUpdateManager")
	var update_state: Dictionary = update_manager.get_update_state() if update_manager != null and update_manager.has_method("get_update_state") else {}
	var equipped_vehicle: String = player_profile.get_equipped_vehicle_id() if player_profile != null and player_profile.has_method("get_equipped_vehicle_id") else "unknown"
	var equipped_skin: String = player_profile.get_equipped_vehicle_skin_id(equipped_vehicle) if player_profile != null and player_profile.has_method("get_equipped_vehicle_skin_id") else "factory"
	var lines := PackedStringArray([
		"Category: %s" % category,
		"Version: %s" % str(build.get("version_name", "")),
		"Version Code: %s" % str(build.get("version_code", "")),
		"Build SHA: %s" % str(build.get("build_sha", "")),
		"Channel: %s" % str(build.get("release_channel", "")),
		"Platform: %s" % str(runtime.get("platform", "")),
		"Renderer: %s" % str(runtime.get("renderer", "")),
		"Frame Rate Setting: %s" % (settings.get_frame_rate_setting() if settings != null and settings.has_method("get_frame_rate_setting") else "unknown"),
		"Equipped Vehicle: %s" % equipped_vehicle,
		"Equipped Skin: %s" % equipped_skin,
		"Last Run Score: %s" % str(last_run.get("score", "n/a")),
		"Last Run Phase: %s" % str(last_run.get("crash_director_phase", "n/a")),
		"Last Run Encounter: %s" % str(last_run.get("crash_encounter_id", "n/a")),
		"Update Status: %s" % str(update_state.get("source", "unknown")),
	])
	return "\n".join(lines)

func flush() -> void:
	if _in_flight or _queue.is_empty() or not OnlineLeaderboardScript.is_configured():
		return
	var payload := _queue[0]
	var error := _request.request(
		OnlineLeaderboardScript.get_edge_function_url("report-client-error"),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_schedule_retry()
		return
	_in_flight = true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_in_flight = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		if not _queue.is_empty():
			_queue.remove_at(0)
			_save_queue()
			queue_changed.emit(_queue.size())
		if not _queue.is_empty():
			flush()
		return
	_schedule_retry()

func _on_retry_timeout() -> void:
	flush()

func _schedule_retry() -> void:
	if _retry_timer.is_stopped():
		_retry_timer.start(RETRY_SECONDS)

func _load_queue() -> void:
	var config := ConfigFile.new()
	if config.load(QUEUE_PATH) != OK:
		_queue = []
		return
	var jobs: Variant = config.get_value(QUEUE_SECTION, "entries", [])
	_queue = jobs.duplicate(true) if jobs is Array else []
	_trim_queue()

func _save_queue() -> void:
	var config := ConfigFile.new()
	config.set_value(QUEUE_SECTION, "entries", _queue.duplicate(true))
	config.save(QUEUE_PATH)

func _trim_queue() -> void:
	while _queue.size() > MAX_QUEUE_SIZE:
		_queue.remove_at(0)

func _build_runtime_context() -> Dictionary:
	var settings: Node = _get_game_settings()
	var current_scene := get_tree().current_scene
	return {
		"platform": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"current_scene": current_scene.scene_file_path if current_scene != null else "",
		"frame_rate_setting": settings.get_frame_rate_setting() if settings != null and settings.has_method("get_frame_rate_setting") else "",
	}

func _sanitize_dictionary(value: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for key_variant in value.keys():
		var key := str(key_variant)
		if _is_sensitive_key(key):
			continue
		var item = value[key_variant]
		if item is Dictionary:
			sanitized[key] = _sanitize_dictionary(item)
		elif item is Array:
			sanitized[key] = _sanitize_array(item)
		else:
			sanitized[key] = item
	return sanitized

func _sanitize_array(values: Array) -> Array:
	var sanitized: Array = []
	for item in values:
		if item is Dictionary:
			sanitized.append(_sanitize_dictionary(item))
		elif item is Array:
			sanitized.append(_sanitize_array(item))
		else:
			sanitized.append(item)
	return sanitized

func _is_sensitive_key(key: String) -> bool:
	var normalized := key.to_lower()
	return normalized.contains("token") or normalized.contains("secret") or normalized.contains("webhook") or normalized.contains("service_key") or normalized.contains("apikey") or normalized.contains("api_key")

func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")

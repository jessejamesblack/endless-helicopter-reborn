extends Node

signal update_state_changed(state: Dictionary)

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const BuildInfoScript = preload("res://systems/build_info.gd")
const CACHE_PATH := "user://app_release_info.json"

var _request: HTTPRequest
var _request_in_flight: bool = false
var _state: Dictionary = {}
var _pending_open_prompt: bool = false
var _has_optional_prompted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_load_cached_state()
	var settings: Node = _get_game_settings()
	if settings != null and settings.has_signal("release_channel_override_changed"):
		var callback := Callable(self, "_on_release_channel_override_changed")
		if not settings.is_connected("release_channel_override_changed", callback):
			settings.connect("release_channel_override_changed", callback)
	call_deferred("refresh_release_info")

func refresh_release_info(force: bool = false) -> void:
	if _request_in_flight and not force:
		return
	if not OnlineLeaderboardScript.is_configured():
		_emit_state(_build_state({}, "offline", "Supabase is not configured."))
		return
	_request_in_flight = true
	var channel := get_effective_release_channel()
	var url := "%s?channel=%s" % [
		OnlineLeaderboardScript.get_edge_function_url("get-app-release-info"),
		channel.uri_encode(),
	]
	var error := _request.request(url, OnlineLeaderboardScript.get_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		_request_in_flight = false
		_emit_state(_build_state(_state.get("release_info", {}), "offline", "Could not start release-info request: %d" % error))

func has_required_update() -> bool:
	return bool(_state.get("required", false))

func has_available_update() -> bool:
	return bool(_state.get("available", false))

func get_update_state() -> Dictionary:
	return _state.duplicate(true)

func get_update_status_text() -> String:
	if has_required_update():
		return "Update required"
	if has_available_update():
		return "Update available"
	if bool(_state.get("checked", false)):
		return "Current"
	return "Checking..."

func get_effective_release_channel() -> String:
	var settings: Node = _get_game_settings()
	if OS.is_debug_build() and settings != null and settings.has_method("get_debug_release_channel_override"):
		var override := str(settings.get_debug_release_channel_override()).strip_edges()
		if not override.is_empty():
			return override
	return str(BuildInfoScript.RELEASE_CHANNEL)

func request_open_prompt() -> void:
	_pending_open_prompt = true

func consume_open_prompt_request() -> bool:
	var should_open := _pending_open_prompt
	_pending_open_prompt = false
	return should_open

func should_auto_prompt_optional_update() -> bool:
	if _has_optional_prompted or has_required_update() or not has_available_update():
		return false
	_has_optional_prompted = true
	return true

func mark_optional_prompt_shown() -> void:
	_has_optional_prompted = true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_text := OnlineLeaderboardScript.parse_api_error(body, "Could not refresh release info.")
		var reporter := get_node_or_null("/root/ErrorReporter")
		if reporter != null and reporter.has_method("report_warning"):
			reporter.report_warning("app_update", error_text, {"response_code": response_code})
		_emit_state(_build_state(_state.get("release_info", {}), "offline", error_text))
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var release_info: Dictionary = {}
	if parsed is Dictionary:
		release_info = parsed
	var next_state := _build_state(release_info, "network", "")
	_save_cached_state(next_state)
	_emit_state(next_state)

func _build_state(release_info: Dictionary, source: String, error_text: String) -> Dictionary:
	var latest_version_code := int(release_info.get("latest_version_code", 0))
	var minimum_supported_version_code := int(release_info.get("minimum_supported_version_code", 0))
	var current_version_code := int(BuildInfoScript.VERSION_CODE)
	var available := latest_version_code > current_version_code
	var required := minimum_supported_version_code > 0 and current_version_code < minimum_supported_version_code
	return {
		"checked": not release_info.is_empty() or source == "offline",
		"source": source,
		"error": error_text,
		"channel": get_effective_release_channel(),
		"current_version_code": current_version_code,
		"current_version_name": str(BuildInfoScript.VERSION_NAME),
		"available": available,
		"required": required,
		"message": str(release_info.get("update_message", "A new build is ready.")),
		"force_message": str(release_info.get("force_update_message", "This version is too old to play. Please update to continue.")),
		"release_info": release_info.duplicate(true),
	}

func _load_cached_state() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		_emit_state(_build_state({}, "cache", ""))
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		_emit_state(_build_state({}, "cache", ""))
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_emit_state(_build_state((parsed as Dictionary).get("release_info", {}), "cache", ""))
		return
	_emit_state(_build_state({}, "cache", ""))

func _save_cached_state(state: Dictionary) -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"release_info": state.get("release_info", {}),
	}))

func _emit_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	update_state_changed.emit(get_update_state())

func _on_release_channel_override_changed(_value: String) -> void:
	_has_optional_prompted = false
	refresh_release_info(true)

func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")

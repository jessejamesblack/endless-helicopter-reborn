extends Node

signal push_token_received(token: String)
signal push_notification_opened(payload: Dictionary)
signal diagnostics_changed(status: Dictionary)

const OnlineLeaderboard = preload("res://systems/online_leaderboard.gd")
const PLUGIN_SINGLETON := "FCMPushBridge"
const DEVICE_ID_CACHE_PATH := "user://push_device_id.save"
const LEADERBOARD_SCENE_PATH := "res://scenes/ui/leaderboard/leaderboard_screen.tscn"
const REGISTRATION_RETRY_SECONDS := 1.5
const REGISTRATION_RETRY_ATTEMPTS := 5

var _http_request: HTTPRequest
var _registration_retry_timer: Timer
var _plugin: Object = null
var _pending_open_leaderboard: bool = false
var _pending_notification_payload: Dictionary = {}
var _is_registering_device: bool = false
var _pending_registration_token: String = ""
var _registration_retry_by_token: bool = false
var _remaining_registration_retries: int = 0
var _last_registration_response_code: int = 0
var _last_registration_result: int = 0
var _last_registration_message: String = "Push has not started yet."
var _last_registration_attempt_at: String = ""
var _last_registered_at: String = ""
var _last_token_preview: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_register_request_completed)
	_registration_retry_timer = Timer.new()
	_registration_retry_timer.one_shot = true
	_registration_retry_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_registration_retry_timer.timeout.connect(_on_registration_retry_timeout)
	add_child(_registration_retry_timer)
	call_deferred("_bootstrap")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_consume_launch_payload()
		register_device_for_push()

func _bootstrap() -> void:
	_refresh_plugin_reference()
	if not is_push_supported():
		_last_registration_message = get_diagnostics_text()
		_emit_diagnostics()
		return

	if _plugin.has_signal("push_token_received"):
		var token_callback := Callable(self, "_on_plugin_push_token_received")
		if not _plugin.is_connected("push_token_received", token_callback):
			_plugin.connect("push_token_received", token_callback)

	if _plugin.has_signal("push_notification_opened"):
		var open_callback := Callable(self, "_on_plugin_push_notification_opened")
		if not _plugin.is_connected("push_notification_opened", open_callback):
			_plugin.connect("push_notification_opened", open_callback)

	request_notification_permission()
	_consume_launch_payload()
	register_device_for_push()
	_schedule_registration_retries()
	_emit_diagnostics()

func is_push_supported() -> bool:
	if not OnlineLeaderboard.is_configured():
		return false
	if OS.get_name() != "Android":
		return false
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		return false
	var singleton := Engine.get_singleton(PLUGIN_SINGLETON)
	if singleton == null or not singleton.has_method("isPushSupported"):
		return false
	return bool(singleton.isPushSupported())

func request_notification_permission() -> void:
	_refresh_plugin_reference()
	if _plugin != null and _plugin.has_method("requestNotificationPermission"):
		_plugin.requestNotificationPermission()
	_emit_diagnostics()

func register_device_for_push() -> void:
	_refresh_plugin_reference()
	if not is_push_supported():
		_last_registration_message = get_diagnostics_text()
		_emit_diagnostics()
		return
	_consume_cached_token()
	if _plugin != null and _plugin.has_method("getLatestToken"):
		var latest_token := str(_plugin.getLatestToken()).strip_edges()
		if not latest_token.is_empty():
			_register_device_token(latest_token)
	if _plugin != null and _plugin.has_method("fetchToken"):
		_plugin.fetchToken()
	_emit_diagnostics()

func enable_notifications() -> void:
	_refresh_plugin_reference()
	request_notification_permission()
	register_device_for_push()
	_schedule_registration_retries()
	_emit_diagnostics()

func get_diagnostics() -> Dictionary:
	_refresh_plugin_reference()
	var latest_token := ""
	if _plugin != null and _plugin.has_method("getLatestToken"):
		latest_token = str(_plugin.getLatestToken()).strip_edges()
	if latest_token.is_empty():
		latest_token = _last_token_preview

	var firebase_ready := false
	if _plugin != null and _plugin.has_method("isPushSupported"):
		firebase_ready = bool(_plugin.isPushSupported())

	var firebase_status := ""
	if _plugin != null and _plugin.has_method("getFirebaseStatus"):
		firebase_status = str(_plugin.getFirebaseStatus())

	var permission_granted := false
	if _plugin != null and _plugin.has_method("hasNotificationPermission"):
		permission_granted = bool(_plugin.hasNotificationPermission())

	return {
		"leaderboard_configured": OnlineLeaderboard.is_configured(),
		"is_android": OS.get_name() == "Android",
		"plugin_loaded": _plugin != null,
		"firebase_ready": firebase_ready,
		"firebase_status": firebase_status,
		"permission_granted": permission_granted,
		"latest_token_present": not latest_token.is_empty(),
		"latest_token_preview": _token_preview(latest_token),
		"is_registering": _is_registering_device,
		"last_response_code": _last_registration_response_code,
		"last_result": _last_registration_result,
		"last_message": _last_registration_message,
		"last_attempt_at": _last_registration_attempt_at,
		"last_registered_at": _last_registered_at,
	}

func get_diagnostics_text() -> String:
	var status := get_diagnostics()
	if not bool(status["leaderboard_configured"]):
		return "Push unavailable: Supabase leaderboard config is missing."
	if not bool(status["is_android"]):
		return "Push unavailable here: Android APK only."
	if not bool(status["plugin_loaded"]):
		return "Push unavailable: Android FCM plugin is not loaded in this APK."
	if not bool(status["firebase_ready"]):
		var firebase_detail := str(status.get("firebase_status", "")).strip_edges()
		if firebase_detail.is_empty():
			firebase_detail = "Firebase config is missing or invalid in this APK."
		return "Push unavailable: %s" % firebase_detail
	if not bool(status["permission_granted"]):
		return "Push permission is not granted. Tap Enable Notifications or allow it in Android app settings."
	if not bool(status["latest_token_present"]):
		return "Push waiting for an FCM token. Keep the app open briefly, then tap Enable Notifications."
	if bool(status["is_registering"]):
		return "Push registering this device with Supabase..."
	if int(status["last_response_code"]) >= 200 and int(status["last_response_code"]) < 300:
		return "Push registered. Token %s" % str(status["latest_token_preview"])
	if int(status["last_response_code"]) > 0:
		return "Push registration failed: HTTP %d. %s" % [int(status["last_response_code"]), str(status["last_message"])]
	return str(status["last_message"])

func consume_open_leaderboard_request() -> bool:
	var should_open := _pending_open_leaderboard
	_pending_open_leaderboard = false
	return should_open

func _consume_launch_payload() -> void:
	if _plugin == null or not _plugin.has_method("consumeLaunchPayload"):
		return

	var payload_json := str(_plugin.consumeLaunchPayload()).strip_edges()
	if payload_json.is_empty():
		return

	_handle_notification_payload(payload_json)

func _consume_cached_token() -> void:
	if _plugin == null or not _plugin.has_method("consumeStoredToken"):
		return

	var cached_token := str(_plugin.consumeStoredToken()).strip_edges()
	if cached_token.is_empty():
		return

	_register_device_token(cached_token)

func _register_device_token(token: String) -> void:
	if _is_registering_device or token.strip_edges().is_empty():
		return

	_last_token_preview = _token_preview(token)
	_last_registration_attempt_at = Time.get_datetime_string_from_system(false, true)
	_last_registration_message = "Registering this Android device with Supabase..."
	_emit_diagnostics()

	var notifications_enabled := true
	if _plugin != null and _plugin.has_method("hasNotificationPermission"):
		notifications_enabled = bool(_plugin.hasNotificationPermission())

	var request_headers := OnlineLeaderboard.get_headers() + PackedStringArray([
		"Prefer: resolution=merge-duplicates,return=minimal",
	])
	var body := OnlineLeaderboard.make_push_device_body(
		token,
		_load_or_create_device_id(),
		notifications_enabled,
		"Android"
	)
	_is_registering_device = true
	_pending_registration_token = token
	_registration_retry_by_token = false
	var error := _http_request.request(
		OnlineLeaderboard.get_push_device_upsert_url(),
		request_headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_is_registering_device = false
		_pending_registration_token = ""
		_last_registration_message = "Could not start Supabase registration request: %d" % error
		_emit_diagnostics()

func _on_plugin_push_token_received(token: String) -> void:
	_last_token_preview = _token_preview(token)
	push_token_received.emit(token)
	_register_device_token(token)

func _on_plugin_push_notification_opened(payload_json: String) -> void:
	_handle_notification_payload(payload_json)

func _handle_notification_payload(payload_json: String) -> void:
	var parsed = JSON.parse_string(payload_json)
	if parsed is not Dictionary:
		return

	var payload: Dictionary = parsed
	_pending_notification_payload = payload
	push_notification_opened.emit(payload)
	if str(payload.get("type", "")) == "score_beaten":
		_pending_open_leaderboard = true
		_route_to_leaderboard_if_possible()

func _route_to_leaderboard_if_possible() -> void:
	if not _pending_open_leaderboard:
		return

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var current_scene := tree.current_scene
	if current_scene.scene_file_path == LEADERBOARD_SCENE_PATH:
		_pending_open_leaderboard = false
		return

	_pending_open_leaderboard = false
	tree.change_scene_to_file(LEADERBOARD_SCENE_PATH)

func _load_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_CACHE_PATH):
		var existing_file := FileAccess.open(DEVICE_ID_CACHE_PATH, FileAccess.READ)
		if existing_file != null:
			var existing_id := existing_file.get_as_text().strip_edges()
			if not existing_id.is_empty():
				return existing_id

	var new_id := _generate_device_id()
	var file := FileAccess.open(DEVICE_ID_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(new_id)
	return new_id

func _generate_device_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%08x" % [int(Time.get_unix_time_from_system()), rng.randi()]

func _on_register_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_last_registration_result = result
	_last_registration_response_code = response_code
	if response_code == 409 and not _registration_retry_by_token and not _pending_registration_token.is_empty():
		_retry_register_device_by_token(_pending_registration_token)
		return

	_is_registering_device = false
	_pending_registration_token = ""
	_registration_retry_by_token = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_last_registration_message = "Supabase device registration failed."
		push_warning("Push device registration failed with response code %d" % response_code)
		_schedule_registration_retries(2)
	else:
		_last_registered_at = Time.get_datetime_string_from_system(false, true)
		_last_registration_message = "Push device registered with Supabase."
	_emit_diagnostics()

func _retry_register_device_by_token(token: String) -> void:
	if token.is_empty():
		_is_registering_device = false
		return

	var notifications_enabled := true
	if _plugin != null and _plugin.has_method("hasNotificationPermission"):
		notifications_enabled = bool(_plugin.hasNotificationPermission())

	_registration_retry_by_token = true
	var request_headers := OnlineLeaderboard.get_headers() + PackedStringArray([
		"Prefer: return=minimal",
	])
	var body := OnlineLeaderboard.make_push_device_body(
		token,
		_load_or_create_device_id(),
		notifications_enabled,
		"Android"
	)
	var error := _http_request.request(
		OnlineLeaderboard.get_push_device_update_by_token_url(token),
		request_headers,
		HTTPClient.METHOD_PATCH,
		body
	)
	if error != OK:
		_is_registering_device = false
		_pending_registration_token = ""
		_registration_retry_by_token = false
		_last_registration_message = "Could not start token recovery request: %d" % error
		_schedule_registration_retries(2)
		_emit_diagnostics()

func _schedule_registration_retries(attempts: int = REGISTRATION_RETRY_ATTEMPTS) -> void:
	if _registration_retry_timer == null or not is_push_supported():
		return

	_remaining_registration_retries = max(_remaining_registration_retries, attempts)
	if _registration_retry_timer.is_stopped():
		_registration_retry_timer.start(REGISTRATION_RETRY_SECONDS)

func _on_registration_retry_timeout() -> void:
	if _remaining_registration_retries <= 0:
		return

	_remaining_registration_retries -= 1
	register_device_for_push()

	if _remaining_registration_retries > 0:
		_registration_retry_timer.start(REGISTRATION_RETRY_SECONDS)

func _refresh_plugin_reference() -> void:
	if _plugin == null and Engine.has_singleton(PLUGIN_SINGLETON):
		_plugin = Engine.get_singleton(PLUGIN_SINGLETON)

func _emit_diagnostics() -> void:
	diagnostics_changed.emit(get_diagnostics())

func _token_preview(token: String) -> String:
	var clean_token := token.strip_edges()
	if clean_token.is_empty():
		return ""
	if clean_token.length() <= 10:
		return clean_token
	return "%s...%s" % [clean_token.substr(0, 6), clean_token.substr(clean_token.length() - 4, 4)]

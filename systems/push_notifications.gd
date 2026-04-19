extends Node

signal push_token_received(token: String)
signal push_notification_opened(payload: Dictionary)
signal diagnostics_changed(status: Dictionary)

const AndroidIdentityScript = preload("res://systems/android_identity.gd")
const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const PLUGIN_SINGLETON := "FCMPushBridge"
const ANDROID_RUNTIME_SINGLETON := "AndroidRuntime"
const JAVA_CLASS_WRAPPER_SINGLETON := "JavaClassWrapper"
const COMPAT_BRIDGE_CLASS := "com.endlesshelicopter.push.FcmPushBridgeCompat"
const LEADERBOARD_SCENE_PATH := "res://scenes/ui/leaderboard/leaderboard_screen.tscn"
const MISSION_SCENE_PATH := "res://scenes/ui/missions/mission_screen.tscn"
const START_SCENE_PATH := "res://scenes/ui/start_screen/start_screen.tscn"
const REGISTRATION_RETRY_SECONDS := 1.5
const REGISTRATION_RETRY_ATTEMPTS := 5

var _http_request: HTTPRequest
var _registration_retry_timer: Timer
var _plugin: Object = null
var _android_runtime: Object = null
var _java_class_wrapper: Object = null
var _compat_bridge = null
var _pending_open_leaderboard: bool = false
var _pending_open_missions: bool = false
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
	if not OnlineLeaderboardScript.is_configured():
		return false
	if OS.get_name() != "Android":
		return false
	_refresh_plugin_reference()
	if _compat_bridge != null:
		var context = _get_android_context()
		if context != null:
			return bool(_compat_bridge.isFirebaseConfigured(context))
		return bool(_compat_bridge.isFirebaseConfigured())
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		return false
	var singleton := Engine.get_singleton(PLUGIN_SINGLETON)
	if singleton == null or not singleton.has_method("isPushSupported"):
		return false
	return bool(singleton.isPushSupported())

func request_notification_permission() -> void:
	_refresh_plugin_reference()
	if _compat_bridge != null:
		var activity = _get_android_activity()
		if activity != null:
			_compat_bridge.requestNotificationPermission(activity)
		else:
			_compat_bridge.requestNotificationPermission()
	elif _plugin != null and _plugin.has_method("requestNotificationPermission"):
		_plugin.requestNotificationPermission()
	_emit_diagnostics()

func register_device_for_push() -> void:
	_refresh_plugin_reference()
	if not is_push_supported():
		_last_registration_message = get_diagnostics_text()
		_emit_diagnostics()
		return
	_consume_cached_token()
	var latest_token := _get_latest_token()
	if not latest_token.is_empty():
		_register_device_token(latest_token)
	if _compat_bridge != null:
		var activity = _get_android_activity()
		if activity != null:
			_compat_bridge.fetchToken(activity)
		else:
			_compat_bridge.fetchToken()
	elif _plugin != null and _plugin.has_method("fetchToken"):
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
	var plugin_method_names := _get_plugin_method_names()
	var plugin_property_names := _get_plugin_property_names()
	var latest_token := _get_latest_token()
	if latest_token.is_empty():
		latest_token = _last_token_preview

	var bridge_supports_firebase_status := _compat_bridge != null or _plugin_supports_any_method(PackedStringArray(["getFirebaseStatus", "get_firebase_status"]))
	var firebase_ready := false
	if _compat_bridge != null:
		var context = _get_android_context()
		firebase_ready = bool(_compat_bridge.isFirebaseConfigured(context)) if context != null else bool(_compat_bridge.isFirebaseConfigured())
	if not firebase_ready and _compat_bridge == null and _plugin != null and _plugin.has_method("isPushSupported"):
		firebase_ready = bool(_plugin.isPushSupported())

	var firebase_status := _get_firebase_status()
	var permission_granted := _has_notification_permission()

	return {
		"leaderboard_configured": OnlineLeaderboardScript.is_configured(),
		"is_android": OS.get_name() == "Android",
		"plugin_loaded": _plugin != null or _compat_bridge != null,
		"compat_bridge_available": _compat_bridge != null,
		"player_identity_source": OnlineLeaderboardScript.get_player_identity_source(),
		"device_identity_source": AndroidIdentityScript.get_device_identity_source(),
		"android_runtime_available": _android_runtime != null,
		"bridge_supports_firebase_status": bridge_supports_firebase_status,
		"plugin_method_names": plugin_method_names,
		"plugin_property_names": plugin_property_names,
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
	if not bool(status["bridge_supports_firebase_status"]):
		return "Push unavailable: this APK is using an outdated Android push bridge. Rebuild the plugin AARs and export a fresh APK."
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

func get_debug_report() -> String:
	var status := get_diagnostics()
	var lines := PackedStringArray([
		"Debug build: %s" % _yes_no(OS.is_debug_build()),
		"Platform: %s" % OS.get_name(),
		"Leaderboard configured: %s" % _yes_no(bool(status["leaderboard_configured"])),
		"Plugin loaded: %s" % _yes_no(bool(status["plugin_loaded"])),
		"Compat bridge available: %s" % _yes_no(bool(status["compat_bridge_available"])),
		"Android runtime available: %s" % _yes_no(bool(status["android_runtime_available"])),
		"Player identity source: %s" % str(status["player_identity_source"]),
		"Device identity source: %s" % str(status["device_identity_source"]),
		"Bridge diagnostics available: %s" % _yes_no(bool(status["bridge_supports_firebase_status"])),
		"Firebase ready: %s" % _yes_no(bool(status["firebase_ready"])),
		"Firebase status: %s" % str(status["firebase_status"]),
		"Permission granted: %s" % _yes_no(bool(status["permission_granted"])),
		"Device ID: %s" % _load_cached_device_id_for_debug(),
		"Token present: %s" % _yes_no(bool(status["latest_token_present"])),
		"Token preview: %s" % str(status["latest_token_preview"]),
		"Registering now: %s" % _yes_no(bool(status["is_registering"])),
		"Retry attempts left: %d" % _remaining_registration_retries,
		"Last response code: %d" % int(status["last_response_code"]),
		"Last HTTP result: %d" % int(status["last_result"]),
		"Last message: %s" % str(status["last_message"]),
		"Last attempt at: %s" % str(status["last_attempt_at"]),
		"Last registered at: %s" % str(status["last_registered_at"]),
		"Plugin methods: %s" % ", ".join(PackedStringArray(status["plugin_method_names"])),
		"Plugin properties: %s" % ", ".join(PackedStringArray(status["plugin_property_names"])),
	])
	return "\n".join(lines)

func consume_open_leaderboard_request() -> bool:
	var should_open := _pending_open_leaderboard
	_pending_open_leaderboard = false
	return should_open

func consume_open_missions_request() -> bool:
	var should_open := _pending_open_missions
	_pending_open_missions = false
	return should_open

func _consume_launch_payload() -> void:
	var payload_json := ""
	if _compat_bridge != null:
		var activity = _get_android_activity()
		payload_json = str(_compat_bridge.consumeLaunchPayload(activity)).strip_edges() if activity != null else str(_compat_bridge.consumeLaunchPayload()).strip_edges()
	elif _plugin != null and _plugin.has_method("consumeLaunchPayload"):
		payload_json = str(_plugin.consumeLaunchPayload()).strip_edges()
	if payload_json.is_empty():
		return

	_handle_notification_payload(payload_json)

func _consume_cached_token() -> void:
	var cached_token := _get_cached_token()
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
	if _compat_bridge != null:
		var activity = _get_android_activity()
		notifications_enabled = bool(_compat_bridge.hasNotificationPermission(activity)) if activity != null else bool(_compat_bridge.hasNotificationPermission())
	elif _plugin != null and _plugin.has_method("hasNotificationPermission"):
		notifications_enabled = bool(_plugin.hasNotificationPermission())

	var request_headers := OnlineLeaderboardScript.get_headers() + PackedStringArray([
		"Prefer: resolution=merge-duplicates,return=minimal",
	])
	var body := OnlineLeaderboardScript.make_push_device_body(
		token,
		_load_or_create_device_id(),
		notifications_enabled,
		"Android",
		_get_daily_reminders_enabled()
	)
	_is_registering_device = true
	_pending_registration_token = token
	_registration_retry_by_token = false
	var error := _http_request.request(
		OnlineLeaderboardScript.get_push_device_upsert_url(),
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
	match str(payload.get("type", "")):
		"score_beaten":
			_pending_open_leaderboard = true
			_route_to_leaderboard_if_possible()
		"daily_missions":
			_pending_open_missions = true
			_route_to_missions_if_possible()

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

func _route_to_missions_if_possible() -> void:
	if not _pending_open_missions:
		return

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var current_scene := tree.current_scene
	if current_scene.scene_file_path == MISSION_SCENE_PATH:
		_pending_open_missions = false
		return

	if current_scene.scene_file_path != START_SCENE_PATH:
		return

	_pending_open_missions = false
	tree.change_scene_to_file(MISSION_SCENE_PATH)

func _load_or_create_device_id() -> String:
	return AndroidIdentityScript.load_or_create_device_id()

func _load_cached_device_id_for_debug() -> String:
	return AndroidIdentityScript.get_cached_device_id_for_debug()

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
	if _compat_bridge != null:
		var activity = _get_android_activity()
		notifications_enabled = bool(_compat_bridge.hasNotificationPermission(activity)) if activity != null else bool(_compat_bridge.hasNotificationPermission())
	elif _plugin != null and _plugin.has_method("hasNotificationPermission"):
		notifications_enabled = bool(_plugin.hasNotificationPermission())

	_registration_retry_by_token = true
	var request_headers := OnlineLeaderboardScript.get_headers() + PackedStringArray([
		"Prefer: return=minimal",
	])
	var body := OnlineLeaderboardScript.make_push_device_body(
		token,
		_load_or_create_device_id(),
		notifications_enabled,
		"Android",
		_get_daily_reminders_enabled()
	)
	var error := _http_request.request(
		OnlineLeaderboardScript.get_push_device_update_by_token_url(token),
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
	if _android_runtime == null and Engine.has_singleton(ANDROID_RUNTIME_SINGLETON):
		_android_runtime = Engine.get_singleton(ANDROID_RUNTIME_SINGLETON)
	if _java_class_wrapper == null and Engine.has_singleton(JAVA_CLASS_WRAPPER_SINGLETON):
		_java_class_wrapper = Engine.get_singleton(JAVA_CLASS_WRAPPER_SINGLETON)
	if _compat_bridge == null and _java_class_wrapper != null and _java_class_wrapper.has_method("wrap"):
		_compat_bridge = _java_class_wrapper.wrap(COMPAT_BRIDGE_CLASS)

func _get_android_activity():
	_refresh_plugin_reference()
	if _android_runtime != null and _android_runtime.has_method("getActivity"):
		return _android_runtime.getActivity()
	return null

func _get_android_context():
	var activity = _get_android_activity()
	if activity != null and activity.has_method("getApplicationContext"):
		return activity.getApplicationContext()
	if _android_runtime != null and _android_runtime.has_method("getApplicationContext"):
		return _android_runtime.getApplicationContext()
	return null

func _get_latest_token() -> String:
	if _compat_bridge != null:
		var context = _get_android_context()
		return str(_compat_bridge.getLatestToken(context)).strip_edges() if context != null else str(_compat_bridge.getLatestToken()).strip_edges()
	return _get_plugin_string_value(
		PackedStringArray(["getLatestToken", "get_latest_token"]),
		PackedStringArray(["latestToken", "latest_token"])
	)

func _get_cached_token() -> String:
	if _compat_bridge != null:
		var context = _get_android_context()
		return str(_compat_bridge.consumeStoredToken(context)).strip_edges() if context != null else str(_compat_bridge.consumeStoredToken()).strip_edges()
	if _plugin != null and _plugin.has_method("consumeStoredToken"):
		return str(_plugin.consumeStoredToken()).strip_edges()
	return ""

func _get_firebase_status() -> String:
	if _compat_bridge != null:
		var context = _get_android_context()
		return str(_compat_bridge.getFirebaseStatus(context)).strip_edges() if context != null else str(_compat_bridge.getFirebaseStatus()).strip_edges()
	return _get_plugin_string_value(
		PackedStringArray(["getFirebaseStatus", "get_firebase_status"]),
		PackedStringArray(["firebaseStatus", "firebase_status"])
	)

func _has_notification_permission() -> bool:
	if _compat_bridge != null:
		var activity = _get_android_activity()
		return bool(_compat_bridge.hasNotificationPermission(activity)) if activity != null else bool(_compat_bridge.hasNotificationPermission())
	if _plugin != null and _plugin.has_method("hasNotificationPermission"):
		return bool(_plugin.hasNotificationPermission())
	return false

func _plugin_supports_any_method(names: PackedStringArray) -> bool:
	if _plugin == null:
		return false
	for method_name in names:
		if _plugin.has_method(method_name):
			return true
	return false

func _get_plugin_method_names() -> PackedStringArray:
	if _plugin == null:
		return PackedStringArray()
	if not _plugin.has_method("get_method_list"):
		return PackedStringArray()

	var interesting_names := PackedStringArray()
	for item in _plugin.get_method_list():
		if item is Dictionary:
			var name := str(item.get("name", ""))
			if name.is_empty():
				continue
			if (
				name.contains("Push")
				or name.contains("push")
				or name.contains("Firebase")
				or name.contains("firebase")
				or name.contains("Token")
				or name.contains("token")
				or name.contains("Permission")
				or name.contains("permission")
			):
				interesting_names.append(name)
	return interesting_names

func _get_plugin_property_names() -> PackedStringArray:
	if _plugin == null:
		return PackedStringArray()
	if not _plugin.has_method("get_property_list"):
		return PackedStringArray()

	var interesting_names := PackedStringArray()
	for item in _plugin.get_property_list():
		if item is Dictionary:
			var name := str(item.get("name", ""))
			if name.is_empty():
				continue
			if (
				name.contains("push")
				or name.contains("Push")
				or name.contains("firebase")
				or name.contains("Firebase")
				or name.contains("token")
				or name.contains("Token")
				or name.contains("permission")
				or name.contains("Permission")
			):
				interesting_names.append(name)
	return interesting_names

func _get_plugin_string_value(method_names: PackedStringArray, property_names: PackedStringArray = PackedStringArray()) -> String:
	if _plugin == null:
		return ""

	for method_name in method_names:
		if _plugin.has_method(method_name):
			return str(_plugin.call(method_name)).strip_edges()

	for property_name in property_names:
		var property_value = _plugin.get(property_name)
		if property_value != null:
			return str(property_value).strip_edges()

	return ""

func _emit_diagnostics() -> void:
	diagnostics_changed.emit(get_diagnostics())

func _token_preview(token: String) -> String:
	var clean_token := token.strip_edges()
	if clean_token.is_empty():
		return ""
	if clean_token.length() <= 10:
		return clean_token
	return "%s...%s" % [clean_token.substr(0, 6), clean_token.substr(clean_token.length() - 4, 4)]

func _yes_no(value: bool) -> String:
	return "yes" if value else "no"

func _get_daily_reminders_enabled() -> bool:
	var player_profile = get_node_or_null("/root/PlayerProfile")
	if player_profile != null and player_profile.has_method("are_daily_reminders_enabled"):
		return bool(player_profile.are_daily_reminders_enabled())
	return false

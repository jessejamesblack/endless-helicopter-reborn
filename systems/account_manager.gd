extends Node

signal account_state_changed(summary: Dictionary)

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const AndroidIdentityScript = preload("res://systems/android_identity.gd")

const SESSION_PATH := "user://account_session.cfg"
const SESSION_SECTION := "account_session"
const REFRESH_MARGIN_SECONDS := 120

var _access_token: String = ""
var _refresh_token: String = ""
var _auth_user_id: String = ""
var _email: String = ""
var _expires_at_unix: int = 0
var _pending_email: String = ""
var _linked_player_id: String = ""
var _linked_family_id: String = OnlineLeaderboardScript.FAMILY_ID
var _last_status_message: String = "Protect your progress with a quick email code."
var _bootstrap_in_progress: bool = false
var _request_in_flight: bool = false
var _last_profile_snapshot: Dictionary = {}
var _last_daily_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_session()
	call_deferred("_bootstrap_account_async")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_signed_in() and not _bootstrap_in_progress:
		refresh_account_state()

func is_bootstrap_in_progress() -> bool:
	return _bootstrap_in_progress

func is_signed_in() -> bool:
	return not _access_token.is_empty() and not _auth_user_id.is_empty()

func has_linked_profile() -> bool:
	return not _linked_player_id.is_empty()

func get_linked_player_id() -> String:
	return _linked_player_id

func get_linked_family_id() -> String:
	return _linked_family_id

func get_signed_in_email() -> String:
	return _email

func get_access_token() -> String:
	return _access_token

func get_pending_email() -> String:
	return _pending_email

func is_request_in_flight() -> bool:
	return _request_in_flight

func get_last_profile_snapshot() -> Dictionary:
	return _last_profile_snapshot.duplicate(true)

func get_last_daily_snapshot() -> Dictionary:
	return _last_daily_snapshot.duplicate(true)

func get_state_summary() -> Dictionary:
	return {
		"signed_in": is_signed_in(),
		"linked": has_linked_profile(),
		"bootstrap_in_progress": _bootstrap_in_progress,
		"request_in_flight": _request_in_flight,
		"email": _email,
		"pending_email": _pending_email,
		"linked_player_id": _linked_player_id,
		"linked_family_id": _linked_family_id,
		"auth_user_id": _auth_user_id,
		"local_profile_claimable": _has_claimable_local_profile(),
		"status_text": _last_status_message,
		"protect_prompt_visible": _should_show_protect_prompt(),
	}

func send_email_otp_async(email: String) -> Dictionary:
	var normalized_email := email.strip_edges().to_lower()
	if not _is_valid_email(normalized_email):
		return {"ok": false, "message": "Enter a valid email address."}
	if _request_in_flight:
		return {"ok": false, "message": "Account request already in progress."}

	_request_in_flight = true
	_pending_email = normalized_email
	_last_status_message = "Sending a sign-in code to %s..." % normalized_email
	_emit_state_changed()

	var response := await _request_json(
		"%s/auth/v1/otp" % OnlineLeaderboardScript.SUPABASE_URL,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"email": normalized_email,
		}),
		_get_public_auth_headers()
	)

	_request_in_flight = false
	if _is_success_response(response):
		_last_status_message = "Enter the email code we sent to %s." % normalized_email
		_emit_state_changed()
		return {"ok": true, "message": _last_status_message}

	var message := _response_error_text(response, "Could not send a sign-in code right now.")
	_pending_email = ""
	_last_status_message = message
	_emit_state_changed()
	return {"ok": false, "message": message}

func verify_email_otp_async(email: String, token: String) -> Dictionary:
	var normalized_email := email.strip_edges().to_lower()
	var clean_token := token.strip_edges()
	if not _is_valid_email(normalized_email):
		return {"ok": false, "message": "Enter a valid email address."}
	if clean_token.is_empty():
		return {"ok": false, "message": "Enter the email code."}
	if _request_in_flight:
		return {"ok": false, "message": "Account request already in progress."}

	_request_in_flight = true
	_last_status_message = "Verifying your email code..."
	_emit_state_changed()

	var response := await _request_json(
		"%s/auth/v1/verify" % OnlineLeaderboardScript.SUPABASE_URL,
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"email": normalized_email,
			"token": clean_token,
			"type": "email",
		}),
		_get_public_auth_headers()
	)

	_request_in_flight = false
	if not _is_success_response(response):
		var failed_message := _response_error_text(response, "Could not verify that email code.")
		_last_status_message = failed_message
		_emit_state_changed()
		return {"ok": false, "message": failed_message}

	var payload := _parse_json_dictionary(response.body)
	if not _apply_session_payload(payload, normalized_email):
		_last_status_message = "The sign-in response did not include a usable session."
		_emit_state_changed()
		return {"ok": false, "message": _last_status_message}

	_pending_email = ""
	await _refresh_linked_profile_state_async(true)
	_emit_state_changed()
	return {
		"ok": true,
		"linked": has_linked_profile(),
		"message": _last_status_message,
	}

func refresh_account_state() -> void:
	call_deferred("_refresh_account_state_async")

func sign_out() -> void:
	_access_token = ""
	_refresh_token = ""
	_auth_user_id = ""
	_email = ""
	_expires_at_unix = 0
	_pending_email = ""
	_linked_player_id = ""
	_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
	_last_profile_snapshot = {}
	_last_daily_snapshot = {}
	_last_status_message = "Signed out. You can still play offline."
	_save_session()
	_emit_state_changed()
	_notify_runtime_state_changed(false)

func _bootstrap_account_async() -> void:
	if _bootstrap_in_progress:
		return
	_bootstrap_in_progress = true
	if not is_signed_in():
		_last_status_message = "Protect your progress with a quick email code."
		_bootstrap_in_progress = false
		_emit_state_changed()
		return
	if not await _ensure_session_valid_async():
		_bootstrap_in_progress = false
		_emit_state_changed()
		return
	await _refresh_linked_profile_state_async(true)
	_bootstrap_in_progress = false
	_emit_state_changed()

func _refresh_account_state_async() -> void:
	if _request_in_flight:
		return
	if not is_signed_in():
		_emit_state_changed()
		return
	_request_in_flight = true
	var valid_session := await _ensure_session_valid_async()
	if valid_session:
		await _refresh_linked_profile_state_async(true)
	_request_in_flight = false
	_emit_state_changed()

func _ensure_session_valid_async() -> bool:
	if not is_signed_in():
		return false
	if not _access_token_needs_refresh():
		return true
	return await _refresh_session_async()

func _refresh_session_async() -> bool:
	if _refresh_token.is_empty():
		sign_out()
		return false
	var body := "refresh_token=%s" % _refresh_token.uri_encode()
	var response := await _request_json(
		"%s/auth/v1/token?grant_type=refresh_token" % OnlineLeaderboardScript.SUPABASE_URL,
		HTTPClient.METHOD_POST,
		body,
		_get_form_auth_headers()
	)
	if not _is_success_response(response):
		sign_out()
		return false
	var payload := _parse_json_dictionary(response.body)
	return _apply_session_payload(payload, _email)

func _refresh_linked_profile_state_async(allow_auto_link: bool = true) -> void:
	if not is_signed_in():
		_linked_player_id = ""
		_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
		_last_profile_snapshot = {}
		_last_daily_snapshot = {}
		_last_status_message = "Protect your progress with a quick email code."
		return

	var account_response := await _request_account_profile_async()
	if int(account_response.get("response_code", 0)) == 401:
		if await _refresh_session_async():
			account_response = await _request_account_profile_async()
		else:
			return
	if not _is_success_response(account_response):
		_linked_player_id = ""
		_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
		_last_profile_snapshot = {}
		_last_daily_snapshot = {}
		_last_status_message = _response_error_text(account_response, "Could not check your progress backup right now.")
		return

	var payload := _parse_json_dictionary(account_response.body)
	_email = str(payload.get("email", _email)).strip_edges().to_lower()
	if bool(payload.get("linked", false)):
		_linked_player_id = str(payload.get("player_id", "")).strip_edges()
		_linked_family_id = str(payload.get("family_id", OnlineLeaderboardScript.FAMILY_ID)).strip_edges()
		if _linked_family_id.is_empty():
			_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
		_last_profile_snapshot = payload.get("profile", {}) as Dictionary
		_last_daily_snapshot = payload.get("daily_progress", {}) as Dictionary
		var restored_name := str(_last_profile_snapshot.get("name", "")).strip_edges()
		if not restored_name.is_empty():
			OnlineLeaderboardScript.save_cached_name(restored_name)
		_last_status_message = "Connected. Progress backup active for %s." % _email
		_notify_runtime_state_changed(true)
		return

	_linked_player_id = ""
	_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
	_last_profile_snapshot = {}
	_last_daily_snapshot = {}
	if allow_auto_link and await _try_auto_link_current_profile_async():
		await _refresh_linked_profile_state_async(false)
		return
	_last_status_message = "Connected as %s. Progress backup is ready when this profile is linked." % _email
	_notify_runtime_state_changed(false)

func _request_account_profile_async() -> Dictionary:
	return await _request_json(
		OnlineLeaderboardScript.get_account_profile_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_get_account_profile_body(_get_current_mission_date()),
		_get_authenticated_headers()
	)

func _try_auto_link_current_profile_async() -> bool:
	if not is_signed_in():
		return false
	if not _has_claimable_local_profile():
		return false
	if not _is_local_player_identity_ready_for_cloud():
		return false
	var local_player_id := OnlineLeaderboardScript.get_local_player_id_for_account_linking().strip_edges()
	if local_player_id.is_empty():
		return false
	var response := await _request_json(
		OnlineLeaderboardScript.get_link_account_profile_url(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_link_account_profile_body(local_player_id),
		_get_authenticated_headers()
	)
	if not _is_success_response(response):
		return false
	return true

func _has_claimable_local_profile() -> bool:
	if not OnlineLeaderboardScript.load_cached_name().is_empty():
		return true
	var player_profile := get_node_or_null("/root/PlayerProfile")
	if player_profile != null and player_profile.has_method("has_meaningful_local_progress"):
		return bool(player_profile.has_meaningful_local_progress())
	return false

func _should_show_protect_prompt() -> bool:
	if has_linked_profile():
		return false
	if is_signed_in():
		return true
	return _has_claimable_local_profile()

func _is_local_player_identity_ready_for_cloud() -> bool:
	if OnlineLeaderboardScript.has_manual_player_id_override():
		return not OnlineLeaderboardScript.load_manual_player_id_override().is_empty()
	if OS.get_name() != "Android":
		return not OnlineLeaderboardScript.get_local_player_id_for_account_linking().is_empty()
	return bool(AndroidIdentityScript.get_player_identity_info().get("remote_ready", false))

func _notify_runtime_state_changed(force_replace_local_state: bool) -> void:
	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("notify_identity_state_changed"):
		sync_queue.notify_identity_state_changed(force_replace_local_state)
	var push_notifications := get_node_or_null("/root/PushNotifications")
	if push_notifications != null and push_notifications.has_method("register_device_for_push"):
		push_notifications.register_device_for_push()

func _load_session() -> void:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return
	_access_token = str(config.get_value(SESSION_SECTION, "access_token", "")).strip_edges()
	_refresh_token = str(config.get_value(SESSION_SECTION, "refresh_token", "")).strip_edges()
	_auth_user_id = str(config.get_value(SESSION_SECTION, "auth_user_id", "")).strip_edges()
	_email = str(config.get_value(SESSION_SECTION, "email", "")).strip_edges().to_lower()
	_expires_at_unix = maxi(int(config.get_value(SESSION_SECTION, "expires_at_unix", 0)), 0)
	_linked_player_id = str(config.get_value(SESSION_SECTION, "linked_player_id", "")).strip_edges()
	_linked_family_id = str(config.get_value(SESSION_SECTION, "linked_family_id", OnlineLeaderboardScript.FAMILY_ID)).strip_edges()
	if _linked_family_id.is_empty():
		_linked_family_id = OnlineLeaderboardScript.FAMILY_ID
	_pending_email = str(config.get_value(SESSION_SECTION, "pending_email", "")).strip_edges().to_lower()

func _save_session() -> void:
	if _access_token.is_empty() or _auth_user_id.is_empty():
		if FileAccess.file_exists(SESSION_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
		return
	var config := ConfigFile.new()
	config.set_value(SESSION_SECTION, "access_token", _access_token)
	config.set_value(SESSION_SECTION, "refresh_token", _refresh_token)
	config.set_value(SESSION_SECTION, "auth_user_id", _auth_user_id)
	config.set_value(SESSION_SECTION, "email", _email)
	config.set_value(SESSION_SECTION, "expires_at_unix", _expires_at_unix)
	config.set_value(SESSION_SECTION, "linked_player_id", _linked_player_id)
	config.set_value(SESSION_SECTION, "linked_family_id", _linked_family_id)
	config.set_value(SESSION_SECTION, "pending_email", _pending_email)
	config.save(SESSION_PATH)

func _apply_session_payload(payload: Dictionary, fallback_email: String = "") -> bool:
	var access_token := str(payload.get("access_token", "")).strip_edges()
	var refresh_token := str(payload.get("refresh_token", "")).strip_edges()
	var user := payload.get("user", {}) as Dictionary
	var auth_user_id := str(user.get("id", "")).strip_edges()
	var resolved_email := str(user.get("email", fallback_email)).strip_edges().to_lower()
	if access_token.is_empty() or refresh_token.is_empty() or auth_user_id.is_empty():
		return false
	_access_token = access_token
	_refresh_token = refresh_token
	_auth_user_id = auth_user_id
	_email = resolved_email
	_expires_at_unix = int(Time.get_unix_time_from_system()) + maxi(int(payload.get("expires_in", 3600)), 60)
	_save_session()
	return true

func _access_token_needs_refresh() -> bool:
	if _expires_at_unix <= 0:
		return true
	return _expires_at_unix <= int(Time.get_unix_time_from_system()) + REFRESH_MARGIN_SECONDS

func _get_public_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % OnlineLeaderboardScript.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % OnlineLeaderboardScript.SUPABASE_ANON_KEY,
		"Content-Type: application/json",
	])

func _get_form_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % OnlineLeaderboardScript.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % OnlineLeaderboardScript.SUPABASE_ANON_KEY,
		"Content-Type: application/x-www-form-urlencoded",
	])

func _get_authenticated_headers() -> PackedStringArray:
	var token := _access_token.strip_edges()
	if token.is_empty():
		return _get_public_auth_headers()
	return PackedStringArray([
		"apikey: %s" % OnlineLeaderboardScript.SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json",
	])

func _request_json(url: String, method: int, body: String = "", headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var request_headers := headers if not headers.is_empty() else _get_public_auth_headers()
	var error := request.request(url, request_headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"result": error,
			"response_code": 0,
			"body": PackedByteArray(),
		}
	var completed = await request.request_completed
	request.queue_free()
	return {
		"result": int(completed[0]),
		"response_code": int(completed[1]),
		"body": completed[3],
	}

func _is_success_response(response: Dictionary) -> bool:
	return int(response.get("result", HTTPRequest.RESULT_CANT_CONNECT)) == HTTPRequest.RESULT_SUCCESS \
		and int(response.get("response_code", 0)) >= 200 \
		and int(response.get("response_code", 0)) < 300

func _response_error_text(response: Dictionary, fallback: String) -> String:
	return OnlineLeaderboardScript.parse_api_error(response.get("body", PackedByteArray()) as PackedByteArray, fallback)

func _parse_json_dictionary(body: PackedByteArray) -> Dictionary:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}

func _get_current_mission_date() -> String:
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null and mission_manager.has_method("get_today_key"):
		return str(mission_manager.get_today_key())
	return ""

func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".") and not email.begins_with("@") and not email.ends_with("@")

func _emit_state_changed() -> void:
	_save_session()
	account_state_changed.emit(get_state_summary())

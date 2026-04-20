class_name OnlineLeaderboard
extends RefCounted

const AndroidIdentityScript = preload("res://systems/android_identity.gd")
const BuildInfoScript = preload("res://systems/build_info.gd")

# Fill these in after creating your Supabase project.
const SUPABASE_URL := "https://lxvniafwjlwatbiblwyi.supabase.co"
const SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4dm5pYWZ3amx3YXRiaWJsd3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyMTQ1MjMsImV4cCI6MjA5MTc5MDUyM30.FzM4zxKx3yVyxvM1hbRFdAcNxrW3x9t6zerDEsDK42w"
const TABLE_NAME := "family_leaderboard"
const NOTIFICATION_TABLE_NAME := "family_notifications"
const PUSH_DEVICE_TABLE_NAME := "family_push_devices"
const PLAYER_PROFILE_TABLE_NAME := "family_player_profiles"
const DAILY_MISSION_PROGRESS_TABLE_NAME := "family_daily_mission_progress"
const FAMILY_ID := "global"
const NAME_CACHE_PATH := "user://player_name.save"
const CLOUD_PROFILE_CACHE_PATH := "user://cloud_profile_present.save"
const PLAYER_ID_OVERRIDE_CACHE_PATH := "user://player_id_override.save"
const MAX_NAME_LENGTH := 12
const MAX_PLAYER_ID_LENGTH := 96
const PLAYER_ID_SOURCE_MANUAL_OVERRIDE := "manual_override"
const PLAYER_ID_SOURCE_ANDROID_PENDING := "android_pending"
const PLAYER_ID_SOURCE_ANDROID_STABLE := "android_stable"
const PLAYER_ID_SOURCE_LEGACY_CACHE := "legacy_cache"
const PLAYER_ID_SOURCE_LOCAL_FALLBACK := "local_fallback"
const BLOCKED_TERMS := [
	"asshole",
	"bastard",
	"bitch",
	"cock",
	"cunt",
	"dick",
	"fag",
	"faggot",
	"fuck",
	"motherfucker",
	"nigga",
	"nigger",
	"pussy",
	"shit",
	"slut",
	"whore",
]

static func is_configured() -> bool:
	return not SUPABASE_URL.is_empty() and not SUPABASE_ANON_KEY.is_empty() and not FAMILY_ID.is_empty() and FAMILY_ID != "your-family"

static func get_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json",
	])

static func get_fetch_url(limit: int = 10, offset: int = 0) -> String:
	return get_fetch_url_with_mode(limit, offset, true)

static func get_fetch_url_with_mode(limit: int = 10, offset: int = 0, include_expanded_fields: bool = true) -> String:
	var encoded_family := FAMILY_ID.uri_encode()
	var select_fields := "player_id,name,score,created_at,updated_at"
	if include_expanded_fields:
		select_fields += ",equipped_skin_id,equipped_vehicle_id,equipped_vehicle_skin_id,skill_score,near_misses,max_combo_multiplier,projectile_intercepts"
	return "%s/rest/v1/%s?select=%s&family_id=eq.%s&order=score.desc,created_at.asc&limit=%d&offset=%d" % [
		SUPABASE_URL,
		TABLE_NAME,
		select_fields,
		encoded_family,
		limit,
		offset,
	]

static func get_legacy_fetch_url(limit: int = 10, offset: int = 0) -> String:
	return get_fetch_url_with_mode(limit, offset, false)

static func get_top_entry_url() -> String:
	var encoded_family := FAMILY_ID.uri_encode()
	return "%s/rest/v1/%s?select=player_id,name,score,created_at,updated_at&family_id=eq.%s&order=score.desc,created_at.asc&limit=1" % [
		SUPABASE_URL,
		TABLE_NAME,
		encoded_family,
	]

static func get_personal_best_url() -> String:
	var player_id := load_or_create_player_id().strip_edges()
	if player_id.is_empty():
		return ""
	var encoded_family := FAMILY_ID.uri_encode()
	var encoded_player_id := player_id.uri_encode()
	return "%s/rest/v1/%s?select=player_id,name,score,created_at,updated_at&family_id=eq.%s&player_id=eq.%s&order=score.desc,created_at.asc&limit=1" % [
		SUPABASE_URL,
		TABLE_NAME,
		encoded_family,
		encoded_player_id,
	]

static func get_submit_v2_url() -> String:
	return get_edge_function_url("save-score")

static func get_submit_url() -> String:
	return get_edge_function_url("save-score")

static func get_legacy_submit_url() -> String:
	return "%s/rest/v1/%s" % [SUPABASE_URL, TABLE_NAME]

static func get_sync_player_profile_url() -> String:
	return get_edge_function_url("sync-player-profile")

static func get_sync_daily_mission_progress_url() -> String:
	return get_edge_function_url("sync-daily-mission-progress")

static func get_get_player_profile_url() -> String:
	return get_edge_function_url("get-player-profile")

static func get_get_daily_mission_progress_url() -> String:
	return get_edge_function_url("get-daily-mission-progress")

static func get_notifications_url(_limit: int = 10) -> String:
	return get_edge_function_url("get-notifications")

static func get_mark_notifications_read_url(_ids: Array[int]) -> String:
	return get_edge_function_url("mark-notifications-read")

static func get_push_device_upsert_url() -> String:
	return get_edge_function_url("register-push-device")

static func get_push_device_update_by_token_url(fcm_token: String) -> String:
	return get_edge_function_url("register-push-device")

static func get_edge_function_url(function_name: String) -> String:
	return "%s/functions/v1/%s" % [SUPABASE_URL, function_name.uri_encode()]

static func parse_entries(body: PackedByteArray) -> Array[Dictionary]:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var entries: Array[Dictionary] = []

	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				entries.append({
					"player_id": str(item.get("player_id", "")),
				"name": str(item.get("name", "Player")).strip_edges(),
				"score": int(item.get("score", 0)),
				"created_at": str(item.get("created_at", "")),
				"updated_at": str(item.get("updated_at", "")),
				"equipped_skin_id": str(item.get("equipped_skin_id", "")),
				"equipped_vehicle_id": str(item.get("equipped_vehicle_id", item.get("equipped_skin_id", ""))),
				"equipped_vehicle_skin_id": str(item.get("equipped_vehicle_skin_id", "factory")),
				"skill_score": int(item.get("skill_score", 0)),
				"near_misses": int(item.get("near_misses", 0)),
				"max_combo_multiplier": float(item.get("max_combo_multiplier", 1.0)),
				"projectile_intercepts": int(item.get("projectile_intercepts", 0)),
			})

	return entries

static func parse_notifications(body: PackedByteArray) -> Array[Dictionary]:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var notifications: Array[Dictionary] = []

	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				notifications.append({
					"id": int(item.get("id", 0)),
					"challenger_name": str(item.get("challenger_name", "Player")).strip_edges(),
					"challenger_score": int(item.get("challenger_score", 0)),
					"beaten_score": int(item.get("beaten_score", 0)),
					"created_at": str(item.get("created_at", "")),
				})

	return notifications

static func format_entries(entries: Array[Dictionary], limit: int = 5) -> String:
	var best_entries := get_best_entries(entries)
	if best_entries.is_empty():
		return "No family scores yet"

	var lines: Array[String] = []
	for i in range(min(limit, best_entries.size())):
		var entry := best_entries[i]
		lines.append("%d. %s - %d" % [i + 1, entry["name"], entry["score"]])

	return "\n".join(lines)

static func make_submit_body(name: String, score: int) -> String:
	var safe_name := sanitize_name(name)
	var payload := {
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
		"p_name": safe_name,
		"p_score": score,
	}
	return JSON.stringify(payload)

static func make_submit_v2_body(name: String, score: int, run_summary: Dictionary, equipped_skin_id: String) -> String:
	var safe_name := sanitize_name(name)
	var payload := {
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
		"p_name": safe_name,
		"p_score": score,
		"p_run_summary": run_summary,
		"p_equipped_skin_id": equipped_skin_id,
	}
	return JSON.stringify(payload)

static func make_legacy_submit_body(name: String, score: int) -> String:
	var safe_name := sanitize_name(name)
	return JSON.stringify({
		"family_id": FAMILY_ID,
		"player_id": load_or_create_player_id(),
		"name": safe_name,
		"score": score,
	})

static func sanitize_name(name: String) -> String:
	var safe_name := name.strip_edges()
	safe_name = _remove_invalid_name_characters(safe_name)
	if safe_name.is_empty():
		safe_name = "Player"
	return safe_name.substr(0, MAX_NAME_LENGTH)

static func validate_player_name(name: String) -> Dictionary:
	var raw_name := _remove_invalid_name_characters(name.strip_edges())
	if raw_name.is_empty():
		return {"ok": false, "error": "Enter a player name."}

	var safe_name := raw_name.substr(0, MAX_NAME_LENGTH)
	var normalized := _normalize_for_filter(safe_name)
	for blocked_term in BLOCKED_TERMS:
		if normalized.contains(blocked_term):
			return {"ok": false, "error": "Choose a more family-friendly name."}

	return {"ok": true, "name": safe_name}

static func save_cached_name(name: String) -> void:
	var file := FileAccess.open(NAME_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(sanitize_name(name))

static func mark_cloud_profile_present() -> void:
	var file := FileAccess.open(CLOUD_PROFILE_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("1")

static func clear_cloud_profile_presence() -> void:
	if FileAccess.file_exists(CLOUD_PROFILE_CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CLOUD_PROFILE_CACHE_PATH))

static func save_manual_player_id_override(player_id: String) -> void:
	var validation := validate_player_id(player_id)
	if not bool(validation.get("ok", false)):
		return
	var file := FileAccess.open(PLAYER_ID_OVERRIDE_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(str(validation.get("player_id", "")))

static func clear_manual_player_id_override() -> void:
	if FileAccess.file_exists(PLAYER_ID_OVERRIDE_CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_ID_OVERRIDE_CACHE_PATH))

static func load_manual_player_id_override() -> String:
	if not FileAccess.file_exists(PLAYER_ID_OVERRIDE_CACHE_PATH):
		return ""
	var file := FileAccess.open(PLAYER_ID_OVERRIDE_CACHE_PATH, FileAccess.READ)
	if file == null:
		return ""
	return str(file.get_as_text()).strip_edges()

static func has_manual_player_id_override() -> bool:
	return not load_manual_player_id_override().is_empty()

static func clear_cached_name() -> void:
	if FileAccess.file_exists(NAME_CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(NAME_CACHE_PATH))

static func load_cached_name() -> String:
	if not FileAccess.file_exists(NAME_CACHE_PATH):
		return ""

	var file := FileAccess.open(NAME_CACHE_PATH, FileAccess.READ)
	if file == null:
		return ""

	return sanitize_name(file.get_as_text())

static func has_saved_player_name() -> bool:
	return not load_cached_name().is_empty()

static func has_cloud_profile() -> bool:
	if has_saved_player_name():
		return true
	if not FileAccess.file_exists(CLOUD_PROFILE_CACHE_PATH):
		return false
	var file := FileAccess.open(CLOUD_PROFILE_CACHE_PATH, FileAccess.READ)
	if file == null:
		return false
	return not str(file.get_as_text()).strip_edges().is_empty()

static func has_saved_profile() -> bool:
	return has_saved_player_name()

static func load_or_create_player_id() -> String:
	var manual_override := load_manual_player_id_override()
	if not manual_override.is_empty():
		return manual_override
	return AndroidIdentityScript.load_or_create_player_id()

static func load_canonical_player_id() -> String:
	return AndroidIdentityScript.load_or_create_player_id()

static func load_canonical_device_id() -> String:
	return AndroidIdentityScript.load_or_create_device_id()

static func get_player_identity_source() -> String:
	if has_manual_player_id_override():
		return PLAYER_ID_SOURCE_MANUAL_OVERRIDE
	return AndroidIdentityScript.get_player_identity_source()

static func get_device_identity_source() -> String:
	return AndroidIdentityScript.get_device_identity_source()

static func get_player_identity_source_label() -> String:
	return get_identity_source_label(get_player_identity_source())

static func get_device_identity_source_label() -> String:
	return get_identity_source_label(get_device_identity_source())

static func is_remote_identity_ready() -> bool:
	return AndroidIdentityScript.is_remote_identity_ready()

static func is_remote_profile_identity_ready() -> bool:
	if has_manual_player_id_override():
		return true
	if OS.get_name() != "Android":
		return not load_or_create_player_id().is_empty()
	return bool(AndroidIdentityScript.get_player_identity_info().get("remote_ready", false))

static func is_current_player_id_ready_for_cloud() -> bool:
	return not load_or_create_player_id().strip_edges().is_empty() and is_remote_profile_identity_ready()

static func is_canonical_player_id_ready_for_cloud() -> bool:
	var canonical_player_id := load_canonical_player_id().strip_edges()
	if canonical_player_id.is_empty():
		return false
	if OS.get_name() != "Android":
		return true
	return bool(AndroidIdentityScript.get_player_identity_info().get("remote_ready", false))

static func has_pending_remote_identity_migration() -> bool:
	if has_manual_player_id_override():
		return false
	return AndroidIdentityScript.has_pending_remote_identity_migration()

static func get_pending_remote_identity_migration() -> Dictionary:
	return AndroidIdentityScript.get_pending_remote_identity_migration()

static func finalize_remote_identity_migration() -> void:
	if has_manual_player_id_override():
		return
	AndroidIdentityScript.finalize_remote_identity_migration()

static func get_player_id_for_display() -> String:
	var player_id := load_or_create_player_id().strip_edges()
	if OS.get_name() == "Android" and not has_manual_player_id_override() and not is_remote_profile_identity_ready():
		return "(waiting for Android-backed player ID)"
	if player_id.is_empty():
		return "(waiting for Android-backed player ID)" if OS.get_name() == "Android" and not has_manual_player_id_override() else "(not ready yet)"
	return player_id

static func validate_player_id(player_id: String) -> Dictionary:
	var trimmed := player_id.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "Enter a player ID."}
	if trimmed.length() > MAX_PLAYER_ID_LENGTH:
		return {"ok": false, "error": "Player ID is too long."}
	for i in range(trimmed.length()):
		var character := trimmed.substr(i, 1)
		var code := character.unicode_at(0)
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_number := code >= 48 and code <= 57
		if is_upper or is_lower or is_number or character == "-" or character == "_" or character == "." or character == ":":
			continue
		return {"ok": false, "error": "Player ID can use letters, numbers, dashes, underscores, dots, and colons only."}
	return {"ok": true, "player_id": trimmed}

static func get_identity_source_label(source: String) -> String:
	match source:
		PLAYER_ID_SOURCE_MANUAL_OVERRIDE:
			return "Manual override"
		PLAYER_ID_SOURCE_ANDROID_STABLE:
			return "Android-backed derived ID"
		PLAYER_ID_SOURCE_LEGACY_CACHE:
			return "Legacy cached app ID"
		PLAYER_ID_SOURCE_ANDROID_PENDING:
			return "Waiting for Android-backed ID"
		PLAYER_ID_SOURCE_LOCAL_FALLBACK:
			return "Local fallback app ID"
	return source.replace("_", " ").capitalize()

static func get_migrate_player_identity_url() -> String:
	return get_edge_function_url("migrate-player-identity")

static func make_migrate_player_identity_body() -> String:
	var migration := get_pending_remote_identity_migration()
	return make_migrate_player_identity_body_for_ids(
		str(migration.get("old_player_id", "")),
		str(migration.get("new_player_id", "")),
		str(migration.get("old_device_id", "")),
		str(migration.get("new_device_id", "")),
	)

static func make_migrate_player_identity_body_for_ids(old_player_id: String, new_player_id: String, old_device_id: String = "", new_device_id: String = "") -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_old_player_id": old_player_id.strip_edges(),
		"p_new_player_id": new_player_id.strip_edges(),
		"p_old_device_id": old_device_id.strip_edges(),
		"p_new_device_id": new_device_id.strip_edges(),
	})

static func make_mark_notifications_read_body() -> String:
	return make_mark_notifications_read_body_for_ids([])

static func make_mark_notifications_read_body_for_ids(ids: Array[int]) -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"ids": ids.duplicate(),
		"read_at": Time.get_datetime_string_from_system(true),
	})

static func make_get_notifications_body(limit: int = 5) -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"family_id": FAMILY_ID,
		"player_id": load_or_create_player_id(),
		"limit": limit,
	})

static func make_push_device_body(fcm_token: String, device_id: String, notifications_enabled: bool, device_label: String = "", daily_missions_enabled: bool = true, app_metadata: Dictionary = {}) -> String:
	var timestamp := Time.get_datetime_string_from_system(true)
	var resolved_metadata := BuildInfoScript.get_summary()
	for key in app_metadata.keys():
		resolved_metadata[str(key)] = app_metadata[key]
	return JSON.stringify({
		"family_id": FAMILY_ID,
		"player_id": load_or_create_player_id(),
		"device_id": device_id,
		"fcm_token": fcm_token,
		"platform": "android",
		"device_label": device_label,
		"notifications_enabled": notifications_enabled,
		"daily_missions_enabled": daily_missions_enabled,
		"last_seen_at": timestamp,
		"app_version_code": int(resolved_metadata.get("version_code", BuildInfoScript.VERSION_CODE)),
		"app_version_name": str(resolved_metadata.get("version_name", BuildInfoScript.VERSION_NAME)),
		"build_sha": str(resolved_metadata.get("build_sha", BuildInfoScript.BUILD_SHA)),
		"release_channel": str(resolved_metadata.get("release_channel", BuildInfoScript.RELEASE_CHANNEL)),
	})

static func make_sync_player_profile_body(profile_summary: Dictionary) -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
		"p_name": load_cached_name(),
		"p_equipped_skin_id": str(profile_summary.get("equipped_vehicle_id", profile_summary.get("equipped_skin_id", "default_scout"))),
		"p_unlocked_skins": profile_summary.get("unlocked_vehicles", profile_summary.get("unlocked_skins", ["default_scout"])),
		"p_total_daily_missions_completed": int(profile_summary.get("total_daily_missions_completed", 0)),
		"p_daily_streak": int(profile_summary.get("daily_streak", 0)),
		"p_last_completed_daily_date": str(profile_summary.get("last_completed_daily_date", "")),
		"p_daily_reminders_enabled": bool(profile_summary.get("daily_reminders_enabled", false)),
		"p_profile_summary": profile_summary,
	})

static func make_sync_daily_mission_progress_body(mission_summary: Dictionary) -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
		"p_mission_date": str(mission_summary.get("mission_date", "")),
		"p_missions": mission_summary.get("missions", []),
		"p_completed_count": int(mission_summary.get("completed_count", 0)),
		"p_total_count": int(mission_summary.get("total_count", 3)),
	})

static func make_get_player_profile_body() -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
	})

static func make_get_daily_mission_progress_body(mission_date: String) -> String:
	return JSON.stringify({
		"current_version_code": int(BuildInfoScript.VERSION_CODE),
		"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
		"p_family_id": FAMILY_ID,
		"p_player_id": load_or_create_player_id(),
		"p_mission_date": mission_date,
	})

static func parse_submit_name(body: PackedByteArray) -> String:
	var submit_result := parse_submit_result(body)
	return sanitize_name(str(submit_result.get("name", "")))

static func parse_submit_result(body: PackedByteArray) -> Dictionary:
	var parsed = _parse_json_dictionary(body)
	if not parsed.is_empty():
		return {
			"name": sanitize_name(str(parsed.get("name", ""))),
			"best_score": int(parsed.get("best_score", parsed.get("score", 0))),
			"score_improved": bool(parsed.get("score_improved", true)),
			"run_summary": parsed.get("run_summary", {}),
			"equipped_skin_id": str(parsed.get("equipped_skin_id", "")),
			"equipped_vehicle_id": str(parsed.get("equipped_vehicle_id", parsed.get("equipped_skin_id", ""))),
			"equipped_vehicle_skin_id": str(parsed.get("equipped_vehicle_skin_id", "factory")),
		}
	return {}

static func parse_profile_sync_result(body: PackedByteArray) -> Dictionary:
	var parsed := _parse_json_dictionary(body)
	var nested_summary = parsed.get("profile_summary", {})
	if nested_summary is Dictionary:
		for key in nested_summary.keys():
			var resolved_key := str(key)
			if not parsed.has(resolved_key):
				parsed[resolved_key] = nested_summary[key]
	return parsed

static func parse_daily_mission_sync_result(body: PackedByteArray) -> Dictionary:
	return _parse_json_dictionary(body)

static func parse_api_error(body: PackedByteArray, fallback: String = "Request failed.") -> String:
	var text := body.get_string_from_utf8().strip_edges()
	if text.is_empty():
		return fallback

	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		var message := str(parsed.get("message", "")).strip_edges()
		if not message.is_empty():
			return message

		var details := str(parsed.get("details", "")).strip_edges()
		if not details.is_empty():
			return details

		var error_description := str(parsed.get("error_description", "")).strip_edges()
		if not error_description.is_empty():
			return error_description

		var error_text := str(parsed.get("error", "")).strip_edges()
		if not error_text.is_empty():
			return error_text

	return text

static func is_upgrade_required_response(response_code: int, body: PackedByteArray) -> bool:
	if response_code != 426:
		return false
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed is Dictionary and str(parsed.get("error", "")).strip_edges() == "upgrade_required"

static func handle_upgrade_required(operation: String, body: PackedByteArray = PackedByteArray(), extra_context: Dictionary = {}) -> void:
	var message := parse_api_error(body, "This build is too old. Please update to continue.")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var app_update_manager := tree.root.get_node_or_null("AppUpdateManager")
		if app_update_manager != null:
			if app_update_manager.has_method("request_open_prompt"):
				app_update_manager.request_open_prompt()
			if app_update_manager.has_method("refresh_release_info"):
				app_update_manager.refresh_release_info(true)
		var reporter := tree.root.get_node_or_null("ErrorReporter")
		if reporter != null and reporter.has_method("report_warning"):
			var context := {
				"operation": operation,
				"response_code": 426,
			}
			for key in extra_context.keys():
				context[str(key)] = extra_context[key]
			reporter.report_warning("upgrade_required", message, context)

static func should_fallback_to_legacy_submit(error_text: String) -> bool:
	var normalized := error_text.to_lower()
	return normalized.contains("submit_family_score") and (
		normalized.contains("could not find the function")
		or normalized.contains("schema cache")
		or normalized.contains("function")
	)

static func should_disable_rpc(error_text: String, rpc_name: String) -> bool:
	var normalized := error_text.to_lower()
	return normalized.contains(rpc_name.to_lower()) and (
		normalized.contains("could not find the function")
		or normalized.contains("schema cache")
		or normalized.contains("function")
	)

static func should_fallback_to_legacy_fetch(error_text: String) -> bool:
	var normalized := error_text.to_lower()
	if not normalized.contains("family_leaderboard"):
		return false
	if normalized.contains("equipped_skin_id") or normalized.contains("equipped_vehicle_id") or normalized.contains("equipped_vehicle_skin_id") or normalized.contains("skill_score") or normalized.contains("near_misses") or normalized.contains("max_combo_multiplier") or normalized.contains("projectile_intercepts"):
		return true
	return normalized.contains("column") and normalized.contains("does not exist")

static func format_notifications(notifications: Array[Dictionary], limit: int = 2) -> String:
	if notifications.is_empty():
		return ""

	var lines: Array[String] = []
	for i in range(min(limit, notifications.size())):
		var entry := notifications[i]
		lines.append("%s beat your %d with %d" % [
			entry["challenger_name"],
			entry["beaten_score"],
			entry["challenger_score"],
		])

	return "\n".join(lines)

static func get_best_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var best_by_player: Dictionary = {}
	for entry in entries:
		var player_id := str(entry.get("player_id", ""))
		var key := player_id
		if key.is_empty():
			key = "%s:%d" % [entry.get("name", "Player"), int(entry.get("score", 0))]

		if not best_by_player.has(key):
			best_by_player[key] = entry
			continue

		var existing: Dictionary = best_by_player[key]
		if int(entry.get("score", 0)) > int(existing.get("score", 0)):
			best_by_player[key] = entry
			continue

		if int(entry.get("score", 0)) == int(existing.get("score", 0)) and _entry_sort_timestamp(entry) < _entry_sort_timestamp(existing):
			best_by_player[key] = entry

	var best_entries: Array[Dictionary] = []
	for value in best_by_player.values():
		best_entries.append(value)

	best_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return _entry_sort_timestamp(a) < _entry_sort_timestamp(b)
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	return best_entries

static func _entry_sort_timestamp(entry: Dictionary) -> String:
	var updated_at := str(entry.get("updated_at", "")).strip_edges()
	if not updated_at.is_empty():
		return updated_at
	return str(entry.get("created_at", ""))

static func _parse_json_dictionary(body: PackedByteArray) -> Dictionary:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	if parsed is Array and not parsed.is_empty():
		var first_entry = parsed[0]
		if first_entry is Dictionary:
			return first_entry
	return {}

static func _remove_invalid_name_characters(name: String) -> String:
	var cleaned := ""
	for i in range(name.length()):
		var character := name.substr(i, 1)
		var code := character.unicode_at(0)
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_number := code >= 48 and code <= 57
		if is_upper or is_lower or is_number or character == " " or character == "_" or character == "-":
			cleaned += character
	return cleaned.strip_edges()

static func _normalize_for_filter(name: String) -> String:
	var normalized := ""
	for i in range(name.length()):
		var character := name.substr(i, 1).to_lower()
		var code := character.unicode_at(0)
		var is_lower := code >= 97 and code <= 122
		var is_number := code >= 48 and code <= 57
		if is_lower or is_number:
			normalized += character
	return normalized

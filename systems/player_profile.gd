extends Node

signal profile_changed(summary: Dictionary)

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const PROFILE_PATH := "user://player_profile.cfg"
const PROFILE_SECTION := "player_profile"
const DEFAULT_SKIN_ID := "default_scout"
const LEADERBOARD_BONUS_SKIN_ID := "pottercar"

var validation_mode_enabled: bool = false
var _unlocked_skins: Array[String] = [DEFAULT_SKIN_ID]
var _equipped_skin_id: String = DEFAULT_SKIN_ID
var _total_daily_missions_completed: int = 0
var _daily_streak: int = 0
var _last_completed_daily_date: String = ""
var _missions_intro_seen: bool = false
var _daily_reminders_enabled: bool = true
var _leaderboard_bonus_skin_access: bool = false
var _top_skin_request: HTTPRequest
var _top_skin_request_in_flight: bool = false

func _ready() -> void:
	_ensure_top_skin_request()
	load_profile()
	if not validation_mode_enabled and OnlineLeaderboardScript.is_configured():
		call_deferred("refresh_top_player_skin_access")

func load_profile() -> void:
	var config := ConfigFile.new()
	var error := config.load(PROFILE_PATH)
	if error != OK:
		_apply_defaults()
		save_profile()
		return

	_unlocked_skins = _sanitize_skin_ids(config.get_value(PROFILE_SECTION, "unlocked_skins", [DEFAULT_SKIN_ID]))
	_equipped_skin_id = str(config.get_value(PROFILE_SECTION, "equipped_skin_id", DEFAULT_SKIN_ID))
	_total_daily_missions_completed = maxi(int(config.get_value(PROFILE_SECTION, "total_daily_missions_completed", 0)), 0)
	_daily_streak = maxi(int(config.get_value(PROFILE_SECTION, "daily_streak", 0)), 0)
	_last_completed_daily_date = str(config.get_value(PROFILE_SECTION, "last_completed_daily_date", ""))
	_missions_intro_seen = bool(config.get_value(PROFILE_SECTION, "missions_intro_seen", false))
	_daily_reminders_enabled = bool(config.get_value(PROFILE_SECTION, "daily_reminders_enabled", true))
	_leaderboard_bonus_skin_access = bool(config.get_value(PROFILE_SECTION, "leaderboard_bonus_skin_access", false))
	_validate_profile_state()
	_emit_profile_changed()

func save_profile() -> void:
	if validation_mode_enabled:
		return
	var config := ConfigFile.new()
	config.set_value(PROFILE_SECTION, "unlocked_skins", _unlocked_skins.duplicate())
	config.set_value(PROFILE_SECTION, "equipped_skin_id", _equipped_skin_id)
	config.set_value(PROFILE_SECTION, "total_daily_missions_completed", _total_daily_missions_completed)
	config.set_value(PROFILE_SECTION, "daily_streak", _daily_streak)
	config.set_value(PROFILE_SECTION, "last_completed_daily_date", _last_completed_daily_date)
	config.set_value(PROFILE_SECTION, "missions_intro_seen", _missions_intro_seen)
	config.set_value(PROFILE_SECTION, "daily_reminders_enabled", _daily_reminders_enabled)
	config.set_value(PROFILE_SECTION, "leaderboard_bonus_skin_access", _leaderboard_bonus_skin_access)
	config.save(PROFILE_PATH)

func is_skin_unlocked(skin_id: String) -> bool:
	return has_skin_access(skin_id)

func has_skin_access(skin_id: String) -> bool:
	var resolved_skin_id := _resolve_skin_id(skin_id)
	if resolved_skin_id.is_empty():
		return false
	if _is_dynamic_skin_id(resolved_skin_id):
		return _leaderboard_bonus_skin_access if resolved_skin_id == LEADERBOARD_BONUS_SKIN_ID else false
	return _unlocked_skins.has(resolved_skin_id)

func unlock_skin(skin_id: String) -> bool:
	var resolved_skin_id := _resolve_skin_id(skin_id)
	if resolved_skin_id.is_empty() or _is_dynamic_skin_id(resolved_skin_id) or _unlocked_skins.has(resolved_skin_id):
		return false

	_unlocked_skins.append(resolved_skin_id)
	_sort_unlocked_skins()
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()
	return true

func get_unlocked_skins() -> Array[String]:
	return _unlocked_skins.duplicate()

func get_equipped_skin_id() -> String:
	if has_skin_access(_equipped_skin_id):
		return _equipped_skin_id
	return DEFAULT_SKIN_ID

func equip_skin(skin_id: String) -> bool:
	var resolved_skin_id := _resolve_skin_id(skin_id)
	if resolved_skin_id.is_empty() or not has_skin_access(resolved_skin_id):
		return false
	if _equipped_skin_id == resolved_skin_id:
		return false

	_equipped_skin_id = resolved_skin_id
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()
	return true

func get_total_daily_missions_completed() -> int:
	return _total_daily_missions_completed

func increment_total_daily_missions_completed(amount: int = 1) -> void:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return
	_total_daily_missions_completed += safe_amount
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()

func get_daily_streak() -> int:
	return _daily_streak

func update_daily_streak(completed_date_key: String) -> void:
	var normalized_date := completed_date_key.strip_edges()
	if normalized_date.is_empty():
		return

	if _last_completed_daily_date == normalized_date:
		return

	if _last_completed_daily_date.is_empty():
		_daily_streak = 1
	else:
		var previous_unix := Time.get_unix_time_from_datetime_string("%sT00:00:00Z" % _last_completed_daily_date)
		var current_unix := Time.get_unix_time_from_datetime_string("%sT00:00:00Z" % normalized_date)
		var day_difference := int(round((current_unix - previous_unix) / 86400.0))
		if day_difference == 1:
			_daily_streak += 1
		else:
			_daily_streak = 1

	_last_completed_daily_date = normalized_date
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()

func are_daily_reminders_enabled() -> bool:
	return _daily_reminders_enabled

func set_daily_reminders_enabled(enabled: bool) -> void:
	if _daily_reminders_enabled == enabled:
		return
	_daily_reminders_enabled = enabled
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()

func has_seen_missions_intro() -> bool:
	return _missions_intro_seen

func mark_missions_intro_seen() -> void:
	if _missions_intro_seen:
		return
	_missions_intro_seen = true
	save_profile()
	_queue_profile_sync()
	_emit_profile_changed()

func refresh_top_player_skin_access() -> void:
	if validation_mode_enabled or not OnlineLeaderboardScript.is_configured() or _top_skin_request_in_flight:
		return
	_ensure_top_skin_request()
	if _top_skin_request == null:
		return
	var request_error := _top_skin_request.request(
		OnlineLeaderboardScript.get_top_entry_url(),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_GET
	)
	if request_error == OK:
		_top_skin_request_in_flight = true

func apply_leaderboard_entries(entries: Array) -> bool:
	var typed_entries: Array[Dictionary] = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			typed_entries.append(entry_variant)
	var best_entries := OnlineLeaderboardScript.get_best_entries(typed_entries)
	var local_player_id := OnlineLeaderboardScript.load_or_create_player_id()
	var is_top_player := false
	if not best_entries.is_empty():
		is_top_player = str(best_entries[0].get("player_id", "")) == local_player_id
	return apply_leaderboard_top_status(is_top_player)

func apply_leaderboard_top_status(is_top_player: bool) -> bool:
	return _apply_verified_bonus_skin_access(is_top_player)

func get_profile_summary() -> Dictionary:
	return {
		"equipped_skin_id": get_equipped_skin_id(),
		"unlocked_skins": get_unlocked_skins(),
		"total_daily_missions_completed": _total_daily_missions_completed,
		"daily_streak": _daily_streak,
		"last_completed_daily_date": _last_completed_daily_date,
		"daily_reminders_enabled": _daily_reminders_enabled,
		"missions_intro_seen": _missions_intro_seen,
	}

func merge_remote_profile(summary: Dictionary) -> bool:
	var merged_unlocked := _unlocked_skins.duplicate()
	for skin_id_variant in summary.get("unlocked_skins", []):
		var resolved_skin_id := _resolve_skin_id(str(skin_id_variant))
		if resolved_skin_id.is_empty() or _is_dynamic_skin_id(resolved_skin_id):
			continue
		if not merged_unlocked.has(resolved_skin_id):
			merged_unlocked.append(resolved_skin_id)

	var remote_equipped_skin_id := _resolve_skin_id(str(summary.get("equipped_skin_id", "")))
	var merged_equipped_skin_id := _equipped_skin_id
	if not _is_skin_accessible_with_unlocks(merged_equipped_skin_id, merged_unlocked):
		if _is_skin_accessible_with_unlocks(remote_equipped_skin_id, merged_unlocked):
			merged_equipped_skin_id = remote_equipped_skin_id
		else:
			merged_equipped_skin_id = DEFAULT_SKIN_ID

	var merged_total := maxi(_total_daily_missions_completed, int(summary.get("total_daily_missions_completed", _total_daily_missions_completed)))
	var merged_streak := maxi(_daily_streak, int(summary.get("daily_streak", _daily_streak)))
	var merged_date := _pick_later_date(_last_completed_daily_date, str(summary.get("last_completed_daily_date", "")))
	var merged_intro_seen := _missions_intro_seen or bool(summary.get("missions_intro_seen", false))

	_sort_skin_ids(merged_unlocked)

	var changed := merged_unlocked != _unlocked_skins \
		or merged_equipped_skin_id != _equipped_skin_id \
		or merged_total != _total_daily_missions_completed \
		or merged_streak != _daily_streak \
		or merged_date != _last_completed_daily_date \
		or merged_intro_seen != _missions_intro_seen

	if not changed:
		return false

	_unlocked_skins = merged_unlocked
	_equipped_skin_id = merged_equipped_skin_id
	_total_daily_missions_completed = merged_total
	_daily_streak = merged_streak
	_last_completed_daily_date = merged_date
	_missions_intro_seen = merged_intro_seen
	_validate_profile_state()
	save_profile()
	_emit_profile_changed()
	return true

func apply_validation_state(summary: Dictionary) -> void:
	validation_mode_enabled = true
	_unlocked_skins = _sanitize_skin_ids(summary.get("unlocked_skins", [DEFAULT_SKIN_ID]))
	_equipped_skin_id = str(summary.get("equipped_skin_id", DEFAULT_SKIN_ID))
	_total_daily_missions_completed = maxi(int(summary.get("total_daily_missions_completed", 0)), 0)
	_daily_streak = maxi(int(summary.get("daily_streak", 0)), 0)
	_last_completed_daily_date = str(summary.get("last_completed_daily_date", ""))
	_missions_intro_seen = bool(summary.get("missions_intro_seen", false))
	_daily_reminders_enabled = bool(summary.get("daily_reminders_enabled", true))
	_leaderboard_bonus_skin_access = bool(summary.get("leaderboard_bonus_skin_access", summary.get("pottercar_access", false)))
	_validate_profile_state()
	_emit_profile_changed()

func _apply_defaults() -> void:
	_unlocked_skins = [DEFAULT_SKIN_ID]
	_equipped_skin_id = DEFAULT_SKIN_ID
	_total_daily_missions_completed = 0
	_daily_streak = 0
	_last_completed_daily_date = ""
	_missions_intro_seen = false
	_daily_reminders_enabled = true
	_leaderboard_bonus_skin_access = false
	_validate_profile_state()

func _sanitize_skin_ids(raw_value) -> Array[String]:
	var sanitized: Array[String] = [DEFAULT_SKIN_ID]
	if raw_value is Array:
		for skin_id_variant in raw_value:
			var resolved_skin_id := _resolve_skin_id(str(skin_id_variant))
			if resolved_skin_id.is_empty() or _is_dynamic_skin_id(resolved_skin_id) or sanitized.has(resolved_skin_id):
				continue
			sanitized.append(resolved_skin_id)
	_sort_skin_ids(sanitized)
	return sanitized

func _validate_profile_state() -> void:
	_unlocked_skins = _sanitize_skin_ids(_unlocked_skins)
	if not has_skin_access(_equipped_skin_id):
		_equipped_skin_id = DEFAULT_SKIN_ID

func _resolve_skin_id(skin_id: String) -> String:
	if skin_id.strip_edges().is_empty():
		return ""
	var helicopter_skins := get_node_or_null("/root/HelicopterSkins")
	if helicopter_skins != null and helicopter_skins.has_method("has_skin"):
		return skin_id if helicopter_skins.has_skin(skin_id) else ""
	return DEFAULT_SKIN_ID if skin_id == DEFAULT_SKIN_ID else skin_id

func _pick_later_date(a: String, b: String) -> String:
	var clean_a := a.strip_edges()
	var clean_b := b.strip_edges()
	if clean_a.is_empty():
		return clean_b
	if clean_b.is_empty():
		return clean_a
	return clean_b if clean_b > clean_a else clean_a

func _sort_unlocked_skins() -> void:
	_sort_skin_ids(_unlocked_skins)

func _ensure_top_skin_request() -> void:
	if _top_skin_request != null:
		return
	_top_skin_request = HTTPRequest.new()
	add_child(_top_skin_request)
	_top_skin_request.request_completed.connect(_on_top_skin_request_completed)

func _on_top_skin_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_top_skin_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	apply_leaderboard_entries(OnlineLeaderboardScript.parse_entries(body))

func _apply_verified_bonus_skin_access(is_top_player: bool) -> bool:
	var previous_access := _leaderboard_bonus_skin_access
	var previous_equipped_skin_id := _equipped_skin_id
	_leaderboard_bonus_skin_access = is_top_player
	_validate_profile_state()

	var access_changed := previous_access != _leaderboard_bonus_skin_access
	var equipped_skin_changed := previous_equipped_skin_id != _equipped_skin_id
	if not access_changed and not equipped_skin_changed:
		return false

	save_profile()
	if equipped_skin_changed:
		_queue_profile_sync()
	_emit_profile_changed()
	return true

func _is_dynamic_skin_id(skin_id: String) -> bool:
	var helicopter_skins := get_node_or_null("/root/HelicopterSkins")
	if helicopter_skins != null and helicopter_skins.has_method("is_dynamic_skin"):
		return bool(helicopter_skins.is_dynamic_skin(skin_id))
	return skin_id == LEADERBOARD_BONUS_SKIN_ID

func _is_skin_accessible_with_unlocks(skin_id: String, unlocked_skins: Array[String]) -> bool:
	if skin_id.is_empty():
		return false
	if _is_dynamic_skin_id(skin_id):
		return _leaderboard_bonus_skin_access if skin_id == LEADERBOARD_BONUS_SKIN_ID else false
	return unlocked_skins.has(skin_id)

func _sort_skin_ids(ids: Array[String]) -> void:
	var helicopter_skins := get_node_or_null("/root/HelicopterSkins")
	if helicopter_skins == null or not helicopter_skins.has_method("get_skin_ids"):
		return

	var ordered_ids: Array[String] = helicopter_skins.get_skin_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ordered_ids.find(a) < ordered_ids.find(b)
	)

func _queue_profile_sync() -> void:
	if validation_mode_enabled:
		return
	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("enqueue_sync_player_profile"):
		sync_queue.enqueue_sync_player_profile(get_profile_summary())
		if sync_queue.has_method("flush"):
			sync_queue.flush()

func _emit_profile_changed() -> void:
	profile_changed.emit(get_profile_summary())

class_name OnlineLeaderboard
extends RefCounted

# Fill these in after creating your Supabase project.
const SUPABASE_URL := "https://lxvniafwjlwatbiblwyi.supabase.co"
const SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4dm5pYWZ3amx3YXRiaWJsd3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyMTQ1MjMsImV4cCI6MjA5MTc5MDUyM30.FzM4zxKx3yVyxvM1hbRFdAcNxrW3x9t6zerDEsDK42w"
const TABLE_NAME := "family_leaderboard"
const NOTIFICATION_TABLE_NAME := "family_notifications"
const FAMILY_ID := "global"
const NAME_CACHE_PATH := "user://player_name.save"
const PLAYER_ID_CACHE_PATH := "user://player_id.save"
const MAX_NAME_LENGTH := 12
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

static func get_fetch_url(limit: int = 10) -> String:
	var encoded_family := FAMILY_ID.uri_encode()
	return "%s/rest/v1/%s?select=player_id,name,score,created_at&family_id=eq.%s&order=score.desc,created_at.asc&limit=%d" % [
		SUPABASE_URL,
		TABLE_NAME,
		encoded_family,
		limit,
	]

static func get_submit_url() -> String:
	return "%s/rest/v1/%s" % [SUPABASE_URL, TABLE_NAME]

static func get_notifications_url(limit: int = 10) -> String:
	var encoded_family := FAMILY_ID.uri_encode()
	var encoded_player := load_or_create_player_id().uri_encode()
	return "%s/rest/v1/%s?select=id,challenger_name,challenger_score,beaten_score,created_at&family_id=eq.%s&target_player_id=eq.%s&read_at=is.null&order=created_at.desc&limit=%d" % [
		SUPABASE_URL,
		NOTIFICATION_TABLE_NAME,
		encoded_family,
		encoded_player,
		limit,
	]

static func get_mark_notifications_read_url(ids: Array[int]) -> String:
	var id_parts: Array[String] = []
	for id in ids:
		id_parts.append(str(id))
	return "%s/rest/v1/%s?id=in.(%s)" % [SUPABASE_URL, NOTIFICATION_TABLE_NAME, ",".join(id_parts)]

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

static func load_cached_name() -> String:
	if not FileAccess.file_exists(NAME_CACHE_PATH):
		return ""

	var file := FileAccess.open(NAME_CACHE_PATH, FileAccess.READ)
	if file == null:
		return ""

	return sanitize_name(file.get_as_text())

static func has_saved_profile() -> bool:
	return not load_cached_name().is_empty()

static func load_or_create_player_id() -> String:
	if FileAccess.file_exists(PLAYER_ID_CACHE_PATH):
		var existing_file := FileAccess.open(PLAYER_ID_CACHE_PATH, FileAccess.READ)
		if existing_file != null:
			var existing_id := existing_file.get_as_text().strip_edges()
			if not existing_id.is_empty():
				return existing_id

	var new_id := _generate_player_id()
	var file := FileAccess.open(PLAYER_ID_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(new_id)
	return new_id

static func make_mark_notifications_read_body() -> String:
	return JSON.stringify({
		"read_at": Time.get_datetime_string_from_system(true),
	})

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

		if int(entry.get("score", 0)) == int(existing.get("score", 0)) and str(entry.get("created_at", "")) < str(existing.get("created_at", "")):
			best_by_player[key] = entry

	var best_entries: Array[Dictionary] = []
	for value in best_by_player.values():
		best_entries.append(value)

	best_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return str(a.get("created_at", "")) < str(b.get("created_at", ""))
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	return best_entries

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

static func _generate_player_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var parts := [
		"%08x" % int(Time.get_unix_time_from_system()),
		"%08x" % rng.randi(),
	]
	return "-".join(parts)

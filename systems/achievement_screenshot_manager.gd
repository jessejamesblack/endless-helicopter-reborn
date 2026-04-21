extends Node

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const BuildInfoScript = preload("res://systems/build_info.gd")
const SHARE_CARD_SCENE := preload("res://scenes/ui/share/achievement_share_card.tscn")
const STATE_PATH := "user://achievement_screenshot_state.cfg"
const STATE_SECTION := "achievement_screenshots"
const MAX_QUEUE_SIZE := 10
const COOLDOWN_SECONDS := 60
const MAX_UPLOAD_BYTES := 5 * 1024 * 1024
const JPEG_QUALITY := 0.85
const CAPTURE_MODE_SHARE_CARD := "share_card"
const CAPTURE_MODE_RESULTS_SCREEN := "results_screen"

var _queue: Array[Dictionary] = []
var _posted_one_time_ids: Array[String] = []
var _last_posted_unix: int = -999999
var _is_processing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_load_state()
	call_deferred("_process_queue")

func _process(_delta: float) -> void:
	if not _queue.is_empty() and not _is_processing:
		_process_queue()

func queue_event(event_id: String, title: String, description: String, details: Dictionary = {}, one_time: bool = false, capture_mode: String = CAPTURE_MODE_SHARE_CARD) -> void:
	if event_id.strip_edges().is_empty() or title.strip_edges().is_empty():
		return
	if one_time and _posted_one_time_ids.has(event_id):
		return
	_queue.append({
		"event_id": event_id,
		"title": title,
		"description": description,
		"details": details.duplicate(true),
		"one_time": one_time,
		"capture_mode": _normalize_capture_mode(capture_mode),
		"queued_at": Time.get_datetime_string_from_system(true),
	})
	while _queue.size() > MAX_QUEUE_SIZE:
		_queue.remove_at(0)
	_save_state()
	call_deferred("_process_queue")

func _process_queue() -> void:
	if _is_processing or _queue.is_empty():
		return
	var settings: Node = _get_game_settings()
	if settings == null or not settings.has_method("is_achievement_screenshot_sharing_enabled") or not settings.is_achievement_screenshot_sharing_enabled():
		return
	if int(Time.get_unix_time_from_system()) - _last_posted_unix < COOLDOWN_SECONDS:
		return
	if not OnlineLeaderboardScript.is_configured():
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var item: Dictionary = _queue[0]
	var capture_mode := _normalize_capture_mode(str(item.get("capture_mode", CAPTURE_MODE_SHARE_CARD)))
	if not _is_capture_target_ready(capture_mode, current_scene):
		return
	_is_processing = true
	await get_tree().process_frame
	current_scene = get_tree().current_scene
	if not _is_capture_target_ready(capture_mode, current_scene):
		_is_processing = false
		return
	var card: Control = null
	if capture_mode == CAPTURE_MODE_SHARE_CARD:
		card = SHARE_CARD_SCENE.instantiate()
		current_scene.add_child(card)
		if card.has_method("configure"):
			card.configure(item)
		await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if is_instance_valid(card):
		card.queue_free()
	var jpeg_bytes: PackedByteArray = _encode_jpeg_bytes(image)
	if jpeg_bytes.is_empty():
		_is_processing = false
		return
	var request := HTTPRequest.new()
	add_child(request)
	var player_name := OnlineLeaderboardScript.load_cached_name()
	var error := request.request(
		OnlineLeaderboardScript.get_edge_function_url("post-achievement-screenshot"),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"current_version_code": int(BuildInfoScript.VERSION_CODE),
			"release_channel": str(BuildInfoScript.RELEASE_CHANNEL),
			"event_id": str(item.get("event_id", "")),
			"title": str(item.get("title", "")),
			"description": str(item.get("description", "")),
			"player_name": player_name,
			"details": item.get("details", {}),
			"build": BuildInfoScript.get_summary(),
			"image_base64": Marshalls.raw_to_base64(jpeg_bytes),
		})
	)
	if error != OK:
		request.queue_free()
		_is_processing = false
		return
	var completed = await request.request_completed
	request.queue_free()
	var result := int(completed[0])
	var response_code := int(completed[1])
	var body := completed[3] as PackedByteArray
	if OnlineLeaderboardScript.is_upgrade_required_response(response_code, body):
		OnlineLeaderboardScript.handle_upgrade_required("post_achievement_screenshot", body, {
			"queue_size": _queue.size(),
			"event_id": str(item.get("event_id", "")),
		})
		_queue.clear()
		_save_state()
		_is_processing = false
		return
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_last_posted_unix = int(Time.get_unix_time_from_system())
		if bool(item.get("one_time", false)) and not _posted_one_time_ids.has(str(item.get("event_id", ""))):
			_posted_one_time_ids.append(str(item.get("event_id", "")))
		_queue.remove_at(0)
		_save_state()
	_is_processing = false
	if not _queue.is_empty():
		call_deferred("_process_queue")

func _normalize_capture_mode(capture_mode: String) -> String:
	var clean_mode := capture_mode.strip_edges().to_lower()
	return clean_mode if clean_mode == CAPTURE_MODE_RESULTS_SCREEN else CAPTURE_MODE_SHARE_CARD

func _is_capture_target_ready(capture_mode: String, current_scene: Node) -> bool:
	if current_scene == null:
		return false
	if capture_mode != CAPTURE_MODE_RESULTS_SCREEN:
		return true
	return current_scene.has_method("is_ready_for_achievement_screenshot") and bool(current_scene.is_ready_for_achievement_screenshot())

func _encode_jpeg_bytes(image: Image) -> PackedByteArray:
	if image == null or image.is_empty():
		return PackedByteArray()
	var scaled: Image = image.duplicate()
	var max_width := 1280
	var max_height := 720
	if scaled.get_width() > max_width or scaled.get_height() > max_height:
		var scale_factor := minf(float(max_width) / float(scaled.get_width()), float(max_height) / float(scaled.get_height()))
		scaled.resize(maxi(int(round(scaled.get_width() * scale_factor)), 1), maxi(int(round(scaled.get_height() * scale_factor)), 1), Image.INTERPOLATE_LANCZOS)
	var jpeg_bytes: PackedByteArray = scaled.save_jpg_to_buffer(JPEG_QUALITY)
	while jpeg_bytes.size() > MAX_UPLOAD_BYTES and scaled.get_width() > 320 and scaled.get_height() > 180:
		scaled.resize(maxi(int(round(scaled.get_width() * 0.85)), 1), maxi(int(round(scaled.get_height() * 0.85)), 1), Image.INTERPOLATE_LANCZOS)
		jpeg_bytes = scaled.save_jpg_to_buffer(JPEG_QUALITY)
	return jpeg_bytes

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return
	var queue_value: Variant = config.get_value(STATE_SECTION, "queue", [])
	var posted_value: Variant = config.get_value(STATE_SECTION, "posted_one_time_ids", [])
	_queue = []
	if queue_value is Array:
		for item in queue_value:
			if item is Dictionary:
				_queue.append((item as Dictionary).duplicate(true))
	_posted_one_time_ids = []
	if posted_value is Array:
		for item in posted_value:
			_posted_one_time_ids.append(str(item))
	_last_posted_unix = int(config.get_value(STATE_SECTION, "last_posted_unix", -999999))

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value(STATE_SECTION, "queue", _queue.duplicate(true))
	config.set_value(STATE_SECTION, "posted_one_time_ids", _posted_one_time_ids.duplicate())
	config.set_value(STATE_SECTION, "last_posted_unix", _last_posted_unix)
	config.save(STATE_PATH)

func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")

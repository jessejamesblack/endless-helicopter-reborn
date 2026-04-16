extends Control

const OnlineLeaderboard = preload("res://systems/online_leaderboard.gd")
const LEADERBOARD_PAGE_SIZE := 25
const LEADERBOARD_SCROLL_TRIGGER_PX := 96.0

var current_score: int = 0
var has_submitted: bool = false
var has_pending_score: bool = false
var needs_profile_setup: bool = false
var pending_player_name: String = ""
var is_submitting: bool = false
var push_notifications: Node = null
var leaderboard_entries: Array[Dictionary] = []
var leaderboard_offset: int = 0
var leaderboard_has_more: bool = true
var leaderboard_fetch_in_flight: bool = false

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var setup_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/SetupCard
@onready var name_help_label: Label = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameHelpLabel
@onready var name_entry: LineEdit = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameEntry
@onready var save_button: Button = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/SaveButton
@onready var refresh_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/RefreshButton
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/BackButton
@onready var alert_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/AlertCard
@onready var alert_label: Label = $Panel/MarginContainer/VBoxContainer/AlertCard/AlertLabel
@onready var leaderboard_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/LeaderboardCard/LeaderboardScroll
@onready var leaderboard_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/LeaderboardCard/LeaderboardScroll/LeaderboardList

func _ready() -> void:
	has_pending_score = get_tree().has_meta("last_run_score")
	current_score = int(get_tree().get_meta("last_run_score", 0))
	if has_pending_score:
		get_tree().remove_meta("last_run_score")

	title_label.text = _get_board_title()
	if has_pending_score:
		score_label.text = "Score: %d" % current_score
	else:
		score_label.text = "Top Scores"

	name_entry.text = OnlineLeaderboard.load_cached_name()
	needs_profile_setup = has_pending_score and not OnlineLeaderboard.has_saved_profile()
	name_help_label.text = "Choose a public name once. This device will remember it."
	alert_label.text = ""
	_apply_screen_mode()
	_connect_leaderboard_scroll()

	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	name_entry.text_submitted.connect(_on_name_submitted)
	$FetchRequest.request_completed.connect(_on_fetch_request_completed)
	$SubmitRequest.request_completed.connect(_on_submit_request_completed)
	$NotificationRequest.request_completed.connect(_on_notification_request_completed)
	$MarkNotificationsReadRequest.request_completed.connect(_on_mark_notifications_read_completed)

	push_notifications = get_node_or_null("/root/PushNotifications")
	if push_notifications != null and push_notifications.has_signal("push_notification_opened"):
		var push_callback := Callable(self, "_on_push_notification_opened")
		if not push_notifications.is_connected("push_notification_opened", push_callback):
			push_notifications.connect("push_notification_opened", push_callback)

	if OnlineLeaderboard.is_configured():
		set_status("Loading leaderboard...")
		fetch_leaderboard(true)
		fetch_notifications()
		if has_pending_score and not needs_profile_setup:
			submit_score()
	else:
		set_status("Leaderboard is not configured yet.")
		_render_leaderboard_rows([], "Waiting for online setup")
		save_button.disabled = true
		refresh_button.disabled = true

func set_status(message: String) -> void:
	status_label.text = message

func _apply_screen_mode() -> void:
	setup_card.visible = needs_profile_setup
	alert_card.visible = not alert_label.text.is_empty()

func _get_board_title() -> String:
	if OnlineLeaderboard.FAMILY_ID == "global":
		return "Global Leaderboard"
	return "Family Leaderboard"

func fetch_leaderboard(reset: bool = false) -> void:
	if leaderboard_fetch_in_flight:
		return

	if reset:
		leaderboard_entries.clear()
		leaderboard_offset = 0
		leaderboard_has_more = true
		leaderboard_scroll.scroll_vertical = 0

	if not leaderboard_has_more:
		return

	leaderboard_fetch_in_flight = true
	var footer_message := "Loading leaderboard..."
	if not leaderboard_entries.is_empty():
		footer_message = "Loading more scores..."
	_render_leaderboard_rows(OnlineLeaderboard.get_best_entries(leaderboard_entries), footer_message)

	$FetchRequest.request(
		OnlineLeaderboard.get_fetch_url(LEADERBOARD_PAGE_SIZE, leaderboard_offset),
		OnlineLeaderboard.get_headers(),
		HTTPClient.METHOD_GET
	)

func fetch_notifications() -> void:
	$NotificationRequest.request(
		OnlineLeaderboard.get_notifications_url(5),
		OnlineLeaderboard.get_headers(),
		HTTPClient.METHOD_GET
	)

func submit_score() -> void:
	if not has_pending_score:
		set_status("Open this screen after a run to save a score.")
		return

	if has_submitted:
		set_status("Score already saved.")
		return

	var validation := OnlineLeaderboard.validate_player_name(name_entry.text)
	if not bool(validation.get("ok", false)):
		set_status(str(validation.get("error", "Choose a different player name.")))
		return

	var player_name := str(validation.get("name", "Player"))
	name_entry.text = player_name
	pending_player_name = player_name
	is_submitting = true
	set_status("Saving your score...")
	save_button.disabled = true
	$SubmitRequest.request(
		OnlineLeaderboard.get_submit_url(),
		OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=representation"]),
		HTTPClient.METHOD_POST,
		OnlineLeaderboard.make_submit_body(player_name, current_score)
	)

func _on_save_pressed() -> void:
	submit_score()

func _on_name_submitted(_text: String) -> void:
	submit_score()

func _on_refresh_pressed() -> void:
	set_status("Refreshing leaderboard...")
	fetch_leaderboard(true)
	fetch_notifications()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen/start_screen.tscn")

func _on_fetch_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	leaderboard_fetch_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if leaderboard_entries.is_empty():
			_render_leaderboard_rows([], "Could not load the leaderboard.")
		set_status("Could not load the leaderboard.")
		return

	var fetched_entries := OnlineLeaderboard.parse_entries(body)
	leaderboard_entries.append_array(fetched_entries)
	leaderboard_offset += fetched_entries.size()
	leaderboard_has_more = fetched_entries.size() >= LEADERBOARD_PAGE_SIZE

	_render_leaderboard_rows(OnlineLeaderboard.get_best_entries(leaderboard_entries))
	_update_status_after_fetch()
	call_deferred("_maybe_prefetch_if_needed")

func _on_submit_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_submitting = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		save_button.disabled = false
		var error_text := OnlineLeaderboard.parse_api_error(body, "Could not submit score.")
		set_status(error_text)
		return

	has_submitted = true
	var saved_name := OnlineLeaderboard.parse_submit_name(body)
	if saved_name.is_empty():
		saved_name = pending_player_name
	if not saved_name.is_empty():
		name_entry.text = saved_name
		OnlineLeaderboard.save_cached_name(saved_name)

	pending_player_name = ""
	has_pending_score = false
	needs_profile_setup = false
	_apply_screen_mode()
	save_button.disabled = true
	fetch_leaderboard(true)
	fetch_notifications()

func _on_notification_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return

	var notifications := OnlineLeaderboard.parse_notifications(body)
	alert_label.text = OnlineLeaderboard.format_notifications(notifications, 3)
	_apply_screen_mode()
	if notifications.is_empty():
		return

	var ids: Array[int] = []
	for notification in notifications:
		ids.append(int(notification.get("id", 0)))

	$MarkNotificationsReadRequest.request(
		OnlineLeaderboard.get_mark_notifications_read_url(ids),
		OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=minimal"]),
		HTTPClient.METHOD_PATCH,
		OnlineLeaderboard.make_mark_notifications_read_body()
	)

func _on_mark_notifications_read_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	pass

func _on_push_notification_opened(payload: Dictionary) -> void:
	if str(payload.get("type", "")) != "score_beaten":
		return
	set_status("Refreshing leaderboard...")
	fetch_leaderboard(true)
	fetch_notifications()

func _update_status_after_fetch() -> void:
	if needs_profile_setup:
		set_status("You crashed. Enter a name to save this run.")
	elif is_submitting:
		set_status("Saving your score...")
	elif has_submitted:
		set_status("Score submitted!")
	elif has_pending_score:
		set_status("Tap Submit Score to save this run.")
	else:
		set_status("Latest scores loaded.")

func _connect_leaderboard_scroll() -> void:
	var scroll_bar := leaderboard_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return

	var scroll_callback := Callable(self, "_on_leaderboard_scroll_changed")
	if not scroll_bar.is_connected("value_changed", scroll_callback):
		scroll_bar.value_changed.connect(scroll_callback)

func _on_leaderboard_scroll_changed(_value: float) -> void:
	_maybe_fetch_next_page()

func _maybe_fetch_next_page() -> void:
	if leaderboard_fetch_in_flight or not leaderboard_has_more:
		return

	var scroll_bar := leaderboard_scroll.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= 0.0:
		return

	if scroll_bar.max_value - scroll_bar.value <= LEADERBOARD_SCROLL_TRIGGER_PX:
		fetch_leaderboard(false)

func _maybe_prefetch_if_needed() -> void:
	if leaderboard_fetch_in_flight or not leaderboard_has_more:
		return

	var scroll_bar := leaderboard_scroll.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= 0.0:
		fetch_leaderboard(false)

func _render_leaderboard_rows(entries: Array[Dictionary], footer_message: String = "") -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()

	if entries.is_empty():
		leaderboard_list.add_child(_create_message_label(footer_message if not footer_message.is_empty() else _get_empty_board_text()))
		return

	for i in range(entries.size()):
		leaderboard_list.add_child(_create_entry_row(i + 1, entries[i]))

	if not footer_message.is_empty():
		leaderboard_list.add_child(_create_message_label(footer_message))
	elif leaderboard_has_more:
		leaderboard_list.add_child(_create_message_label("Scroll down to load more pilots..."))

func _create_entry_row(rank: int, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(44, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.theme_override_colors.font_color = Color(0.588235, 0.784314, 0.964706, 1)
	rank_label.theme_override_constants.outline_size = 2
	rank_label.theme_override_colors.font_outline_color = Color(0.0156863, 0.0313726, 0.0823529, 1)
	rank_label.theme_override_font_sizes.font_size = 20
	rank_label.text = "%d." % rank
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.theme_override_colors.font_color = Color(0.921569, 0.94902, 1, 1)
	name_label.theme_override_constants.outline_size = 2
	name_label.theme_override_colors.font_outline_color = Color(0.0156863, 0.0313726, 0.0823529, 1)
	name_label.theme_override_font_sizes.font_size = 20
	name_label.text = str(entry.get("name", "Player"))
	row.add_child(name_label)

	var score_label_row := Label.new()
	score_label_row.custom_minimum_size = Vector2(116, 0)
	score_label_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label_row.theme_override_colors.font_color = Color(0.964706, 0.843137, 0.54902, 1)
	score_label_row.theme_override_constants.outline_size = 2
	score_label_row.theme_override_colors.font_outline_color = Color(0.0156863, 0.0313726, 0.0823529, 1)
	score_label_row.theme_override_font_sizes.font_size = 20
	score_label_row.text = str(int(entry.get("score", 0)))
	row.add_child(score_label_row)

	return row

func _create_message_label(message: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_override_colors.font_color = Color(0.776471, 0.85098, 0.94902, 0.95)
	label.theme_override_constants.outline_size = 2
	label.theme_override_colors.font_outline_color = Color(0.0156863, 0.0313726, 0.0823529, 1)
	label.theme_override_font_sizes.font_size = 18
	label.text = message
	return label

func _get_empty_board_text() -> String:
	if OnlineLeaderboard.FAMILY_ID == "global":
		return "No global scores yet"
	return "No family scores yet"

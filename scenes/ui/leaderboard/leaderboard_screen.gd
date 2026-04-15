extends Control

const OnlineLeaderboard = preload("res://systems/online_leaderboard.gd")

var current_score: int = 0
var has_submitted: bool = false
var has_pending_score: bool = false
var needs_profile_setup: bool = false
var pending_player_name: String = ""
var is_submitting: bool = false

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
@onready var leaderboard_label: Label = $Panel/MarginContainer/VBoxContainer/LeaderboardCard/LeaderboardLabel

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

	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	name_entry.text_submitted.connect(_on_name_submitted)
	$FetchRequest.request_completed.connect(_on_fetch_request_completed)
	$SubmitRequest.request_completed.connect(_on_submit_request_completed)
	$NotificationRequest.request_completed.connect(_on_notification_request_completed)
	$MarkNotificationsReadRequest.request_completed.connect(_on_mark_notifications_read_completed)

	if OnlineLeaderboard.is_configured():
		set_status("Loading leaderboard...")
		fetch_leaderboard()
		fetch_notifications()
		if has_pending_score and not needs_profile_setup:
			submit_score()
	else:
		set_status("Leaderboard is not configured yet.")
		leaderboard_label.text = "Waiting for online setup"
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

func fetch_leaderboard() -> void:
	$FetchRequest.request(
		OnlineLeaderboard.get_fetch_url(10),
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
	fetch_leaderboard()
	fetch_notifications()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen/start_screen.tscn")

func _on_fetch_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		set_status("Could not load the leaderboard.")
		return

	var entries := OnlineLeaderboard.parse_entries(body)
	leaderboard_label.text = OnlineLeaderboard.format_entries(entries, 10)
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
	fetch_leaderboard()
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

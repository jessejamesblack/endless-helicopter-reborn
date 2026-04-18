extends Control

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const LEADERBOARD_PAGE_SIZE := 25
const LEADERBOARD_SCROLL_TRIGGER_PX := 96.0
const RESULTS_PANEL_RECT := Rect2(-320.0, -328.0, 640.0, 656.0)
const BOARD_PANEL_RECT := Rect2(-320.0, -310.0, 640.0, 620.0)
const SETUP_PANEL_RECT := Rect2(-280.0, -210.0, 560.0, 420.0)
const PANEL_MARGIN := 24.0

enum ScreenMode {
	RESULTS,
	LEADERBOARD,
}

var current_score: int = 0
var current_mode: int = ScreenMode.LEADERBOARD
var current_run_summary: Dictionary = {}
var has_run_context: bool = false
var has_submitted: bool = false
var has_pending_score: bool = false
var needs_profile_setup: bool = false
var pending_player_name: String = ""
var is_submitting: bool = false
var validation_mode_enabled: bool = false
var _use_legacy_submit_api: bool = false
var _validation_online_configured: bool = false
var _validation_saved_profile: bool = false
var push_notifications: Node = null
var leaderboard_entries: Array[Dictionary] = []
var leaderboard_offset: int = 0
var leaderboard_has_more: bool = true
var leaderboard_fetch_in_flight: bool = false

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var panel: Panel = $Panel
@onready var score_label: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var results_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/ResultsCard
@onready var best_score_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/BestScoreLabel
@onready var delta_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/DeltaLabel
@onready var time_survived_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/TimeValueLabel
@onready var missiles_fired_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/MissilesValueLabel
@onready var hostiles_destroyed_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/HostilesValueLabel
@onready var pickups_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/PickupsValueLabel
@onready var glowing_clears_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/GlowingClearsValueLabel
@onready var boundary_recoveries_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/StatsGrid/BoundaryRecoveriesValueLabel
@onready var try_again_button: Button = $Panel/MarginContainer/VBoxContainer/TryAgainButton
@onready var results_button_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow
@onready var leaderboard_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/LeaderboardButton
@onready var menu_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/MenuButton
@onready var setup_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/SetupCard
@onready var name_help_label: Label = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameHelpLabel
@onready var name_entry: LineEdit = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameEntry
@onready var save_button: Button = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/SaveButton
@onready var alert_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/AlertCard
@onready var alert_label: Label = $Panel/MarginContainer/VBoxContainer/AlertCard/AlertLabel
@onready var leaderboard_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/LeaderboardCard
@onready var leaderboard_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/LeaderboardCard/LeaderboardScroll
@onready var leaderboard_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/LeaderboardCard/LeaderboardScroll/LeaderboardList
@onready var button_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ButtonRow
@onready var refresh_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/RefreshButton
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/BackButton

func _ready() -> void:
	var music_player = get_node_or_null("/root/MusicPlayer")
	if music_player != null and music_player.has_method("play_menu_music"):
		music_player.play_menu_music()

	get_tree().paused = false
	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("consume_last_run_summary"):
		current_run_summary = run_stats.consume_last_run_summary()
	else:
		current_run_summary = {}
	has_run_context = not current_run_summary.is_empty()
	has_pending_score = has_run_context
	if has_run_context:
		current_score = int(current_run_summary.get("score", 0))
		current_mode = ScreenMode.RESULTS
	else:
		current_score = 0
		current_mode = ScreenMode.LEADERBOARD

	name_entry.text = OnlineLeaderboardScript.load_cached_name()
	name_help_label.text = "Choose a public name once. This device will remember it."
	alert_label.text = ""
	_populate_results_summary()
	_apply_screen_mode()
	_configure_touch_scroll()
	_connect_leaderboard_scroll()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	try_again_button.pressed.connect(_on_try_again_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
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

	if validation_mode_enabled:
		return

	if current_mode == ScreenMode.RESULTS:
		_prepare_results_mode()
	else:
		_prepare_leaderboard_mode(true)

func set_status(message: String) -> void:
	status_label.text = message

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
	_render_leaderboard_rows(OnlineLeaderboardScript.get_best_entries(leaderboard_entries), footer_message)

	$FetchRequest.request(
		OnlineLeaderboardScript.get_fetch_url(LEADERBOARD_PAGE_SIZE, leaderboard_offset),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_GET
	)

func fetch_notifications() -> void:
	$NotificationRequest.request(
		OnlineLeaderboardScript.get_notifications_url(5),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_GET
	)

func submit_score() -> void:
	if not has_pending_score:
		set_status("Open this screen after a run to save a score.")
		return

	if has_submitted:
		set_status("Score already saved.")
		return

	var validation := OnlineLeaderboardScript.validate_player_name(name_entry.text)
	if not bool(validation.get("ok", false)):
		set_status(str(validation.get("error", "Choose a different player name.")))
		return

	var player_name := str(validation.get("name", "Player"))
	name_entry.text = player_name
	pending_player_name = player_name
	is_submitting = true
	set_status("Saving your score to the leaderboard..." if current_mode == ScreenMode.RESULTS else "Saving your score...")
	save_button.disabled = true
	$SubmitRequest.request(
		_get_submit_url(),
		OnlineLeaderboardScript.get_headers() + PackedStringArray(["Prefer: return=representation"]),
		HTTPClient.METHOD_POST,
		_get_submit_body(player_name)
	)

func _prepare_results_mode() -> void:
	if not has_run_context:
		_show_leaderboard_mode(true)
		return

	if not _is_online_configured():
		_render_leaderboard_rows([], "Waiting for online setup")
		set_status("Local best saved. Leaderboard not configured.")
		return

	if _has_saved_profile():
		set_status("Saving your score to the leaderboard...")
		fetch_leaderboard(true)
		fetch_notifications()
		submit_score()
		return

	set_status("Open Leaderboard to enter a name and save online.")
	_render_leaderboard_rows([], "Enter a name to save this run.")

func _prepare_leaderboard_mode(force_refresh: bool = false) -> void:
	needs_profile_setup = _should_show_profile_setup()
	_apply_screen_mode()

	if not _is_online_configured():
		_render_leaderboard_rows([], "Waiting for online setup")
		set_status("Leaderboard is not configured yet.")
		save_button.disabled = true
		refresh_button.disabled = true
		return

	if needs_profile_setup:
		set_status("Enter your name to save this run.")
		name_entry.grab_focus()
		return

	if force_refresh or leaderboard_entries.is_empty():
		set_status("Loading leaderboard...")
		fetch_leaderboard(true)
	else:
		_update_status_after_fetch()

	if force_refresh or alert_label.text.is_empty():
		fetch_notifications()

func _show_leaderboard_mode(force_refresh: bool = false) -> void:
	current_mode = ScreenMode.LEADERBOARD
	_prepare_leaderboard_mode(force_refresh)

func _apply_screen_mode() -> void:
	needs_profile_setup = _should_show_profile_setup()
	var showing_results := current_mode == ScreenMode.RESULTS
	results_card.visible = showing_results
	try_again_button.visible = showing_results
	results_button_row.visible = showing_results
	setup_card.visible = current_mode == ScreenMode.LEADERBOARD and needs_profile_setup
	alert_card.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup and not alert_label.text.is_empty()
	leaderboard_card.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup
	button_row.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup
	refresh_button.disabled = current_mode != ScreenMode.LEADERBOARD or needs_profile_setup or not _is_online_configured()
	back_button.disabled = current_mode != ScreenMode.LEADERBOARD or needs_profile_setup
	title_label.text = _get_title_text()
	score_label.text = _get_score_text()
	title_label.add_theme_font_size_override("font_size", 28 if showing_results else 34)
	score_label.add_theme_font_size_override("font_size", 52 if showing_results else 30)
	status_label.add_theme_font_size_override("font_size", 16 if showing_results else 18)
	status_label.custom_minimum_size = Vector2(0, 40 if showing_results else 34 if needs_profile_setup else 52)
	_apply_panel_rect(_get_active_panel_rect())

func _get_title_text() -> String:
	if current_mode == ScreenMode.RESULTS:
		return "Run Results"
	if needs_profile_setup:
		return "Save Your Score"
	return _get_board_title()

func _get_score_text() -> String:
	if current_mode == ScreenMode.RESULTS:
		return str(current_score)
	if has_run_context:
		return "Score: %d" % current_score
	return "Top Scores"

func _get_board_title() -> String:
	if OnlineLeaderboardScript.FAMILY_ID == "global":
		return "Global Leaderboard"
	return "Family Leaderboard"

func _get_active_panel_rect() -> Rect2:
	if current_mode == ScreenMode.RESULTS:
		return RESULTS_PANEL_RECT
	if current_mode == ScreenMode.LEADERBOARD and needs_profile_setup:
		return SETUP_PANEL_RECT
	return BOARD_PANEL_RECT

func _should_show_profile_setup() -> bool:
	return current_mode == ScreenMode.LEADERBOARD \
		and has_pending_score \
		and _is_online_configured() \
		and not _has_saved_profile()

func _populate_results_summary() -> void:
	if not has_run_context:
		best_score_label.text = "Local Best: %d" % _get_local_best_score()
		delta_label.text = ""
		time_survived_value_label.text = "0.0s"
		missiles_fired_value_label.text = "0"
		hostiles_destroyed_value_label.text = "0"
		pickups_value_label.text = "0"
		glowing_clears_value_label.text = "0"
		boundary_recoveries_value_label.text = "0"
		return

	best_score_label.text = "Local Best: %d" % int(current_run_summary.get("best_score_after_run", _get_local_best_score()))

	var distance_to_best := int(current_run_summary.get("distance_to_best_before_run", 0))
	if bool(current_run_summary.get("is_new_best", false)):
		delta_label.text = "New local best"
	elif distance_to_best == 0:
		delta_label.text = "Matched your local best"
	else:
		delta_label.text = "%d short of your local best" % distance_to_best

	time_survived_value_label.text = "%.1fs" % float(current_run_summary.get("time_survived_seconds", 0.0))
	missiles_fired_value_label.text = str(int(current_run_summary.get("missiles_fired", 0)))
	hostiles_destroyed_value_label.text = str(int(current_run_summary.get("hostiles_destroyed", 0)))
	pickups_value_label.text = str(int(current_run_summary.get("ammo_pickups_collected", 0)))
	glowing_clears_value_label.text = str(int(current_run_summary.get("glowing_rocks_triggered", 0)))
	boundary_recoveries_value_label.text = str(int(current_run_summary.get("boundary_bounces", 0)))

func _on_try_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/main/main.tscn")

func _on_leaderboard_pressed() -> void:
	_show_leaderboard_mode(false)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/start_screen/start_screen.tscn")

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
		if current_mode == ScreenMode.RESULTS:
			set_status("Leaderboard unavailable. Local results saved.")
		else:
			set_status("Could not load the leaderboard.")
		return

	var fetched_entries := OnlineLeaderboardScript.parse_entries(body)
	leaderboard_entries.append_array(fetched_entries)
	leaderboard_offset += fetched_entries.size()
	leaderboard_has_more = fetched_entries.size() >= LEADERBOARD_PAGE_SIZE

	_render_leaderboard_rows(OnlineLeaderboardScript.get_best_entries(leaderboard_entries))
	_update_status_after_fetch()
	call_deferred("_maybe_prefetch_if_needed")

func _on_submit_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_submitting = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var error_text := OnlineLeaderboardScript.parse_api_error(body, "Could not submit score.")
		if not _use_legacy_submit_api and OnlineLeaderboardScript.should_fallback_to_legacy_submit(error_text):
			_use_legacy_submit_api = true
			is_submitting = true
			set_status("Using legacy leaderboard submit path...")
			$SubmitRequest.request(
				_get_submit_url(),
				OnlineLeaderboardScript.get_headers() + PackedStringArray(["Prefer: return=representation"]),
				HTTPClient.METHOD_POST,
				_get_submit_body(pending_player_name)
			)
			return

		save_button.disabled = false
		if current_mode == ScreenMode.RESULTS:
			set_status("Online save unavailable. Local results saved.")
		else:
			set_status(error_text)
		return

	has_submitted = true
	var submit_result := OnlineLeaderboardScript.parse_submit_result(body)
	var saved_name := str(submit_result.get("name", ""))
	if saved_name.is_empty():
		saved_name = pending_player_name
	if not saved_name.is_empty():
		name_entry.text = saved_name
		OnlineLeaderboardScript.save_cached_name(saved_name)

	pending_player_name = ""
	has_pending_score = false
	needs_profile_setup = false
	_apply_screen_mode()
	save_button.disabled = true
	if current_mode == ScreenMode.RESULTS:
		set_status("Score saved online.")
	else:
		set_status("Score submitted!")
	fetch_leaderboard(true)
	fetch_notifications()

func _get_submit_url() -> String:
	if _use_legacy_submit_api:
		return OnlineLeaderboardScript.get_legacy_submit_url()
	return OnlineLeaderboardScript.get_submit_url()

func _get_submit_body(player_name: String) -> String:
	if _use_legacy_submit_api:
		return OnlineLeaderboardScript.make_legacy_submit_body(player_name, current_score)
	return OnlineLeaderboardScript.make_submit_body(player_name, current_score)

func _on_notification_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return

	var notifications := OnlineLeaderboardScript.parse_notifications(body)
	alert_label.text = OnlineLeaderboardScript.format_notifications(notifications, 3)
	_apply_screen_mode()
	if notifications.is_empty():
		return

	var ids: Array[int] = []
	for notification in notifications:
		ids.append(int(notification.get("id", 0)))

	$MarkNotificationsReadRequest.request(
		OnlineLeaderboardScript.get_mark_notifications_read_url(ids),
		OnlineLeaderboardScript.get_headers() + PackedStringArray(["Prefer: return=minimal"]),
		HTTPClient.METHOD_PATCH,
		OnlineLeaderboardScript.make_mark_notifications_read_body()
	)

func _on_mark_notifications_read_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	pass

func _on_push_notification_opened(payload: Dictionary) -> void:
	if str(payload.get("type", "")) != "score_beaten":
		return
	set_status("Refreshing leaderboard...")
	_show_leaderboard_mode(true)

func _update_status_after_fetch() -> void:
	if current_mode == ScreenMode.RESULTS:
		if not _is_online_configured():
			set_status("Local best saved. Leaderboard not configured.")
		elif has_submitted:
			set_status("Score saved online.")
		elif is_submitting:
			set_status("Saving score online...")
		elif has_pending_score and not _has_saved_profile():
			set_status("Open Leaderboard to enter a name and save online.")
		else:
			set_status("Leaderboard synced in the background.")
		return

	if needs_profile_setup:
		set_status("Enter your name to save this run.")
	elif is_submitting:
		set_status("Saving your score...")
	elif has_submitted:
		set_status("Score submitted!")
	elif has_pending_score:
		set_status("This run is ready to save.")
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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(44, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_label_theme(rank_label, Color(0.588235, 0.784314, 0.964706, 1), 20)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_label.text = "%d." % rank
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_label_theme(name_label, Color(0.921569, 0.94902, 1, 1), 20)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(entry.get("name", "Player"))
	row.add_child(name_label)

	var score_label_row := Label.new()
	score_label_row.custom_minimum_size = Vector2(116, 0)
	score_label_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_label_theme(score_label_row, Color(0.964706, 0.843137, 0.54902, 1), 20)
	score_label_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label_row.text = str(int(entry.get("score", 0)))
	row.add_child(score_label_row)

	return row

func _create_message_label(message: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_theme(label, Color(0.776471, 0.85098, 0.94902, 0.95), 18)
	label.text = message
	return label

func _apply_label_theme(label: Label, font_color: Color, font_size: int) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", font_size)

func _configure_touch_scroll() -> void:
	leaderboard_scroll.scroll_deadzone = 12
	leaderboard_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_panel_rect(rect: Rect2) -> void:
	_apply_responsive_panel_rect(rect)

func _get_empty_board_text() -> String:
	if OnlineLeaderboardScript.FAMILY_ID == "global":
		return "No global scores yet"
	return "No family scores yet"

func _apply_responsive_panel_rect(rect: Rect2) -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(260.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(260.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(rect.size.x, max_size.x),
		min(rect.size.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

func _on_viewport_size_changed() -> void:
	_apply_responsive_panel_rect(_get_active_panel_rect())

func apply_validation_state(mode: int, summary: Dictionary = {}, online_configured: bool = false, saved_profile: bool = false, show_alert: bool = false) -> void:
	validation_mode_enabled = true
	_validation_online_configured = online_configured
	_validation_saved_profile = saved_profile
	current_mode = mode
	current_run_summary = summary.duplicate(true)
	has_run_context = not current_run_summary.is_empty()
	has_pending_score = has_run_context
	current_score = int(current_run_summary.get("score", 0))
	has_submitted = false
	needs_profile_setup = false
	pending_player_name = ""
	is_submitting = false
	_use_legacy_submit_api = false
	leaderboard_entries.clear()
	leaderboard_offset = 0
	leaderboard_has_more = false
	leaderboard_fetch_in_flight = false
	alert_label.text = "Validation alert" if show_alert else ""
	name_entry.text = "Pilot"
	save_button.disabled = false
	_populate_results_summary()

	if current_mode == ScreenMode.RESULTS:
		_apply_screen_mode()
		_prepare_results_mode()
		return

	if _should_show_profile_setup():
		_apply_screen_mode()
		set_status("Enter your name to save this run.")
		return

	leaderboard_entries = [
		{"name": "Ace Pilot", "score": 999},
		{"name": "Cloud Runner", "score": 742},
	]
	_apply_screen_mode()
	_render_leaderboard_rows(leaderboard_entries)
	_update_status_after_fetch()

func _get_run_stats() -> Node:
	return get_node_or_null("/root/RunStats")

func _get_local_best_score() -> int:
	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("get_local_best_score"):
		return int(run_stats.get_local_best_score())
	return 0

func _is_online_configured() -> bool:
	if validation_mode_enabled:
		return _validation_online_configured
	return OnlineLeaderboardScript.is_configured()

func _has_saved_profile() -> bool:
	if validation_mode_enabled:
		return _validation_saved_profile
	return OnlineLeaderboardScript.has_saved_profile()

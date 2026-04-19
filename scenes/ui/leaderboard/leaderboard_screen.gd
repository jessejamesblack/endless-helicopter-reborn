extends Control

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const LEADERBOARD_PAGE_SIZE := 25
const LEADERBOARD_SCROLL_TRIGGER_PX := 96.0
const RESULTS_PANEL_RECT := Rect2(-340.0, -354.0, 680.0, 708.0)
const BOARD_PANEL_RECT := Rect2(-320.0, -310.0, 640.0, 620.0)
const SETUP_PANEL_RECT := Rect2(-280.0, -220.0, 560.0, 440.0)
const PANEL_MARGIN := 4.0
const TOUCH_SCROLL_DEADZONE := 10.0
const TOUCH_SCROLL_AXIS_BIAS := 1.2
const MOUSE_POINTER_ID := -1000

enum ScreenMode {
	RESULTS,
	LEADERBOARD,
}

var current_score: int = 0
var current_mode: int = ScreenMode.LEADERBOARD
var current_run_summary: Dictionary = {}
var current_mission_result: Dictionary = {}
var has_run_context: bool = false
var has_submitted: bool = false
var has_pending_score: bool = false
var needs_profile_setup: bool = false
var pending_player_name: String = ""
var is_submitting: bool = false
var validation_mode_enabled: bool = false
var _use_expanded_fetch_fields: bool = true
var _validation_online_configured: bool = false
var _validation_saved_profile: bool = false
var push_notifications: Node = null
var leaderboard_entries: Array[Dictionary] = []
var leaderboard_offset: int = 0
var leaderboard_has_more: bool = true
var leaderboard_fetch_in_flight: bool = false
var _scroll_pointer_active: bool = false
var _scroll_dragging: bool = false
var _scroll_pointer_id: int = -1
var _scroll_press_position: Vector2 = Vector2.ZERO
var _scroll_origin: float = 0.0

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var panel: Panel = $Panel
@onready var score_label: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var results_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/ResultsCard
@onready var best_score_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/BestScoreLabel
@onready var delta_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/DeltaLabel
@onready var time_survived_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/TimeValueLabel
@onready var missiles_fired_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/MissilesValueLabel
@onready var hostiles_destroyed_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/HostilesValueLabel
@onready var pickups_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/PickupsValueLabel
@onready var glowing_clears_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/GlowingClearsValueLabel
@onready var boundary_recoveries_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/RunStatsColumn/StatsGrid/BoundaryRecoveriesValueLabel
@onready var near_misses_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/SkillStatsColumn/SkillStatsGrid/NearMissesValueLabel
@onready var max_combo_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/SkillStatsColumn/SkillStatsGrid/MaxComboValueLabel
@onready var intercepts_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/SkillStatsColumn/SkillStatsGrid/InterceptsValueLabel
@onready var skill_score_value_label: Label = $Panel/MarginContainer/VBoxContainer/ResultsCard/ResultsVBox/ResultsColumns/SkillStatsColumn/SkillStatsGrid/SkillScoreValueLabel
@onready var mission_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/MissionCard
@onready var mission_progress_label: Label = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionVBox/MissionProgressLabel
@onready var mission_line_one_label: Label = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionVBox/MissionLineOneLabel
@onready var mission_line_two_label: Label = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionVBox/MissionLineTwoLabel
@onready var mission_line_three_label: Label = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionVBox/MissionLineThreeLabel
@onready var try_again_button: Button = $Panel/MarginContainer/VBoxContainer/TryAgainButton
@onready var results_button_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow
@onready var leaderboard_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/LeaderboardButton
@onready var missions_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/MissionsButton
@onready var open_hangar_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/OpenHangarButton
@onready var menu_button: Button = $Panel/MarginContainer/VBoxContainer/ResultsButtonRow/MenuButton
@onready var setup_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/SetupCard
@onready var name_help_label: Label = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameHelpLabel
@onready var name_entry: LineEdit = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/NameEntry
@onready var setup_action_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/SetupActionRow
@onready var setup_back_button: Button = $Panel/MarginContainer/VBoxContainer/SetupCard/SetupVBox/SetupActionRow/SetupBackButton
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
	var mission_manager := _get_mission_manager()
	if mission_manager != null and mission_manager.has_method("consume_recent_run_result"):
		current_mission_result = mission_manager.consume_recent_run_result()
	else:
		current_mission_result = {}
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
	_configure_setup_buttons()
	_populate_results_summary()
	_apply_screen_mode()
	_configure_touch_scroll()
	_connect_leaderboard_scroll()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	try_again_button.pressed.connect(_on_try_again_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	missions_button.pressed.connect(_on_missions_pressed)
	open_hangar_button.pressed.connect(_on_open_hangar_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	save_button.pressed.connect(_on_save_pressed)
	setup_back_button.pressed.connect(_on_back_pressed)
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
	var sync_queue := _get_sync_queue()
	if sync_queue != null and sync_queue.has_signal("startup_sync_state_changed"):
		var startup_sync_callback := Callable(self, "_on_startup_sync_state_changed")
		if not sync_queue.is_connected("startup_sync_state_changed", startup_sync_callback):
			sync_queue.connect("startup_sync_state_changed", startup_sync_callback)

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
		_get_fetch_url(),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_GET
	)

func fetch_notifications() -> void:
	if OS.get_name() == "Android" and not OnlineLeaderboardScript.is_remote_profile_identity_ready():
		alert_label.text = ""
		_apply_screen_mode()
		return
	$NotificationRequest.request(
		OnlineLeaderboardScript.get_notifications_url(),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_get_notifications_body(5)
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
	if not await _prepare_player_id_for_online_actions():
		return
	pending_player_name = player_name
	is_submitting = true
	set_status("Saving your score to the leaderboard..." if current_mode == ScreenMode.RESULTS else "Saving your score...")
	save_button.disabled = true
	$SubmitRequest.request(
		OnlineLeaderboardScript.get_submit_v2_url(),
		OnlineLeaderboardScript.get_headers() + PackedStringArray(["Prefer: return=representation"]),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_submit_v2_body(player_name, current_score, current_run_summary, _get_equipped_skin_id())
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
		has_submitted = true
		has_pending_score = false
		_apply_screen_mode()
		set_status("Syncing run online in the background...")
		var sync_queue := _get_sync_queue()
		if sync_queue != null and sync_queue.has_method("flush"):
			sync_queue.flush()
		fetch_leaderboard(true)
		fetch_notifications()
		return

	if _is_waiting_for_startup_restore():
		set_status("Checking cloud progress for this device...")
		_render_leaderboard_rows([], "Checking cloud progress...")
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

	if _is_waiting_for_startup_restore():
		_render_leaderboard_rows([], "Checking cloud progress...")
		set_status("Checking cloud progress for this device...")
		save_button.disabled = true
		return

	if needs_profile_setup:
		set_status("Enter your name to save this run.")
		save_button.disabled = false
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
	mission_card.visible = showing_results and _should_show_mission_card()
	try_again_button.visible = showing_results
	results_button_row.visible = showing_results
	open_hangar_button.visible = showing_results and _has_hangar_unlock_cta()
	setup_card.visible = current_mode == ScreenMode.LEADERBOARD and needs_profile_setup
	alert_card.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup and not alert_label.text.is_empty()
	leaderboard_card.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup
	button_row.visible = current_mode == ScreenMode.LEADERBOARD and not needs_profile_setup
	refresh_button.disabled = current_mode != ScreenMode.LEADERBOARD or needs_profile_setup or not _is_online_configured()
	back_button.disabled = current_mode != ScreenMode.LEADERBOARD or needs_profile_setup
	title_label.text = _get_title_text()
	score_label.text = _get_score_text()
	title_label.add_theme_font_size_override("font_size", 22 if showing_results else 34)
	score_label.add_theme_font_size_override("font_size", 40 if showing_results else 30)
	status_label.add_theme_font_size_override("font_size", 14 if showing_results else 18)
	status_label.custom_minimum_size = Vector2(0, 24 if showing_results else 34 if needs_profile_setup else 52)
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
		and not _is_waiting_for_startup_restore() \
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
		near_misses_value_label.text = "0"
		max_combo_value_label.text = "x1.00"
		intercepts_value_label.text = "0"
		skill_score_value_label.text = "0"
		_populate_mission_summary()
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
	near_misses_value_label.text = str(int(current_run_summary.get("near_misses", 0)))
	max_combo_value_label.text = "x%.2f" % float(current_run_summary.get("max_combo_multiplier", 1.0))
	intercepts_value_label.text = str(int(current_run_summary.get("projectile_intercepts", 0)))
	skill_score_value_label.text = str(int(current_run_summary.get("skill_score", 0)))
	_populate_mission_summary()

func _populate_mission_summary() -> void:
	var mission_manager := _get_mission_manager()
	var progress_summary: Dictionary = {}
	if mission_manager != null and mission_manager.has_method("get_daily_progress_summary"):
		progress_summary = mission_manager.get_daily_progress_summary()

	mission_progress_label.text = "%d / %d COMPLETE" % [
		int(progress_summary.get("completed", 0)),
		int(progress_summary.get("total", 3))
	]

	var completed_titles = current_mission_result.get("missions_completed_this_run", []) if current_mission_result.has("missions_completed_this_run") else []
	var unlock_entries: Array = current_run_summary.get("post_run_unlocks", []) if current_run_summary.has("post_run_unlocks") else current_mission_result.get("unlocks", [])
	if unlock_entries.is_empty() and current_mission_result.has("newly_unlocked_vehicles"):
		for vehicle_id in current_mission_result.get("newly_unlocked_vehicles", []):
			unlock_entries.append({
				"unlock_type": "vehicle",
				"vehicle_id": str(vehicle_id),
			})
	var next_unlock: Dictionary = current_mission_result.get("next_unlock", progress_summary.get("next_unlock", {}))

	mission_line_one_label.text = "+ %s complete!" % str(completed_titles[0]) if completed_titles is Array and not completed_titles.is_empty() else "Keep flying to clear today's missions."
	mission_line_two_label.text = _format_unlock_line(unlock_entries[0]) if unlock_entries.size() >= 1 else ""
	if unlock_entries.size() >= 2:
		mission_line_three_label.text = _format_unlock_line(unlock_entries[1])
	elif next_unlock.is_empty():
		mission_line_three_label.text = "Next vehicle: Collection complete"
	else:
		mission_line_three_label.text = "Next vehicle: %s %s" % [
			str(next_unlock.get("display_name", "Scout")),
			str(next_unlock.get("progress_text", "")),
		]

func _on_try_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/main/main.tscn")

func _on_leaderboard_pressed() -> void:
	_show_leaderboard_mode(false)

func _on_missions_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/missions/mission_screen.tscn")

func _on_open_hangar_pressed() -> void:
	var unlock_entry := _get_primary_hangar_unlock_entry()
	if unlock_entry.is_empty():
		return
	var hangar_navigation_state := get_node_or_null("/root/HangarNavigationState")
	if hangar_navigation_state != null and hangar_navigation_state.has_method("set_focus_from_unlock"):
		hangar_navigation_state.set_focus_from_unlock(unlock_entry)
	get_tree().change_scene_to_file("res://scenes/ui/hangar/hangar_screen.tscn")

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
		var error_text := OnlineLeaderboardScript.parse_api_error(body, "Could not load the leaderboard.")
		if _use_expanded_fetch_fields and OnlineLeaderboardScript.should_fallback_to_legacy_fetch(error_text):
			_use_expanded_fetch_fields = false
			set_status("Using compatible leaderboard fetch...")
			fetch_leaderboard(false)
			return
		if leaderboard_entries.is_empty():
			_render_leaderboard_rows([], "Could not load the leaderboard.")
		if current_mode == ScreenMode.RESULTS:
			set_status("Leaderboard unavailable. Local results saved.")
		else:
			set_status(error_text)
		return

	var fetched_entries := OnlineLeaderboardScript.parse_entries(body)
	leaderboard_entries.append_array(fetched_entries)
	leaderboard_offset += fetched_entries.size()
	leaderboard_has_more = fetched_entries.size() >= LEADERBOARD_PAGE_SIZE

	var best_entries := OnlineLeaderboardScript.get_best_entries(leaderboard_entries)
	var player_profile := _get_player_profile()
	if player_profile != null and player_profile.has_method("apply_leaderboard_entries"):
		player_profile.apply_leaderboard_entries(best_entries)

	_render_leaderboard_rows(best_entries)
	_update_status_after_fetch()
	call_deferred("_maybe_prefetch_if_needed")

func _on_submit_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_submitting = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if _handle_upgrade_required_response("submit_score", response_code, body):
			save_button.disabled = false
			set_status("This build is too old to submit scores. Please update to continue.")
			return
		var error_text := OnlineLeaderboardScript.parse_api_error(body, "Could not submit score.")
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
	var sync_queue := _get_sync_queue()
	if sync_queue != null and sync_queue.has_method("flush"):
		sync_queue.flush()
	var player_profile := _get_player_profile()
	if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
		player_profile.refresh_top_player_skin_access()
	if current_mode == ScreenMode.RESULTS:
		set_status("Score saved online.")
	else:
		set_status("Score submitted!")
	fetch_leaderboard(true)
	fetch_notifications()

func _get_fetch_url() -> String:
	if _use_expanded_fetch_fields:
		return OnlineLeaderboardScript.get_fetch_url_with_mode(LEADERBOARD_PAGE_SIZE, leaderboard_offset, true)
	return OnlineLeaderboardScript.get_legacy_fetch_url(LEADERBOARD_PAGE_SIZE, leaderboard_offset)

func _on_notification_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_upgrade_required_response("get_notifications", response_code, body)
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
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_POST,
		OnlineLeaderboardScript.make_mark_notifications_read_body_for_ids(ids)
	)

func _on_mark_notifications_read_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_upgrade_required_response("mark_notifications_read", response_code, body)

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
			set_status("Run syncing in the background.")
		elif is_submitting:
			set_status("Saving score online...")
		elif _is_waiting_for_startup_restore():
			set_status("Checking cloud progress for this device...")
		elif has_pending_score and not _has_saved_profile():
			set_status("Open Leaderboard to enter a name and save online.")
		else:
			set_status("Leaderboard synced in the background.")
		return

	if needs_profile_setup:
		set_status("Enter your name to save this run.")
	elif _is_waiting_for_startup_restore():
		set_status("Checking cloud progress for this device...")
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
	leaderboard_scroll.scroll_deadzone = int(TOUCH_SCROLL_DEADZONE)
	leaderboard_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not leaderboard_card.visible:
		return
	if event is InputEventScreenTouch:
		_handle_scroll_touch(event.position, event.index, event.pressed)
		return
	if event is InputEventScreenDrag:
		_handle_scroll_drag(event.position, event.index)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_scroll_touch(event.position, MOUSE_POINTER_ID, event.pressed)
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_scroll_drag(event.position, MOUSE_POINTER_ID)

func _handle_scroll_touch(position: Vector2, pointer_id: int, pressed: bool) -> void:
	if pressed:
		if not _is_touch_inside_scroll(position) or not _can_scroll_content():
			return
		_scroll_pointer_active = true
		_scroll_dragging = false
		_scroll_pointer_id = pointer_id
		_scroll_press_position = position
		_scroll_origin = float(leaderboard_scroll.scroll_vertical)
		return
	if _scroll_pointer_active and _scroll_pointer_id == pointer_id:
		if _scroll_dragging:
			get_viewport().set_input_as_handled()
		_reset_touch_scroll_state()

func _handle_scroll_drag(position: Vector2, pointer_id: int) -> void:
	if not _scroll_pointer_active or _scroll_pointer_id != pointer_id:
		return
	var drag_delta := position - _scroll_press_position
	if not _scroll_dragging:
		if abs(drag_delta.y) < TOUCH_SCROLL_DEADZONE:
			return
		if abs(drag_delta.y) < abs(drag_delta.x) * TOUCH_SCROLL_AXIS_BIAS:
			return
		_scroll_dragging = true
	if _scroll_dragging:
		var next_scroll := _scroll_origin - drag_delta.y
		leaderboard_scroll.scroll_vertical = int(round(next_scroll))
		get_viewport().set_input_as_handled()

func _is_touch_inside_scroll(position: Vector2) -> bool:
	return leaderboard_scroll.get_global_rect().has_point(position)

func _can_scroll_content() -> bool:
	var scroll_bar := leaderboard_scroll.get_v_scroll_bar()
	return scroll_bar != null and scroll_bar.max_value > 0.0

func _reset_touch_scroll_state() -> void:
	_scroll_pointer_active = false
	_scroll_dragging = false
	_scroll_pointer_id = -1
	_scroll_press_position = Vector2.ZERO
	_scroll_origin = 0.0

func _apply_panel_rect(rect: Rect2) -> void:
	_apply_responsive_panel_rect(rect)

func _configure_setup_buttons() -> void:
	if setup_action_row == null or setup_back_button == null or save_button == null:
		return
	if save_button.get_parent() != setup_action_row:
		save_button.reparent(setup_action_row)
		setup_action_row.move_child(save_button, 1)
	setup_action_row.add_theme_constant_override("separation", 10)
	setup_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_back_button.custom_minimum_size = Vector2(0, 48)
	save_button.custom_minimum_size = Vector2(0, 48)
	setup_back_button.add_theme_font_size_override("font_size", 18)
	save_button.add_theme_font_size_override("font_size", 18)

func _get_empty_board_text() -> String:
	if OnlineLeaderboardScript.FAMILY_ID == "global":
		return "No global scores yet"
	return "No family scores yet"

func _prepare_player_id_for_online_actions() -> bool:
	if _is_waiting_for_startup_restore():
		set_status("Checking cloud progress for this device. Try again in a moment.")
		return false
	if not OnlineLeaderboardScript.load_or_create_player_id().strip_edges().is_empty():
		return true
	set_status("Cloud profile isn't ready yet. Try again in a moment.")
	return false

func _handle_upgrade_required_response(operation: String, response_code: int, body: PackedByteArray) -> bool:
	if not OnlineLeaderboardScript.is_upgrade_required_response(response_code, body):
		return false
	OnlineLeaderboardScript.handle_upgrade_required(operation, body, {
		"screen": "leaderboard",
		"current_mode": current_mode,
		"has_pending_score": has_pending_score,
	})
	return true

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

func _is_waiting_for_startup_restore() -> bool:
	if validation_mode_enabled:
		return false
	if not has_pending_score or not _is_online_configured() or _has_saved_profile():
		return false
	var sync_queue := _get_sync_queue()
	if sync_queue == null:
		return false
	if sync_queue.has_method("has_completed_startup_sync"):
		return not bool(sync_queue.has_completed_startup_sync())
	if sync_queue.has_method("is_startup_sync_in_progress"):
		return bool(sync_queue.is_startup_sync_in_progress())
	return false

func _on_startup_sync_state_changed() -> void:
	if validation_mode_enabled:
		return
	name_entry.text = OnlineLeaderboardScript.load_cached_name()
	if current_mode == ScreenMode.RESULTS:
		_prepare_results_mode()
		return
	_prepare_leaderboard_mode(leaderboard_entries.is_empty())

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
	_use_expanded_fetch_fields = true
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

func _get_mission_manager() -> Node:
	return get_node_or_null("/root/MissionManager")

func _get_sync_queue() -> Node:
	return get_node_or_null("/root/SupabaseSyncQueue")

func _get_player_profile() -> Node:
	return get_node_or_null("/root/PlayerProfile")

func _get_local_best_score() -> int:
	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("get_local_best_score"):
		return int(run_stats.get_local_best_score())
	return 0

func _should_show_mission_card() -> bool:
	return has_run_context

func _get_equipped_skin_id() -> String:
	var player_profile = get_node_or_null("/root/PlayerProfile")
	if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
		return str(player_profile.get_equipped_vehicle_id())
	if player_profile != null and player_profile.has_method("get_equipped_skin_id"):
		return str(player_profile.get_equipped_skin_id())
	return "default_scout"

func _get_vehicle_display_name(vehicle_id: String) -> String:
	var helicopter_skins = get_node_or_null("/root/HelicopterSkins")
	if helicopter_skins != null and helicopter_skins.has_method("get_display_name"):
		return str(helicopter_skins.get_display_name(vehicle_id))
	return vehicle_id

func _get_skin_display_name(vehicle_id: String, skin_id: String) -> String:
	var helicopter_skins = get_node_or_null("/root/HelicopterSkins")
	if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_skin_data"):
		return str(helicopter_skins.get_vehicle_skin_data(vehicle_id, skin_id).get("display_name", skin_id))
	return skin_id

func _format_unlock_line(unlock_entry: Dictionary) -> String:
	match str(unlock_entry.get("unlock_type", "")):
		"vehicle":
			return "+ %s vehicle" % _get_vehicle_display_name(str(unlock_entry.get("vehicle_id", "")))
		"vehicle_skin":
			var vehicle_id := str(unlock_entry.get("vehicle_id", ""))
			var skin_id := str(unlock_entry.get("skin_id", ""))
			return "+ %s / %s skin" % [_get_vehicle_display_name(vehicle_id), _get_skin_display_name(vehicle_id, skin_id)]
		"global_skin_set":
			return "+ Original Icon skin set"
	return ""

func _has_hangar_unlock_cta() -> bool:
	return not _get_primary_hangar_unlock_entry().is_empty()

func _get_primary_hangar_unlock_entry() -> Dictionary:
	var unlock_entries: Array = current_run_summary.get("post_run_unlocks", []) if current_run_summary.has("post_run_unlocks") else []
	for unlock_variant in unlock_entries:
		if unlock_variant is not Dictionary:
			continue
		var unlock_entry := unlock_variant as Dictionary
		match str(unlock_entry.get("unlock_type", "")):
			"vehicle", "vehicle_skin", "global_skin_set":
				return unlock_entry
	return {}

func _is_online_configured() -> bool:
	if validation_mode_enabled:
		return _validation_online_configured
	return OnlineLeaderboardScript.is_configured()

func _has_saved_profile() -> bool:
	if validation_mode_enabled:
		return _validation_saved_profile
	return OnlineLeaderboardScript.has_saved_profile()

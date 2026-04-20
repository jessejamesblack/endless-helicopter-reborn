extends Control

signal closed

const BuildInfoScript = preload("res://systems/build_info.gd")
const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const QA_TESTING_NAME := "QATesting"
const QA_LOOKUP_LIMIT := 10
const PANEL_DESIRED_SIZE := Vector2(980.0, 640.0)
const PANEL_MARGIN := 18.0
const TOUCH_SCROLL_DEADZONE := 10.0
const TOUCH_SCROLL_AXIS_BIAS := 1.2
const MOUSE_POINTER_ID := -1000

@onready var panel: Panel = $Overlay/Panel
@onready var panel_margin: MarginContainer = $Overlay/Panel/MarginContainer
@onready var root_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var content_scroll: ScrollContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll
@onready var debug_columns: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns
@onready var summary_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard
@onready var details_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard
@onready var summary_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn
@onready var details_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn
@onready var summary_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/SummaryHeader
@onready var update_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/BuildInfoSection/UpdateStatusLabel
@onready var build_info_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/BuildInfoSection/BuildInfoLabel
@onready var screenshot_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/ScreenshotToggle
@onready var release_channel_row: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/DebugReleaseChannelRow
@onready var release_channel_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/DebugReleaseChannelRow/DebugReleaseChannelOption
@onready var cached_name_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/LocalNameSection/CachedNameLabel
@onready var use_qa_name_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/LocalNameSection/NameButtonRow/UseQaNameButton
@onready var clear_name_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/LocalNameSection/NameButtonRow/ClearNameButton
@onready var send_feedback_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/FeedbackSection/FeedbackButtonRow/SendFeedbackButton
@onready var copy_bug_report_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/FeedbackSection/FeedbackButtonRow/CopyBugReportButton
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/PushStatusLabel
@onready var summary_button_row: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/ButtonRow
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/ButtonRow/EnablePushButton
@onready var retry_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/SummaryCard/SummaryColumn/ButtonRow/RetryPushButton
@onready var details_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/PushDebugHeader
@onready var status_grid: GridContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid
@onready var platform_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PlatformValueLabel
@onready var plugin_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PluginValueLabel
@onready var compat_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/CompatValueLabel
@onready var firebase_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/FirebaseValueLabel
@onready var permission_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PermissionValueLabel
@onready var player_identity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PlayerIdentityValueLabel
@onready var device_identity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/DeviceIdentityValueLabel
@onready var remote_identity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/RemoteIdentityValueLabel
@onready var identity_migration_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/IdentityMigrationValueLabel
@onready var device_id_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/DeviceIdValueLabel
@onready var token_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/TokenValueLabel
@onready var response_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/ResponseValueLabel
@onready var registering_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/RegisteringValueLabel
@onready var last_message_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/LastMessageHeader
@onready var last_message_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugColumns/DetailsCard/DetailsColumn/LastMessageValueLabel
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var feedback_screen = $FeedbackScreen

var _scroll_pointer_active: bool = false
var _scroll_dragging: bool = false
var _scroll_pointer_id: int = -1
var _scroll_press_position: Vector2 = Vector2.ZERO
var _scroll_origin: float = 0.0
var _qa_lookup_request: HTTPRequest
var _qa_lookup_in_flight: bool = false
var _cached_name_status_message: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_populate_release_channel_options()

	enable_push_button.pressed.connect(_on_enable_push_pressed)
	retry_push_button.pressed.connect(_on_retry_push_pressed)
	screenshot_toggle.toggled.connect(_on_screenshot_toggle_toggled)
	release_channel_option.item_selected.connect(_on_release_channel_selected)
	use_qa_name_button.pressed.connect(_on_use_qa_name_pressed)
	clear_name_button.pressed.connect(_on_clear_name_pressed)
	send_feedback_button.pressed.connect(_on_send_feedback_pressed)
	copy_bug_report_button.pressed.connect(_on_copy_bug_report_pressed)
	close_button.pressed.connect(_on_close_pressed)

	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_signal("diagnostics_changed"):
		var diagnostics_callback := Callable(self, "_on_push_diagnostics_changed")
		if not push_notifications.is_connected("diagnostics_changed", diagnostics_callback):
			push_notifications.connect("diagnostics_changed", diagnostics_callback)

	var update_manager = _get_app_update_manager()
	if update_manager != null and update_manager.has_signal("update_state_changed"):
		var update_callback := Callable(self, "_on_update_state_changed")
		if not update_manager.is_connected("update_state_changed", update_callback):
			update_manager.connect("update_state_changed", update_callback)

	_refresh_support_state()
	_update_push_status()
	_configure_touch_scroll()
	_ensure_qa_lookup_request()

func open_menu() -> void:
	_fit_panel_to_viewport()
	_refresh_support_state()
	_update_push_status()
	if is_instance_valid(content_scroll):
		content_scroll.scroll_vertical = 0
	_reset_touch_scroll_state()
	visible = true
	close_button.grab_focus()

func close_menu(emit_closed_signal: bool = true) -> void:
	visible = false
	if emit_closed_signal:
		closed.emit()

func _populate_release_channel_options() -> void:
	if release_channel_option.item_count > 0:
		return
	release_channel_option.add_item("Build Default")
	release_channel_option.add_item("Stable")
	release_channel_option.add_item("Beta")
	release_channel_option.add_item("Dev")

func _refresh_support_state() -> void:
	var settings = _get_game_settings()
	if settings != null:
		screenshot_toggle.set_block_signals(true)
		release_channel_option.set_block_signals(true)
		screenshot_toggle.button_pressed = bool(settings.is_achievement_screenshot_sharing_enabled()) if settings.has_method("is_achievement_screenshot_sharing_enabled") else true
		match str(settings.get_debug_release_channel_override()) if settings.has_method("get_debug_release_channel_override") else "":
			"stable":
				release_channel_option.select(1)
			"beta":
				release_channel_option.select(2)
			"dev":
				release_channel_option.select(3)
			_:
				release_channel_option.select(0)
		screenshot_toggle.set_block_signals(false)
		release_channel_option.set_block_signals(false)

	update_status_label.text = "Update Status: %s" % _get_update_status_text()
	build_info_label.text = "Version: %s\nBuild: %s\nChannel: %s" % [
		BuildInfoScript.get_version_label(),
		str(BuildInfoScript.BUILD_SHA),
		_get_effective_release_channel_label(),
	]
	_update_cached_name_label()
	release_channel_row.visible = OS.is_debug_build()

func _get_update_status_text() -> String:
	var update_manager = _get_app_update_manager()
	if update_manager != null and update_manager.has_method("get_update_status_text"):
		return str(update_manager.get_update_status_text())
	return "Unavailable"

func _get_effective_release_channel_label() -> String:
	var update_manager = _get_app_update_manager()
	if update_manager != null and update_manager.has_method("get_effective_release_channel"):
		return str(update_manager.get_effective_release_channel())
	return str(BuildInfoScript.RELEASE_CHANNEL)

func _on_screenshot_toggle_toggled(enabled: bool) -> void:
	var settings = _get_game_settings()
	if settings != null and settings.has_method("set_achievement_screenshot_sharing_enabled"):
		settings.set_achievement_screenshot_sharing_enabled(enabled)

func _on_release_channel_selected(index: int) -> void:
	var override := ""
	match index:
		1:
			override = "stable"
		2:
			override = "beta"
		3:
			override = "dev"
	var settings = _get_game_settings()
	if settings != null and settings.has_method("set_debug_release_channel_override"):
		settings.set_debug_release_channel_override(override)
	_refresh_support_state()

func _on_send_feedback_pressed() -> void:
	if feedback_screen != null and feedback_screen.has_method("open_menu"):
		feedback_screen.open_menu()

func _on_use_qa_name_pressed() -> void:
	call_deferred("_apply_qa_profile_async")

func _on_clear_name_pressed() -> void:
	_clear_pending_sync_jobs()
	OnlineLeaderboardScript.clear_cached_name()
	OnlineLeaderboardScript.clear_cloud_profile_presence()
	OnlineLeaderboardScript.clear_manual_player_id_override()
	_cached_name_status_message = ""
	_update_cached_name_label()
	_update_push_status()

func _on_copy_bug_report_pressed() -> void:
	var reporter = get_node_or_null("/root/ErrorReporter")
	var report_text := "Build: %s" % BuildInfoScript.get_debug_label()
	if reporter != null and reporter.has_method("build_bug_report_text"):
		report_text = reporter.build_bug_report_text("bug")
	DisplayServer.clipboard_set(report_text)

func _on_enable_push_pressed() -> void:
	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_method("enable_notifications"):
		push_notifications.enable_notifications()
	_update_push_status()

func _on_retry_push_pressed() -> void:
	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_method("enable_notifications"):
		push_notifications.enable_notifications()
	_update_push_status()

func _on_push_diagnostics_changed(_status: Dictionary) -> void:
	_update_push_status()

func _on_update_state_changed(_state: Dictionary) -> void:
	_refresh_support_state()

func _update_push_status() -> void:
	var push_notifications = _get_push_notifications()
	if push_notifications == null:
		push_status_label.text = "Push unavailable: runtime service not loaded."
		_set_detail_labels({}, null)
		enable_push_button.disabled = true
		retry_push_button.disabled = true
		return

	var status := {}
	if push_notifications.has_method("get_diagnostics"):
		status = push_notifications.get_diagnostics()

	if push_notifications.has_method("get_diagnostics_text"):
		push_status_label.text = push_notifications.get_diagnostics_text()
	else:
		push_status_label.text = "Push diagnostics text unavailable."

	_set_detail_labels(status, push_notifications)

	var is_android := OS.get_name() == "Android"
	enable_push_button.disabled = not is_android
	retry_push_button.disabled = not is_android

func _set_detail_labels(status: Dictionary, push_notifications) -> void:
	var firebase_text := _yes_no(bool(status.get("firebase_ready", false)))
	var firebase_status := str(status.get("firebase_status", "")).strip_edges()
	if not firebase_status.is_empty():
		firebase_text = "%s (%s)" % [firebase_text, firebase_status]

	platform_value_label.text = OS.get_name()
	plugin_value_label.text = _yes_no(bool(status.get("plugin_loaded", false)))
	compat_value_label.text = _yes_no(bool(status.get("compat_bridge_available", false)))
	firebase_value_label.text = firebase_text
	permission_value_label.text = _yes_no(bool(status.get("permission_granted", false)))
	player_identity_value_label.text = OnlineLeaderboardScript.get_identity_source_label(str(status.get("player_identity_source", "unknown")))
	device_identity_value_label.text = OnlineLeaderboardScript.get_identity_source_label(str(status.get("device_identity_source", "unknown")))
	remote_identity_value_label.text = _yes_no(bool(status.get("remote_identity_ready", false)))
	identity_migration_value_label.text = _yes_no(bool(status.get("identity_migration_pending", false)))
	device_id_value_label.text = _get_device_id_for_debug(push_notifications)
	token_value_label.text = str(status.get("latest_token_preview", "")).strip_edges()
	if token_value_label.text.is_empty():
		token_value_label.text = "waiting"
	response_value_label.text = str(int(status.get("last_response_code", 0)))
	registering_value_label.text = _yes_no(bool(status.get("is_registering", false)))
	last_message_value_label.text = str(status.get("last_message", "Push runtime service missing."))

func _get_device_id_for_debug(push_notifications) -> String:
	if push_notifications != null and push_notifications.has_method("_load_cached_device_id_for_debug"):
		var device_id := str(push_notifications._load_cached_device_id_for_debug()).strip_edges()
		if not device_id.is_empty():
			return device_id
	return "(not created yet)"

func _on_close_pressed() -> void:
	close_menu()

func _input(event: InputEvent) -> void:
	if not visible or not is_instance_valid(content_scroll):
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

func _configure_touch_scroll() -> void:
	content_scroll.scroll_deadzone = int(TOUCH_SCROLL_DEADZONE)

func _handle_scroll_touch(position: Vector2, pointer_id: int, pressed: bool) -> void:
	if pressed:
		if not _is_touch_inside_scroll(position) or not _can_scroll_content():
			return
		_scroll_pointer_active = true
		_scroll_dragging = false
		_scroll_pointer_id = pointer_id
		_scroll_press_position = position
		_scroll_origin = float(content_scroll.scroll_vertical)
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
		content_scroll.scroll_vertical = int(round(next_scroll))
		get_viewport().set_input_as_handled()

func _is_touch_inside_scroll(position: Vector2) -> bool:
	return content_scroll.get_global_rect().has_point(position)

func _can_scroll_content() -> bool:
	var scroll_bar := content_scroll.get_v_scroll_bar()
	return scroll_bar != null and scroll_bar.max_value > 0.0

func _reset_touch_scroll_state() -> void:
	_scroll_pointer_active = false
	_scroll_dragging = false
	_scroll_pointer_id = -1
	_scroll_press_position = Vector2.ZERO
	_scroll_origin = 0.0

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

func _get_game_settings():
	return get_node_or_null("/root/GameSettings")

func _get_app_update_manager():
	return get_node_or_null("/root/AppUpdateManager")

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(260.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(280.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(PANEL_DESIRED_SIZE.x, max_size.x),
		min(PANEL_DESIRED_SIZE.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5
	_apply_modal_density(target_size)

func _apply_modal_density(target_size: Vector2) -> void:
	var compact := target_size.x < 1000.0 or target_size.y < 620.0
	var summary_panel := summary_card.get_theme_stylebox("panel") as StyleBoxFlat
	var details_panel := details_card.get_theme_stylebox("panel") as StyleBoxFlat

	panel_margin.add_theme_constant_override("margin_left", 20 if compact else 26)
	panel_margin.add_theme_constant_override("margin_top", 18 if compact else 24)
	panel_margin.add_theme_constant_override("margin_right", 20 if compact else 26)
	panel_margin.add_theme_constant_override("margin_bottom", 18 if compact else 24)
	root_column.add_theme_constant_override("separation", 12 if compact else 16)
	title_label.add_theme_font_size_override("font_size", 28 if compact else 32)
	subtitle_label.add_theme_font_size_override("font_size", 14 if compact else 17)
	debug_columns.add_theme_constant_override("separation", 12 if compact else 18)
	debug_columns.custom_minimum_size = Vector2(maxf(target_size.x - 84.0, 360.0), 0.0)
	summary_column.add_theme_constant_override("separation", 10 if compact else 14)
	details_column.add_theme_constant_override("separation", 8 if compact else 12)
	summary_button_row.add_theme_constant_override("separation", 10 if compact else 12)
	status_grid.add_theme_constant_override("h_separation", 12 if compact else 16)
	status_grid.add_theme_constant_override("v_separation", 6 if compact else 8)
	summary_header.add_theme_font_size_override("font_size", 18 if compact else 22)
	details_header.add_theme_font_size_override("font_size", 18 if compact else 22)
	last_message_header.add_theme_font_size_override("font_size", 16 if compact else 18)
	push_status_label.add_theme_font_size_override("font_size", 14 if compact else 16)
	push_status_label.custom_minimum_size = Vector2(0, 108 if compact else 132)
	last_message_value_label.add_theme_font_size_override("font_size", 14 if compact else 15)
	last_message_value_label.custom_minimum_size = Vector2(0, 44 if compact else 58)
	enable_push_button.custom_minimum_size = Vector2(0, 40 if compact else 44)
	retry_push_button.custom_minimum_size = Vector2(0, 40 if compact else 44)
	enable_push_button.add_theme_font_size_override("font_size", 16 if compact else 18)
	retry_push_button.add_theme_font_size_override("font_size", 16 if compact else 18)
	close_button.custom_minimum_size = Vector2(180.0, 44.0 if compact else 52.0)
	close_button.add_theme_font_size_override("font_size", 20 if compact else 24)

	if summary_panel != null:
		summary_panel.content_margin_left = 14.0 if compact else 18.0
		summary_panel.content_margin_top = 14.0 if compact else 18.0
		summary_panel.content_margin_right = 14.0 if compact else 18.0
		summary_panel.content_margin_bottom = 14.0 if compact else 18.0
	if details_panel != null and details_panel != summary_panel:
		details_panel.content_margin_left = 14.0 if compact else 18.0
		details_panel.content_margin_top = 14.0 if compact else 18.0
		details_panel.content_margin_right = 14.0 if compact else 18.0
		details_panel.content_margin_bottom = 14.0 if compact else 18.0

	for label in _get_debug_value_labels():
		label.add_theme_font_size_override("font_size", 13 if compact else 15)

	for label in _get_debug_key_labels():
		label.add_theme_font_size_override("font_size", 13 if compact else 15)

func _yes_no(value: bool) -> String:
	return "yes" if value else "no"

func _update_cached_name_label() -> void:
	var cached_name := OnlineLeaderboardScript.load_cached_name()
	var player_id := OnlineLeaderboardScript.get_player_id_for_display()
	var source_text := OnlineLeaderboardScript.get_player_identity_source_label()
	var name_text := "(not set)" if cached_name.is_empty() else cached_name
	var lines := PackedStringArray([
		"Cached leaderboard name: %s" % name_text,
		"Player ID: %s" % player_id,
		"Player ID source: %s" % source_text,
	])
	if not _cached_name_status_message.is_empty():
		lines.append(_cached_name_status_message)
	cached_name_label.text = "\n".join(lines)

func _ensure_qa_lookup_request() -> void:
	if _qa_lookup_request != null:
		return
	_qa_lookup_request = HTTPRequest.new()
	add_child(_qa_lookup_request)

func _apply_qa_profile_async() -> void:
	if _qa_lookup_in_flight:
		return
	_ensure_qa_lookup_request()
	if not OnlineLeaderboardScript.is_configured():
		_cached_name_status_message = "QATesting lookup unavailable: online services are not configured."
		_update_cached_name_label()
		return
	_qa_lookup_in_flight = true
	use_qa_name_button.disabled = true
	_cached_name_status_message = "Resolving the live QATesting player ID..."
	_update_cached_name_label()

	var resolved_player_id := await _resolve_player_id_for_name(QA_TESTING_NAME)
	if resolved_player_id.is_empty():
		_cached_name_status_message = "Couldn't find a cloud QATesting profile to apply."
		_qa_lookup_in_flight = false
		use_qa_name_button.disabled = false
		_update_cached_name_label()
		return

	var active_player_id_before_restore := OnlineLeaderboardScript.load_or_create_player_id().strip_edges()
	if resolved_player_id != active_player_id_before_restore:
		_clear_pending_sync_jobs()
	OnlineLeaderboardScript.save_cached_name(QA_TESTING_NAME)
	OnlineLeaderboardScript.save_manual_player_id_override(resolved_player_id)
	_cached_name_status_message = "QATesting applied with player ID %s. Restoring cloud progress..." % resolved_player_id
	_update_cached_name_label()
	_update_push_status()

	var sync_queue = get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("pull_remote_profile_state_async"):
		var restore_result: Dictionary = await sync_queue.pull_remote_profile_state_async(true)
		if not bool(restore_result.get("ok", false)):
			_cached_name_status_message = "QATesting applied, but cloud restore failed: %s" % str(restore_result.get("error_message", "unknown error"))
		elif bool(restore_result.get("profile_restored", false)) or bool(restore_result.get("mission_restored", false)):
			_cached_name_status_message = "QATesting applied and cloud progress restored."
		else:
			_cached_name_status_message = "QATesting applied, but no cloud progress was found for that player ID."
	else:
		_cached_name_status_message = "QATesting applied. Restore service was not available in this scene."

	_qa_lookup_in_flight = false
	use_qa_name_button.disabled = false
	_update_cached_name_label()

func _resolve_player_id_for_name(player_name: String) -> String:
	var profile_url := "%s/rest/v1/%s?select=player_id,name,total_daily_missions_completed,unlocked_vehicles,updated_at&family_id=eq.%s&name=eq.%s&order=updated_at.desc&limit=%d" % [
		OnlineLeaderboardScript.SUPABASE_URL,
		OnlineLeaderboardScript.PLAYER_PROFILE_TABLE_NAME,
		OnlineLeaderboardScript.FAMILY_ID.uri_encode(),
		player_name.uri_encode(),
		QA_LOOKUP_LIMIT,
	]
	var profile_response := await _request_json(_qa_lookup_request, profile_url)
	if _is_success_response(profile_response):
		var best_profile_id := _pick_best_player_id_from_profile_rows(profile_response.body)
		if not best_profile_id.is_empty():
			return best_profile_id

	var leaderboard_url := "%s/rest/v1/%s?select=player_id,name,score,updated_at&family_id=eq.%s&name=eq.%s&order=score.desc,updated_at.desc&limit=%d" % [
		OnlineLeaderboardScript.SUPABASE_URL,
		OnlineLeaderboardScript.TABLE_NAME,
		OnlineLeaderboardScript.FAMILY_ID.uri_encode(),
		player_name.uri_encode(),
		QA_LOOKUP_LIMIT,
	]
	var leaderboard_response := await _request_json(_qa_lookup_request, leaderboard_url)
	if _is_success_response(leaderboard_response):
		return _pick_best_player_id_from_leaderboard_rows(leaderboard_response.body)
	return ""

func _pick_best_player_id_from_profile_rows(body: PackedByteArray) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is not Array:
		return ""
	var best_player_id := ""
	var best_completed := -1
	var best_unlock_count := -1
	var best_updated_at := ""
	for row_variant in parsed:
		if row_variant is not Dictionary:
			continue
		var row := row_variant as Dictionary
		var player_id := str(row.get("player_id", "")).strip_edges()
		if player_id.is_empty():
			continue
		var completed_count := int(row.get("total_daily_missions_completed", 0))
		var unlock_count := 0
		var unlocked_vehicles = row.get("unlocked_vehicles", [])
		if unlocked_vehicles is Array:
			unlock_count = unlocked_vehicles.size()
		var updated_at := str(row.get("updated_at", "")).strip_edges()
		var is_better := false
		if completed_count > best_completed:
			is_better = true
		elif completed_count == best_completed and unlock_count > best_unlock_count:
			is_better = true
		elif completed_count == best_completed and unlock_count == best_unlock_count and updated_at > best_updated_at:
			is_better = true
		if is_better:
			best_player_id = player_id
			best_completed = completed_count
			best_unlock_count = unlock_count
			best_updated_at = updated_at
	return best_player_id

func _pick_best_player_id_from_leaderboard_rows(body: PackedByteArray) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is not Array:
		return ""
	for row_variant in parsed:
		if row_variant is not Dictionary:
			continue
		var player_id := str((row_variant as Dictionary).get("player_id", "")).strip_edges()
		if not player_id.is_empty():
			return player_id
	return ""

func _request_json(request: HTTPRequest, url: String, method: int = HTTPClient.METHOD_GET, body: String = "") -> Dictionary:
	var start_error := request.request(url, OnlineLeaderboardScript.get_headers(), method, body)
	if start_error != OK:
		return {
			"result": start_error,
			"response_code": 0,
			"body": PackedByteArray(),
		}
	var completed = await request.request_completed
	return {
		"result": int(completed[0]),
		"response_code": int(completed[1]),
		"body": completed[3],
	}

func _is_success_response(response: Dictionary) -> bool:
	return int(response.get("result", HTTPRequest.RESULT_CANT_CONNECT)) == HTTPRequest.RESULT_SUCCESS \
		and int(response.get("response_code", 0)) >= 200 \
		and int(response.get("response_code", 0)) < 300

func _clear_pending_sync_jobs() -> void:
	var sync_queue = get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("clear_pending_jobs"):
		sync_queue.clear_pending_jobs()

func _get_debug_value_labels() -> Array[Label]:
	return [
		platform_value_label,
		plugin_value_label,
		compat_value_label,
		firebase_value_label,
		permission_value_label,
		player_identity_value_label,
		device_identity_value_label,
		remote_identity_value_label,
		identity_migration_value_label,
		device_id_value_label,
		token_value_label,
		response_value_label,
		registering_value_label,
	]

func _get_debug_key_labels() -> Array[Label]:
	var value_labels := _get_debug_value_labels()
	var labels: Array[Label] = []
	for child in status_grid.get_children():
		if child is Label and not value_labels.has(child):
			labels.append(child as Label)
	return labels

extends Control

signal closed

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const PANEL_DESIRED_SIZE := Vector2(920.0, 560.0)
const PANEL_MARGIN := 18.0
const TOUCH_SCROLL_DEADZONE := 10.0
const TOUCH_SCROLL_AXIS_BIAS := 1.2
const MOUSE_POINTER_ID := -1000

@onready var panel: Panel = $Overlay/Panel
@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var content_scroll: ScrollContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll
@onready var content_columns: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns
@onready var audio_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard
@onready var audio_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn
@onready var master_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/MasterRow/MasterValueRow/MasterSlider
@onready var master_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/MasterRow/MasterValueRow/MasterValueLabel
@onready var music_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/MusicRow/MusicValueRow/MusicSlider
@onready var music_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/MusicRow/MusicValueRow/MusicValueLabel
@onready var sfx_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/SfxRow/SfxValueRow/SfxSlider
@onready var sfx_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/SfxRow/SfxValueRow/SfxValueLabel
@onready var restore_player_id_entry: LineEdit = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/ProgressSection/RestorePlayerIdEntry
@onready var restore_progress_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/ProgressSection/ProgressActionRow/RestoreProgressButton
@onready var clear_restore_player_id_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/ProgressSection/ProgressActionRow/ClearRestorePlayerIdButton
@onready var restore_progress_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/ProgressSection/RestoreProgressStatusLabel
@onready var replay_tips_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/ProgressSection/ReplayTipsButton
@onready var system_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard
@onready var system_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn
@onready var fire_side_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/FireSideRow/FireSideOption
@onready var hud_side_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/HudSideValueLabel
@onready var haptics_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/HapticsToggle
@onready var haptics_intensity_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/HapticsIntensityRow/HapticsIntensityValueRow/HapticsIntensitySlider
@onready var haptics_intensity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/HapticsIntensityRow/HapticsIntensityValueRow/HapticsIntensityValueLabel
@onready var frame_rate_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/FrameRateRow/FrameRateOption
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/PushSection/PushStatusLabel
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/SystemCard/SystemColumn/PushSection/EnablePushButton
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

var _scroll_pointer_active: bool = false
var _scroll_dragging: bool = false
var _scroll_pointer_id: int = -1
var _scroll_press_position: Vector2 = Vector2.ZERO
var _scroll_last_position: Vector2 = Vector2.ZERO
var _scroll_origin: float = 0.0
var _restore_progress_in_flight: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_populate_side_options()
	_populate_frame_rate_options()

	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fire_side_option.item_selected.connect(_on_fire_side_selected)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	haptics_intensity_slider.value_changed.connect(_on_haptics_intensity_changed)
	frame_rate_option.item_selected.connect(_on_frame_rate_selected)
	restore_progress_button.pressed.connect(_on_restore_progress_pressed)
	clear_restore_player_id_button.pressed.connect(_on_clear_restore_player_id_pressed)
	restore_player_id_entry.text_submitted.connect(_on_restore_player_id_text_submitted)
	replay_tips_button.pressed.connect(_on_replay_tips_pressed)
	enable_push_button.pressed.connect(_on_enable_push_pressed)
	close_button.pressed.connect(_on_close_pressed)

	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_signal("diagnostics_changed"):
		var diagnostics_callback := Callable(self, "_on_push_diagnostics_changed")
		if not push_notifications.is_connected("diagnostics_changed", diagnostics_callback):
			push_notifications.connect("diagnostics_changed", diagnostics_callback)

	var player_profile = _get_player_profile()
	if player_profile != null and player_profile.has_signal("profile_changed"):
		var profile_callback := Callable(self, "_on_profile_changed")
		if not player_profile.is_connected("profile_changed", profile_callback):
			player_profile.connect("profile_changed", profile_callback)

	_sync_from_settings()
	_configure_touch_scroll()

func open_menu() -> void:
	_fit_panel_to_viewport()
	_sync_from_settings()
	if is_instance_valid(content_scroll):
		content_scroll.scroll_vertical = 0
	_reset_touch_scroll_state()
	visible = true
	close_button.grab_focus()

func close_menu(emit_closed_signal: bool = true) -> void:
	visible = false
	if emit_closed_signal:
		closed.emit()

func _populate_side_options() -> void:
	if fire_side_option.item_count > 0:
		return
	fire_side_option.add_item("Left")
	fire_side_option.add_item("Right")

func _populate_frame_rate_options() -> void:
	if frame_rate_option.item_count > 0:
		return
	frame_rate_option.add_item("Battery Saver")
	frame_rate_option.add_item("Smooth")
	frame_rate_option.add_item("Ultra Smooth")
	frame_rate_option.add_item("Device Default")

func _sync_from_settings() -> void:
	var game_settings = _get_game_settings()
	if game_settings == null:
		return

	master_slider.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	fire_side_option.set_block_signals(true)
	haptics_toggle.set_block_signals(true)
	haptics_intensity_slider.set_block_signals(true)
	frame_rate_option.set_block_signals(true)

	master_slider.value = float(game_settings.get_master_volume())
	music_slider.value = float(game_settings.get_music_volume())
	sfx_slider.value = float(game_settings.get_sfx_volume())
	fire_side_option.select(0 if str(game_settings.get_fire_button_side()) == SIDE_LEFT else 1)
	haptics_toggle.button_pressed = bool(game_settings.is_haptics_enabled())
	haptics_intensity_slider.value = float(game_settings.get_haptics_intensity())
	match str(game_settings.get_frame_rate_setting()):
		"battery_saver":
			frame_rate_option.select(0)
		"smooth":
			frame_rate_option.select(1)
		"ultra":
			frame_rate_option.select(2)
		_:
			frame_rate_option.select(3)

	master_slider.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	fire_side_option.set_block_signals(false)
	haptics_toggle.set_block_signals(false)
	haptics_intensity_slider.set_block_signals(false)
	frame_rate_option.set_block_signals(false)

	_update_audio_labels()
	_update_layout_labels()
	_update_haptics_labels()
	_update_push_status()
	if is_instance_valid(restore_player_id_entry) and not restore_player_id_entry.has_focus():
		restore_player_id_entry.text = OnlineLeaderboardScript.load_manual_player_id_override()
	_refresh_restore_progress_section()

func _update_audio_labels() -> void:
	master_value_label.text = "%d%%" % int(round(master_slider.value * 100.0))
	music_value_label.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value_label.text = "%d%%" % int(round(sfx_slider.value * 100.0))

func _update_haptics_labels() -> void:
	haptics_intensity_value_label.text = "%d%%" % int(round(haptics_intensity_slider.value * 100.0))

func _update_layout_labels() -> void:
	var game_settings = _get_game_settings()
	var hud_side_text := "Left"
	if game_settings != null and str(game_settings.get_hud_side()) == SIDE_RIGHT:
		hud_side_text = "Right"
	hud_side_value_label.text = "HUD mirrors to: %s" % hud_side_text

func _on_master_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_master_volume(value)
	_update_audio_labels()

func _on_music_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_music_volume(value)
	_update_audio_labels()

func _on_sfx_slider_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_sfx_volume(value)
	_update_audio_labels()

func _on_fire_side_selected(index: int) -> void:
	var side := SIDE_LEFT if index == 0 else SIDE_RIGHT
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_fire_button_side(side)
	_update_layout_labels()

func _on_haptics_toggled(enabled: bool) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_haptics_enabled(enabled)

func _on_haptics_intensity_changed(value: float) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_haptics_intensity(value)
	_update_haptics_labels()

func _on_frame_rate_selected(index: int) -> void:
	var setting := "device_default"
	match index:
		0:
			setting = "battery_saver"
		1:
			setting = "smooth"
		2:
			setting = "ultra"
	var game_settings = _get_game_settings()
	if game_settings != null:
		game_settings.set_frame_rate_setting(setting)

func _on_restore_progress_pressed() -> void:
	call_deferred("_restore_progress_async")

func _on_clear_restore_player_id_pressed() -> void:
	call_deferred("_restore_with_device_player_id_async")

func _on_restore_player_id_text_submitted(_text: String) -> void:
	call_deferred("_restore_progress_async")

func _restore_with_device_player_id_async() -> void:
	if _restore_progress_in_flight:
		return
	_clear_pending_sync_jobs()
	OnlineLeaderboardScript.clear_manual_player_id_override()
	if is_instance_valid(restore_player_id_entry):
		restore_player_id_entry.text = ""
	var current_player_id := OnlineLeaderboardScript.load_or_create_player_id().strip_edges()
	var current_player_id_source := OnlineLeaderboardScript.get_player_identity_source()
	if current_player_id.is_empty():
		_refresh_restore_progress_section("This phone's player ID is not ready yet. Try again in a moment.")
		return
	_refresh_restore_progress_section("Switched back to this device's player ID %s (%s). Restoring cloud progress..." % [
		current_player_id,
		current_player_id_source,
	])
	await _restore_progress_async()

func _on_enable_push_pressed() -> void:
	var player_profile = _get_player_profile()
	if player_profile == null or not player_profile.has_method("are_daily_reminders_enabled") or not player_profile.has_method("set_daily_reminders_enabled"):
		return

	var reminders_enabled := bool(player_profile.are_daily_reminders_enabled())
	var push_notifications = _get_push_notifications()
	var diagnostics := _get_push_diagnostics()
	var permission_granted := bool(diagnostics.get("permission_granted", false))
	var can_request_permission := bool(diagnostics.get("is_android", false))

	if not reminders_enabled:
		player_profile.set_daily_reminders_enabled(true)
		if push_notifications != null and push_notifications.has_method("enable_notifications"):
			push_notifications.enable_notifications()
		_update_push_status()
		return

	if can_request_permission and not permission_granted:
		if push_notifications != null and push_notifications.has_method("enable_notifications"):
			push_notifications.enable_notifications()
		_update_push_status()
		return

	player_profile.set_daily_reminders_enabled(false)
	if push_notifications != null and push_notifications.has_method("register_device_for_push"):
		push_notifications.register_device_for_push()
	_update_push_status()

func _on_replay_tips_pressed() -> void:
	var discovery_manager := get_node_or_null("/root/FeatureDiscoveryManager")
	if discovery_manager != null and discovery_manager.has_method("replay_all_tips"):
		discovery_manager.replay_all_tips()
	_refresh_restore_progress_section("Progress tips will show again on the main menu.")

func _on_push_diagnostics_changed(_status: Dictionary) -> void:
	_update_push_status()

func _on_profile_changed(_summary: Dictionary) -> void:
	_update_push_status()
	_refresh_restore_progress_section()

func _update_push_status() -> void:
	var player_profile = _get_player_profile()
	var reminders_enabled: bool = player_profile != null and player_profile.has_method("are_daily_reminders_enabled") and bool(player_profile.are_daily_reminders_enabled())

	var push_notifications = _get_push_notifications()
	if push_notifications == null or not push_notifications.has_method("get_diagnostics"):
		push_status_label.text = "Daily reminders: %s\nPush permission: Unavailable here\nStatus: Android APK only" % ("On" if reminders_enabled else "Off")
		enable_push_button.text = "Turn Notifications %s" % ("Off" if reminders_enabled else "On")
		enable_push_button.disabled = player_profile == null
		return

	var diagnostics := _get_push_diagnostics()
	var permission_granted := bool(diagnostics.get("permission_granted", false))
	var can_request_permission := bool(diagnostics.get("is_android", false))
	var permission_text := "Granted" if permission_granted else ("Not granted" if can_request_permission else "Unavailable here")
	var status_text := "Notifications off"
	if reminders_enabled and permission_granted:
		status_text = "Ready"
	elif reminders_enabled and can_request_permission:
		status_text = "Tap below to finish setup"
	elif reminders_enabled:
		status_text = "Android APK only"
	push_status_label.text = "Daily reminders: %s\nPush permission: %s\nStatus: %s" % [
		"On" if reminders_enabled else "Off",
		permission_text,
		status_text,
	]
	if not reminders_enabled:
		enable_push_button.text = "Turn Notifications On"
	elif can_request_permission and not permission_granted:
		enable_push_button.text = "Enable Push Permission"
	else:
		enable_push_button.text = "Turn Notifications Off"
	enable_push_button.disabled = player_profile == null

func _get_push_diagnostics() -> Dictionary:
	var push_notifications = _get_push_notifications()
	if push_notifications == null or not push_notifications.has_method("get_diagnostics"):
		return {}
	return push_notifications.get_diagnostics()

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
		_scroll_last_position = position
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
		_scroll_last_position = position
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
	_scroll_last_position = Vector2.ZERO
	_scroll_origin = 0.0

func _get_game_settings():
	return get_node_or_null("/root/GameSettings")

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

func _get_player_profile():
	return get_node_or_null("/root/PlayerProfile")

func _get_sync_queue():
	return get_node_or_null("/root/SupabaseSyncQueue")

func _refresh_restore_progress_section(message: String = "") -> void:
	if not is_instance_valid(restore_progress_button) or not is_instance_valid(restore_progress_status_label):
		return
	restore_progress_button.disabled = _restore_progress_in_flight
	restore_progress_button.text = "Restoring..." if _restore_progress_in_flight else "Restore Progress"
	if is_instance_valid(restore_player_id_entry):
		restore_player_id_entry.editable = not _restore_progress_in_flight
	if is_instance_valid(clear_restore_player_id_button):
		clear_restore_player_id_button.disabled = _restore_progress_in_flight
	if not message.is_empty():
		restore_progress_status_label.text = message
		return
	var player_id := OnlineLeaderboardScript.get_player_id_for_display()
	var player_id_source := OnlineLeaderboardScript.get_player_identity_source()
	var entered_player_id := ""
	if is_instance_valid(restore_player_id_entry):
		entered_player_id = restore_player_id_entry.text.strip_edges()
	var source_hint := "Uses this device's current player ID."
	if not entered_player_id.is_empty():
		source_hint = "Restore will use the pasted player ID above."
	elif OnlineLeaderboardScript.has_manual_player_id_override():
		source_hint = "Using a pasted player ID."
	restore_progress_status_label.text = "Current Player ID: %s\nPlayer ID Source: %s\n%s Paste a player ID from support if restore doesn't work on its own, then tap Restore Progress." % [
		player_id,
		player_id_source,
		source_hint,
	]

func _restore_progress_async() -> void:
	if _restore_progress_in_flight:
		return
	if not OnlineLeaderboardScript.is_configured():
		_refresh_restore_progress_section("Online restore is not configured in this build.")
		return
	var active_player_id_before_restore := OnlineLeaderboardScript.load_or_create_player_id().strip_edges()
	var entered_player_id := ""
	if is_instance_valid(restore_player_id_entry):
		entered_player_id = restore_player_id_entry.text.strip_edges()
	if not entered_player_id.is_empty():
		var validation := OnlineLeaderboardScript.validate_player_id(entered_player_id)
		if not bool(validation.get("ok", false)):
			_refresh_restore_progress_section(str(validation.get("error", "Enter a valid player ID.")))
			return
		var validated_player_id := str(validation.get("player_id", ""))
		if validated_player_id != active_player_id_before_restore:
			_clear_pending_sync_jobs()
		OnlineLeaderboardScript.save_manual_player_id_override(validated_player_id)
		restore_player_id_entry.text = validated_player_id
	var player_id := OnlineLeaderboardScript.load_or_create_player_id().strip_edges()
	if player_id.is_empty():
		_refresh_restore_progress_section("No player ID is ready yet. Paste one from support or try again once this device has one.")
		return
	var sync_queue = _get_sync_queue()
	if sync_queue == null:
		_refresh_restore_progress_section("Restore service is not available right now.")
		return
	_restore_progress_in_flight = true
	_refresh_restore_progress_section("Checking cloud saves for player ID %s..." % player_id)
	var restore_result := {
		"ok": false,
		"profile_restored": false,
		"mission_restored": false,
		"error_message": "Could not restore progress right now.",
	}
	if sync_queue.has_method("pull_remote_profile_state_async"):
		restore_result = await sync_queue.pull_remote_profile_state_async(true)
	elif sync_queue.has_method("pull_remote_profile_state"):
		sync_queue.pull_remote_profile_state(true)
		restore_result["ok"] = true
	_restore_progress_in_flight = false
	if not bool(restore_result.get("ok", false)):
		_refresh_restore_progress_section(str(restore_result.get("error_message", "Could not restore progress right now.")))
		return
	var profile_restored := bool(restore_result.get("profile_restored", false))
	var mission_restored := bool(restore_result.get("mission_restored", false))
	if profile_restored and mission_restored:
		_refresh_restore_progress_section("Profile and daily progress restored from cloud for player ID %s." % player_id)
		return
	if profile_restored:
		_refresh_restore_progress_section("Profile restored from cloud for player ID %s." % player_id)
		return
	if mission_restored:
		_refresh_restore_progress_section("Daily mission progress restored from cloud for player ID %s, but no saved profile was found." % player_id)
		return
	_refresh_restore_progress_section("No saved progress was found for player ID %s. Double-check the pasted player ID with support and try again." % player_id)

func _clear_pending_sync_jobs() -> void:
	var sync_queue = _get_sync_queue()
	if sync_queue != null and sync_queue.has_method("clear_pending_jobs"):
		sync_queue.clear_pending_jobs()

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(240.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(260.0, viewport_size.y - PANEL_MARGIN * 2.0)
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
	var compact := target_size.x < 860.0 or target_size.y < 540.0
	title_label.add_theme_font_size_override("font_size", 28 if compact else 32)
	subtitle_label.add_theme_font_size_override("font_size", 15 if compact else 17)
	content_columns.add_theme_constant_override("separation", 14 if compact else 18)
	content_columns.custom_minimum_size = Vector2(maxf(target_size.x - 84.0, 320.0), 0.0)
	audio_column.add_theme_constant_override("separation", 12 if compact else 14)
	system_column.add_theme_constant_override("separation", 12 if compact else 14)
	audio_card.custom_minimum_size = Vector2(maxf((target_size.x - 116.0) * 0.5, 220.0), 0.0)
	system_card.custom_minimum_size = Vector2(maxf((target_size.x - 116.0) * 0.5, 220.0), 0.0)
	push_status_label.custom_minimum_size = Vector2(0.0, 72.0 if compact else 84.0)
	enable_push_button.custom_minimum_size = Vector2(0.0, 44.0 if compact else 48.0)
	close_button.custom_minimum_size = Vector2(180.0, 48.0 if compact else 52.0)

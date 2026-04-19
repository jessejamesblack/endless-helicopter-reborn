extends Control

signal closed

const BuildInfoScript = preload("res://systems/build_info.gd")
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const PANEL_DESIRED_SIZE := Vector2(920.0, 560.0)
const PANEL_MARGIN := 18.0

@onready var panel: Panel = $Overlay/Panel
@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var content_columns: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns
@onready var audio_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard
@onready var audio_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn
@onready var master_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/MasterRow/MasterValueRow/MasterSlider
@onready var master_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/MasterRow/MasterValueRow/MasterValueLabel
@onready var music_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/MusicRow/MusicValueRow/MusicSlider
@onready var music_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/MusicRow/MusicValueRow/MusicValueLabel
@onready var sfx_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/SfxRow/SfxValueRow/SfxSlider
@onready var sfx_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/AudioCard/AudioColumn/SfxRow/SfxValueRow/SfxValueLabel
@onready var system_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard
@onready var system_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn
@onready var fire_side_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/FireSideRow/FireSideOption
@onready var hud_side_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HudSideValueLabel
@onready var haptics_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HapticsToggle
@onready var haptics_intensity_slider: HSlider = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HapticsIntensityRow/HapticsIntensityValueRow/HapticsIntensitySlider
@onready var haptics_intensity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/HapticsIntensityRow/HapticsIntensityValueRow/HapticsIntensityValueLabel
@onready var frame_rate_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/FrameRateRow/FrameRateOption
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/PushSection/PushStatusLabel
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/PushSection/EnablePushButton
@onready var screenshot_toggle: CheckButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/ScreenshotToggle
@onready var update_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/BuildInfoSection/UpdateStatusLabel
@onready var build_info_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/BuildInfoSection/BuildInfoLabel
@onready var release_channel_row: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/DebugReleaseChannelRow
@onready var release_channel_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/DebugReleaseChannelRow/DebugReleaseChannelOption
@onready var send_feedback_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/FeedbackSection/FeedbackButtonRow/SendFeedbackButton
@onready var copy_bug_report_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentColumns/SystemCard/SystemColumn/FeedbackSection/FeedbackButtonRow/CopyBugReportButton
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var feedback_screen = $FeedbackScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_populate_side_options()
	_populate_frame_rate_options()
	_populate_release_channel_options()

	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fire_side_option.item_selected.connect(_on_fire_side_selected)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	haptics_intensity_slider.value_changed.connect(_on_haptics_intensity_changed)
	frame_rate_option.item_selected.connect(_on_frame_rate_selected)
	enable_push_button.pressed.connect(_on_enable_push_pressed)
	screenshot_toggle.toggled.connect(_on_screenshot_toggle_toggled)
	release_channel_option.item_selected.connect(_on_release_channel_selected)
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

	var player_profile = _get_player_profile()
	if player_profile != null and player_profile.has_signal("profile_changed"):
		var profile_callback := Callable(self, "_on_profile_changed")
		if not player_profile.is_connected("profile_changed", profile_callback):
			player_profile.connect("profile_changed", profile_callback)

	_sync_from_settings()

func open_menu() -> void:
	_fit_panel_to_viewport()
	_sync_from_settings()
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

func _populate_release_channel_options() -> void:
	if release_channel_option.item_count > 0:
		return
	release_channel_option.add_item("Build Default")
	release_channel_option.add_item("Stable")
	release_channel_option.add_item("Beta")
	release_channel_option.add_item("Dev")

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
	screenshot_toggle.set_block_signals(true)
	release_channel_option.set_block_signals(true)

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
	screenshot_toggle.button_pressed = bool(game_settings.is_achievement_screenshot_sharing_enabled())
	match str(game_settings.get_debug_release_channel_override()):
		"stable":
			release_channel_option.select(1)
		"beta":
			release_channel_option.select(2)
		"dev":
			release_channel_option.select(3)
		_:
			release_channel_option.select(0)

	master_slider.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	fire_side_option.set_block_signals(false)
	haptics_toggle.set_block_signals(false)
	haptics_intensity_slider.set_block_signals(false)
	frame_rate_option.set_block_signals(false)
	screenshot_toggle.set_block_signals(false)
	release_channel_option.set_block_signals(false)

	_update_audio_labels()
	_update_layout_labels()
	_update_haptics_labels()
	_update_push_status()
	_update_support_labels()

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

func _on_screenshot_toggle_toggled(enabled: bool) -> void:
	var game_settings = _get_game_settings()
	if game_settings != null and game_settings.has_method("set_achievement_screenshot_sharing_enabled"):
		game_settings.set_achievement_screenshot_sharing_enabled(enabled)

func _on_release_channel_selected(index: int) -> void:
	var value := ""
	match index:
		1:
			value = "stable"
		2:
			value = "beta"
		3:
			value = "dev"
	var game_settings = _get_game_settings()
	if game_settings != null and game_settings.has_method("set_debug_release_channel_override"):
		game_settings.set_debug_release_channel_override(value)
	_update_support_labels()

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

func _on_push_diagnostics_changed(_status: Dictionary) -> void:
	_update_push_status()

func _on_profile_changed(_summary: Dictionary) -> void:
	_update_push_status()

func _on_update_state_changed(_state: Dictionary) -> void:
	_update_support_labels()

func _update_push_status() -> void:
	var player_profile = _get_player_profile()
	var reminders_enabled: bool = player_profile != null and player_profile.has_method("are_daily_reminders_enabled") and bool(player_profile.are_daily_reminders_enabled())

	var push_notifications = _get_push_notifications()
	if push_notifications == null or not push_notifications.has_method("get_diagnostics_text"):
		push_status_label.text = "Daily reminders: %s\nPush permission: Unavailable here\nPush unavailable: runtime service not loaded." % ("On" if reminders_enabled else "Off")
		enable_push_button.text = "Turn Notifications %s" % ("Off" if reminders_enabled else "On")
		enable_push_button.disabled = player_profile == null
		return

	var diagnostics := _get_push_diagnostics()
	var permission_granted := bool(diagnostics.get("permission_granted", false))
	var can_request_permission := bool(diagnostics.get("is_android", false))
	var permission_text := "Granted" if permission_granted else ("Not granted" if can_request_permission else "Unavailable here")
	push_status_label.text = "Daily reminders: %s\nPush permission: %s\n%s" % [
		"On" if reminders_enabled else "Off",
		permission_text,
		push_notifications.get_diagnostics_text(),
	]
	if not reminders_enabled:
		enable_push_button.text = "Turn Notifications On"
	elif can_request_permission and not permission_granted:
		enable_push_button.text = "Enable Push Permission"
	else:
		enable_push_button.text = "Turn Notifications Off"
	enable_push_button.disabled = player_profile == null

func _update_support_labels() -> void:
	update_status_label.text = "Update Status: %s" % _get_update_status_text()
	build_info_label.text = "Version: %s\nBuild: %s\nChannel: %s" % [
		BuildInfoScript.get_version_label(),
		str(BuildInfoScript.BUILD_SHA),
		_get_effective_release_channel_label(),
	]
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

func _on_send_feedback_pressed() -> void:
	if feedback_screen != null and feedback_screen.has_method("open_menu"):
		feedback_screen.open_menu()

func _on_copy_bug_report_pressed() -> void:
	var reporter = get_node_or_null("/root/ErrorReporter")
	var report_text := "Build: %s" % BuildInfoScript.get_debug_label()
	if reporter != null and reporter.has_method("build_bug_report_text"):
		report_text = reporter.build_bug_report_text("bug")
	DisplayServer.clipboard_set(report_text)

func _get_app_update_manager():
	return get_node_or_null("/root/AppUpdateManager")

func _get_push_diagnostics() -> Dictionary:
	var push_notifications = _get_push_notifications()
	if push_notifications == null or not push_notifications.has_method("get_diagnostics"):
		return {}
	return push_notifications.get_diagnostics()

func _on_close_pressed() -> void:
	close_menu()

func _get_game_settings():
	return get_node_or_null("/root/GameSettings")

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

func _get_player_profile():
	return get_node_or_null("/root/PlayerProfile")

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
	audio_column.add_theme_constant_override("separation", 12 if compact else 14)
	system_column.add_theme_constant_override("separation", 12 if compact else 14)
	audio_card.custom_minimum_size = Vector2(0.0, 0.0)
	system_card.custom_minimum_size = Vector2(0.0, 0.0)
	close_button.custom_minimum_size = Vector2(180.0, 48.0 if compact else 52.0)

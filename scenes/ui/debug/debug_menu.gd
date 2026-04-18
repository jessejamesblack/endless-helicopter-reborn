extends Control

signal closed

const PANEL_DESIRED_SIZE := Vector2(980.0, 600.0)
const PANEL_MARGIN := 18.0

@onready var panel: Panel = $Overlay/Panel
@onready var panel_margin: MarginContainer = $Overlay/Panel/MarginContainer
@onready var root_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var debug_columns: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns
@onready var summary_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard
@onready var details_card: PanelContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard
@onready var summary_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn
@onready var details_column: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn
@onready var summary_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn/SummaryHeader
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn/PushStatusLabel
@onready var summary_button_row: VBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn/ButtonRow
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn/ButtonRow/EnablePushButton
@onready var retry_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/SummaryCard/SummaryColumn/ButtonRow/RetryPushButton
@onready var details_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/PushDebugHeader
@onready var status_grid: GridContainer = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid
@onready var platform_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PlatformValueLabel
@onready var plugin_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PluginValueLabel
@onready var compat_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/CompatValueLabel
@onready var firebase_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/FirebaseValueLabel
@onready var permission_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PermissionValueLabel
@onready var player_identity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/PlayerIdentityValueLabel
@onready var device_identity_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/DeviceIdentityValueLabel
@onready var device_id_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/DeviceIdValueLabel
@onready var token_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/TokenValueLabel
@onready var response_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/ResponseValueLabel
@onready var registering_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/StatusGrid/RegisteringValueLabel
@onready var last_message_header: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/LastMessageHeader
@onready var last_message_value_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugColumns/DetailsCard/DetailsColumn/LastMessageValueLabel
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	enable_push_button.pressed.connect(_on_enable_push_pressed)
	retry_push_button.pressed.connect(_on_retry_push_pressed)
	close_button.pressed.connect(_on_close_pressed)

	var push_notifications = _get_push_notifications()
	if push_notifications != null and push_notifications.has_signal("diagnostics_changed"):
		var diagnostics_callback := Callable(self, "_on_push_diagnostics_changed")
		if not push_notifications.is_connected("diagnostics_changed", diagnostics_callback):
			push_notifications.connect("diagnostics_changed", diagnostics_callback)

	_update_push_status()

func open_menu() -> void:
	_fit_panel_to_viewport()
	_update_push_status()
	visible = true
	close_button.grab_focus()

func close_menu(emit_closed_signal: bool = true) -> void:
	visible = false
	if emit_closed_signal:
		closed.emit()

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
	player_identity_value_label.text = str(status.get("player_identity_source", "unknown"))
	device_identity_value_label.text = str(status.get("device_identity_source", "unknown"))
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

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

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
	var card_panel := summary_card.get_theme_stylebox("panel") as StyleBoxFlat
	var details_panel := details_card.get_theme_stylebox("panel") as StyleBoxFlat

	panel_margin.add_theme_constant_override("margin_left", 20 if compact else 26)
	panel_margin.add_theme_constant_override("margin_top", 18 if compact else 24)
	panel_margin.add_theme_constant_override("margin_right", 20 if compact else 26)
	panel_margin.add_theme_constant_override("margin_bottom", 18 if compact else 24)
	root_column.add_theme_constant_override("separation", 12 if compact else 16)
	title_label.add_theme_font_size_override("font_size", 28 if compact else 32)
	subtitle_label.add_theme_font_size_override("font_size", 14 if compact else 17)
	debug_columns.add_theme_constant_override("separation", 12 if compact else 18)
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

	if card_panel != null:
		card_panel.content_margin_left = 14.0 if compact else 18.0
		card_panel.content_margin_top = 14.0 if compact else 18.0
		card_panel.content_margin_right = 14.0 if compact else 18.0
		card_panel.content_margin_bottom = 14.0 if compact else 18.0
	if details_panel != null and details_panel != card_panel:
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

func _get_debug_value_labels() -> Array[Label]:
	return [
		platform_value_label,
		plugin_value_label,
		compat_value_label,
		firebase_value_label,
		permission_value_label,
		player_identity_value_label,
		device_identity_value_label,
		device_id_value_label,
		token_value_label,
		response_value_label,
		registering_value_label,
	]

func _get_debug_key_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for child in status_grid.get_children():
		if child is Label and not _get_debug_value_labels().has(child):
			labels.append(child as Label)
	return labels

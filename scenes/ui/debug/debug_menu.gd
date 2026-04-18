extends Control

signal closed

const PANEL_DESIRED_SIZE := Vector2(720.0, 416.0)
const PANEL_MARGIN := 24.0

@onready var panel: Panel = $Overlay/Panel
@onready var content_scroll: ScrollContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll
@onready var details_scroll: ScrollContainer = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugCard/DebugColumns/DetailsColumn/DetailsScroll
@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugCard/DebugColumns/SummaryColumn/PushStatusLabel
@onready var push_debug_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugCard/DebugColumns/DetailsColumn/DetailsScroll/PushDebugLabel
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugCard/DebugColumns/SummaryColumn/ButtonRow/EnablePushButton
@onready var retry_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/DebugCard/DebugColumns/SummaryColumn/ButtonRow/RetryPushButton
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
	content_scroll.scroll_vertical = 0
	details_scroll.scroll_vertical = 0
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
		push_debug_label.text = "Push runtime service missing."
		enable_push_button.disabled = true
		retry_push_button.disabled = true
		return

	if push_notifications.has_method("get_diagnostics_text"):
		push_status_label.text = push_notifications.get_diagnostics_text()
	else:
		push_status_label.text = "Push diagnostics text unavailable."

	if push_notifications.has_method("get_debug_report"):
		push_debug_label.text = push_notifications.get_debug_report()
	else:
		push_debug_label.text = "Push debug report unavailable."

	var is_android := OS.get_name() == "Android"
	enable_push_button.disabled = not is_android
	retry_push_button.disabled = not is_android

func _on_close_pressed() -> void:
	close_menu()

func _get_push_notifications():
	return get_node_or_null("/root/PushNotifications")

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(220.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(220.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(PANEL_DESIRED_SIZE.x, max_size.x),
		min(PANEL_DESIRED_SIZE.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

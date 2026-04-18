extends Control

signal closed

@onready var push_status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugCard/DebugColumns/SummaryColumn/PushStatusLabel
@onready var push_debug_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DebugCard/DebugColumns/DetailsColumn/PushDebugLabel
@onready var enable_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/DebugCard/DebugColumns/SummaryColumn/ButtonRow/EnablePushButton
@onready var retry_push_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/DebugCard/DebugColumns/SummaryColumn/ButtonRow/RetryPushButton
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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

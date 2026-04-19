extends Button
class_name TouchScrollButton

signal touch_activated

const DEFAULT_DRAG_THRESHOLD := 14.0

@export var drag_threshold: float = DEFAULT_DRAG_THRESHOLD

var _press_position: Vector2 = Vector2.ZERO
var _pointer_active: bool = false
var _dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(event.position, event.pressed)
		return
	if event is InputEventScreenDrag and _pointer_active:
		_update_drag_state(event.position)
		return
	if event is InputEventMouseMotion and _pointer_active:
		_update_drag_state(event.position)

func _pressed() -> void:
	var was_dragging := _dragging
	_pointer_active = false
	_dragging = false
	if was_dragging:
		return
	touch_activated.emit()

func _handle_touch(position: Vector2, pressed: bool) -> void:
	if pressed:
		_pointer_active = true
		_dragging = false
		_press_position = position
		return
	_pointer_active = false

func _update_drag_state(position: Vector2) -> void:
	if _dragging:
		return
	if position.distance_to(_press_position) >= drag_threshold:
		_dragging = true
		release_focus()

extends Node2D

const FLOAT_DURATION_SECONDS := 0.72

@onready var label: Label = $Label
var _pending_text: String = "+0"
var _pending_is_score: bool = true

func configure(text_value: String, is_score: bool = true) -> void:
	_pending_text = text_value
	_pending_is_score = is_score
	_apply_label_state()

func _ready() -> void:
	_apply_label_state()
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 36.0, FLOAT_DURATION_SECONDS)
	tween.parallel().tween_property(self, "modulate:a", 0.0, FLOAT_DURATION_SECONDS)
	tween.finished.connect(queue_free)

func _apply_label_state() -> void:
	if label == null:
		return

	label.text = _pending_text
	if _pending_is_score:
		label.add_theme_color_override("font_color", Color(0.99, 0.87, 0.58, 1.0))
		label.add_theme_constant_override("outline_size", 5)
	else:
		label.add_theme_color_override("font_color", Color(0.79, 0.92, 1.0, 1.0))
		label.add_theme_constant_override("outline_size", 4)

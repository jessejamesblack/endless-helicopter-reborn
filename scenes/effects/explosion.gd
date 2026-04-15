extends Sprite2D

@export var normal_peak_scale: float = 4.6
@export var large_peak_scale: float = 7.2
@export var normal_expand_time: float = 0.42
@export var large_expand_time: float = 0.52
@export var normal_fade_time: float = 0.72
@export var large_fade_time: float = 0.92

var _is_large: bool = false

func configure(is_large: bool = false) -> void:
    _is_large = is_large

func _ready() -> void:
    z_index = 20
    scale = Vector2.ONE * (0.2 if _is_large else 0.14)
    modulate = Color(1.0, 0.92, 0.74, 1.0)
    rotation = randf_range(-0.22, 0.22)

    var peak_scale := Vector2.ONE * (large_peak_scale if _is_large else normal_peak_scale)
    var expand_time := large_expand_time if _is_large else normal_expand_time
    var fade_time := large_fade_time if _is_large else normal_fade_time

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "scale", peak_scale, expand_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate", Color(1.0, 0.54, 0.18, 0.0), fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "rotation", rotation + randf_range(-0.35, 0.35), expand_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    await tween.finished
    queue_free()

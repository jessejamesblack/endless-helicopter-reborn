extends Sprite2D

func _ready() -> void:
    # Simple procedural explosion animation using a Tween
    scale = Vector2.ZERO
    var tween = create_tween()
    tween.set_parallel(true)
    # Pop the scale up quickly, fade the alpha out slowly
    tween.tween_property(self, "scale", Vector2(3.0, 3.0), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    
    await tween.finished
    queue_free()
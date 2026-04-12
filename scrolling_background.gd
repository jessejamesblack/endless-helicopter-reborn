extends Parallax2D

@export var scroll_speed: float = 150.0

func _ready() -> void:
    # Parallax2D has built-in autoscrolling! We just set the vector once.
    autoscroll = Vector2(-scroll_speed, 0)
extends Parallax2D

@export var scroll_speed: float = 150.0

func _ready() -> void:
    # Parallax2D has built-in autoscrolling! We just set the vector once.
    autoscroll = Vector2(-scroll_speed, 0)
    
    # Increase the number of times the background repeats to cover ultra-wide screens
    repeat_times = 4

func _process(_delta: float) -> void:
    var multiplier = 1.0
    var main = get_tree().current_scene as Main
    if main:
        if main.is_crashed:
            autoscroll = Vector2.ZERO
            return
        multiplier = main.speed_multiplier
    autoscroll = Vector2(-scroll_speed * multiplier, 0)
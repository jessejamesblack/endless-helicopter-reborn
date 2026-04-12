extends Parallax2D

@export var scroll_speed: float = 150.0

func _ready() -> void:
    # Parallax2D has built-in autoscrolling! We just set the vector once.
    autoscroll = Vector2(-scroll_speed, 0)
    
    # Increase the number of times the background repeats to cover ultra-wide screens
    repeat_times = 4

func _process(_delta: float) -> void:
    var multiplier = 1.0
    if "speed_multiplier" in get_tree().current_scene:
        multiplier = get_tree().current_scene.speed_multiplier
    autoscroll = Vector2(-scroll_speed * multiplier, 0)
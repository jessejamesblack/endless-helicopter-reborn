extends Parallax2D

@export var scroll_speed: float = 150.0
@export var height_fill_ratio: float = 1.0

@onready var background_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    _configure_background_sprite()
    # Parallax2D has built-in autoscrolling! We just set the vector once.
    autoscroll = Vector2(-scroll_speed, 0)
    
    # Increase the number of times the background repeats to cover ultra-wide screens
    repeat_times = 4

func _process(_delta: float) -> void:
    var multiplier = 1.0
    var main := get_tree().current_scene
    if main != null:
        if main.is_crashed:
            autoscroll = Vector2.ZERO
            return
        multiplier = main.speed_multiplier
    autoscroll = Vector2(-scroll_speed * multiplier, 0)

func _configure_background_sprite() -> void:
    if background_sprite == null or background_sprite.texture == null:
        return

    var texture_size := background_sprite.texture.get_size()
    if texture_size.y <= 0.0:
        return

    var viewport_size := get_viewport_rect().size
    var target_height := viewport_size.y * height_fill_ratio
    var scale_factor := target_height / texture_size.y

    background_sprite.scale = Vector2(scale_factor, scale_factor)
    background_sprite.position = Vector2((texture_size.x * scale_factor) * 0.5, viewport_size.y * 0.5)
    repeat_size = Vector2(texture_size.x * scale_factor, 0.0)

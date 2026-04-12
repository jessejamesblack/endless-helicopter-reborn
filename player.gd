extends CharacterBody2D

@export var jump_velocity: float = -400.0
@export var tilt_speed: float = 5.0
@export var max_tilt: float = 0.5

var missile_scene: PackedScene = preload("res://missile.tscn")

# Get gravity from project settings so it syncs with standard physics behavior
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
    # Apply constant downward gravity
    velocity.y += gravity * delta
    
    # Tilt the helicopter based on vertical velocity
    var target_tilt = clamp(velocity.y / 800.0, -max_tilt, max_tilt)
    rotation = lerp_angle(rotation, target_tilt, tilt_speed * delta)

    move_and_slide()
    
    # End game if the player flies off the top or bottom of the screen
    if global_position.y < 0 or global_position.y > get_viewport_rect().size.y:
        die()

func die() -> void:
    if get_tree().current_scene.has_method("trigger_crash"):
        get_tree().current_scene.trigger_crash(global_position)
    queue_free()

func fire_missile() -> void:
    if missile_scene:
        var missile = missile_scene.instantiate()
        # Spawn slightly in front of the helicopter
        missile.global_position = global_position + Vector2(40, 0)
        get_tree().current_scene.add_child(missile)

func _unhandled_input(event: InputEvent) -> void:
    # Fire missile on 'X' key
    if event is InputEventKey and event.keycode == KEY_X and event.pressed and not event.echo:
        fire_missile()
        
    # Jump on 'ui_accept' (Spacebar), left mouse click, or screen touch
    if event.is_action_pressed("ui_accept") or \
       (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
       (event is InputEventScreenTouch and event.pressed):
        velocity.y = jump_velocity
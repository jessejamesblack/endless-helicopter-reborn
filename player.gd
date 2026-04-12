extends CharacterBody2D

@export var jump_velocity: float = -400.0
@export var tilt_speed: float = 5.0
@export var max_tilt: float = 0.5

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
        print("Crash! Game Over.")
        get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    # Jump on 'ui_accept' (Spacebar), left mouse click, or screen touch
    if event.is_action_pressed("ui_accept") or \
       (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
       (event is InputEventScreenTouch and event.pressed):
        velocity.y = jump_velocity
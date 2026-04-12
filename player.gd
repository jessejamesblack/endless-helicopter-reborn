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

func _draw() -> void:
    # Main body
    draw_circle(Vector2.ZERO, 20.0, Color.CORNFLOWER_BLUE)
    # Cockpit window
    draw_circle(Vector2(8, -5), 10.0, Color.ALICE_BLUE)
    # Tail boom
    draw_rect(Rect2(-45, -5, 30, 10), Color.DARK_GRAY)
    # Tail rotor
    draw_rect(Rect2(-50, -15, 10, 30), Color.INDIAN_RED)
    # Main rotor mast and blades
    draw_rect(Rect2(-3, -30, 6, 15), Color.DARK_GRAY)
    draw_rect(Rect2(-35, -35, 70, 5), Color.LIGHT_GRAY)

func _unhandled_input(event: InputEvent) -> void:
    # Jump on 'ui_accept' (Spacebar), left mouse click, or screen touch
    if event.is_action_pressed("ui_accept") or \
       (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
       (event is InputEventScreenTouch and event.pressed):
        velocity.y = jump_velocity
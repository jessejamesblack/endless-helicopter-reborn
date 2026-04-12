extends Area2D

@export var move_speed: float = 200.0

func _ready() -> void:
    # Listen for collisions with physics bodies (like your Player)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    position.x -= move_speed * delta
    
    # Delete the obstacle once it is safely off the left side of the screen
    if position.x < -200:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player":
        print("Crash! Game Over.")
        get_tree().reload_current_scene()
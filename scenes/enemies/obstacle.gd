extends Area2D

@export var move_speed: float = 200.0
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")

func _ready() -> void:
    add_to_group("hostile_units")
    # Listen for collisions with physics bodies (like your Player)
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    var current_speed = move_speed
    var main := get_tree().current_scene
    if main != null:
        if main.is_crashed: return
        current_speed *= main.speed_multiplier
        
    position.x -= current_speed * delta
    
    # Check global_position so it accounts for the Spawner's starting location
    if global_position.x < -200:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player":
        if body.has_method("die"):
            body.die()

func destroy(_skip_special: bool = false) -> void:
    # Spawn an explosion exactly where the obstacle was
    var explosion = explosion_scene.instantiate()
    explosion.global_position = global_position
    if explosion.has_method("configure"):
        explosion.configure(false)
    get_tree().current_scene.add_child(explosion)
    
    queue_free()

func get_destroy_score() -> int:
    return 50

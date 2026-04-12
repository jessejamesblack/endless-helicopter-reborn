extends Node2D

@export var obstacle_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_y_min: float = 100.0
@export var spawn_y_max: float = 500.0

var _timer: float = 0.0

func _process(delta: float) -> void:
    _timer += delta
    if _timer >= spawn_interval:
        _timer = 0.0
        spawn_obstacle()

func spawn_obstacle() -> void:
    if obstacle_scene == null:
        push_error("Obstacle scene is not assigned in the Spawner!")
        return
        
    var obstacle = obstacle_scene.instantiate()
    # Randomize the Y position between our min and max values
    obstacle.position = Vector2(global_position.x, randf_range(spawn_y_min, spawn_y_max))
    add_child(obstacle)
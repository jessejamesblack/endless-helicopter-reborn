extends Node2D

@export var obstacle_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://missile_pickup.tscn")
@export var spawn_interval: float = 2.0
@export var spawn_y_min: float = 100.0
@export var spawn_y_max: float = 500.0

var _timer: float = 0.0

func _process(delta: float) -> void:
    _timer += delta
    if _timer >= spawn_interval:
        _timer -= spawn_interval

        # 20% chance to spawn a missile pickup
        if randf() < 0.2:
            spawn_item(pickup_scene)
        else:
            spawn_item(obstacle_scene)

func spawn_item(scene_to_spawn: PackedScene) -> void:
    if scene_to_spawn == null:
        push_error("Scene is not assigned in the Spawner!")
        return
        
    var item = scene_to_spawn.instantiate()
    # Randomize the Y position between our min and max values
    item.position = Vector2(0, randf_range(spawn_y_min, spawn_y_max))
    add_child(item)
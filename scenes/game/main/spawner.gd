extends Node2D

@export var obstacle_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://scenes/pickups/missile_pickup.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy_unit.tscn")
@export var spawn_interval: float = 2.0
@export var spawn_y_min: float = 100.0
@export var spawn_y_max: float = 500.0

var _timer: float = 0.0

const ENEMY_VARIANTS := [
	{"kind": "large_spiky_rock", "weight": 0.55},
	{"kind": "stationary_turret", "weight": 0.15},
	{"kind": "alien_drone", "weight": 0.15},
	{"kind": "rock_core", "weight": 0.15},
]

func _process(delta: float) -> void:
    var current_interval = spawn_interval
    var main = get_tree().current_scene as Main
    if main:
        if main.is_crashed: return
        current_interval /= main.speed_multiplier

    _timer += delta
    if _timer >= current_interval:
        _timer -= current_interval

        # 20% chance to spawn a missile pickup
        if randf() < 0.2:
            spawn_scene(pickup_scene)
        else:
            spawn_enemy()

func spawn_enemy() -> void:
    var roll := randf()
    var running_total := 0.0

    for variant in ENEMY_VARIANTS:
        running_total += float(variant["weight"])
        if roll <= running_total:
            var kind := String(variant["kind"])
            if kind == "large_spiky_rock":
                spawn_scene(obstacle_scene)
            else:
                spawn_enemy_variant(kind)
            return

    spawn_scene(obstacle_scene)

func spawn_scene(scene_to_spawn: PackedScene) -> void:
    if scene_to_spawn == null:
        push_error("Scene is not assigned in the Spawner!")
        return
        
    var item = scene_to_spawn.instantiate()
    # Randomize the Y position between our min and max values
    item.position = Vector2(0, randf_range(spawn_y_min, spawn_y_max))
    add_child(item)

func spawn_enemy_variant(kind: String) -> void:
    if enemy_scene == null:
        push_error("Enemy scene is not assigned in the Spawner!")
        return

    var enemy = enemy_scene.instantiate()
    enemy.position = Vector2(0, randf_range(spawn_y_min, spawn_y_max))
    if enemy.has_method("configure"):
        enemy.configure(kind)
    add_child(enemy)

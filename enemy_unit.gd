extends Area2D

const ENEMY_DATA := {
	"stationary_turret": {
		"region": Rect2(1149, 1134, 242, 266),
		"scale": Vector2(0.48, 0.48),
		"speed": 165.0,
		"collision_radius": 44.0,
		"collision_offset": Vector2(0, 20),
		"fire_interval": 2.35,
		"projectile_kind": "turret_round",
		"projectile_speed": 420.0,
		"fire_offset": Vector2(-58, -44),
		"score": 80,
	},
	"alien_drone": {
		"region": Rect2(1623, 1192, 206, 180),
		"scale": Vector2(0.58, 0.58),
		"speed": 235.0,
		"collision_radius": 34.0,
		"collision_offset": Vector2(0, 2),
		"fire_interval": 1.9,
		"projectile_kind": "player_missile",
		"projectile_speed": 520.0,
		"fire_offset": Vector2(-38, 0),
		"bob_amplitude": 24.0,
		"bob_speed": 4.1,
		"score": 90,
	},
	"rock_core": {
		"region": Rect2(2393, 1123, 351, 277),
		"scale": Vector2(0.42, 0.42),
		"speed": 180.0,
		"collision_radius": 58.0,
		"collision_offset": Vector2(0, 0),
		"rotation_speed": 0.6,
		"score": 100,
	},
}

@export_enum("stationary_turret", "alien_drone", "rock_core") var enemy_kind: String = "stationary_turret"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var enemy_projectile_scene: PackedScene = preload("res://enemy_projectile.tscn")
var explosion_scene: PackedScene = preload("res://explosion.tscn")

var _base_y: float = 0.0
var _fire_timer: float = 0.0
var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	apply_enemy_config()

func configure(kind: String) -> void:
	enemy_kind = kind
	if is_inside_tree():
		_base_y = position.y
		apply_enemy_config()

func apply_enemy_config() -> void:
	var data: Dictionary = ENEMY_DATA.get(enemy_kind, ENEMY_DATA["stationary_turret"])
	sprite.region_rect = data["region"]
	sprite.scale = data["scale"]

	var shape := CircleShape2D.new()
	shape.radius = float(data.get("collision_radius", 40.0))
	collision_shape.shape = shape
	collision_shape.position = data.get("collision_offset", Vector2.ZERO)

	var fire_interval := float(data.get("fire_interval", 999.0))
	_fire_timer = randf_range(0.35, fire_interval)

func _process(delta: float) -> void:
	var data: Dictionary = ENEMY_DATA.get(enemy_kind, ENEMY_DATA["stationary_turret"])
	var current_speed := float(data.get("speed", 200.0))
	var main := get_tree().current_scene as Main
	if main:
		if main.is_crashed:
			return
		current_speed *= main.speed_multiplier

	position.x -= current_speed * delta
	_time_alive += delta

	if data.has("bob_amplitude") and data.has("bob_speed"):
		var bob_speed := float(data["bob_speed"])
		var bob_amplitude := float(data["bob_amplitude"])
		position.y = _base_y + sin(_time_alive * bob_speed) * bob_amplitude

	if data.has("rotation_speed"):
		sprite.rotation += float(data["rotation_speed"]) * delta

	if data.has("fire_interval") and data.has("projectile_kind"):
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			fire_projectile(data)
			var fire_interval := float(data["fire_interval"])
			_fire_timer = fire_interval + randf_range(-0.25, 0.35)

	if global_position.x < -250:
		queue_free()

func fire_projectile(data: Dictionary) -> void:
	var projectile = enemy_projectile_scene.instantiate()
	projectile.global_position = global_position + data.get("fire_offset", Vector2(-40, 0))
	projectile.rotation = PI
	projectile.move_speed = float(data.get("projectile_speed", 480.0))
	projectile.configure(data.get("projectile_kind", "player_missile"))
	get_tree().current_scene.add_child(projectile)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("die"):
		body.die()

func destroy() -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	queue_free()

func get_destroy_score() -> int:
	var data: Dictionary = ENEMY_DATA.get(enemy_kind, ENEMY_DATA["stationary_turret"])
	return int(data.get("score", 80))

extends Area2D

var ENEMY_DATA := {
	"stationary_turret": {
		"region": Rect2(1149, 1134, 242, 266),
		"scale": Vector2(0.48, 0.48),
		"speed": 165.0,
		"collision_offset": Vector2(0, 8),
		"collision_polygon": PackedVector2Array([
			Vector2(-44, -50),
			Vector2(38, -50),
			Vector2(46, -28),
			Vector2(36, -10),
			Vector2(20, -2),
			Vector2(20, 18),
			Vector2(34, 50),
			Vector2(18, 64),
			Vector2(-18, 64),
			Vector2(-34, 48),
			Vector2(-22, 18),
			Vector2(-22, -2),
			Vector2(-36, -12),
			Vector2(-44, -28),
		]),
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
		"collision_offset": Vector2(0, 2),
		"collision_polygon": PackedVector2Array([
			Vector2(-48, -6),
			Vector2(-38, -26),
			Vector2(-12, -36),
			Vector2(18, -34),
			Vector2(42, -20),
			Vector2(52, -4),
			Vector2(48, 14),
			Vector2(34, 30),
			Vector2(10, 40),
			Vector2(-12, 38),
			Vector2(-34, 28),
			Vector2(-48, 10),
		]),
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
		"collision_offset": Vector2(0, 0),
		"collision_polygon": PackedVector2Array([
			Vector2(-6, -56),
			Vector2(18, -54),
			Vector2(42, -44),
			Vector2(62, -20),
			Vector2(72, 4),
			Vector2(58, 28),
			Vector2(40, 48),
			Vector2(14, 58),
			Vector2(-10, 56),
			Vector2(-36, 46),
			Vector2(-58, 22),
			Vector2(-70, -2),
			Vector2(-58, -28),
			Vector2(-34, -46),
		]),
		"rotation_speed": 0.6,
		"score": 100,
	},
}

@export_enum("stationary_turret", "alien_drone", "rock_core") var enemy_kind: String = "stationary_turret"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

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
	sprite.rotation = 0.0

	collision_polygon.polygon = data["collision_polygon"]
	collision_polygon.position = data.get("collision_offset", Vector2.ZERO)
	collision_polygon.rotation = 0.0

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
		collision_polygon.rotation = sprite.rotation

	if data.has("fire_interval") and data.has("projectile_kind"):
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			fire_projectile(data)
			var fire_interval := float(data["fire_interval"])
			_fire_timer = fire_interval + randf_range(-0.25, 0.35)

	if global_position.x < -250:
		queue_free()

	if not data.has("rotation_speed"):
		collision_polygon.rotation = 0.0

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

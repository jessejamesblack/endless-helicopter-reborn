extends Area2D

var ENEMY_DATA := {
	"stationary_turret": {
		"region": Rect2(1149, 1134, 242, 266),
		"scale": Vector2(0.34, 0.34),
		"speed": 150.0,
		"collision_offset": Vector2(0, 10),
		"collision_polygon": PackedVector2Array([
			Vector2(-24, -30),
			Vector2(18, -30),
			Vector2(24, -14),
			Vector2(20, 2),
			Vector2(24, 24),
			Vector2(12, 34),
			Vector2(-12, 34),
			Vector2(-24, 22),
			Vector2(-20, 0),
			Vector2(-18, -14),
		]),
		"fire_interval": 2.75,
		"projectile_kind": "turret_round",
		"projectile_speed": 285.0,
		"fire_offset": Vector2(-30, -18),
		"score": 85,
	},
	"alien_drone": {
		"region": Rect2(1623, 1192, 206, 180),
		"scale": Vector2(0.54, 0.54),
		"speed": 228.0,
		"collision_offset": Vector2(0, 2),
		"collision_polygon": PackedVector2Array([
			Vector2(-42, -6),
			Vector2(-34, -22),
			Vector2(-10, -32),
			Vector2(16, -30),
			Vector2(38, -18),
			Vector2(46, -2),
			Vector2(42, 14),
			Vector2(28, 26),
			Vector2(8, 34),
			Vector2(-12, 32),
			Vector2(-30, 24),
			Vector2(-42, 8),
		]),
		"fire_interval": 2.05,
		"projectile_kind": "player_missile",
		"projectile_speed": 500.0,
		"fire_offset": Vector2(-36, 0),
		"bob_amplitude": 18.0,
		"bob_speed": 3.9,
		"score": 90,
	},
	"glowing_rock": {
		"region": Rect2(2393, 1123, 351, 277),
		"scale": Vector2(0.39, 0.39),
		"speed": 172.0,
		"collision_offset": Vector2(0, 0),
		"collision_polygon": PackedVector2Array([
			Vector2(-8, -48),
			Vector2(16, -46),
			Vector2(36, -38),
			Vector2(52, -18),
			Vector2(60, 2),
			Vector2(48, 24),
			Vector2(34, 40),
			Vector2(12, 48),
			Vector2(-10, 46),
			Vector2(-30, 38),
			Vector2(-48, 18),
			Vector2(-58, -2),
			Vector2(-48, -24),
			Vector2(-26, -40),
		]),
		"rotation_speed": 0.6,
		"score": 110,
	},
}

@export_enum("stationary_turret", "alien_drone", "glowing_rock", "rock_core") var enemy_kind: String = "stationary_turret"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var fire_sound: AudioStreamPlayer = $FireSound

var enemy_projectile_scene: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")

var _base_y: float = 0.0
var _fire_timer: float = 0.0
var _time_alive: float = 0.0

func _ready() -> void:
	add_to_group("hostile_units")
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	apply_enemy_config()

func configure(kind: String) -> void:
	enemy_kind = _resolve_enemy_kind(kind)
	if is_inside_tree():
		_base_y = position.y
		apply_enemy_config()

func apply_enemy_config() -> void:
	enemy_kind = _resolve_enemy_kind(enemy_kind)
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
	var data: Dictionary = ENEMY_DATA.get(_resolve_enemy_kind(enemy_kind), ENEMY_DATA["stationary_turret"])
	var current_speed := float(data.get("speed", 200.0))
	var main := get_tree().current_scene
	if main != null:
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
	_play_fire_sound()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("die"):
		body.die()

func destroy(skip_special: bool = false) -> void:
	if _resolve_enemy_kind(enemy_kind) == "glowing_rock" and not skip_special:
		var main := get_tree().current_scene
		if main != null and main.has_method("trigger_glowing_rock_blast"):
			main.trigger_glowing_rock_blast(global_position, self)
			return

	_spawn_explosion()
	queue_free()

func get_destroy_score() -> int:
	var data: Dictionary = ENEMY_DATA.get(_resolve_enemy_kind(enemy_kind), ENEMY_DATA["stationary_turret"])
	return int(data.get("score", 80))

func _play_fire_sound() -> void:
	if fire_sound == null:
		return

	if fire_sound.playing:
		fire_sound.stop()

	fire_sound.pitch_scale = 0.88 if enemy_kind == "stationary_turret" else 1.06
	fire_sound.play()

func _resolve_enemy_kind(kind: String) -> String:
	if kind == "rock_core":
		return "glowing_rock"
	if ENEMY_DATA.has(kind):
		return kind
	return "stationary_turret"

func _spawn_explosion(is_large: bool = false) -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	if explosion.has_method("configure"):
		explosion.configure(is_large)
	get_tree().current_scene.add_child(explosion)

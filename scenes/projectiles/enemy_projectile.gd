extends Area2D

var PROJECTILE_DATA := {
	"player_missile": {
		"region": Rect2(435, 998, 289, 102),
		"scale": Vector2(0.08191126, 0.055045888),
		"collision_polygon": PackedVector2Array([
			Vector2(-12, -1),
			Vector2(-9, -3),
			Vector2(-1, -3),
			Vector2(7, -3),
			Vector2(11, -2),
			Vector2(12, 0),
			Vector2(11, 2),
			Vector2(7, 3),
			Vector2(-1, 3),
			Vector2(-9, 3),
			Vector2(-12, 1),
		]),
		"score": 20,
		"homing_enabled": false,
		"turn_rate": 0.0,
	},
	"turret_round": {
		"region": Rect2(782, 1017, 242, 55),
		"scale": Vector2(0.118, 0.118),
		"collision_polygon": PackedVector2Array([
			Vector2(-16, -2),
			Vector2(-18, -5),
			Vector2(-8, -4),
			Vector2(-2, -6),
			Vector2(12, -4),
			Vector2(16, -2),
			Vector2(16, 2),
			Vector2(12, 4),
			Vector2(-2, 6),
			Vector2(-8, 4),
			Vector2(-18, 5),
			Vector2(-16, 2),
		]),
		"score": 25,
		"homing_enabled": true,
		"turn_rate": 1.55,
	},
}

@export_enum("player_missile", "turret_round") var projectile_kind: String = "player_missile"
@export var move_speed: float = 480.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")
var direction: Vector2 = Vector2.LEFT
var homing_enabled: bool = false
var homing_turn_rate: float = 0.0

func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	direction = Vector2.RIGHT.rotated(rotation).normalized()
	if direction.length_squared() == 0.0:
		direction = Vector2.LEFT
	apply_projectile_config()

func configure(kind: String) -> void:
	projectile_kind = kind
	if is_inside_tree():
		apply_projectile_config()

func apply_projectile_config() -> void:
	var data: Dictionary = PROJECTILE_DATA.get(projectile_kind, PROJECTILE_DATA["player_missile"])
	sprite.region_rect = data["region"]
	sprite.scale = data["scale"]
	collision_polygon.polygon = data["collision_polygon"]
	homing_enabled = bool(data.get("homing_enabled", false))
	homing_turn_rate = float(data.get("turn_rate", 0.0))
	rotation = direction.angle()

func _process(delta: float) -> void:
	var current_speed: float = move_speed
	var main := get_tree().current_scene
	if main != null:
		if main.is_crashed:
			return
		current_speed *= main.speed_multiplier

	if homing_enabled:
		var player: Node2D = _get_player_target()
		if player != null:
			var desired_direction: Vector2 = (player.global_position - global_position).normalized()
			if desired_direction.length_squared() > 0.0:
				var angle_delta: float = wrapf(desired_direction.angle() - direction.angle(), -PI, PI)
				var clamped_turn: float = clamp(angle_delta, -homing_turn_rate * delta, homing_turn_rate * delta)
				direction = direction.rotated(clamped_turn).normalized()

	global_position += direction * current_speed * delta
	rotation = direction.angle()

	if global_position.x < -150 or global_position.y < -100 or global_position.y > get_viewport_rect().size.y + 100:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("die"):
		body.die()
		queue_free()

func destroy(_skip_special: bool = false) -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	if explosion.has_method("configure"):
		explosion.configure(false)
	get_tree().current_scene.add_child(explosion)
	queue_free()

func get_destroy_score() -> int:
	var data: Dictionary = PROJECTILE_DATA.get(projectile_kind, PROJECTILE_DATA["player_missile"])
	return int(data.get("score", 20))

func _get_player_target() -> Node2D:
	var main := get_tree().current_scene
	if main == null:
		return null
	return main.get_node_or_null("Player") as Node2D

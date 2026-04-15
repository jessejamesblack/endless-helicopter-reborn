extends Area2D

const PROJECTILE_DATA := {
	"player_missile": {
		"region": Rect2(435, 998, 289, 102),
		"scale": Vector2(0.08191126, 0.055045888),
		"collision_size": Vector2(24, 6),
		"score": 20,
	},
	"turret_round": {
		"region": Rect2(782, 1017, 242, 55),
		"scale": Vector2(0.132, 0.132),
		"collision_size": Vector2(30, 8),
		"score": 25,
	},
}

@export_enum("player_missile", "turret_round") var projectile_kind: String = "player_missile"
@export var move_speed: float = 480.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var explosion_scene: PackedScene = preload("res://explosion.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	apply_projectile_config()

func configure(kind: String) -> void:
	projectile_kind = kind
	if is_inside_tree():
		apply_projectile_config()

func apply_projectile_config() -> void:
	var data: Dictionary = PROJECTILE_DATA.get(projectile_kind, PROJECTILE_DATA["player_missile"])
	sprite.region_rect = data["region"]
	sprite.scale = data["scale"]

	var shape := RectangleShape2D.new()
	shape.size = data["collision_size"]
	collision_shape.shape = shape

func _process(delta: float) -> void:
	var current_speed := move_speed
	var main := get_tree().current_scene as Main
	if main:
		if main.is_crashed:
			return
		current_speed *= main.speed_multiplier

	position.x -= current_speed * delta

	if global_position.x < -150:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.has_method("die"):
		body.die()
		queue_free()

func destroy() -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	queue_free()

func get_destroy_score() -> int:
	var data: Dictionary = PROJECTILE_DATA.get(projectile_kind, PROJECTILE_DATA["player_missile"])
	return int(data.get("score", 20))

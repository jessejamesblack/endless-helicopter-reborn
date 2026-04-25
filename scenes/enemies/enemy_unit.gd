extends Area2D

var ENEMY_DATA := {
	"stationary_turret": {
		"region": Rect2(1149, 1134, 242, 266),
		"scale": Vector2(0.255, 0.255),
		"speed": 150.0,
		"collision_offset": Vector2(0, 7.5),
		"collision_polygon": PackedVector2Array([
			Vector2(-18, -22.5),
			Vector2(13.5, -22.5),
			Vector2(18, -10.5),
			Vector2(15, 1.5),
			Vector2(18, 18),
			Vector2(9, 25.5),
			Vector2(-9, 25.5),
			Vector2(-18, 16.5),
			Vector2(-15, 0),
			Vector2(-13.5, -10.5),
		]),
		"fire_interval": 2.75,
		"projectile_kind": "turret_round",
		"projectile_speed": 285.0,
		"fire_offset": Vector2(-22.5, -13.5),
		"score": 85,
	},
	"alien_drone": {
		"region": Rect2(1623, 1192, 206, 180),
		"scale": Vector2(0.405, 0.405),
		"speed": 228.0,
		"collision_offset": Vector2(0, 1.5),
		"collision_polygon": PackedVector2Array([
			Vector2(-31.5, -4.5),
			Vector2(-25.5, -16.5),
			Vector2(-7.5, -24),
			Vector2(12, -22.5),
			Vector2(28.5, -13.5),
			Vector2(34.5, -1.5),
			Vector2(31.5, 10.5),
			Vector2(21, 19.5),
			Vector2(6, 25.5),
			Vector2(-9, 24),
			Vector2(-22.5, 18),
			Vector2(-31.5, 6),
		]),
		"fire_interval": 2.05,
		"projectile_kind": "player_missile",
		"projectile_speed": 500.0,
		"fire_offset": Vector2(-27, 0),
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
@export var enemy_modifier: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var fire_sound: AudioStreamPlayer = $FireSound

var enemy_projectile_scene: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")

const TURRET_FIRE_RETRY_SECONDS := 0.25
const MAX_ACTIVE_ENEMY_PROJECTILES := 5
const TURRET_MIN_FIRE_INTERVAL_SECONDS := 1.4
const DRONE_MIN_FIRE_INTERVAL_SECONDS := 0.9

var _base_y: float = 0.0
var _fire_timer: float = 0.0
var _time_alive: float = 0.0
var _hits_remaining: int = 1

func _ready() -> void:
	add_to_group("hostile_units")
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	apply_enemy_config()

func configure(kind: String, modifier: String = "") -> void:
	enemy_kind = _resolve_enemy_kind(kind)
	enemy_modifier = modifier
	if is_inside_tree():
		_base_y = position.y
		apply_enemy_config()

func apply_enemy_config() -> void:
	enemy_kind = _resolve_enemy_kind(enemy_kind)
	var data: Dictionary = ENEMY_DATA.get(enemy_kind, ENEMY_DATA["stationary_turret"])
	sprite.region_rect = data["region"]
	sprite.scale = data["scale"]
	sprite.rotation = 0.0
	sprite.modulate = _get_modifier_color()

	collision_polygon.polygon = data["collision_polygon"]
	collision_polygon.position = data.get("collision_offset", Vector2.ZERO)
	collision_polygon.rotation = 0.0
	_hits_remaining = _get_modifier_hit_count()

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
		var pressure := 1.0
		if main != null and main.has_method("get_enemy_fire_pressure_scale"):
			pressure = maxf(float(main.get_enemy_fire_pressure_scale()), 1.0)
		if enemy_modifier == "elite":
			pressure += 0.18
		bob_speed *= minf(pressure, 1.45)
		bob_amplitude *= minf(pressure, 1.35)
		position.y = _base_y + sin(_time_alive * bob_speed) * bob_amplitude

	if data.has("rotation_speed"):
		sprite.rotation += float(data["rotation_speed"]) * delta
		collision_polygon.rotation = sprite.rotation

	if data.has("fire_interval") and data.has("projectile_kind"):
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			if _can_fire_projectile(data):
				fire_projectile(data)
				var fire_interval := _get_effective_fire_interval(data)
				_fire_timer = fire_interval + randf_range(-0.25, 0.35)
			else:
				_fire_timer = _get_effective_retry_seconds()

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
		if body.has_method("absorb_incoming_hit") and body.absorb_incoming_hit(self):
			destroy(true, false)
			return
		body.die()

func destroy(skip_special: bool = false, caused_by_player: bool = false) -> bool:
	if caused_by_player and _hits_remaining > 1:
		_hits_remaining -= 1
		_flash_modifier_hit()
		return false

	if caused_by_player:
		var run_stats := get_node_or_null("/root/RunStats")
		if run_stats != null and run_stats.has_method("record_hostile_destroyed"):
			run_stats.record_hostile_destroyed()
		if run_stats != null and not enemy_modifier.is_empty() and run_stats.has_method("record_special_enemy_kill"):
			run_stats.record_special_enemy_kill(enemy_modifier)
		if run_stats != null and enemy_modifier == "elite" and run_stats.has_method("record_elite_kill"):
			run_stats.record_elite_kill()

	if _resolve_enemy_kind(enemy_kind) == "glowing_rock" and not skip_special:
		var main := get_tree().current_scene
		if main != null and main.has_method("trigger_glowing_rock_blast"):
			main.trigger_glowing_rock_blast(global_position, self, caused_by_player)
			return true

	_spawn_explosion()
	queue_free()
	return true

func get_destroy_score() -> int:
	var data: Dictionary = ENEMY_DATA.get(_resolve_enemy_kind(enemy_kind), ENEMY_DATA["stationary_turret"])
	var score := int(data.get("score", 80))
	match enemy_modifier:
		"armored":
			score += 35
		"shielded":
			score += 45
		"elite":
			score += 90
	return score

func _play_fire_sound() -> void:
	if fire_sound == null:
		return

	if fire_sound.playing:
		fire_sound.stop()

	fire_sound.pitch_scale = (0.78 if enemy_modifier == "elite" else 0.88) if enemy_kind == "stationary_turret" else (1.18 if enemy_modifier == "elite" else 1.06)
	fire_sound.play()

func _can_fire_projectile(data: Dictionary) -> bool:
	if _count_active_enemy_projectiles() >= _get_projectile_cap():
		return false
	if str(data.get("projectile_kind", "")) != "turret_round":
		return true
	return not _has_active_turret_round()

func _count_active_enemy_projectiles() -> int:
	var count := 0
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(projectile):
			continue
		if not projectile.is_inside_tree() or projectile.is_queued_for_deletion():
			continue
		count += 1
	return count

func _has_active_turret_round() -> bool:
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(projectile):
			continue
		if not projectile.is_inside_tree() or projectile.is_queued_for_deletion():
			continue
		if str(projectile.get("projectile_kind")) == "turret_round":
			return true
	return false

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
		explosion.configure(is_large or enemy_modifier == "elite")
	get_tree().current_scene.add_child(explosion)

func _get_modifier_hit_count() -> int:
	match enemy_modifier:
		"shielded":
			return 2
		"armored":
			return 2
		"elite":
			return 3
	return 1

func _get_modifier_color() -> Color:
	match enemy_modifier:
		"armored":
			return Color(0.82, 0.86, 0.92, 1.0)
		"shielded":
			return Color(0.55, 0.88, 1.0, 1.0)
		"elite":
			return Color(1.0, 0.72, 0.34, 1.0)
	return Color.WHITE

func _get_effective_fire_interval(data: Dictionary) -> float:
	var base_interval := float(data.get("fire_interval", 999.0))
	var main := get_tree().current_scene
	var pressure_scale := 1.0
	if main != null and main.has_method("get_enemy_fire_pressure_scale"):
		pressure_scale = maxf(float(main.get_enemy_fire_pressure_scale()), 1.0)
	if enemy_modifier == "elite":
		pressure_scale += 0.16
	var minimum := TURRET_MIN_FIRE_INTERVAL_SECONDS if _resolve_enemy_kind(enemy_kind) == "stationary_turret" else DRONE_MIN_FIRE_INTERVAL_SECONDS
	return maxf(base_interval / pressure_scale, minimum)

func _get_effective_retry_seconds() -> float:
	var main := get_tree().current_scene
	if main != null and main.has_method("get_enemy_fire_retry_seconds"):
		return float(main.get_enemy_fire_retry_seconds())
	return TURRET_FIRE_RETRY_SECONDS

func _get_projectile_cap() -> int:
	var main := get_tree().current_scene
	if main != null and main.has_method("get_enemy_projectile_cap"):
		return int(main.get_enemy_projectile_cap())
	return MAX_ACTIVE_ENEMY_PROJECTILES

func _flash_modifier_hit() -> void:
	var original := sprite.modulate
	sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", original, 0.12)

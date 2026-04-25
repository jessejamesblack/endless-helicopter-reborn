extends Area2D

@export var speed: float = 600.0

var _has_hit: bool = false
var _homing_enabled: bool = false
var _homing_turn_rate: float = 2.4
var _direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_direction = Vector2.RIGHT.rotated(rotation).normalized()

func configure_depth(homing_enabled: bool = false) -> void:
	_homing_enabled = homing_enabled

func _process(delta: float) -> void:
	var current_speed = speed
	var main := get_tree().current_scene
	if main != null:
		if main.is_crashed: return
		current_speed *= main.speed_multiplier
	var powerup_manager := get_node_or_null("/root/PowerupManager")
	if powerup_manager != null and powerup_manager.has_method("has_active_effect") and powerup_manager.has_active_effect("missile_overdrive"):
		current_speed *= 1.18

	if _homing_enabled:
		_update_homing(delta)

	global_position += _direction * current_speed * delta
	rotation = _direction.angle()
	
	# Despawn if it flies off the right side of the screen
	if global_position.x > get_viewport_rect().size.x + 100:
		_record_missile_miss()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	if not area.has_method("destroy"):
		return

	_has_hit = true

	var score_boost := 50
	if area.has_method("get_destroy_score"):
		score_boost = area.get_destroy_score()

	var is_enemy_projectile := area.is_in_group("enemy_projectiles")
	var destroy_result = area.destroy(false, true)
	var target_destroyed := true
	if destroy_result is bool:
		target_destroyed = bool(destroy_result)

	var main := get_tree().current_scene
	if main != null:
		if is_enemy_projectile and main.has_method("record_projectile_intercept"):
			main.record_projectile_intercept(global_position, score_boost)
		elif main.has_method("record_player_missile_hit"):
			main.record_player_missile_hit(area, global_position, score_boost, target_destroyed)
		else:
			main.score += score_boost
			if main.has_method("_update_score_ui"):
				main._update_score_ui()

	queue_free()

func _record_missile_miss() -> void:
	if _has_hit:
		return

	var main := get_tree().current_scene
	if main == null:
		return
	if "is_crashed" in main and main.is_crashed:
		return
	if main.has_method("record_player_missile_miss"):
		main.record_player_missile_miss()

func _update_homing(delta: float) -> void:
	var target := _find_homing_target()
	if target == null:
		return
	var desired := (target.global_position - global_position).normalized()
	if desired.length_squared() <= 0.0:
		return
	var angle_delta := wrapf(desired.angle() - _direction.angle(), -PI, PI)
	var turn := clampf(angle_delta, -_homing_turn_rate * delta, _homing_turn_rate * delta)
	_direction = _direction.rotated(turn).normalized()

func _find_homing_target() -> Node2D:
	var best_target: Node2D = null
	var best_distance := 999999.0
	for unit in get_tree().get_nodes_in_group("hostile_units"):
		if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion():
			continue
		if unit.global_position.x < global_position.x:
			continue
		var distance := global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = unit as Node2D
	return best_target

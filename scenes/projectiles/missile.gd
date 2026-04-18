extends Area2D

@export var speed: float = 600.0

var _has_hit: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	var current_speed = speed
	var main := get_tree().current_scene
	if main != null:
		if main.is_crashed: return
		current_speed *= main.speed_multiplier
		
	position.x += current_speed * delta
	
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

	var main := get_tree().current_scene
	var is_enemy_projectile := area.is_in_group("enemy_projectiles")
	area.destroy(false, true)

	if main != null:
		if is_enemy_projectile and main.has_method("record_projectile_intercept"):
			main.record_projectile_intercept(global_position, score_boost)
		elif main.has_method("record_player_missile_hit"):
			main.record_player_missile_hit(area, global_position, score_boost)
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

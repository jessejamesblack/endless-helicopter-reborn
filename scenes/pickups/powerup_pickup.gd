extends Area2D

@export var move_speed: float = 205.0
@export var powerup_id: String = ""

@onready var icon: Polygon2D = $Icon
@onready var label: Label = $Label

var _bob_time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("screen_pickups")
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	if powerup_id.is_empty():
		var manager := get_node_or_null("/root/PowerupManager")
		if manager != null and manager.has_method("get_random_powerup_id"):
			powerup_id = str(manager.get_random_powerup_id())
		else:
			powerup_id = "shield_bubble"
	_apply_visual_state()

func configure(next_powerup_id: String) -> void:
	powerup_id = next_powerup_id
	if is_inside_tree():
		_apply_visual_state()

func _process(delta: float) -> void:
	var current_speed := move_speed
	var main := get_tree().current_scene
	if main != null:
		if bool(main.get("is_crashed")):
			return
		current_speed *= float(main.get("speed_multiplier"))

	_bob_time += delta
	position.y = _base_y + sin(_bob_time * 4.2) * 7.0
	position.x -= current_speed * delta
	_apply_magnet(delta)

	if global_position.x < -220:
		queue_free()

func _apply_magnet(delta: float) -> void:
	var manager := get_node_or_null("/root/PowerupManager")
	if manager == null or not manager.has_method("has_active_effect") or not manager.has_active_effect("ammo_magnet"):
		return
	var player := _get_player()
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance > 280.0:
		return
	global_position = global_position.move_toward(player.global_position, 430.0 * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	var manager := get_node_or_null("/root/PowerupManager")
	if manager != null and manager.has_method("activate_powerup"):
		manager.activate_powerup(powerup_id)
	queue_free()

func _apply_visual_state() -> void:
	var color := Color(0.48, 0.85, 1.0, 0.95)
	match powerup_id:
		"shield_bubble":
			color = Color(0.42, 0.84, 1.0, 0.95)
		"score_rush":
			color = Color(1.0, 0.78, 0.25, 0.95)
		"missile_overdrive":
			color = Color(1.0, 0.35, 0.26, 0.95)
		"ammo_magnet":
			color = Color(0.48, 1.0, 0.58, 0.95)
		"emp_burst":
			color = Color(0.68, 0.62, 1.0, 0.95)
		"afterburner_burst":
			color = Color(1.0, 0.55, 0.18, 0.95)
	if icon != null:
		icon.color = color
	if label != null:
		label.text = "PWR"

func _get_player() -> Node2D:
	var main := get_tree().current_scene
	if main == null:
		return null
	return main.get_node_or_null("Player") as Node2D

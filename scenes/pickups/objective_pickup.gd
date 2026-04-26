extends Area2D

@export var move_speed: float = 190.0
@export var objective_action: String = "rescue_pickup"

@onready var icon: Polygon2D = $Icon
@onready var label: Label = $Label

var _bob_time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("screen_pickups")
	body_entered.connect(_on_body_entered)
	_base_y = position.y

func configure(action: String) -> void:
	objective_action = action
	_apply_objective_visuals()

func _process(delta: float) -> void:
	var current_speed := move_speed
	var main := get_tree().current_scene
	if main != null:
		if bool(main.get("is_crashed")):
			return
		current_speed *= float(main.get("speed_multiplier"))
	_bob_time += delta
	position.y = _base_y + sin(_bob_time * 5.0) * 8.0
	position.x -= current_speed * delta
	if global_position.x < -220:
		queue_free()

func _apply_objective_visuals() -> void:
	if icon == null or label == null:
		return
	match objective_action:
		"black_box_pickup":
			icon.color = Color(0.35, 0.86, 1.0, 0.96)
			icon.polygon = PackedVector2Array([
				Vector2(-28, -20),
				Vector2(28, -20),
				Vector2(28, 20),
				Vector2(-28, 20),
			])
			label.text = "BOX"
		"signal_gate":
			icon.color = Color(0.56, 1.0, 0.68, 0.94)
			icon.polygon = PackedVector2Array([
				Vector2(0, -32),
				Vector2(30, -14),
				Vector2(30, 14),
				Vector2(0, 32),
				Vector2(-30, 14),
				Vector2(-30, -14),
			])
			label.text = "GATE"
		_:
			icon.color = Color(0.964706, 0.843137, 0.54902, 0.95)
			icon.polygon = PackedVector2Array([
				Vector2(0, -30),
				Vector2(28, 0),
				Vector2(0, 30),
				Vector2(-28, 0),
			])
			label.text = "OBJ"

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	var manager := get_node_or_null("/root/RunObjectiveManager")
	if manager != null and manager.has_method("record_objective_action"):
		manager.record_objective_action(objective_action)
	queue_free()

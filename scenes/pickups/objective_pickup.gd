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

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	var manager := get_node_or_null("/root/RunObjectiveManager")
	if manager != null and manager.has_method("record_objective_action"):
		manager.record_objective_action(objective_action)
	queue_free()

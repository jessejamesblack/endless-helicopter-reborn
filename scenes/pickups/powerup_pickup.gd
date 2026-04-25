extends Area2D

@export var move_speed: float = 205.0
@export var powerup_id: String = ""

@onready var shadow: Polygon2D = $Shadow
@onready var border: Polygon2D = $Border
@onready var backplate: Polygon2D = $Backplate
@onready var accent: Polygon2D = $Accent
@onready var label: Label = $Label

const UI_PANEL_COLOR := Color(0.0313726, 0.0784314, 0.145098, 0.94)
const UI_CYAN := Color(0.286275, 0.603922, 0.8, 0.95)
const UI_GOLD := Color(0.964706, 0.788235, 0.403922, 0.96)
const UI_LIGHT_TEXT := Color(0.921569, 0.94902, 1.0, 1.0)
const UI_GOLD_TEXT := Color(0.964706, 0.843137, 0.54902, 1.0)

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
	_update_pickup_pulse()
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
	var accent_color := Color(0.819608, 0.92549, 1.0, 0.98)
	var border_color := UI_CYAN
	var label_text := "PWR"
	var label_color := UI_LIGHT_TEXT
	match powerup_id:
		"shield_bubble":
			accent_color = Color(0.56, 0.807843, 0.988235, 0.98)
			border_color = UI_CYAN
			label_text = "SHLD"
		"score_rush":
			accent_color = UI_GOLD
			border_color = UI_GOLD
			label_text = "RUSH"
			label_color = UI_GOLD_TEXT
		"missile_overdrive":
			accent_color = Color(1.0, 0.38, 0.27, 0.98)
			border_color = Color(0.964706, 0.443137, 0.337255, 0.96)
			label_text = "OVR"
		"ammo_magnet":
			accent_color = Color(0.48, 1.0, 0.58, 0.98)
			border_color = Color(0.34902, 0.862745, 0.588235, 0.95)
			label_text = "MAG"
		"emp_burst":
			accent_color = Color(0.68, 0.62, 1.0, 0.98)
			border_color = Color(0.580392, 0.698039, 1.0, 0.95)
			label_text = "EMP"
		"afterburner_burst":
			accent_color = Color(1.0, 0.55, 0.18, 0.98)
			border_color = UI_GOLD
			label_text = "BURN"
			label_color = UI_GOLD_TEXT
	if shadow != null:
		shadow.color = Color(0.0, 0.0, 0.0, 0.36)
	if backplate != null:
		backplate.color = UI_PANEL_COLOR
	if border != null:
		border.color = border_color
	if accent != null:
		accent.color = accent_color
	if label != null:
		label.text = label_text
		label.add_theme_color_override("font_color", label_color)

func _update_pickup_pulse() -> void:
	var pulse := 0.5 + sin(_bob_time * 5.8) * 0.5
	var border_scale := 1.0 + pulse * 0.035
	if border != null:
		border.scale = Vector2(border_scale, border_scale)
		border.modulate.a = 0.84 + pulse * 0.16
	if accent != null:
		accent.modulate.a = 0.88 + pulse * 0.12
	if shadow != null:
		shadow.modulate.a = 0.9

func _get_player() -> Node2D:
	var main := get_tree().current_scene
	if main == null:
		return null
	return main.get_node_or_null("Player") as Node2D

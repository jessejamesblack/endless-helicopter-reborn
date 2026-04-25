extends Area2D

@export var move_speed: float = 200.0

func _ready() -> void:
    add_to_group("screen_pickups")
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    var current_speed = move_speed
    var main := get_tree().current_scene
    if main != null:
        if main.is_crashed: return
        current_speed *= main.speed_multiplier
        
    position.x -= current_speed * delta
    _apply_ammo_magnet(delta)
    
    if global_position.x < -200:
        queue_free()

func _apply_ammo_magnet(delta: float) -> void:
    var powerup_manager := get_node_or_null("/root/PowerupManager")
    if powerup_manager == null or not powerup_manager.has_method("has_active_effect") or not powerup_manager.has_active_effect("ammo_magnet"):
        return
    var main := get_tree().current_scene
    if main == null:
        return
    var player := main.get_node_or_null("Player") as Node2D
    if player == null:
        return
    if global_position.distance_to(player.global_position) > 280.0:
        return
    global_position = global_position.move_toward(player.global_position, 430.0 * delta)

func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player":
        if body.has_method("add_ammo"):
            body.add_ammo(2)
        var run_stats := get_node_or_null("/root/RunStats")
        if run_stats != null and run_stats.has_method("record_pickup_collected"):
            run_stats.record_pickup_collected()
        var mission_manager := get_node_or_null("/root/MissionManager")
        if mission_manager != null and mission_manager.has_method("record_live_mission_progress"):
            mission_manager.record_live_mission_progress("ammo_pickups", 1.0)
        queue_free()

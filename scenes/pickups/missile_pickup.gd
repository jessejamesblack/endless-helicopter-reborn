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
    
    if global_position.x < -200:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player":
        if body.has_method("add_ammo"):
            body.add_ammo(3)
        var run_stats := get_node_or_null("/root/RunStats")
        if run_stats != null and run_stats.has_method("record_pickup_collected"):
            run_stats.record_pickup_collected()
        queue_free()

extends Area2D

@export var speed: float = 600.0

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
    var current_speed = speed
    if "speed_multiplier" in get_tree().current_scene:
        current_speed *= get_tree().current_scene.speed_multiplier
        
    position.x += current_speed * delta
    
    # Despawn if it flies off the right side of the screen
    if global_position.x > get_viewport_rect().size.x + 100:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area.has_method("destroy"):
        area.destroy()
        
        # Bonus: Give the player a quick score boost for destroying it!
        if "score" in get_tree().current_scene:
            get_tree().current_scene.score += 50
            
        queue_free()
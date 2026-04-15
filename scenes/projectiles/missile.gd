extends Area2D

@export var speed: float = 600.0

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
    var current_speed = speed
    var main = get_tree().current_scene as Main
    if main:
        if main.is_crashed: return
        current_speed *= main.speed_multiplier
        
    position.x += current_speed * delta
    
    # Despawn if it flies off the right side of the screen
    if global_position.x > get_viewport_rect().size.x + 100:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area.has_method("destroy"):
        var score_boost := 50
        if area.has_method("get_destroy_score"):
            score_boost = area.get_destroy_score()
        area.destroy()
        
        # Reward the player based on what they destroyed.
        var main = get_tree().current_scene as Main
        if main:
            main.score += score_boost
            
        queue_free()

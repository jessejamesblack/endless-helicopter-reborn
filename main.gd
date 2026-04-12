extends Node2D

var score: float = 0.0
var is_crashed: bool = false
var explosion_scene: PackedScene = preload("res://explosion.tscn")

func _process(delta: float) -> void:
    if is_crashed: return
    
    # Increase score continuously based on time survived
    score += delta * 10.0
    $UI/ScoreLabel.text = "Score: %d" % int(score)

func trigger_crash(crash_pos: Vector2) -> void:
    if is_crashed: return
    is_crashed = true
    
    # Spawn explosion
    var explosion = explosion_scene.instantiate()
    explosion.global_position = crash_pos
    add_child(explosion)
    
    # Wait for 1.5 seconds to let the explosion finish
    await get_tree().create_timer(1.5).timeout
    game_over()

func game_over() -> void:
    var high_score: int = 0
    # Load the previous high score if it exists
    if FileAccess.file_exists("user://highscore.save"):
        var file = FileAccess.open("user://highscore.save", FileAccess.READ)
        high_score = file.get_64()
        
    # Save the new high score if we beat it
    if int(score) > high_score:
        var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
        file.store_64(int(score))
        
    # Transition to the Start Screen
    get_tree().change_scene_to_file("res://start_screen.tscn")
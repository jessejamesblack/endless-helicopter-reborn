class_name Main
extends Node2D

var score: float = 0.0
var is_crashed: bool = false
var explosion_scene: PackedScene = preload("res://explosion.tscn")
var speed_multiplier: float = 1.0

func _ready() -> void:
    if has_node("Player") and has_node("UI/AmmoLabel"):
        update_ammo_ui($Player.ammo)
    if has_node("Player") and has_node("UI/FireButton"):
        $UI/FireButton.pressed.connect($Player.fire_missile)
        
    # Dynamically place the spawner just off the right edge of the screen
    if has_node("Spawner"):
        $Spawner.position.x = get_viewport_rect().size.x + 100

func _process(delta: float) -> void:
    if is_crashed: return
    
    # Increase score continuously based on time survived
    score += delta * 10.0
    $UI/ScoreLabel.text = "Score: %d" % int(score)
    
    # Gradually increase game speed to make it harder over time!
    speed_multiplier += delta * 0.015

func update_ammo_ui(ammo: int) -> void:
    if has_node("UI/AmmoLabel"):
        $UI/AmmoLabel.text = "Ammo: %d" % ammo

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
    get_tree().set_meta("last_run_score", int(score))
    get_tree().change_scene_to_file("res://leaderboard_screen.tscn")

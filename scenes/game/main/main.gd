class_name Main
extends Node2D

var score: float = 0.0
var is_crashed: bool = false
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")
var speed_multiplier: float = 1.0

func _ready() -> void:
    if has_node("Player") and has_node("UI/AmmoPanel/AmmoLabel"):
        update_ammo_ui($Player.ammo)
    _update_score_ui()
    if has_node("Player") and has_node("UI/FireButton"):
        $UI/FireButton.pressed.connect($Player.fire_missile)
        
    # Dynamically place the spawner just off the right edge of the screen
    if has_node("Spawner"):
        $Spawner.position.x = get_viewport_rect().size.x + 100

func _process(delta: float) -> void:
    if is_crashed: return
    
    # Increase score continuously based on time survived
    score += delta * 10.0
    _update_score_ui()
    
    # Gradually increase game speed to make it harder over time!
    speed_multiplier += delta * 0.015

func update_ammo_ui(ammo: int) -> void:
    if has_node("UI/AmmoPanel/AmmoLabel"):
        $UI/AmmoPanel/AmmoLabel.text = "MISSILES %02d" % ammo

func _update_score_ui() -> void:
    if has_node("UI/ScorePanel/ScoreLabel"):
        $UI/ScorePanel/ScoreLabel.text = "SCORE %04d" % int(score)

func trigger_crash(crash_pos: Vector2) -> void:
    if is_crashed: return
    is_crashed = true
    
    spawn_explosion(crash_pos, true)
    
    # Wait for 1.5 seconds to let the explosion finish
    await get_tree().create_timer(1.5).timeout
    game_over()

func game_over() -> void:
    get_tree().set_meta("last_run_score", int(score))
    get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

func spawn_explosion(at_position: Vector2, is_large: bool = false) -> Node2D:
    var explosion = explosion_scene.instantiate()
    explosion.global_position = at_position
    if explosion.has_method("configure"):
        explosion.configure(is_large)
    add_child(explosion)
    return explosion

func trigger_glowing_rock_blast(blast_pos: Vector2, source: Node = null) -> void:
    if is_crashed:
        return

    spawn_explosion(blast_pos, true)
    _destroy_group_members("enemy_projectiles")
    _destroy_group_members("hostile_units", source)
    _clear_group_members("screen_pickups")

    if is_instance_valid(source):
        source.queue_free()

func _destroy_group_members(group_name: String, exclude: Node = null) -> void:
    for member in get_tree().get_nodes_in_group(group_name):
        if member == exclude or not is_instance_valid(member):
            continue
        if member.has_method("destroy"):
            member.destroy(true)
        else:
            member.queue_free()

func _clear_group_members(group_name: String) -> void:
    for member in get_tree().get_nodes_in_group(group_name):
        if is_instance_valid(member):
            member.queue_free()

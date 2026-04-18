class_name Main
extends Node2D

const HUD_SIDE_LEFT := "left"
const FIRE_SIDE_LEFT := "left"
const SCORE_PANEL_LEFT_RECT := Rect2(20, 20, 212, 56)
const SCORE_PANEL_RIGHT_RECT := Rect2(-232, 20, 212, 56)
const AMMO_PANEL_LEFT_RECT := Rect2(20, 88, 176, 56)
const AMMO_PANEL_RIGHT_RECT := Rect2(-196, 88, 176, 56)
const FIRE_BUTTON_RIGHT_RECT := Rect2(-220, -140, 188, 120)
const FIRE_BUTTON_LEFT_RECT := Rect2(32, -140, 188, 120)

var score: float = 0.0
var is_crashed: bool = false
var is_transitioning_to_game_over: bool = false
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")
var speed_multiplier: float = 1.0
var _screen_flash_tween: Tween

@onready var fire_button: TextureButton = $UI/FireButton
@onready var score_panel: Panel = $UI/ScorePanel
@onready var ammo_panel: Panel = $UI/AmmoPanel
@onready var pause_button: Button = $UI/PauseButton
@onready var pause_menu = $UI/PauseMenu
@onready var screen_flash: ColorRect = $UI/ScreenFlash

func _ready() -> void:
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("start_run"):
        run_stats.start_run()

    var music_player = get_node_or_null("/root/MusicPlayer")
    if music_player != null and music_player.has_method("play_gameplay_music"):
        music_player.play_gameplay_music()

    pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

    if has_node("Player") and has_node("UI/AmmoPanel/AmmoLabel"):
        update_ammo_ui($Player.ammo)
    _update_score_ui()
    if has_node("Player") and has_node("UI/FireButton"):
        fire_button.pressed.connect($Player.fire_missile)
    if pause_button != null:
        pause_button.pressed.connect(_on_pause_pressed)
    if pause_menu != null:
        pause_menu.resume_requested.connect(_resume_game)
        pause_menu.quit_to_menu_requested.connect(_quit_to_menu)
    var game_settings = _get_game_settings()
    if game_settings != null and not game_settings.layout_settings_changed.is_connected(_on_layout_settings_changed):
        game_settings.layout_settings_changed.connect(_on_layout_settings_changed)
    _apply_runtime_layout()
        
    # Dynamically place the spawner just off the right edge of the screen
    if has_node("Spawner"):
        $Spawner.position.x = get_viewport_rect().size.x + 100

func _process(delta: float) -> void:
    if is_crashed or is_transitioning_to_game_over or get_tree().paused:
        return
    
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_survival_time"):
        run_stats.record_survival_time(delta)

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
    is_transitioning_to_game_over = true
    _clear_pause_state()
    _disable_gameplay_ui()
    var game_settings = _get_game_settings()
    if game_settings != null and game_settings.has_method("vibrate"):
        game_settings.vibrate(70)
    
    spawn_explosion(crash_pos, true)
    
    # Keep the explosion readable, but move to results quickly.
    await get_tree().create_timer(0.5, true).timeout
    game_over()

func game_over() -> void:
    _clear_pause_state()
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("complete_run"):
        run_stats.complete_run(int(score))
    var error := get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
    if error != OK:
        push_error("Could not change to leaderboard screen after death. Error code: %d" % error)
        is_transitioning_to_game_over = false

func spawn_explosion(at_position: Vector2, is_large: bool = false) -> Node2D:
    return spawn_configured_explosion(at_position, is_large, false)

func spawn_configured_explosion(at_position: Vector2, is_large: bool = false, is_blast: bool = false) -> Node2D:
    var explosion = explosion_scene.instantiate()
    explosion.global_position = at_position
    if explosion.has_method("configure"):
        explosion.configure(is_large, is_blast)
    add_child(explosion)
    return explosion

func trigger_glowing_rock_blast(blast_pos: Vector2, source: Node = null, caused_by_player: bool = false) -> void:
    if is_crashed:
        return

    spawn_configured_explosion(blast_pos, true, true)
    _play_screen_flash_pulses()
    _destroy_group_members("enemy_projectiles", null, caused_by_player)
    _destroy_group_members("hostile_units", source, caused_by_player)
    _clear_group_members("screen_pickups")

    if is_instance_valid(source):
        source.queue_free()

func _destroy_group_members(group_name: String, exclude: Node = null, caused_by_player: bool = false) -> void:
    for member in get_tree().get_nodes_in_group(group_name):
        if member == exclude or not is_instance_valid(member):
            continue
        if member.has_method("destroy"):
            member.destroy(true, caused_by_player)
        else:
            member.queue_free()

func _clear_group_members(group_name: String) -> void:
    for member in get_tree().get_nodes_in_group(group_name):
        if is_instance_valid(member):
            member.queue_free()

func _play_screen_flash_pulses() -> void:
    if screen_flash == null:
        return

    if _screen_flash_tween != null and _screen_flash_tween.is_valid():
        _screen_flash_tween.kill()

    screen_flash.visible = true
    screen_flash.color = Color(1.0, 0.94, 0.76, 0.0)

    _screen_flash_tween = create_tween()
    _screen_flash_tween.set_parallel(false)

    for pulse in 3:
        var peak_alpha := 0.26 - (pulse * 0.04)
        _screen_flash_tween.tween_property(screen_flash, "color", Color(1.0, 0.96, 0.82, peak_alpha), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        _screen_flash_tween.tween_property(screen_flash, "color", Color(1.0, 0.94, 0.76, 0.0), 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

    _screen_flash_tween.finished.connect(func() -> void:
        screen_flash.visible = false
    )

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if get_tree().paused:
            _resume_game()
        else:
            _pause_game()

func _on_pause_pressed() -> void:
    _pause_game()

func _pause_game() -> void:
    if is_crashed or get_tree().paused:
        return

    if fire_button != null:
        fire_button.disabled = true
    if pause_menu != null:
        pause_menu.open_menu()
    get_tree().paused = true

func _resume_game() -> void:
    if not get_tree().paused:
        return

    get_tree().paused = false
    if fire_button != null:
        fire_button.disabled = false
    if pause_menu != null:
        pause_menu.close_menu()

func _quit_to_menu() -> void:
    if not is_crashed:
        var run_stats := _get_run_stats()
        if run_stats != null and run_stats.has_method("cancel_run"):
            run_stats.cancel_run()
    _clear_pause_state()
    get_tree().change_scene_to_file("res://scenes/ui/start_screen/start_screen.tscn")

func _clear_pause_state() -> void:
    get_tree().paused = false
    if fire_button != null:
        fire_button.disabled = false
    if pause_menu != null:
        pause_menu.close_menu()

func _disable_gameplay_ui() -> void:
    if fire_button != null:
        fire_button.disabled = true
        fire_button.visible = false
    if pause_button != null:
        pause_button.disabled = true
        pause_button.visible = false

func _on_layout_settings_changed(_fire_button_side: String, _hud_side: String) -> void:
    _apply_runtime_layout()

func _apply_runtime_layout() -> void:
    var game_settings = _get_game_settings()
    if game_settings == null:
        return

    _apply_fire_button_layout(str(game_settings.get_fire_button_side()))
    _apply_hud_layout(str(game_settings.get_hud_side()))

func _apply_fire_button_layout(side: String) -> void:
    if fire_button == null:
        return

    var rect := FIRE_BUTTON_LEFT_RECT if side == FIRE_SIDE_LEFT else FIRE_BUTTON_RIGHT_RECT
    if side == FIRE_SIDE_LEFT:
        fire_button.anchor_left = 0.0
        fire_button.anchor_right = 0.0
    else:
        fire_button.anchor_left = 1.0
        fire_button.anchor_right = 1.0
    fire_button.anchor_top = 1.0
    fire_button.anchor_bottom = 1.0
    fire_button.offset_left = rect.position.x
    fire_button.offset_top = rect.position.y
    fire_button.offset_right = rect.position.x + rect.size.x
    fire_button.offset_bottom = rect.position.y + rect.size.y

func _apply_hud_layout(side: String) -> void:
    var score_rect := SCORE_PANEL_LEFT_RECT if side == HUD_SIDE_LEFT else SCORE_PANEL_RIGHT_RECT
    var ammo_rect := AMMO_PANEL_LEFT_RECT if side == HUD_SIDE_LEFT else AMMO_PANEL_RIGHT_RECT

    _position_panel(score_panel, score_rect, side == HUD_SIDE_LEFT)
    _position_panel(ammo_panel, ammo_rect, side == HUD_SIDE_LEFT)

func _position_panel(panel: Control, rect: Rect2, is_left_side: bool) -> void:
    if panel == null:
        return

    panel.anchor_left = 0.0 if is_left_side else 1.0
    panel.anchor_right = 0.0 if is_left_side else 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = rect.position.x
    panel.offset_top = rect.position.y
    panel.offset_right = rect.position.x + rect.size.x
    panel.offset_bottom = rect.position.y + rect.size.y

func _get_game_settings():
    return get_node_or_null("/root/GameSettings")

func _get_run_stats() -> Node:
    return get_node_or_null("/root/RunStats")

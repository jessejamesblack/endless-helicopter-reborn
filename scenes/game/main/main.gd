class_name Main
extends Node2D

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const RunUpgradeChoiceScene: PackedScene = preload("res://scenes/ui/upgrades/run_upgrade_choice.tscn")
const HUD_SIDE_LEFT := "left"
const FIRE_SIDE_LEFT := "left"
const SCORE_PANEL_LEFT_RECT := Rect2(20, 20, 212, 56)
const SCORE_PANEL_RIGHT_RECT := Rect2(-232, 20, 212, 56)
const AMMO_PANEL_LEFT_RECT := Rect2(20, 88, 176, 56)
const AMMO_PANEL_RIGHT_RECT := Rect2(-196, 88, 176, 56)
const COMBO_PANEL_LEFT_RECT := Rect2(20, 156, 176, 48)
const COMBO_PANEL_RIGHT_RECT := Rect2(-196, 156, 176, 48)
const FIRE_BUTTON_RIGHT_RECT := Rect2(-220, -140, 188, 120)
const FIRE_BUTTON_LEFT_RECT := Rect2(32, -140, 188, 120)
const NEAR_MISS_HOSTILE_SCORE := 15
const NEAR_MISS_PROJECTILE_SCORE := 25
const PROJECTILE_INTERCEPT_BONUS := 25
const MISSILE_STREAK_BONUS_THRESHOLD := 3
const MISSILE_STREAK_BONUS := 75
const COMBO_TIMEOUT_SECONDS := 4.25
const COMBO_EVENTS_PER_STEP := 3
const COMBO_STEP := 0.25
const COMBO_MAX_MULTIPLIER := 3.0
const SURVIVAL_POINTS_PER_SECOND := 10.0
const SURVIVAL_SCORE_TIME_STEP_SECONDS := 0.001
const PAUSE_TOGGLE_COOLDOWN_SECONDS := 0.35
const PAUSE_RESUME_GRACE_SECONDS := 0.15
const PAUSE_SPAM_WINDOW_SECONDS := 2.0
const PAUSE_SPAM_MAX_TOGGLES := 6
const PAUSE_SPAM_LOCKOUT_SECONDS := 1.25

var score: int = 0
var survival_time_seconds: float = 0.0
var survival_score: int = 0
var skill_score: int = 0
var is_crashed: bool = false
var is_transitioning_to_game_over: bool = false
var explosion_scene: PackedScene = preload("res://scenes/effects/explosion.tscn")
var floating_score_scene: PackedScene = preload("res://scenes/effects/floating_score_text.tscn")
var speed_multiplier: float = 1.0
var combo_events: int = 0
var combo_multiplier: float = 1.0
var combo_timer: float = 0.0
var missile_hit_streak: int = 0
var _screen_flash_tween: Tween
var _upgrade_choice_active: bool = false
var _upgrade_choice_overlay: Control
var _active_effects_panel: Panel
var _active_effects_label: Label
var _objective_panel: Panel
var _objective_label: Label
var _last_pause_toggle_msec: int = -999999
var _resume_grace_until_msec: int = 0
var _pause_toggle_msec_history: Array[int] = []
var _pause_lockout_until_msec: int = 0

@onready var fire_button: TextureButton = $UI/FireButton
@onready var score_panel: Panel = $UI/ScorePanel
@onready var ammo_panel: Panel = $UI/AmmoPanel
@onready var combo_panel: Panel = $UI/ComboPanel
@onready var combo_label: Label = $UI/ComboPanel/ComboLabel
@onready var director_debug_label: Label = $UI/DirectorDebugLabel
@onready var pause_button: Button = $UI/PauseButton
@onready var pause_menu = $UI/PauseMenu
@onready var screen_flash: ColorRect = $UI/ScreenFlash

func _ready() -> void:
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("start_run"):
        run_stats.start_run()
    var vehicle_id := _get_equipped_vehicle_id()
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null:
        if run_upgrade_manager.has_method("start_run"):
            run_upgrade_manager.start_run(vehicle_id)
        var choice_callback := Callable(self, "_on_upgrade_choice_ready")
        if run_upgrade_manager.has_signal("choice_ready") and not run_upgrade_manager.is_connected("choice_ready", choice_callback):
            run_upgrade_manager.connect("choice_ready", choice_callback)
        var chosen_callback := Callable(self, "_on_upgrade_chosen")
        if run_upgrade_manager.has_signal("upgrade_chosen") and not run_upgrade_manager.is_connected("upgrade_chosen", chosen_callback):
            run_upgrade_manager.connect("upgrade_chosen", chosen_callback)
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null:
        if powerup_manager.has_method("start_run"):
            powerup_manager.start_run()
        var effects_callback := Callable(self, "_on_active_effects_changed")
        if powerup_manager.has_signal("active_effects_changed") and not powerup_manager.is_connected("active_effects_changed", effects_callback):
            powerup_manager.connect("active_effects_changed", effects_callback)
        var activated_callback := Callable(self, "_on_powerup_activated")
        if powerup_manager.has_signal("powerup_activated") and not powerup_manager.is_connected("powerup_activated", activated_callback):
            powerup_manager.connect("powerup_activated", activated_callback)
    var objective_manager := _get_run_objective_manager()
    if objective_manager != null:
        if objective_manager.has_method("start_run"):
            objective_manager.start_run()
        var objective_started_callback := Callable(self, "_on_objective_started")
        if objective_manager.has_signal("objective_started") and not objective_manager.is_connected("objective_started", objective_started_callback):
            objective_manager.connect("objective_started", objective_started_callback)
        var objective_progressed_callback := Callable(self, "_on_objective_progressed")
        if objective_manager.has_signal("objective_progressed") and not objective_manager.is_connected("objective_progressed", objective_progressed_callback):
            objective_manager.connect("objective_progressed", objective_progressed_callback)
        var objective_completed_callback := Callable(self, "_on_objective_completed")
        if objective_manager.has_signal("objective_completed") and not objective_manager.is_connected("objective_completed", objective_completed_callback):
            objective_manager.connect("objective_completed", objective_completed_callback)
        var objective_failed_callback := Callable(self, "_on_objective_failed")
        if objective_manager.has_signal("objective_failed") and not objective_manager.is_connected("objective_failed", objective_failed_callback):
            objective_manager.connect("objective_failed", objective_failed_callback)
    var spawner = get_node_or_null("Spawner")
    if spawner != null and spawner.has_method("reset_for_run"):
        spawner.reset_for_run()
    reset_combo()
    missile_hit_streak = 0
    score = 0
    survival_time_seconds = 0.0
    survival_score = 0
    skill_score = 0

    var music_player = get_node_or_null("/root/MusicPlayer")
    var background_manager = get_node_or_null("Background")
    if music_player != null:
        if background_manager != null and background_manager.has_method("get_current_biome_id") and music_player.has_method("play_biome_music"):
            var current_biome_id := str(background_manager.get_current_biome_id())
            if not current_biome_id.is_empty():
                music_player.play_biome_music(current_biome_id)
        elif music_player.has_method("play_gameplay_music"):
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
    _create_depth_hud()
        
    # Dynamically place the spawner just off the right edge of the screen
    if has_node("Spawner"):
        $Spawner.position.x = get_viewport_rect().size.x + 100
    _configure_director_debug_overlay()
    _update_director_debug_overlay()

func _process(delta: float) -> void:
    _update_director_debug_overlay()
    if is_crashed or is_transitioning_to_game_over or get_tree().paused:
        return
    
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_survival_time"):
        run_stats.record_survival_time(delta)
    _update_combo_timer(delta)
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("update_run"):
        powerup_manager.update_run(delta)
        _update_active_effects_ui()
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null and run_upgrade_manager.has_method("update_run"):
        run_upgrade_manager.update_run(delta)
    var objective_manager := _get_run_objective_manager()
    if objective_manager != null and objective_manager.has_method("update_run"):
        objective_manager.update_run(delta)
        if objective_manager.has_method("get_active_objective"):
            _update_objective_ui(objective_manager.get_active_objective())

    survival_time_seconds += delta
    survival_score = int(round(float(_calculate_survival_score(survival_time_seconds)) * _get_survival_score_multiplier()))
    score = survival_score + skill_score
    _update_score_ui()
    
    # Gradually increase game speed to make it harder over time!
    speed_multiplier += delta * 0.015

func update_ammo_ui(ammo: int) -> void:
    if has_node("UI/AmmoPanel/AmmoLabel"):
        $UI/AmmoPanel/AmmoLabel.text = "MISSILES %d" % ammo

func _update_score_ui() -> void:
    if has_node("UI/ScorePanel/ScoreLabel"):
        $UI/ScorePanel/ScoreLabel.text = "SCORE %d" % int(score)

func award_skill_score(base_points: int, reason: String, world_position: Vector2 = Vector2.ZERO, builds_combo: bool = true) -> int:
    if is_crashed or is_transitioning_to_game_over or get_tree().paused:
        return 0

    var applied_multiplier := combo_multiplier
    var adjusted_points := _adjust_skill_points_for_reason(base_points, reason)
    var awarded := int(round(float(maxi(adjusted_points, 0)) * applied_multiplier * _get_skill_score_multiplier()))
    skill_score += awarded
    score = survival_score + skill_score
    _update_score_ui()

    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_skill_score"):
        run_stats.record_skill_score(awarded)

    if builds_combo:
        _register_combo_event()

    _show_floating_score(world_position, awarded, reason, applied_multiplier)
    return awarded

func _register_combo_event() -> void:
    var previous_multiplier := combo_multiplier
    combo_events += 1
    combo_timer = COMBO_TIMEOUT_SECONDS + _get_combo_timeout_bonus()
    combo_multiplier = _calculate_combo_multiplier(combo_events)

    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_combo_state"):
        run_stats.record_combo_state(combo_events, combo_multiplier)

    if combo_multiplier > previous_multiplier:
        _play_haptic("combo_up")

    _update_combo_ui()

func _calculate_combo_multiplier(events: int) -> float:
    var steps := int(floor(float(events) / float(COMBO_EVENTS_PER_STEP)))
    return minf(1.0 + float(steps) * COMBO_STEP, COMBO_MAX_MULTIPLIER)

func _calculate_survival_score(elapsed_seconds: float) -> int:
    var quantized_elapsed := snappedf(maxf(elapsed_seconds, 0.0), SURVIVAL_SCORE_TIME_STEP_SECONDS)
    return int(floor(quantized_elapsed * SURVIVAL_POINTS_PER_SECOND))

func _update_combo_timer(delta: float) -> void:
    if combo_events <= 0:
        return

    combo_timer -= delta
    if combo_timer <= 0.0:
        reset_combo()

func reset_combo() -> void:
    combo_events = 0
    combo_multiplier = 1.0
    combo_timer = 0.0
    _update_combo_ui()

func record_near_miss(kind: String, world_position: Vector2) -> void:
    if is_crashed or is_transitioning_to_game_over:
        return

    var base_points := NEAR_MISS_PROJECTILE_SCORE if kind == "projectile" else NEAR_MISS_HOSTILE_SCORE
    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_near_miss"):
        run_stats.record_near_miss(kind)

    _play_haptic("near_miss")
    award_skill_score(base_points, "NEAR MISS", world_position, true)

func record_player_missile_hit(_target: Node, world_position: Vector2, base_score: int, target_destroyed: bool = true) -> void:
    if is_crashed or is_transitioning_to_game_over:
        return

    missile_hit_streak += 1
    var adjusted_base_score := base_score + _get_numeric_run_modifier("missile_score_bonus")
    var feedback_reason := _get_missile_hit_feedback_reason(_target, target_destroyed)
    if not target_destroyed:
        adjusted_base_score = maxi(20, mini(base_score, 45))
    if target_destroyed and missile_hit_streak >= MISSILE_STREAK_BONUS_THRESHOLD:
        adjusted_base_score += _get_numeric_run_modifier("precision_bonus")

    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_missile_hit"):
        run_stats.record_missile_hit(missile_hit_streak)

    _play_haptic("missile_hit")
    award_skill_score(adjusted_base_score, feedback_reason, world_position, true)
    _try_refund_ammo_on_hit()
    if _target != null and target_destroyed:
        var objective_manager := _get_run_objective_manager()
        if objective_manager != null and objective_manager.has_method("record_objective_action"):
            objective_manager.record_objective_action("reactor_chain_kill")

    if missile_hit_streak % MISSILE_STREAK_BONUS_THRESHOLD == 0:
        award_skill_score(MISSILE_STREAK_BONUS, "HIT STREAK", world_position + Vector2(0, -28), true)

func _get_missile_hit_feedback_reason(target: Node, target_destroyed: bool) -> String:
    if not target_destroyed:
        return "ARMOR"
    if target != null and "enemy_modifier" in target:
        var modifier := str(target.get("enemy_modifier"))
        match modifier:
            "elite":
                return "ELITE HIT"
            "armored":
                return "ARMORED HIT"
            "shielded":
                return "SHIELDED HIT"
    return "HIT"

func record_player_missile_miss() -> void:
    if is_crashed or is_transitioning_to_game_over:
        return

    missile_hit_streak = 0

    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_missile_miss"):
        run_stats.record_missile_miss()

func record_projectile_intercept(world_position: Vector2, base_score: int) -> void:
    if is_crashed or is_transitioning_to_game_over:
        return

    var run_stats := _get_run_stats()
    if run_stats != null and run_stats.has_method("record_projectile_intercept"):
        run_stats.record_projectile_intercept()

    _play_haptic("projectile_intercept")
    record_player_missile_hit(null, world_position, base_score + PROJECTILE_INTERCEPT_BONUS + _get_numeric_run_modifier("interceptor_bonus"))
    _show_floating_text(world_position + Vector2(0, -24), "INTERCEPT", false)

func record_boundary_recovery_feedback(world_position: Vector2) -> void:
    if is_crashed or is_transitioning_to_game_over:
        return

    reset_combo()
    _show_floating_text(world_position, "RECOVERED", false)

func _update_combo_ui() -> void:
    if combo_panel == null or combo_label == null:
        return

    if combo_events <= 0 or combo_multiplier <= 1.0:
        combo_panel.visible = false
        return

    combo_panel.visible = true
    combo_label.text = "COMBO x%.2f" % combo_multiplier

func _show_floating_score(world_position: Vector2, points: int, reason: String, multiplier: float = 1.0) -> void:
    var label_text := "+%d %s" % [points, reason]
    if multiplier > 1.0:
        label_text += " x%.2f" % multiplier

    _show_floating_text(world_position, label_text, true)

func _show_floating_text(world_position: Vector2, text_value: String, is_score: bool = true) -> void:
    if floating_score_scene == null:
        return

    var node := floating_score_scene.instantiate()
    node.global_position = world_position
    if node.has_method("configure"):
        node.configure(text_value, is_score)
    add_child(node)

func trigger_crash(crash_pos: Vector2) -> void:
    if is_crashed: return
    is_crashed = true
    is_transitioning_to_game_over = true
    reset_combo()
    missile_hit_streak = 0
    _clear_pause_state()
    _disable_gameplay_ui()
    var game_settings = _get_game_settings()
    if game_settings != null and game_settings.has_method("vibrate"):
        game_settings.vibrate(70)
    _play_haptic("crash")
    
    spawn_explosion(crash_pos, true)
    
    # Keep the explosion readable, but move to results quickly.
    await get_tree().create_timer(0.5, true).timeout
    game_over()

func game_over() -> void:
    _clear_pause_state()
    var run_stats := _get_run_stats()
    var summary: Dictionary = {}
    var player_profile = _get_player_profile()
    var vehicle_id := "default_scout"
    var vehicle_skin_id := "factory"
    if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
        vehicle_id = str(player_profile.get_equipped_vehicle_id())
    elif player_profile != null and player_profile.has_method("get_equipped_skin_id"):
        vehicle_id = str(player_profile.get_equipped_skin_id())
    if player_profile != null and player_profile.has_method("get_equipped_vehicle_skin_id"):
        vehicle_skin_id = str(player_profile.get_equipped_vehicle_skin_id(vehicle_id))
    var extra_summary := {
        "survival_time_seconds": survival_time_seconds,
        "time_survived": survival_time_seconds,
        "survival_score": survival_score,
        "skill_score": skill_score,
        "equipped_vehicle_id": vehicle_id,
        "equipped_vehicle_skin_id": vehicle_skin_id,
        "equipped_skin_id": vehicle_id,
    }
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null and run_upgrade_manager.has_method("get_summary"):
        extra_summary.merge(run_upgrade_manager.get_summary(), true)
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("get_summary"):
        extra_summary.merge(powerup_manager.get_summary(), true)
    var objective_manager := _get_run_objective_manager()
    if objective_manager != null and objective_manager.has_method("get_summary"):
        extra_summary.merge(objective_manager.get_summary(), true)
    if run_stats != null and run_stats.has_method("complete_run"):
        summary = run_stats.complete_run(int(score), extra_summary)
    var mission_manager := _get_mission_manager()
    var mission_result: Dictionary = {}
    if mission_manager != null and mission_manager.has_method("apply_run_summary"):
        mission_result = mission_manager.apply_run_summary(summary)
    if (mission_result.get("missions_completed_this_run", []) as Array).size() > 0:
        _play_haptic("mission_complete")

    var unlock_entries: Array[Dictionary] = []
    if mission_result.has("newly_unlocked_vehicles"):
        for vehicle_unlock in mission_result.get("newly_unlocked_vehicles", []):
            unlock_entries.append({
                "unlock_type": "vehicle",
                "vehicle_id": str(vehicle_unlock),
            })

    if player_profile != null and player_profile.has_method("apply_run_skin_progress"):
        unlock_entries.append_array(player_profile.apply_run_skin_progress(vehicle_id, summary))
    if player_profile != null and player_profile.has_method("apply_daily_mission_vehicle_credit"):
        unlock_entries.append_array(player_profile.apply_daily_mission_vehicle_credit(vehicle_id, int((mission_result.get("missions_completed_this_run", []) as Array).size())))
    if player_profile != null and player_profile.has_method("apply_depth_run_progress"):
        unlock_entries.append_array(player_profile.apply_depth_run_progress(summary))

    if mission_manager != null and mission_manager.has_method("merge_recent_run_details") and not unlock_entries.is_empty():
        mission_manager.merge_recent_run_details({"unlocks": unlock_entries})

    summary["post_run_unlocks"] = unlock_entries.duplicate(true)
    if not unlock_entries.is_empty():
        _play_haptic("unlock")
    if bool(summary.get("is_new_best", false)):
        _play_haptic("new_best")
    _queue_achievement_screenshots(summary, unlock_entries)
    _queue_post_run_sync(summary)
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

    if caused_by_player:
        var run_stats := _get_run_stats()
        if run_stats != null and run_stats.has_method("record_glowing_rock_clear"):
            run_stats.record_glowing_rock_clear()
        _play_haptic("glowing_clear")

    spawn_configured_explosion(blast_pos, true, true)
    _play_screen_flash_pulses()
    _destroy_group_members("enemy_projectiles")
    _destroy_group_members("hostile_units", source)
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

func _on_upgrade_choice_ready(offers: Array[Dictionary], reason: String) -> void:
    if is_crashed or is_transitioning_to_game_over:
        return
    _ensure_upgrade_choice_overlay()
    _upgrade_choice_active = true
    if fire_button != null:
        fire_button.disabled = true
    if pause_menu != null:
        pause_menu.close_menu()
    get_tree().paused = true
    if _upgrade_choice_overlay.has_method("open_choice"):
        _upgrade_choice_overlay.open_choice(offers, reason)

func _on_upgrade_card_selected(upgrade_id: String) -> void:
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null and run_upgrade_manager.has_method("choose_upgrade"):
        run_upgrade_manager.choose_upgrade(upgrade_id)
    if _upgrade_choice_overlay != null and _upgrade_choice_overlay.has_method("close_choice"):
        _upgrade_choice_overlay.close_choice()
    _upgrade_choice_active = false
    get_tree().paused = false
    if fire_button != null:
        fire_button.disabled = false
    _resume_grace_until_msec = Time.get_ticks_msec() + int(PAUSE_RESUME_GRACE_SECONDS * 1000.0)

func _on_upgrade_chosen(_upgrade_id: String, _summary: Dictionary) -> void:
    _play_haptic("mission_complete")
    _refresh_player_depth_modifiers()
    _update_active_effects_ui()

func _on_active_effects_changed(_effects: Array[Dictionary]) -> void:
    _refresh_player_depth_modifiers()
    _update_active_effects_ui()

func _on_powerup_activated(powerup_id: String, _data: Dictionary) -> void:
    _play_haptic("mission_complete")
    if powerup_id == "emp_burst":
        trigger_emp_burst()
    _refresh_player_depth_modifiers()

func _on_objective_started(objective: Dictionary) -> void:
    _update_objective_ui(objective)
    if str(objective.get("id", "")) == "rescue_pickup":
        var spawner := get_node_or_null("Spawner")
        if spawner != null and spawner.has_method("spawn_objective_pickup"):
            spawner.spawn_objective_pickup("rescue_pickup")
    _play_haptic("combo_up")

func _on_objective_progressed(objective: Dictionary) -> void:
    _update_objective_ui(objective)

func _on_objective_completed(objective: Dictionary) -> void:
    _update_objective_ui({})
    award_skill_score(int(objective.get("reward_score", 150)), "OBJECTIVE", get_viewport_rect().size * 0.5, true)
    var reward := str(objective.get("reward", "powerup"))
    if reward == "upgrade":
        var run_upgrade_manager := _get_run_upgrade_manager()
        if run_upgrade_manager != null and run_upgrade_manager.has_method("request_choice"):
            run_upgrade_manager.request_choice("objective")
    else:
        var powerup_manager := _get_powerup_manager()
        if powerup_manager != null and powerup_manager.has_method("activate_powerup") and powerup_manager.has_method("get_random_powerup_id"):
            powerup_manager.activate_powerup(str(powerup_manager.get_random_powerup_id()))
    _play_haptic("mission_complete")

func _on_objective_failed(_objective: Dictionary) -> void:
    _update_objective_ui({})

func _ensure_upgrade_choice_overlay() -> void:
    if _upgrade_choice_overlay != null and is_instance_valid(_upgrade_choice_overlay):
        return
    _upgrade_choice_overlay = RunUpgradeChoiceScene.instantiate()
    _upgrade_choice_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    if _upgrade_choice_overlay.has_signal("upgrade_selected"):
        _upgrade_choice_overlay.upgrade_selected.connect(_on_upgrade_card_selected)
    $UI.add_child(_upgrade_choice_overlay)

func _create_depth_hud() -> void:
    var ui := get_node_or_null("UI")
    if ui == null:
        return

    _active_effects_panel = Panel.new()
    _active_effects_panel.name = "ActiveEffectsPanel"
    _active_effects_panel.visible = false
    _active_effects_panel.anchor_left = 0.5
    _active_effects_panel.anchor_right = 0.5
    _active_effects_panel.offset_left = -180
    _active_effects_panel.offset_top = 146
    _active_effects_panel.offset_right = 180
    _active_effects_panel.offset_bottom = 184
    _active_effects_panel.add_theme_stylebox_override("panel", _create_depth_hud_panel_style(false))
    ui.add_child(_active_effects_panel)

    _active_effects_label = Label.new()
    _active_effects_label.name = "ActiveEffectsLabel"
    _active_effects_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _active_effects_label.offset_left = 10
    _active_effects_label.offset_right = -10
    _active_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _active_effects_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _active_effects_label.add_theme_color_override("font_color", Color(0.819608, 0.92549, 1, 1))
    _active_effects_label.add_theme_color_override("font_outline_color", Color(0.0470588, 0.109804, 0.180392, 1))
    _active_effects_label.add_theme_constant_override("outline_size", 3)
    _active_effects_label.add_theme_font_size_override("font_size", 14)
    _active_effects_panel.add_child(_active_effects_label)

    _objective_panel = Panel.new()
    _objective_panel.name = "ObjectivePromptPanel"
    _objective_panel.visible = false
    _objective_panel.anchor_left = 0.5
    _objective_panel.anchor_right = 0.5
    _objective_panel.offset_left = -210
    _objective_panel.offset_top = 86
    _objective_panel.offset_right = 210
    _objective_panel.offset_bottom = 136
    _objective_panel.add_theme_stylebox_override("panel", _create_depth_hud_panel_style(true))
    ui.add_child(_objective_panel)

    _objective_label = Label.new()
    _objective_label.name = "ObjectivePromptLabel"
    _objective_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _objective_label.offset_left = 12
    _objective_label.offset_right = -12
    _objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _objective_label.add_theme_color_override("font_color", Color(0.964706, 0.843137, 0.54902, 1))
    _objective_label.add_theme_color_override("font_outline_color", Color(0.0470588, 0.109804, 0.180392, 1))
    _objective_label.add_theme_constant_override("outline_size", 3)
    _objective_label.add_theme_font_size_override("font_size", 15)
    _objective_panel.add_child(_objective_label)
    _update_active_effects_ui()

func _create_depth_hud_panel_style(is_accent: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.0313726, 0.0784314, 0.145098, 0.86)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.border_color = Color(0.964706, 0.788235, 0.403922, 0.92) if is_accent else Color(0.286275, 0.603922, 0.8, 0.95)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.shadow_color = Color(0, 0, 0, 0.45)
    style.shadow_size = 6
    return style

func _update_active_effects_ui() -> void:
    if _active_effects_panel == null or _active_effects_label == null:
        return
    var effects: Array[Dictionary] = []
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("get_active_effects"):
        effects = powerup_manager.get_active_effects()
    if effects.is_empty():
        _active_effects_panel.visible = false
        return
    var labels: Array[String] = []
    for effect in effects:
        labels.append("%s %.0fs" % [str(effect.get("name", "Effect")), float(effect.get("remaining", 0.0))])
    _active_effects_label.text = "  |  ".join(labels)
    _active_effects_panel.visible = true

func _update_objective_ui(objective: Dictionary) -> void:
    if _objective_panel == null or _objective_label == null:
        return
    if objective.is_empty():
        _objective_panel.visible = false
        return
    _objective_panel.visible = true
    _objective_label.text = "%s  %d/%d  %.0fs" % [
        str(objective.get("title", "Objective")),
        int(objective.get("progress", 0)),
        int(objective.get("target", 1)),
        float(objective.get("remaining", 0.0)),
    ]

func trigger_emp_burst() -> void:
    if is_crashed:
        return
    _play_screen_flash_pulses()
    _destroy_group_members("enemy_projectiles")
    var shocked := 0
    for member in get_tree().get_nodes_in_group("hostile_units"):
        if not is_instance_valid(member) or member.is_queued_for_deletion():
            continue
        if member.has_method("destroy"):
            member.destroy(true, true)
            shocked += 1
            if shocked >= 4:
                break

func get_player_run_power_score() -> float:
    var run_power := 0.0
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null and run_upgrade_manager.has_method("get_run_power_score"):
        run_power += float(run_upgrade_manager.get_run_power_score())
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("get_power_score"):
        run_power += float(powerup_manager.get_power_score())
    return minf(run_power, 12.0)

func get_enemy_fire_pressure_scale() -> float:
    var elapsed_pressure := clampf((survival_time_seconds - 55.0) / 130.0, 0.0, 1.0)
    return 1.0 + elapsed_pressure * 0.45 + get_player_run_power_score() * 0.035

func get_enemy_projectile_cap() -> int:
    if survival_time_seconds >= 130.0:
        return 8
    if survival_time_seconds >= 75.0:
        return 7
    return 6

func get_enemy_fire_retry_seconds() -> float:
    var pressure := clampf((get_enemy_fire_pressure_scale() - 1.0) / 0.55, 0.0, 1.0)
    return lerpf(0.25, 0.14, pressure)

func _can_toggle_pause(is_resume: bool) -> bool:
    var now := Time.get_ticks_msec()
    if now < _pause_lockout_until_msec:
        return false
    if not is_resume and now < _resume_grace_until_msec:
        return false
    if now - _last_pause_toggle_msec < int(PAUSE_TOGGLE_COOLDOWN_SECONDS * 1000.0):
        return false
    return true

func _record_pause_toggle(is_resume: bool) -> void:
    var now := Time.get_ticks_msec()
    _last_pause_toggle_msec = now
    if is_resume:
        _resume_grace_until_msec = now + int(PAUSE_RESUME_GRACE_SECONDS * 1000.0)
    _pause_toggle_msec_history.append(now)
    var cutoff := now - int(PAUSE_SPAM_WINDOW_SECONDS * 1000.0)
    _pause_toggle_msec_history = _pause_toggle_msec_history.filter(func(value: int) -> bool:
        return value >= cutoff
    )
    if _pause_toggle_msec_history.size() > PAUSE_SPAM_MAX_TOGGLES:
        _pause_lockout_until_msec = now + int(PAUSE_SPAM_LOCKOUT_SECONDS * 1000.0)

func _adjust_skill_points_for_reason(base_points: int, reason: String) -> int:
    var adjusted := float(base_points)
    if reason == "NEAR MISS":
        adjusted *= 1.0 + _get_numeric_run_modifier("near_miss_multiplier")
    return int(round(adjusted))

func _get_skill_score_multiplier() -> float:
    var multiplier := 1.0
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("get_effect_modifiers"):
        multiplier *= float(powerup_manager.get_effect_modifiers().get("score_multiplier", 1.0))
    return multiplier

func _get_survival_score_multiplier() -> float:
    var multiplier := 1.0
    var powerup_manager := _get_powerup_manager()
    if powerup_manager != null and powerup_manager.has_method("get_effect_modifiers"):
        multiplier *= float(powerup_manager.get_effect_modifiers().get("survival_score_multiplier", 1.0))
    return multiplier

func _get_combo_timeout_bonus() -> float:
    return _get_numeric_run_modifier("combo_timeout_bonus")

func _get_numeric_run_modifier(key: String) -> float:
    var run_upgrade_manager := _get_run_upgrade_manager()
    if run_upgrade_manager != null and run_upgrade_manager.has_method("get_run_modifiers"):
        return float(run_upgrade_manager.get_run_modifiers().get(key, 0.0))
    return 0.0

func _try_refund_ammo_on_hit() -> void:
    var chance := _get_numeric_run_modifier("ammo_refund_chance")
    if chance <= 0.0 or randf() > chance:
        return
    var player := get_node_or_null("Player")
    if player != null and player.has_method("add_ammo"):
        player.add_ammo(1)
        var run_upgrade_manager := _get_run_upgrade_manager()
        if run_upgrade_manager != null and run_upgrade_manager.has_method("record_ammo_refund"):
            run_upgrade_manager.record_ammo_refund()
        var run_stats := _get_run_stats()
        if run_stats != null and run_stats.has_method("record_ammo_refund"):
            run_stats.record_ammo_refund()

func _refresh_player_depth_modifiers() -> void:
    var player := get_node_or_null("Player")
    if player != null and player.has_method("refresh_depth_modifiers"):
        player.refresh_depth_modifiers()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _request_pause_toggle()

func _on_pause_pressed() -> void:
    _request_pause_toggle()

func _request_pause_toggle() -> void:
    if _upgrade_choice_active:
        return
    if get_tree().paused:
        _resume_game()
    else:
        _pause_game()

func _pause_game() -> void:
    if is_crashed or get_tree().paused:
        return
    if not _can_toggle_pause(false):
        return

    if fire_button != null:
        fire_button.disabled = true
    if pause_menu != null:
        pause_menu.open_menu()
    get_tree().paused = true
    _record_pause_toggle(false)

func _resume_game() -> void:
    if not get_tree().paused:
        return
    if _upgrade_choice_active:
        return
    if not _can_toggle_pause(true):
        return

    get_tree().paused = false
    if fire_button != null:
        fire_button.disabled = false
    if pause_menu != null:
        pause_menu.close_menu()
    _record_pause_toggle(true)

func _quit_to_menu() -> void:
    if not is_crashed:
        var run_stats := _get_run_stats()
        if run_stats != null and run_stats.has_method("cancel_run"):
            run_stats.cancel_run()
    reset_combo()
    missile_hit_streak = 0
    _clear_pause_state()
    get_tree().change_scene_to_file("res://scenes/ui/start_screen/start_screen.tscn")

func _clear_pause_state() -> void:
    _upgrade_choice_active = false
    get_tree().paused = false
    if fire_button != null:
        fire_button.disabled = false
    if pause_menu != null:
        pause_menu.close_menu()
    if _upgrade_choice_overlay != null and _upgrade_choice_overlay.has_method("close_choice"):
        _upgrade_choice_overlay.close_choice()

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
    var combo_rect := COMBO_PANEL_LEFT_RECT if side == HUD_SIDE_LEFT else COMBO_PANEL_RIGHT_RECT

    _position_panel(score_panel, score_rect, side == HUD_SIDE_LEFT)
    _position_panel(ammo_panel, ammo_rect, side == HUD_SIDE_LEFT)
    _position_panel(combo_panel, combo_rect, side == HUD_SIDE_LEFT)

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

func _configure_director_debug_overlay() -> void:
    if director_debug_label == null:
        return

    var spawner = get_node_or_null("Spawner")
    if spawner == null or not spawner.has_method("get_debug_snapshot"):
        director_debug_label.visible = false
        return

    var snapshot: Dictionary = spawner.get_debug_snapshot()
    director_debug_label.visible = bool(snapshot.get("enabled", false))

func _update_director_debug_overlay() -> void:
    if director_debug_label == null:
        return

    var spawner = get_node_or_null("Spawner")
    if spawner == null or not spawner.has_method("get_debug_snapshot"):
        director_debug_label.visible = false
        return

    var snapshot: Dictionary = spawner.get_debug_snapshot()
    var show_overlay := bool(snapshot.get("enabled", false))
    director_debug_label.visible = show_overlay
    if not show_overlay:
        return

    director_debug_label.text = "Phase: %s\nEncounter: %s\nSeed: %s\nActive: %d" % [
        str(snapshot.get("phase", "unknown")),
        str(snapshot.get("encounter_id", "idle")),
        str(snapshot.get("seed", 0)),
        int(snapshot.get("active_hostiles", 0)),
    ]

func is_director_debug_enabled() -> bool:
    var spawner = get_node_or_null("Spawner")
    if spawner == null:
        return false
    return bool(spawner.get("show_director_debug"))

func set_director_debug_enabled(enabled: bool) -> void:
    var spawner = get_node_or_null("Spawner")
    if spawner == null:
        return
    spawner.set("show_director_debug", enabled and OS.is_debug_build())
    _configure_director_debug_overlay()
    _update_director_debug_overlay()

func _play_haptic(preset_id: String) -> void:
    var haptics_manager = get_node_or_null("/root/HapticsManager")
    if haptics_manager != null and haptics_manager.has_method("play"):
        haptics_manager.play(preset_id)

func _get_game_settings():
    return get_node_or_null("/root/GameSettings")

func _get_run_stats() -> Node:
    return get_node_or_null("/root/RunStats")

func _get_mission_manager() -> Node:
    return get_node_or_null("/root/MissionManager")

func _get_run_upgrade_manager() -> Node:
    return get_node_or_null("/root/RunUpgradeManager")

func _get_powerup_manager() -> Node:
    return get_node_or_null("/root/PowerupManager")

func _get_run_objective_manager() -> Node:
    return get_node_or_null("/root/RunObjectiveManager")

func _get_player_profile():
    return get_node_or_null("/root/PlayerProfile")

func _get_sync_queue():
    return get_node_or_null("/root/SupabaseSyncQueue")

func _get_equipped_vehicle_id() -> String:
    var player_profile = _get_player_profile()
    if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
        return str(player_profile.get_equipped_vehicle_id())
    if player_profile != null and player_profile.has_method("get_equipped_skin_id"):
        return str(player_profile.get_equipped_skin_id())
    return "default_scout"

func _queue_post_run_sync(summary: Dictionary) -> void:
    var sync_queue = _get_sync_queue()
    if sync_queue == null:
        return

    var player_profile = _get_player_profile()
    var mission_manager = _get_mission_manager()
    if player_profile != null and player_profile.has_method("get_profile_sync_summary") and sync_queue.has_method("enqueue_sync_player_profile"):
        sync_queue.enqueue_sync_player_profile(player_profile.get_profile_sync_summary())
    elif player_profile != null and player_profile.has_method("get_profile_summary") and sync_queue.has_method("enqueue_sync_player_profile"):
        sync_queue.enqueue_sync_player_profile(player_profile.get_profile_summary())

    if mission_manager != null and mission_manager.has_method("get_daily_sync_summary") and sync_queue.has_method("enqueue_sync_daily_mission_progress"):
        sync_queue.enqueue_sync_daily_mission_progress(mission_manager.get_daily_sync_summary())

    if OnlineLeaderboardScript.is_configured() and OnlineLeaderboardScript.has_saved_player_name() and sync_queue.has_method("enqueue_submit_score_v2"):
        var equipped_vehicle_id := str(summary.get("equipped_vehicle_id", "default_scout"))
        if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
            equipped_vehicle_id = str(player_profile.get_equipped_vehicle_id())
        sync_queue.enqueue_submit_score_v2(
            OnlineLeaderboardScript.load_cached_name(),
            int(summary.get("score", int(score))),
            summary,
            equipped_vehicle_id
        )

    if sync_queue.has_method("flush"):
        sync_queue.flush()

func _queue_achievement_screenshots(summary: Dictionary, unlock_entries: Array[Dictionary]) -> void:
    var screenshot_manager = get_node_or_null("/root/AchievementScreenshotManager")
    if screenshot_manager == null or not screenshot_manager.has_method("queue_event"):
        return

    if bool(summary.get("is_new_best", false)):
        screenshot_manager.queue_event(
            "new_best_%d" % int(summary.get("score", 0)),
            "New Personal Best",
            "Reached %d points in a fresh run." % int(summary.get("score", 0)),
            {
                "score": int(summary.get("score", 0)),
                "time_survived": float(summary.get("time_survived_seconds", 0.0)),
            },
            false,
            "results_screen"
        )

    for unlock_entry in unlock_entries:
        var unlock_type := str(unlock_entry.get("unlock_type", ""))
        var vehicle_id := str(unlock_entry.get("vehicle_id", ""))
        var skin_id := str(unlock_entry.get("skin_id", ""))
        var title := str(unlock_entry.get("title", "")).strip_edges()

        if unlock_type == "vehicle":
            var vehicle_title := title if not title.is_empty() else vehicle_id.capitalize()
            screenshot_manager.queue_event(
                "unlock_vehicle_%s" % vehicle_id,
                "%s unlocked" % vehicle_title,
                "A new helicopter joined the hangar.",
                {"vehicle_id": vehicle_id},
                true,
                "results_screen"
            )
            continue

        if unlock_type == "vehicle_skin" and skin_id == "gold":
            screenshot_manager.queue_event(
                "unlock_gold_%s" % vehicle_id,
                "Gold unlocked",
                "Gold mastery is now available for %s." % (title if not title.is_empty() else vehicle_id),
                {"vehicle_id": vehicle_id, "skin_id": skin_id},
                true,
                "results_screen"
            )
            continue

        if unlock_type == "global_skin_set" and skin_id == "original_icon":
            screenshot_manager.queue_event(
                "unlock_original_icon",
                "Original Icon unlocked",
                "The classic look is now available on supported vehicles.",
                {"skin_id": skin_id},
                true,
                "results_screen"
            )

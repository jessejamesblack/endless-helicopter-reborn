extends CharacterBody2D

@export var jump_velocity: float = -400.0
@export var tilt_speed: float = 5.0
@export var max_tilt: float = 0.5
@export var boundary_bounce_down_speed: float = 300.0
@export var boundary_bounce_up_speed: float = 360.0
@export var boundary_recovery_seconds: float = 0.18
@export var boundary_inset: float = 44.0

const ENGINE_TARGET_VOLUME_DB := -14.0
const BASE_AMMO_CAPACITY := 2
const BASE_MISSILE_COOLDOWN_SECONDS := 0.22
const BOUNDARY_STALL_TIMEOUT_SECONDS := 0.65
const BOUNDARY_ZONE_EXTRA_MARGIN := 6.0
const BOUNDARY_CHAIN_WINDOW_SECONDS := 1.5
const MAX_BOUNDARY_CHAIN_RECOVERIES := 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var engine_sound: AudioStreamPlayer = $EngineSound

var missile_scene: PackedScene = preload("res://scenes/projectiles/missile.tscn")
var ammo: int = 2
var max_ammo: int = BASE_AMMO_CAPACITY
var _boundary_recovery_timer: float = 0.0
var _boundary_zone_timer: float = 0.0
var _boundary_chain_times: Array[float] = []
var _fire_cooldown_timer: float = 0.0
var _run_time_seconds: float = 0.0
var _vehicle_id: String = "default_scout"
var _last_known_max_ammo: int = BASE_AMMO_CAPACITY

# Get gravity from project settings so it syncs with standard physics behavior
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _base_jump_velocity: float = jump_velocity
var _base_tilt_speed: float = tilt_speed
var _base_max_tilt: float = max_tilt
var _base_boundary_bounce_down_speed: float = boundary_bounce_down_speed
var _base_boundary_bounce_up_speed: float = boundary_bounce_up_speed
var _base_boundary_recovery_seconds: float = boundary_recovery_seconds
var _base_boundary_inset: float = boundary_inset
var _base_gravity: float = gravity

func _ready() -> void:
    _apply_equipped_vehicle_and_skin()
    refresh_depth_modifiers()
    _setup_engine_audio()

func _physics_process(delta: float) -> void:
    _run_time_seconds += delta
    if _fire_cooldown_timer > 0.0:
        _fire_cooldown_timer = max(0.0, _fire_cooldown_timer - delta)
    if _boundary_recovery_timer > 0.0:
        _boundary_recovery_timer = max(0.0, _boundary_recovery_timer - delta)

    # Apply constant downward gravity
    var effective_gravity := gravity
    var powerup_manager := get_node_or_null("/root/PowerupManager")
    if powerup_manager != null and powerup_manager.has_method("get_effect_modifiers") and bool(powerup_manager.get_effect_modifiers().get("afterburner", false)):
        effective_gravity *= 0.72
    velocity.y += effective_gravity * delta
    
    # Tilt the helicopter based on vertical velocity
    var target_tilt = clamp(velocity.y / 800.0, -max_tilt, max_tilt)
    sprite.rotation = lerp_angle(sprite.rotation, target_tilt, tilt_speed * delta)

    move_and_slide()
    _apply_boundary_bounce(delta)

func die() -> void:
    var main := get_tree().current_scene
    if main != null and main.has_method("trigger_crash"):
        main.trigger_crash(global_position)
    queue_free()

func fire_missile() -> void:
    if missile_scene == null or _fire_cooldown_timer > 0.0:
        return

    var powerup_manager := get_node_or_null("/root/PowerupManager")
    var powerup_modifiers: Dictionary = {}
    if powerup_manager != null and powerup_manager.has_method("get_effect_modifiers"):
        powerup_modifiers = powerup_manager.get_effect_modifiers()
    var free_missiles := bool(powerup_modifiers.get("free_missiles", false))
    if ammo <= 0 and not free_missiles:
        return

    if not free_missiles:
        ammo -= 1
    var main := get_tree().current_scene
    if main != null and main.has_method("update_ammo_ui"):
        main.update_ammo_ui(ammo)

    var modifiers := _get_run_modifiers()
    var missile_count := 1 + int(modifiers.get("extra_missiles", 0))
    missile_count = clampi(missile_count, 1, 3)
    var spread_gap := 18.0
    for index in range(missile_count):
        var missile = missile_scene.instantiate()
        var centered_index := float(index) - (float(missile_count - 1) * 0.5)
        var spawn_offset = Vector2(48, centered_index * spread_gap).rotated(sprite.rotation)
        missile.global_position = global_position + spawn_offset
        missile.rotation = sprite.rotation
        if missile.has_method("configure_depth"):
            missile.configure_depth(bool(modifiers.get("homing_missiles", false)))
        get_tree().current_scene.add_child(missile)

    _fire_cooldown_timer = _get_effective_missile_cooldown()
    var run_stats := get_node_or_null("/root/RunStats")
    if run_stats != null and run_stats.has_method("record_missile_fired"):
        run_stats.record_missile_fired()
    var haptics_manager = get_node_or_null("/root/HapticsManager")
    if haptics_manager != null and haptics_manager.has_method("play"):
        haptics_manager.play("missile_fire")

    if has_node("MissileFireSound"):
        $MissileFireSound.play()

func add_ammo(amount: int) -> void:
    ammo = mini(ammo + amount, max_ammo)
    var main := get_tree().current_scene
    if main != null and main.has_method("update_ammo_ui"):
        main.update_ammo_ui(ammo)

    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null and game_settings.has_method("vibrate"):
        game_settings.vibrate(30)
    var haptics_manager = get_node_or_null("/root/HapticsManager")
    if haptics_manager != null and haptics_manager.has_method("play"):
        haptics_manager.play("mission_complete")
        
    if has_node("ReloadSound"):
        $ReloadSound.play()

func _apply_boundary_bounce(delta: float) -> void:
    var viewport_height := get_viewport_rect().size.y
    var top_limit := boundary_inset
    var bottom_limit := viewport_height - boundary_inset
    var in_boundary_zone := global_position.y < top_limit + BOUNDARY_ZONE_EXTRA_MARGIN or global_position.y > bottom_limit - BOUNDARY_ZONE_EXTRA_MARGIN
    if in_boundary_zone:
        _boundary_zone_timer += delta
        if _boundary_zone_timer >= BOUNDARY_STALL_TIMEOUT_SECONDS:
            _crash_from_boundary("timeout")
            return
    else:
        _boundary_zone_timer = 0.0

    if global_position.y < top_limit:
        global_position.y = top_limit
        if _boundary_recovery_timer <= 0.0:
            if not _register_boundary_chain_or_crash():
                return
            velocity.y = boundary_bounce_down_speed
            _boundary_recovery_timer = boundary_recovery_seconds
            _record_boundary_bounce()
        elif velocity.y < 0.0:
            velocity.y = 0.0

    elif global_position.y > bottom_limit:
        global_position.y = bottom_limit
        if _boundary_recovery_timer <= 0.0:
            if not _register_boundary_chain_or_crash():
                return
            velocity.y = -boundary_bounce_up_speed
            _boundary_recovery_timer = boundary_recovery_seconds
            _record_boundary_bounce()
        elif velocity.y > 0.0:
            velocity.y = 0.0

func _record_boundary_bounce() -> void:
    var run_stats := get_node_or_null("/root/RunStats")
    if run_stats != null and run_stats.has_method("record_boundary_bounce"):
        run_stats.record_boundary_bounce()
    _record_boundary_recovery_feedback()

func _register_boundary_chain_or_crash() -> bool:
    var cutoff := _run_time_seconds - BOUNDARY_CHAIN_WINDOW_SECONDS
    _boundary_chain_times = _boundary_chain_times.filter(func(value: float) -> bool:
        return value >= cutoff
    )
    _boundary_chain_times.append(_run_time_seconds)
    var chain_bonus := int(_get_run_modifiers().get("boundary_chain_bonus", 0))
    if _boundary_chain_times.size() > MAX_BOUNDARY_CHAIN_RECOVERIES + chain_bonus:
        _crash_from_boundary("chain")
        return false
    return true

func _crash_from_boundary(reason: String) -> void:
    var run_stats := get_node_or_null("/root/RunStats")
    if run_stats != null:
        if reason == "timeout" and run_stats.has_method("record_boundary_timeout_death"):
            run_stats.record_boundary_timeout_death()
        elif reason == "chain" and run_stats.has_method("record_boundary_chain_crash"):
            run_stats.record_boundary_chain_crash()
    die()

func _record_boundary_recovery_feedback() -> void:
    var main := get_tree().current_scene
    if main != null and main.has_method("record_boundary_recovery_feedback"):
        main.record_boundary_recovery_feedback(global_position)

    var game_settings = get_node_or_null("/root/GameSettings")
    if game_settings != null and game_settings.has_method("vibrate"):
        game_settings.vibrate(20)
    var haptics_manager = get_node_or_null("/root/HapticsManager")
    if haptics_manager != null and haptics_manager.has_method("play"):
        haptics_manager.play("boundary_recovery")

func _apply_equipped_vehicle_and_skin() -> void:
    if sprite == null:
        return

    var profile := get_node_or_null("/root/PlayerProfile")
    var skins := get_node_or_null("/root/HelicopterSkins")
    if profile == null or skins == null:
        return

    var vehicle_id := "default_scout"
    var skin_id := "factory"
    if profile.has_method("get_equipped_vehicle_id"):
        vehicle_id = profile.get_equipped_vehicle_id()
    elif profile.has_method("get_equipped_skin_id"):
        vehicle_id = profile.get_equipped_skin_id()
    if profile.has_method("get_equipped_vehicle_skin_id"):
        skin_id = profile.get_equipped_vehicle_skin_id(vehicle_id)
    _vehicle_id = vehicle_id

    if skins.has_method("apply_vehicle_and_skin_to_player"):
        skins.apply_vehicle_and_skin_to_player(sprite, collision_polygon, vehicle_id, skin_id)
    elif skins.has_method("apply_skin_to_player"):
        skins.apply_skin_to_player(sprite, collision_polygon, vehicle_id)
    elif skins.has_method("apply_skin_to_sprite"):
        skins.apply_skin_to_sprite(sprite, vehicle_id)

    if skins.has_method("get_vehicle_profile"):
        var vehicle_profile: Dictionary = skins.get_vehicle_profile(vehicle_id)
        jump_velocity = float(vehicle_profile.get("jump_velocity", jump_velocity))
        tilt_speed = float(vehicle_profile.get("tilt_speed", tilt_speed))
        max_tilt = float(vehicle_profile.get("max_tilt", max_tilt))
        boundary_bounce_down_speed = float(vehicle_profile.get("boundary_bounce_down_speed", boundary_bounce_down_speed))
        boundary_bounce_up_speed = float(vehicle_profile.get("boundary_bounce_up_speed", boundary_bounce_up_speed))
        boundary_recovery_seconds = float(vehicle_profile.get("boundary_recovery_seconds", boundary_recovery_seconds))
        boundary_inset = float(vehicle_profile.get("boundary_inset", boundary_inset))
        gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * float(vehicle_profile.get("gravity_scale", 1.0))
        _base_jump_velocity = jump_velocity
        _base_tilt_speed = tilt_speed
        _base_max_tilt = max_tilt
        _base_boundary_bounce_down_speed = boundary_bounce_down_speed
        _base_boundary_bounce_up_speed = boundary_bounce_up_speed
        _base_boundary_recovery_seconds = boundary_recovery_seconds
        _base_boundary_inset = boundary_inset
        _base_gravity = gravity

func refresh_depth_modifiers() -> void:
    var modifiers := _get_run_modifiers()
    var powerup_modifiers := _get_powerup_modifiers()
    jump_velocity = _base_jump_velocity
    if bool(powerup_modifiers.get("afterburner", false)):
        jump_velocity *= 1.08
    tilt_speed = _base_tilt_speed + float(modifiers.get("tilt_speed_bonus", 0.0))
    max_tilt = _base_max_tilt
    boundary_bounce_down_speed = _base_boundary_bounce_down_speed * (1.0 + float(modifiers.get("boundary_recovery_multiplier", 0.0)))
    boundary_bounce_up_speed = _base_boundary_bounce_up_speed * (1.0 + float(modifiers.get("boundary_recovery_multiplier", 0.0)))
    boundary_recovery_seconds = _base_boundary_recovery_seconds
    boundary_inset = _base_boundary_inset
    gravity = _base_gravity * maxf(0.75, 1.0 + float(modifiers.get("gravity_multiplier", 0.0)))
    var previous_max := max_ammo
    max_ammo = maxi(BASE_AMMO_CAPACITY + int(round(float(modifiers.get("max_ammo_bonus", 0.0)))), BASE_AMMO_CAPACITY)
    if max_ammo > previous_max:
        ammo += max_ammo - previous_max
    ammo = mini(ammo, max_ammo)
    _last_known_max_ammo = max_ammo
    var main := get_tree().current_scene
    if main != null and main.has_method("update_ammo_ui"):
        main.update_ammo_ui(ammo)

func absorb_incoming_hit(_source: Node = null) -> bool:
    var powerup_manager := get_node_or_null("/root/PowerupManager")
    if powerup_manager != null and powerup_manager.has_method("consume_shield_hit") and powerup_manager.consume_shield_hit():
        _record_shield_absorb()
        return true
    var run_upgrade_manager := get_node_or_null("/root/RunUpgradeManager")
    if run_upgrade_manager != null and run_upgrade_manager.has_method("consume_run_shield_charge") and run_upgrade_manager.consume_run_shield_charge():
        _record_shield_absorb()
        return true
    return false

func _record_shield_absorb() -> void:
    var run_stats := get_node_or_null("/root/RunStats")
    if run_stats != null and run_stats.has_method("record_shield_hit_absorbed"):
        run_stats.record_shield_hit_absorbed()
    var main := get_tree().current_scene
    if main != null and main.has_method("_show_floating_text"):
        main._show_floating_text(global_position, "SHIELD", false)
    var haptics_manager = get_node_or_null("/root/HapticsManager")
    if haptics_manager != null and haptics_manager.has_method("play"):
        haptics_manager.play("boundary_recovery")

func _get_effective_missile_cooldown() -> float:
    var cooldown := BASE_MISSILE_COOLDOWN_SECONDS
    var modifiers := _get_run_modifiers()
    cooldown *= maxf(0.35, 1.0 + float(modifiers.get("missile_cooldown_multiplier", 0.0)))
    var powerup_modifiers := _get_powerup_modifiers()
    cooldown *= float(powerup_modifiers.get("missile_cooldown_multiplier", 1.0))
    return cooldown

func _get_run_modifiers() -> Dictionary:
    var manager := get_node_or_null("/root/RunUpgradeManager")
    if manager != null and manager.has_method("get_run_modifiers"):
        return manager.get_run_modifiers()
    return {}

func _get_powerup_modifiers() -> Dictionary:
    var manager := get_node_or_null("/root/PowerupManager")
    if manager != null and manager.has_method("get_effect_modifiers"):
        return manager.get_effect_modifiers()
    return {}

func _setup_engine_audio() -> void:
    if engine_sound == null or engine_sound.stream == null:
        return

    var engine_stream_mp3 := engine_sound.stream as AudioStreamMP3
    if engine_stream_mp3 != null:
        engine_stream_mp3.loop = true

    var engine_stream_wav := engine_sound.stream as AudioStreamWAV
    if engine_stream_wav != null:
        engine_stream_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        engine_stream_wav.loop_begin = 0
        engine_stream_wav.loop_end = -1

    engine_sound.volume_db = ENGINE_TARGET_VOLUME_DB
    engine_sound.stop()
    engine_sound.play()

func _unhandled_input(event: InputEvent) -> void:
    # Fire missile on 'X' key
    if event is InputEventKey and event.keycode == KEY_X and event.pressed and not event.echo:
        fire_missile()
        
    # Jump on 'ui_accept' (Spacebar), left mouse click, or screen touch
    if event.is_action_pressed("ui_accept") or \
       (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
       (event is InputEventScreenTouch and event.pressed):
        velocity.y = jump_velocity

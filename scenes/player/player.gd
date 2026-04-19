extends CharacterBody2D

@export var jump_velocity: float = -400.0
@export var tilt_speed: float = 5.0
@export var max_tilt: float = 0.5
@export var boundary_bounce_down_speed: float = 300.0
@export var boundary_bounce_up_speed: float = 360.0
@export var boundary_recovery_seconds: float = 0.18
@export var boundary_inset: float = 44.0

const ENGINE_TARGET_VOLUME_DB := -14.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var engine_sound: AudioStreamPlayer = $EngineSound

var missile_scene: PackedScene = preload("res://scenes/projectiles/missile.tscn")
var ammo: int = 2
var _boundary_recovery_timer: float = 0.0

# Get gravity from project settings so it syncs with standard physics behavior
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
    _apply_equipped_vehicle_and_skin()
    _setup_engine_audio()

func _physics_process(delta: float) -> void:
    if _boundary_recovery_timer > 0.0:
        _boundary_recovery_timer = max(0.0, _boundary_recovery_timer - delta)

    # Apply constant downward gravity
    velocity.y += gravity * delta
    
    # Tilt the helicopter based on vertical velocity
    var target_tilt = clamp(velocity.y / 800.0, -max_tilt, max_tilt)
    sprite.rotation = lerp_angle(sprite.rotation, target_tilt, tilt_speed * delta)

    move_and_slide()
    _apply_boundary_bounce()

func die() -> void:
    var main := get_tree().current_scene
    if main != null and main.has_method("trigger_crash"):
        main.trigger_crash(global_position)
    queue_free()

func fire_missile() -> void:
    if missile_scene and ammo > 0:
        ammo -= 1
        var main := get_tree().current_scene
        if main != null and main.has_method("update_ammo_ui"):
            main.update_ammo_ui(ammo)

        var missile = missile_scene.instantiate()
        # Spawn slightly in front of the helicopter, matching its tilt
        var spawn_offset = Vector2(48, 0).rotated(sprite.rotation)
        missile.global_position = global_position + spawn_offset
        missile.rotation = sprite.rotation
        get_tree().current_scene.add_child(missile)
        var run_stats := get_node_or_null("/root/RunStats")
        if run_stats != null and run_stats.has_method("record_missile_fired"):
            run_stats.record_missile_fired()
        var haptics_manager = get_node_or_null("/root/HapticsManager")
        if haptics_manager != null and haptics_manager.has_method("play"):
            haptics_manager.play("missile_fire")
        
        if has_node("MissileFireSound"):
            $MissileFireSound.play()

func add_ammo(amount: int) -> void:
    ammo += amount
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

func _apply_boundary_bounce() -> void:
    var viewport_height := get_viewport_rect().size.y
    var top_limit := boundary_inset
    var bottom_limit := viewport_height - boundary_inset

    if global_position.y < top_limit:
        global_position.y = top_limit
        if _boundary_recovery_timer <= 0.0:
            velocity.y = boundary_bounce_down_speed
            _boundary_recovery_timer = boundary_recovery_seconds
            _record_boundary_bounce()
        elif velocity.y < 0.0:
            velocity.y = 0.0

    elif global_position.y > bottom_limit:
        global_position.y = bottom_limit
        if _boundary_recovery_timer <= 0.0:
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

extends CharacterBody2D

@export var jump_velocity: float = -400.0
@export var tilt_speed: float = 5.0
@export var max_tilt: float = 0.5
@export var boundary_bounce_down_speed: float = 300.0
@export var boundary_bounce_up_speed: float = 360.0
@export var boundary_recovery_seconds: float = 0.18
@export var boundary_inset: float = 44.0

const ENGINE_TARGET_VOLUME_DB := -14.0
const ENGINE_SILENT_VOLUME_DB := -40.0
const ENGINE_CROSSFADE_SECONDS := 0.22

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var engine_sound: AudioStreamPlayer = $EngineSound

var missile_scene: PackedScene = preload("res://scenes/projectiles/missile.tscn")
var ammo: int = 2
var _engine_overlap_sound: AudioStreamPlayer
var _engine_loop_timer: Timer
var _engine_loop_length: float = 0.0
var _engine_primary_is_active: bool = true
var _boundary_recovery_timer: float = 0.0

# Get gravity from project settings so it syncs with standard physics behavior
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
    _apply_equipped_skin()
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

func _apply_equipped_skin() -> void:
    if sprite == null:
        return

    var profile := get_node_or_null("/root/PlayerProfile")
    var skins := get_node_or_null("/root/HelicopterSkins")
    if profile == null or skins == null:
        return

    var skin_id := "default_scout"
    if profile.has_method("get_equipped_skin_id"):
        skin_id = profile.get_equipped_skin_id()

    if skins.has_method("apply_skin_to_player"):
        skins.apply_skin_to_player(sprite, collision_polygon, skin_id)
        return

    if skins.has_method("apply_skin_to_sprite"):
        skins.apply_skin_to_sprite(sprite, skin_id)

func _setup_engine_audio() -> void:
    if engine_sound == null or engine_sound.stream == null:
        return

    var engine_stream_mp3 := engine_sound.stream as AudioStreamMP3
    if engine_stream_mp3 != null:
        engine_stream_mp3.loop = false

    var engine_stream_wav := engine_sound.stream as AudioStreamWAV
    if engine_stream_wav != null:
        engine_stream_wav.loop_mode = AudioStreamWAV.LOOP_DISABLED

    _engine_loop_length = engine_sound.stream.get_length()
    engine_sound.volume_db = ENGINE_TARGET_VOLUME_DB
    _engine_overlap_sound = AudioStreamPlayer.new()
    _engine_overlap_sound.stream = engine_sound.stream
    _engine_overlap_sound.bus = engine_sound.bus
    _engine_overlap_sound.volume_db = ENGINE_SILENT_VOLUME_DB
    add_child(_engine_overlap_sound)

    _engine_loop_timer = Timer.new()
    _engine_loop_timer.one_shot = true
    _engine_loop_timer.timeout.connect(_crossfade_engine_loop)
    add_child(_engine_loop_timer)

    _engine_primary_is_active = true
    engine_sound.stop()
    _engine_overlap_sound.stop()
    engine_sound.play()
    _schedule_engine_crossfade()

func _schedule_engine_crossfade() -> void:
    if _engine_loop_timer == null:
        return

    var wait_time := _engine_loop_length - ENGINE_CROSSFADE_SECONDS
    if wait_time <= 0.05:
        wait_time = max(0.1, _engine_loop_length * 0.5)
    _engine_loop_timer.start(wait_time)

func _crossfade_engine_loop() -> void:
    if engine_sound == null or _engine_overlap_sound == null:
        return

    var from_player := engine_sound if _engine_primary_is_active else _engine_overlap_sound
    var to_player := _engine_overlap_sound if _engine_primary_is_active else engine_sound

    to_player.stop()
    to_player.volume_db = ENGINE_SILENT_VOLUME_DB
    to_player.play()

    var tween := create_tween()
    tween.tween_property(from_player, "volume_db", ENGINE_SILENT_VOLUME_DB, ENGINE_CROSSFADE_SECONDS)
    tween.parallel().tween_property(to_player, "volume_db", ENGINE_TARGET_VOLUME_DB, ENGINE_CROSSFADE_SECONDS)
    tween.finished.connect(func() -> void:
        from_player.stop()
        from_player.volume_db = ENGINE_TARGET_VOLUME_DB
    )

    _engine_primary_is_active = not _engine_primary_is_active
    _schedule_engine_crossfade()

func _unhandled_input(event: InputEvent) -> void:
    # Fire missile on 'X' key
    if event is InputEventKey and event.keycode == KEY_X and event.pressed and not event.echo:
        fire_missile()
        
    # Jump on 'ui_accept' (Spacebar), left mouse click, or screen touch
    if event.is_action_pressed("ui_accept") or \
       (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
       (event is InputEventScreenTouch and event.pressed):
        velocity.y = jump_velocity

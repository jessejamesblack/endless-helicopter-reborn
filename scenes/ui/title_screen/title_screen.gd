extends Control

const START_SCREEN_SCENE_PATH := "res://scenes/ui/start_screen/start_screen.tscn"
const AUTO_CONTINUE_SECONDS := 2.4
const ENDLESS_LOGO_BASE_SIZE := 360.0
const ENDLESS_LOGO_MIN_SIZE := 260.0
const ENDLESS_LOGO_MAX_SIZE := 400.0
const BAD_GAMES_SCALE_RATIO := 0.8
const LOGO_ROW_MIN_SPACING := 18.0
const LOGO_ROW_MAX_SPACING := 34.0
const DISCLAIMER_MIN_WIDTH := 420.0
const DISCLAIMER_MAX_WIDTH := 780.0

@onready var logo_row = $CenterLockup/LockupVBox/LogoRow
@onready var bad_games_texture = $CenterLockup/LockupVBox/LogoRow/BadGamesTexture
@onready var endless_helicopter_texture = $CenterLockup/LockupVBox/LogoRow/EndlessHelicopterTexture
@onready var continue_label = $CenterLockup/LockupVBox/ContinueCard/ContinueMargin/ContinueLabel
@onready var disclaimer_label = $CenterLockup/LockupVBox/DisclaimerLabel

var _transition_started: bool = false

func _ready() -> void:
	get_tree().paused = false
	var size_changed_callback := Callable(self, "_refresh_title_layout")
	if not get_viewport().is_connected("size_changed", size_changed_callback):
		get_viewport().size_changed.connect(size_changed_callback)
	var music_player = get_node_or_null("/root/MusicPlayer")
	if music_player != null and music_player.has_method("play_menu_music"):
		music_player.play_menu_music()
	_refresh_title_layout()
	call_deferred("_auto_continue")

func _unhandled_input(event: InputEvent) -> void:
	if _transition_started:
		return
	if event is InputEventMouseButton and event.pressed:
		_continue_to_start_screen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and event.pressed:
		_continue_to_start_screen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_continue_to_start_screen()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_continue_to_start_screen()
		get_viewport().set_input_as_handled()

func _auto_continue() -> void:
	await get_tree().create_timer(AUTO_CONTINUE_SECONDS).timeout
	_continue_to_start_screen()

func _process(delta: float) -> void:
	if continue_label == null:
		return
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() / 220.0)
	continue_label.modulate.a = clampf(pulse, 0.55, 1.0)

func _continue_to_start_screen() -> void:
	if _transition_started:
		return
	_transition_started = true
	get_tree().change_scene_to_file(START_SCREEN_SCENE_PATH)

func _refresh_title_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var layout_scale := minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	var endless_logo_size := clampf(
		ENDLESS_LOGO_BASE_SIZE * layout_scale,
		ENDLESS_LOGO_MIN_SIZE,
		ENDLESS_LOGO_MAX_SIZE
	)
	var bad_games_logo_size := endless_logo_size * BAD_GAMES_SCALE_RATIO
	bad_games_texture.custom_minimum_size = Vector2(bad_games_logo_size, bad_games_logo_size)
	endless_helicopter_texture.custom_minimum_size = Vector2(endless_logo_size, endless_logo_size)
	logo_row.add_theme_constant_override(
		"separation",
		int(clampf(endless_logo_size * 0.07, LOGO_ROW_MIN_SPACING, LOGO_ROW_MAX_SPACING))
	)
	disclaimer_label.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 96.0, DISCLAIMER_MIN_WIDTH, DISCLAIMER_MAX_WIDTH),
		disclaimer_label.custom_minimum_size.y
	)

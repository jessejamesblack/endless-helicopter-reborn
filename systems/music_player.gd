extends Node

const MUSIC_BUS_NAME := "Music"
const TARGET_VOLUME_DB := -7.0
const SILENT_VOLUME_DB := -40.0
const FADE_SECONDS := 0.6
const MENU_THEME_PATH := "res://assets/audio/music/menu_theme.wav"
const GAMEPLAY_THEME_PATH := "res://assets/audio/music/gameplay_theme.wav"

var _player: AudioStreamPlayer
var _current_track_id: String = ""
var _fade_tween: Tween

func _ready() -> void:
	_ensure_player()

func play_menu_music() -> void:
	_play_track("menu", MENU_THEME_PATH)

func play_gameplay_music() -> void:
	_play_track("gameplay", GAMEPLAY_THEME_PATH)

func stop_music() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_ensure_player()
	if _player == null:
		return
	_player.stop()
	_player.volume_db = TARGET_VOLUME_DB
	_current_track_id = ""

func _play_track(track_id: String, resource_path: String) -> void:
	_ensure_player()
	if _player == null:
		return
	if _current_track_id == track_id and _player.playing:
		return

	var stream := _load_looping_stream(resource_path)
	if stream == null:
		push_warning("Could not load music track at %s" % resource_path)
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if not _player.playing:
		_player.stream = stream
		_player.volume_db = TARGET_VOLUME_DB
		_player.play()
		_current_track_id = track_id
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, FADE_SECONDS * 0.5)
	_fade_tween.finished.connect(func() -> void:
		_player.stop()
		_player.stream = stream
		_player.volume_db = SILENT_VOLUME_DB
		_player.play()
		_current_track_id = track_id
		var fade_in := create_tween()
		fade_in.tween_property(_player, "volume_db", TARGET_VOLUME_DB, FADE_SECONDS)
	)

func _on_track_finished() -> void:
	if _player == null or _player.stream == null:
		return
	_player.play()

func _load_looping_stream(resource_path: String) -> AudioStream:
	var loaded := load(resource_path)
	if loaded == null:
		return null

	var stream := loaded.duplicate(true) as AudioStream
	if stream == null:
		stream = loaded as AudioStream
	if stream == null:
		return null

	var wav_stream := stream as AudioStreamWAV
	if wav_stream != null:
		wav_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		wav_stream.loop_begin = 0
		wav_stream.loop_end = -1

	var mp3_stream := stream as AudioStreamMP3
	if mp3_stream != null:
		mp3_stream.loop = false

	return stream

func _ensure_player() -> void:
	if _player != null:
		return

	_ensure_music_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = MUSIC_BUS_NAME
	_player.volume_db = TARGET_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_on_track_finished)
	add_child(_player)

func _ensure_music_bus() -> void:
	var music_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if music_index == -1:
		music_index = AudioServer.get_bus_count()
		AudioServer.add_bus(music_index)
		AudioServer.set_bus_name(music_index, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(music_index, "Master")

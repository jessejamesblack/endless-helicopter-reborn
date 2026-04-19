extends Node2D
class_name BackgroundManager

const BackgroundCatalogScript = preload("res://systems/background_catalog.gd")

const SKY_ZOOM := 1.0
const FAR_LAYER_ZOOM := 1.08
const MID_LAYER_ZOOM := 1.18
const NEAR_LAYER_ZOOM := 1.32
const DEFAULT_FAR_SPEED_FACTOR := 0.12
const DEFAULT_MID_SPEED_FACTOR := 0.32
const DEFAULT_NEAR_SPEED_FACTOR := 0.68
const DEFAULT_STAR_SPEED_FACTOR := 0.18
const DEFAULT_ACCENT_SPEED_FACTOR := 1.05

@export var base_scroll_speed: float = 150.0
@export var allow_long_run_transitions: bool = true
@export var transition_interval_seconds: float = 105.0

var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _next_transition_elapsed: float = 9999.0
var _current_biome_id: String = ""
var _current_biome: Dictionary = {}
var _biome_rotation: Array[String] = []
var _current_biome_index: int = 0
var _transition_in_progress: bool = false

var _sky_sprite: Sprite2D
var _star_layer: Node2D
var _accent_layer: Node2D
var _far_layer: Node2D
var _mid_layer: Node2D
var _near_layer: Node2D
var _transition_overlay: ColorRect

func _ready() -> void:
	z_index = -100
	_rng.seed = int(Time.get_ticks_usec() & 0x7fffffff)
	_create_runtime_nodes()
	_build_biome_rotation()
	_apply_biome(_biome_rotation[0], true)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(delta: float) -> void:
	var main := get_tree().current_scene
	if main != null and ("is_crashed" in main) and main.is_crashed:
		return

	_elapsed += delta
	var intensity_scale := _get_intensity_scale(main)
	_scroll_repeating_layer(_star_layer, base_scroll_speed * _get_speed_factor("star_speed_factor", DEFAULT_STAR_SPEED_FACTOR) * delta)
	_scroll_repeating_layer(_accent_layer, base_scroll_speed * _get_speed_factor("accent_speed_factor", DEFAULT_ACCENT_SPEED_FACTOR) * delta * intensity_scale)
	_pan_dynamic_layer(_far_layer, base_scroll_speed * _get_speed_factor("far_speed_factor", DEFAULT_FAR_SPEED_FACTOR) * delta)
	_pan_dynamic_layer(_mid_layer, base_scroll_speed * _get_speed_factor("mid_speed_factor", DEFAULT_MID_SPEED_FACTOR) * delta * intensity_scale)
	_pan_dynamic_layer(_near_layer, base_scroll_speed * _get_speed_factor("near_speed_factor", DEFAULT_NEAR_SPEED_FACTOR) * delta * intensity_scale)

	if allow_long_run_transitions and not _transition_in_progress and _elapsed >= _next_transition_elapsed and _biome_rotation.size() > 1:
		_transition_to_next_biome()

func get_current_biome_id() -> String:
	return _current_biome_id

func _create_runtime_nodes() -> void:
	_sky_sprite = Sprite2D.new()
	_sky_sprite.centered = true
	_sky_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sky_sprite)

	_star_layer = Node2D.new()
	add_child(_star_layer)

	_accent_layer = Node2D.new()
	add_child(_accent_layer)

	_far_layer = Node2D.new()
	add_child(_far_layer)

	_mid_layer = Node2D.new()
	add_child(_mid_layer)

	_near_layer = Node2D.new()
	add_child(_near_layer)

	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.0117647, 0.0196078, 0.0470588, 0.0)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_transition_overlay)

func _build_biome_rotation() -> void:
	var biome_ids := BackgroundCatalogScript.get_biome_ids()
	if biome_ids.is_empty():
		_biome_rotation = ["classic_night_city"]
		return
	var start_index := _rng.randi_range(0, biome_ids.size() - 1)
	_biome_rotation.clear()
	for offset in range(biome_ids.size()):
		_biome_rotation.append(biome_ids[(start_index + offset) % biome_ids.size()])

func _apply_biome(biome_id: String, reset_timer: bool = false) -> void:
	var biome := BackgroundCatalogScript.get_biome_data(biome_id)
	_current_biome_id = str(biome.get("id", biome_id))
	_current_biome = biome.duplicate(true)
	_rebuild_sky(biome)
	_rebuild_star_layer(biome)
	_rebuild_accent_layer(biome)
	_rebuild_textured_layer(_far_layer, biome, "far")
	_rebuild_textured_layer(_mid_layer, biome, "mid")
	_rebuild_textured_layer(_near_layer, biome, "near")
	var music_player = get_node_or_null("/root/MusicPlayer")
	if music_player != null and music_player.has_method("play_biome_music"):
		music_player.play_biome_music(_current_biome_id)
	if reset_timer:
		_elapsed = 0.0
	_next_transition_elapsed = _elapsed + transition_interval_seconds + _rng.randf_range(8.0, 18.0)

func _rebuild_sky(biome: Dictionary) -> void:
	var viewport_size := _get_viewport_size()
	var texture := _load_texture(str(biome.get("sky_texture", "")))
	if texture == null:
		return
	var texture_size := texture.get_size()
	var scale_factor := maxf(
		viewport_size.x / maxf(texture_size.x, 1.0),
		viewport_size.y / maxf(texture_size.y, 1.0)
	) * SKY_ZOOM
	_sky_sprite.texture = texture
	_sky_sprite.position = viewport_size * 0.5
	_sky_sprite.scale = Vector2.ONE * scale_factor
	_transition_overlay.position = Vector2.ZERO
	_transition_overlay.size = viewport_size

func _rebuild_star_layer(biome: Dictionary) -> void:
	_clear_children(_star_layer)
	_star_layer.position = Vector2.ZERO
	var viewport_size := _get_viewport_size()
	var chunk_width := viewport_size.x
	_star_layer.set_meta("chunk_width", chunk_width)
	for chunk_index in range(_get_required_chunk_count(chunk_width)):
		var chunk := Node2D.new()
		chunk.position.x = float(chunk_index) * chunk_width
		_populate_star_chunk(chunk, biome, chunk_index, chunk_width)
		_star_layer.add_child(chunk)

func _rebuild_accent_layer(biome: Dictionary) -> void:
	_clear_children(_accent_layer)
	_accent_layer.position = Vector2.ZERO
	var viewport_size := _get_viewport_size()
	var chunk_width := viewport_size.x
	_accent_layer.set_meta("chunk_width", chunk_width)
	for chunk_index in range(_get_required_chunk_count(chunk_width)):
		var chunk := Node2D.new()
		chunk.position.x = float(chunk_index) * chunk_width
		_populate_accent_chunk(chunk, biome, chunk_index, chunk_width)
		_accent_layer.add_child(chunk)

func _populate_star_chunk(chunk: Node2D, biome: Dictionary, chunk_index: int, chunk_width: float) -> void:
	var viewport_size := _get_viewport_size()
	var star_count := int(biome.get("star_count", 12))
	var star_color: Color = biome.get("star_color", Color.WHITE)
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = _rng.seed + chunk_index * 991 + int(viewport_size.y)

	for star_index in range(star_count):
		var star := Polygon2D.new()
		var size := star_rng.randf_range(1.4, 3.6)
		star.polygon = PackedVector2Array([
			Vector2(-size, 0.0),
			Vector2(0.0, -size),
			Vector2(size, 0.0),
			Vector2(0.0, size),
		])
		star.position = Vector2(star_rng.randf_range(0.0, chunk_width), star_rng.randf_range(24.0, viewport_size.y * 0.5))
		var alpha_scale := star_rng.randf_range(0.35, 1.0)
		star.color = Color(star_color.r, star_color.g, star_color.b, star_color.a * alpha_scale)
		chunk.add_child(star)

func _populate_accent_chunk(chunk: Node2D, biome: Dictionary, chunk_index: int, chunk_width: float) -> void:
	var accent_count := int(biome.get("accent_count", 0))
	if accent_count <= 0:
		return
	var viewport_size := _get_viewport_size()
	var accent_color: Color = biome.get("accent_color", Color(1.0, 1.0, 1.0, 0.12))
	var accent_rng := RandomNumberGenerator.new()
	accent_rng.seed = _rng.seed + chunk_index * 719 + int(viewport_size.x)
	for accent_index in range(accent_count):
		var accent := Polygon2D.new()
		var width := accent_rng.randf_range(10.0, 26.0)
		var height := accent_rng.randf_range(3.0, 8.0)
		accent.polygon = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(width, 0.0),
			Vector2(width, height),
			Vector2(0.0, height),
		])
		accent.color = Color(accent_color.r, accent_color.g, accent_color.b, accent_color.a * accent_rng.randf_range(0.45, 1.0))
		accent.position = Vector2(accent_rng.randf_range(0.0, chunk_width), accent_rng.randf_range(viewport_size.y * 0.2, viewport_size.y * 0.82))
		chunk.add_child(accent)

func _rebuild_textured_layer(layer: Node2D, biome: Dictionary, layer_kind: String) -> void:
	_clear_children(layer)
	layer.position = Vector2.ZERO
	var texture := _load_texture(str(biome.get("%s_texture" % layer_kind, "")))
	if texture == null:
		layer.set_meta("max_offset", 0.0)
		layer.set_meta("base_x", 0.0)
		return
	var viewport_size := _get_viewport_size()
	var texture_size := texture.get_size()
	var zoom := _get_layer_zoom(layer_kind)
	var scale_factor := maxf(
		viewport_size.x / maxf(texture_size.x, 1.0),
		viewport_size.y / maxf(texture_size.y, 1.0)
	) * zoom
	var scaled_width := texture_size.x * scale_factor
	var scaled_height := texture_size.y * scale_factor
	var extra_width := maxf(0.0, scaled_width - viewport_size.x)
	var base_x := -extra_width * 0.5
	var base_y := viewport_size.y - scaled_height
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(base_x, base_y)
	layer.add_child(sprite)
	layer.set_meta("max_offset", extra_width)
	layer.set_meta("base_x", base_x)
	layer.set_meta("current_offset", 0.0)
	layer.set_meta("direction", 1.0)

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _scroll_repeating_layer(layer: Node2D, delta_x: float) -> void:
	if layer == null:
		return
	layer.position.x -= delta_x
	var chunk_width := float(layer.get_meta("chunk_width", 0.0))
	if chunk_width <= 0.0:
		return
	while layer.position.x <= -chunk_width:
		layer.position.x += chunk_width

func _pan_dynamic_layer(layer: Node2D, delta_x: float) -> void:
	if layer == null or layer.get_child_count() == 0:
		return
	var max_offset := float(layer.get_meta("max_offset", 0.0))
	if max_offset <= 0.0:
		return
	var current_offset := float(layer.get_meta("current_offset", 0.0))
	var direction := float(layer.get_meta("direction", 1.0))
	current_offset += delta_x * direction
	if current_offset >= max_offset:
		current_offset = max_offset
		direction = -1.0
	elif current_offset <= 0.0:
		current_offset = 0.0
		direction = 1.0
	layer.set_meta("current_offset", current_offset)
	layer.set_meta("direction", direction)
	var base_x := float(layer.get_meta("base_x", 0.0))
	var sprite := layer.get_child(0) as Sprite2D
	if sprite != null:
		sprite.position.x = base_x - current_offset

func _get_required_chunk_count(chunk_width: float) -> int:
	var viewport_width := _get_viewport_size().x
	if chunk_width <= 0.0:
		return 2
	return maxi(int(ceil(viewport_width / chunk_width)) + 2, 2)

func _get_layer_zoom(layer_kind: String) -> float:
	match layer_kind:
		"far":
			return FAR_LAYER_ZOOM
		"mid":
			return MID_LAYER_ZOOM
		"near":
			return NEAR_LAYER_ZOOM
		_:
			return 1.0

func _get_speed_factor(key: String, fallback: float) -> float:
	return float(_current_biome.get(key, fallback))

func _get_intensity_scale(main: Node) -> float:
	if main == null or not ("speed_multiplier" in main):
		return 1.0
	return 1.0 + clampf(float(main.speed_multiplier) - 1.0, 0.0, 1.2) * 0.22

func _transition_to_next_biome() -> void:
	if _transition_in_progress:
		return
	_transition_in_progress = true
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color", Color(0.0117647, 0.0196078, 0.0470588, 0.58), 0.32)
	tween.tween_callback(Callable(self, "_swap_to_next_biome"))
	tween.tween_property(_transition_overlay, "color", Color(0.0117647, 0.0196078, 0.0470588, 0.0), 0.34)
	tween.finished.connect(func() -> void:
		_transition_in_progress = false
	)

func _swap_to_next_biome() -> void:
	_current_biome_index = (_current_biome_index + 1) % _biome_rotation.size()
	_apply_biome(_biome_rotation[_current_biome_index], false)

func _on_viewport_size_changed() -> void:
	if _current_biome_id.is_empty():
		return
	_apply_biome(_current_biome_id, false)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _get_viewport_size() -> Vector2:
	return get_viewport_rect().size

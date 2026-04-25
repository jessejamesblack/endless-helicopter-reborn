extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")

const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(900, 1200),
	Vector2i(768, 1024),
]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _validate_spawner_for_size(viewport_size)
	_validate_no_legacy_fixed_lane_code()
	Helper.finish(self, _failures, "Spawn layout responsiveness validation completed successfully.")

func _validate_spawner_for_size(viewport_size: Vector2i) -> void:
	var root_window := get_root()
	root_window.size = viewport_size
	paused = false
	await process_frame
	var main := MAIN_SCENE.instantiate()
	root_window.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var spawner := main.get_node_or_null("Spawner")
	if spawner == null:
		_failures.append("Main scene should include Spawner at %s." % _format_viewport_size(viewport_size))
		await _destroy_node(main)
		return

	var bounds: Vector2 = spawner.call("_get_effective_spawn_bounds")
	var actual_height: float = spawner.get_viewport_rect().size.y
	_assert(bounds.x >= 0.0, "Spawn top should stay on-screen at %s." % _format_viewport_size(viewport_size))
	_assert(bounds.y <= actual_height, "Spawn bottom should stay on-screen at %s." % _format_viewport_size(viewport_size))
	_assert(bounds.y - bounds.x >= 80.0, "Spawn band should preserve playable vertical space at %s." % _format_viewport_size(viewport_size))

	var lane_top := float(spawner.call("_get_lane_y", 0))
	var lane_mid := float(spawner.call("_get_lane_y", 1))
	var lane_bottom := float(spawner.call("_get_lane_y", 2))
	_assert(lane_top < lane_mid and lane_mid < lane_bottom, "Responsive lanes should be ordered at %s." % _format_viewport_size(viewport_size))
	for lane_y in [lane_top, lane_mid, lane_bottom]:
		_assert(lane_y >= bounds.x and lane_y <= bounds.y, "Responsive lane y should stay in bounds at %s." % _format_viewport_size(viewport_size))

	for y_mode in ["random_high", "random_mid", "random_low", "bottom_turret"]:
		var y := float(spawner.call("_resolve_spawn_y", {"y_mode": y_mode}))
		_assert(y >= 0.0 and y <= actual_height, "%s y should stay on-screen at %s." % [y_mode, _format_viewport_size(viewport_size)])

	await _destroy_node(main)

func _validate_no_legacy_fixed_lane_code() -> void:
	var spawner_text := Helper.read_text("res://scenes/game/main/spawner.gd")
	_assert(spawner_text.contains("_get_lane_y"), "Spawner should use proportional lane helpers.")
	_assert(spawner_text.contains("PLAYFIELD_TOP_RATIO"), "Spawner should compute playfield top from viewport ratio.")
	_assert(spawner_text.contains("PLAYFIELD_BOTTOM_RATIO"), "Spawner should compute playfield bottom from viewport ratio.")
	_assert(not spawner_text.contains("return 160"), "Spawner should not use a fixed 160 y lane.")
	_assert(not spawner_text.contains("return 300"), "Spawner should not use a fixed 300 y lane.")
	_assert(not spawner_text.contains("return 440"), "Spawner should not use a fixed 440 y lane.")

func _destroy_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
	current_scene = null
	paused = false
	await process_frame

func _format_viewport_size(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

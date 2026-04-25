extends SceneTree

const NEAR_MISS_DETECTOR_SCRIPT := preload("res://scenes/player/near_miss_detector.gd")
const FLOATING_SCORE_TEXT_SCENE := preload("res://scenes/effects/floating_score_text.tscn")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")

class TestMain:
	extends Node2D

	var near_miss_calls: Array[Dictionary] = []
	var is_crashed: bool = false
	var is_transitioning_to_game_over: bool = false

	func record_near_miss(kind: String, world_position: Vector2) -> void:
		near_miss_calls.append({
			"kind": kind,
			"position": world_position,
		})

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	await _validate_combo_threshold_feedback_multiplier()
	await _validate_near_miss_awards_once()
	await _validate_destroyed_hazard_is_dropped()
	await _validate_floating_score_configure_before_ready()

	if _failures.is_empty():
		print("Sprint 2 runtime validation completed successfully.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _validate_combo_threshold_feedback_multiplier() -> void:
	var main := await _create_runtime_main_scene()
	main.set("combo_events", 2)
	main.set("combo_multiplier", 1.0)
	main.set("combo_timer", 3.0)
	var score_before: float = float(main.get("score"))

	var awarded: int = int(main.call("award_skill_score", 20, "TEST", Vector2(240, 180), true))
	var score_after_award: float = float(main.get("score"))
	await process_frame

	if awarded != 20:
		_failures.append("Combo threshold award should use the pre-event multiplier when calculating skill score.")

	if absf((score_after_award - score_before) - 20.0) > 0.01:
		_failures.append("Combo threshold award should add the pre-event multiplied points to the score.")

	if absf(float(main.get("combo_multiplier")) - 1.30) > 0.001:
		_failures.append("Combo threshold event should still advance the combo multiplier after awarding score.")

	var floating_text := main.find_child("FloatingScoreText", true, false)
	if floating_text == null:
		_failures.append("Combo threshold award should spawn floating score feedback.")
	else:
		var label := floating_text.get_node_or_null("Label") as Label
		if label == null:
			_failures.append("Floating score feedback should include a Label child.")
		elif label.text != "+20 TEST":
			_failures.append("Combo threshold floating text should show the applied pre-event multiplier, not the post-event multiplier.")

	await _destroy_node(main)

func _validate_near_miss_awards_once() -> void:
	var main := await _create_test_main()
	var detector := _create_detector(main)
	var hazard := _create_hazard(main, "hostile_units", Vector2(128, 128))

	detector.call("_on_area_entered", hazard)
	detector.call("_on_area_exited", hazard)
	await process_frame

	if main.near_miss_calls.size() != 1:
		_failures.append("Near miss detector should award exactly one near miss after a clean exit.")
	elif str(main.near_miss_calls[0].get("kind", "")) != "hostile":
		_failures.append("Near miss detector should classify hostile exits as hostile near misses.")

	await _destroy_node(main)

func _validate_destroyed_hazard_is_dropped() -> void:
	var main := await _create_test_main()
	var detector := _create_detector(main)
	var hazard := _create_hazard(main, "enemy_projectiles", Vector2(160, 160))

	detector.call("_on_area_entered", hazard)
	hazard.queue_free()
	detector.call("_on_area_exited", hazard)
	await process_frame
	detector.call("_process", 0.016)
	await process_frame

	if main.near_miss_calls.size() != 0:
		_failures.append("Near miss detector should not award when a hazard is destroyed inside the detector.")

	var active_candidates = detector.get("_active_candidates") as Dictionary
	if active_candidates.size() != 0:
		_failures.append("Near miss detector should clear queued-for-deletion hazards from active candidates.")

	await _destroy_node(main)

func _validate_floating_score_configure_before_ready() -> void:
	var main := await _create_test_main()
	var node := FLOATING_SCORE_TEXT_SCENE.instantiate()

	if not node.has_method("configure"):
		_failures.append("Floating score text scene should expose configure().")
		await _destroy_node(main)
		return

	node.configure("+25 NEAR MISS", true)
	main.add_child(node)
	await process_frame

	var label := node.get_node_or_null("Label") as Label
	if label == null:
		_failures.append("Floating score text scene should contain a Label child.")
	elif label.text != "+25 NEAR MISS":
		_failures.append("Floating score text should preserve configure() text when called before _ready().")

	await _destroy_node(main)

func _create_test_main() -> TestMain:
	var main := TestMain.new()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	return main

func _create_runtime_main_scene() -> Node:
	var main := MAIN_SCENE.instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	return main

func _create_detector(main: Node) -> Area2D:
	var detector := Area2D.new()
	detector.set_script(NEAR_MISS_DETECTOR_SCRIPT)
	main.add_child(detector)
	return detector

func _create_hazard(main: Node, group_name: String, world_position: Vector2) -> Area2D:
	var hazard := Area2D.new()
	main.add_child(hazard)
	hazard.add_to_group(group_name)
	hazard.global_position = world_position
	return hazard

func _destroy_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
	await process_frame

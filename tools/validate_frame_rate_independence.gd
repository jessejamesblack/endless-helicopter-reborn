extends SceneTree

const MainScript = preload("res://scenes/game/main/main.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var skill_events := [
		{"time": 1.2, "points": 30},
		{"time": 2.8, "points": 45},
		{"time": 4.0, "points": 25},
		{"time": 6.5, "points": 75},
		{"time": 9.9, "points": 50},
	]

	var sixty := _simulate_score_run(_build_fixed_deltas(600, 1.0 / 60.0), skill_events)
	var ninety := _simulate_score_run(_build_fixed_deltas(900, 1.0 / 90.0), skill_events)
	var one_twenty := _simulate_score_run(_build_fixed_deltas(1200, 1.0 / 120.0), skill_events)
	var uneven := _simulate_score_run(_build_uneven_deltas(10.0), skill_events)

	_assert(sixty["survival_score"] == ninety["survival_score"], "Survival score should match between 60 FPS and 90 FPS.")
	_assert(sixty["survival_score"] == one_twenty["survival_score"], "Survival score should match between 60 FPS and 120 FPS.")
	_assert(sixty["survival_score"] == uneven["survival_score"], "Survival score should match uneven delta playback.")
	_assert(sixty["final_score"] == ninety["final_score"], "Final score should match between 60 FPS and 90 FPS.")
	_assert(sixty["final_score"] == one_twenty["final_score"], "Final score should match between 60 FPS and 120 FPS.")
	_assert(sixty["final_score"] == uneven["final_score"], "Final score should match uneven delta playback.")

	var active_before_timeout := _simulate_combo_state(MainScript.COMBO_TIMEOUT_SECONDS - 0.01)
	var inactive_after_timeout := _simulate_combo_state(MainScript.COMBO_TIMEOUT_SECONDS + 0.01)
	_assert(active_before_timeout, "Combo timeout should still be active before the elapsed timeout threshold.")
	_assert(not inactive_after_timeout, "Combo timeout should expire based on elapsed seconds, not frame count.")

	_finish()

func _simulate_score_run(deltas: Array[float], skill_events: Array) -> Dictionary:
	var time_survived := 0.0
	var next_skill_index := 0
	var skill_score := 0
	for delta in deltas:
		time_survived += delta
		while next_skill_index < skill_events.size() and time_survived >= float(skill_events[next_skill_index]["time"]):
			skill_score += int(skill_events[next_skill_index]["points"])
			next_skill_index += 1
	var quantized_elapsed := snappedf(maxf(time_survived, 0.0), MainScript.SURVIVAL_SCORE_TIME_STEP_SECONDS)
	var survival_score := int(floor(quantized_elapsed * MainScript.SURVIVAL_POINTS_PER_SECOND))
	return {
		"survival_score": survival_score,
		"final_score": survival_score + skill_score,
	}

func _simulate_combo_state(total_elapsed: float) -> bool:
	var combo_timer := MainScript.COMBO_TIMEOUT_SECONDS
	var step_count := maxi(int(ceil(total_elapsed * 120.0)), 1)
	var steps := _build_fixed_deltas(step_count, total_elapsed / float(step_count))
	for delta in steps:
		combo_timer -= delta
		if combo_timer <= 0.0:
			return false
	return true

func _build_fixed_deltas(frame_count: int, delta: float) -> Array[float]:
	var deltas: Array[float] = []
	for _i in range(frame_count):
		deltas.append(delta)
	return deltas

func _build_uneven_deltas(total_seconds: float) -> Array[float]:
	var pattern := [0.008, 0.011, 0.017, 0.010, 0.014, 0.021]
	var deltas: Array[float] = []
	var accumulated := 0.0
	var index := 0
	while accumulated < total_seconds - 0.0001:
		var delta := float(pattern[index % pattern.size()])
		if accumulated + delta > total_seconds:
			delta = total_seconds - accumulated
		deltas.append(delta)
		accumulated += delta
		index += 1
	return deltas

func _finish() -> void:
	if _failures.is_empty():
		print("Frame-rate independence validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

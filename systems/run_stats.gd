extends Node

const STATS_PATH := "user://run_stats.cfg"
const STATS_SECTION := "run_stats"

var _local_best_score: int = 0
var _last_run_summary: Dictionary = {}
var _run_active: bool = false
var _time_survived_seconds: float = 0.0
var _missiles_fired: int = 0
var _hostiles_destroyed: int = 0
var _ammo_pickups_collected: int = 0

func _ready() -> void:
	_load_local_best_score()

func start_run() -> void:
	_last_run_summary = {}
	_run_active = true
	_reset_live_stats()

func record_survival_time(delta: float) -> void:
	if not _run_active:
		return
	_time_survived_seconds += maxf(delta, 0.0)

func record_missile_fired() -> void:
	if not _run_active:
		return
	_missiles_fired += 1

func record_hostile_destroyed() -> void:
	if not _run_active:
		return
	_hostiles_destroyed += 1

func record_pickup_collected() -> void:
	if not _run_active:
		return
	_ammo_pickups_collected += 1

func complete_run(final_score: int) -> Dictionary:
	var safe_score: int = maxi(final_score, 0)
	var best_score_before_run: int = _local_best_score
	var best_score_after_run: int = maxi(best_score_before_run, safe_score)
	var is_new_best: bool = safe_score > best_score_before_run

	if best_score_after_run != _local_best_score:
		_local_best_score = best_score_after_run
		_save_local_best_score()

	_last_run_summary = {
		"score": safe_score,
		"best_score_before_run": best_score_before_run,
		"best_score_after_run": best_score_after_run,
		"distance_to_best_before_run": max(best_score_before_run - safe_score, 0),
		"is_new_best": is_new_best,
		"time_survived_seconds": _time_survived_seconds,
		"missiles_fired": _missiles_fired,
		"hostiles_destroyed": _hostiles_destroyed,
		"ammo_pickups_collected": _ammo_pickups_collected,
	}

	_run_active = false
	_reset_live_stats()
	return _last_run_summary.duplicate(true)

func cancel_run() -> void:
	_run_active = false
	_reset_live_stats()

func consume_last_run_summary() -> Dictionary:
	var summary := _last_run_summary.duplicate(true)
	_last_run_summary = {}
	return summary

func has_last_run_summary() -> bool:
	return not _last_run_summary.is_empty()

func get_local_best_score() -> int:
	return _local_best_score

func _reset_live_stats() -> void:
	_time_survived_seconds = 0.0
	_missiles_fired = 0
	_hostiles_destroyed = 0
	_ammo_pickups_collected = 0

func _load_local_best_score() -> void:
	var config := ConfigFile.new()
	var error := config.load(STATS_PATH)
	if error != OK:
		_local_best_score = 0
		return

	_local_best_score = max(int(config.get_value(STATS_SECTION, "local_best_score", 0)), 0)

func _save_local_best_score() -> void:
	var config := ConfigFile.new()
	config.set_value(STATS_SECTION, "local_best_score", _local_best_score)
	config.save(STATS_PATH)

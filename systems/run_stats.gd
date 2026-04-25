extends Node

const STATS_PATH := "user://run_stats.cfg"
const STATS_SECTION := "run_stats"
const SURVIVAL_SCORE_TIME_STEP_SECONDS := 0.001

var _local_best_score: int = 0
var _last_run_summary: Dictionary = {}
var _run_active: bool = false
var _time_survived_seconds: float = 0.0
var _survival_score: int = 0
var _missiles_fired: int = 0
var _hostiles_destroyed: int = 0
var _ammo_pickups_collected: int = 0
var _glowing_rocks_triggered: int = 0
var _boundary_bounces: int = 0
var _near_misses: int = 0
var _hostile_near_misses: int = 0
var _projectile_near_misses: int = 0
var _skill_score: int = 0
var _max_combo_multiplier: float = 1.0
var _max_combo_events: int = 0
var _missile_hits: int = 0
var _missile_misses: int = 0
var _max_missile_hit_streak: int = 0
var _projectile_intercepts: int = 0
var _director_seed: int = 0
var _encounters_started: int = 0
var _encounters_completed: int = 0
var _breathers_seen: int = 0
var _highest_director_difficulty: int = 0
var _forced_rescue_ammo_spawns: int = 0
var _shield_hits_absorbed: int = 0
var _elite_kills: int = 0
var _special_enemy_kills: int = 0
var _armored_enemy_kills: int = 0
var _shielded_enemy_kills: int = 0
var _boundary_timeout_deaths: int = 0
var _boundary_chain_crashes: int = 0
var _ammo_refunds: int = 0
var _current_encounter_id: String = ""
var _current_director_phase: String = ""

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
	var quantized_elapsed := snappedf(maxf(_time_survived_seconds, 0.0), SURVIVAL_SCORE_TIME_STEP_SECONDS)
	_survival_score = int(floor(quantized_elapsed * 10.0))

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

func record_glowing_rock_clear() -> void:
	if not _run_active:
		return
	_glowing_rocks_triggered += 1

func record_boundary_bounce() -> void:
	if not _run_active:
		return
	_boundary_bounces += 1

func record_near_miss(kind: String) -> void:
	if not _run_active:
		return

	_near_misses += 1
	if kind == "projectile":
		_projectile_near_misses += 1
	else:
		_hostile_near_misses += 1

func record_skill_score(points: int) -> void:
	if not _run_active:
		return
	_skill_score += maxi(points, 0)

func record_combo_state(combo_events: int, multiplier: float) -> void:
	if not _run_active:
		return

	_max_combo_events = maxi(_max_combo_events, combo_events)
	_max_combo_multiplier = maxf(_max_combo_multiplier, multiplier)

func record_missile_hit(streak: int) -> void:
	if not _run_active:
		return

	_missile_hits += 1
	_max_missile_hit_streak = maxi(_max_missile_hit_streak, streak)

func record_missile_miss() -> void:
	if not _run_active:
		return
	_missile_misses += 1

func record_projectile_intercept() -> void:
	if not _run_active:
		return
	_projectile_intercepts += 1

func record_director_seed(seed_value: int) -> void:
	if not _run_active:
		return
	_director_seed = seed_value

func record_encounter_started(encounter_id: String, phase: String, difficulty: int) -> void:
	if not _run_active:
		return
	_encounters_started += 1
	_current_encounter_id = encounter_id
	_current_director_phase = phase
	_highest_director_difficulty = maxi(_highest_director_difficulty, difficulty)

func record_encounter_completed(_encounter_id: String) -> void:
	if not _run_active:
		return
	_encounters_completed += 1

func record_breather_seen() -> void:
	if not _run_active:
		return
	_breathers_seen += 1

func record_forced_rescue_ammo_spawn() -> void:
	if not _run_active:
		return
	_forced_rescue_ammo_spawns += 1

func record_shield_hit_absorbed() -> void:
	if not _run_active:
		return
	_shield_hits_absorbed += 1

func record_elite_kill() -> void:
	if not _run_active:
		return
	_elite_kills += 1

func record_special_enemy_kill(modifier: String = "") -> void:
	if not _run_active:
		return
	_special_enemy_kills += 1
	match modifier:
		"armored":
			_armored_enemy_kills += 1
		"shielded":
			_shielded_enemy_kills += 1

func record_boundary_timeout_death() -> void:
	if not _run_active:
		return
	_boundary_timeout_deaths += 1

func record_boundary_chain_crash() -> void:
	if not _run_active:
		return
	_boundary_chain_crashes += 1

func record_ammo_refund() -> void:
	if not _run_active:
		return
	_ammo_refunds += 1

func complete_run(final_score: int, extra_summary: Dictionary = {}) -> Dictionary:
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
		"time_survived": _time_survived_seconds,
		"time_survived_seconds": _time_survived_seconds,
		"survival_score": _survival_score,
		"missiles_fired": _missiles_fired,
		"hostiles_destroyed": _hostiles_destroyed,
		"ammo_pickups_collected": _ammo_pickups_collected,
		"glowing_rocks_triggered": _glowing_rocks_triggered,
		"boundary_bounces": _boundary_bounces,
		"near_misses": _near_misses,
		"hostile_near_misses": _hostile_near_misses,
		"projectile_near_misses": _projectile_near_misses,
		"skill_score": _skill_score,
		"max_combo_multiplier": _max_combo_multiplier,
		"max_combo_events": _max_combo_events,
		"missile_hits": _missile_hits,
		"missile_misses": _missile_misses,
		"max_missile_hit_streak": _max_missile_hit_streak,
		"projectile_intercepts": _projectile_intercepts,
		"director_seed": _director_seed,
		"encounters_started": _encounters_started,
		"encounters_completed": _encounters_completed,
		"breathers_seen": _breathers_seen,
		"highest_director_difficulty": _highest_director_difficulty,
		"forced_rescue_ammo_spawns": _forced_rescue_ammo_spawns,
		"shield_hits_absorbed": _shield_hits_absorbed,
		"elite_kills": _elite_kills,
		"special_enemy_kills": _special_enemy_kills,
		"armored_enemy_kills": _armored_enemy_kills,
		"shielded_enemy_kills": _shielded_enemy_kills,
		"boundary_timeout_deaths": _boundary_timeout_deaths,
		"boundary_chain_crashes": _boundary_chain_crashes,
		"ammo_refunds": _ammo_refunds,
		"crash_encounter_id": _current_encounter_id,
		"crash_director_phase": _current_director_phase,
	}
	for key in extra_summary.keys():
		_last_run_summary[str(key)] = extra_summary[key]

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

func restore_local_best_score(restored_best_score: int) -> bool:
	var safe_restored_best := maxi(restored_best_score, 0)
	if safe_restored_best <= _local_best_score:
		return false
	_local_best_score = safe_restored_best
	_save_local_best_score()
	return true

func get_last_run_summary() -> Dictionary:
	return _last_run_summary.duplicate(true)

func _reset_live_stats() -> void:
	_time_survived_seconds = 0.0
	_survival_score = 0
	_missiles_fired = 0
	_hostiles_destroyed = 0
	_ammo_pickups_collected = 0
	_glowing_rocks_triggered = 0
	_boundary_bounces = 0
	_near_misses = 0
	_hostile_near_misses = 0
	_projectile_near_misses = 0
	_skill_score = 0
	_max_combo_multiplier = 1.0
	_max_combo_events = 0
	_missile_hits = 0
	_missile_misses = 0
	_max_missile_hit_streak = 0
	_projectile_intercepts = 0
	_director_seed = 0
	_encounters_started = 0
	_encounters_completed = 0
	_breathers_seen = 0
	_highest_director_difficulty = 0
	_forced_rescue_ammo_spawns = 0
	_shield_hits_absorbed = 0
	_elite_kills = 0
	_special_enemy_kills = 0
	_armored_enemy_kills = 0
	_shielded_enemy_kills = 0
	_boundary_timeout_deaths = 0
	_boundary_chain_crashes = 0
	_ammo_refunds = 0
	_current_encounter_id = ""
	_current_director_phase = ""

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

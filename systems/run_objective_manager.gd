extends Node

signal objective_started(objective: Dictionary)
signal objective_progressed(objective: Dictionary)
signal objective_completed(objective: Dictionary)
signal objective_failed(objective: Dictionary)

const FIRST_OBJECTIVE_SECONDS := 70.0
const MIN_SECONDS_BETWEEN_OBJECTIVES := 45.0
const MAX_OBJECTIVES_PER_RUN := 2

const OBJECTIVE_CATALOG := {
	"rescue_pickup": {
		"title": "Rescue Pickup",
		"description": "Grab the rescue beacon.",
		"action": "rescue_pickup",
		"target": 1,
		"duration": 18.0,
		"reward_score": 160,
		"reward": "powerup",
	},
	"reactor_chain": {
		"title": "Reactor Chain",
		"description": "Destroy 3 threats quickly.",
		"action": "reactor_chain_kill",
		"target": 3,
		"duration": 24.0,
		"reward_score": 220,
		"reward": "upgrade",
	},
}

const DEFAULT_UNLOCKED_OBJECTIVES := ["rescue_pickup", "reactor_chain"]

var _rng := RandomNumberGenerator.new()
var _elapsed_seconds: float = 0.0
var _last_objective_time: float = -999.0
var _objectives_started: int = 0
var _objectives_completed: int = 0
var _objective_rewards_claimed: int = 0
var _active_objective: Dictionary = {}
var _completed_objective_ids: Array[String] = []

func start_run() -> void:
	_rng.seed = int(Time.get_ticks_usec() & 0x7fffffff)
	_elapsed_seconds = 0.0
	_last_objective_time = -999.0
	_objectives_started = 0
	_objectives_completed = 0
	_objective_rewards_claimed = 0
	_active_objective.clear()
	_completed_objective_ids.clear()

func update_run(delta: float) -> void:
	_elapsed_seconds += maxf(delta, 0.0)
	if not _active_objective.is_empty():
		_active_objective["remaining"] = maxf(float(_active_objective.get("remaining", 0.0)) - delta, 0.0)
		if float(_active_objective.get("remaining", 0.0)) <= 0.0:
			var failed := _active_objective.duplicate(true)
			_active_objective.clear()
			objective_failed.emit(failed)
		return

	if _objectives_started >= MAX_OBJECTIVES_PER_RUN:
		return
	if _elapsed_seconds < FIRST_OBJECTIVE_SECONDS:
		return
	if (_elapsed_seconds - _last_objective_time) < MIN_SECONDS_BETWEEN_OBJECTIVES:
		return

	var ids := get_unlocked_objective_ids()
	if ids.is_empty():
		return
	begin_objective(ids[_rng.randi_range(0, ids.size() - 1)])

func begin_objective(objective_id: String) -> bool:
	if not OBJECTIVE_CATALOG.has(objective_id) or not _active_objective.is_empty():
		return false
	var data: Dictionary = OBJECTIVE_CATALOG[objective_id]
	_active_objective = data.duplicate(true)
	_active_objective["id"] = objective_id
	_active_objective["progress"] = 0
	_active_objective["remaining"] = float(data.get("duration", 20.0))
	_objectives_started += 1
	_last_objective_time = _elapsed_seconds
	objective_started.emit(_active_objective.duplicate(true))
	return true

func record_objective_action(action: String, amount: int = 1) -> void:
	if _active_objective.is_empty():
		return
	if str(_active_objective.get("action", "")) != action:
		return
	_active_objective["progress"] = int(_active_objective.get("progress", 0)) + maxi(amount, 0)
	if int(_active_objective.get("progress", 0)) >= int(_active_objective.get("target", 1)):
		complete_objective(str(_active_objective.get("id", "")))
	else:
		objective_progressed.emit(_active_objective.duplicate(true))

func complete_objective(objective_id: String) -> bool:
	if _active_objective.is_empty() or str(_active_objective.get("id", "")) != objective_id:
		return false
	var completed := _active_objective.duplicate(true)
	_active_objective.clear()
	_objectives_completed += 1
	_objective_rewards_claimed += 1
	_completed_objective_ids.append(objective_id)
	objective_completed.emit(completed)
	return true

func fail_objective(objective_id: String) -> bool:
	if _active_objective.is_empty() or str(_active_objective.get("id", "")) != objective_id:
		return false
	var failed := _active_objective.duplicate(true)
	_active_objective.clear()
	objective_failed.emit(failed)
	return true

func get_active_objective() -> Dictionary:
	return _active_objective.duplicate(true)

func get_summary() -> Dictionary:
	return {
		"objective_events_started": _objectives_started,
		"objective_events_completed": _objectives_completed,
		"objective_rewards_claimed": _objective_rewards_claimed,
		"completed_objective_ids": _completed_objective_ids.duplicate(),
	}

func get_objective_catalog() -> Dictionary:
	return OBJECTIVE_CATALOG.duplicate(true)

func get_unlocked_objective_ids() -> Array[String]:
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile != null and profile.has_method("get_unlocked_objective_ids"):
		var ids: Array[String] = []
		for id_variant in profile.get_unlocked_objective_ids():
			var id := str(id_variant)
			if OBJECTIVE_CATALOG.has(id):
				ids.append(id)
		if not ids.is_empty():
			return ids
	return DEFAULT_UNLOCKED_OBJECTIVES.duplicate()

extends Node

signal objective_started(objective: Dictionary)
signal objective_progressed(objective: Dictionary)
signal objective_completed(objective: Dictionary)
signal objective_failed(objective: Dictionary)

const FIRST_OBJECTIVE_SECONDS := 42.0
const MIN_SECONDS_BETWEEN_OBJECTIVES := 32.0
const MAX_OBJECTIVES_PER_RUN := 3

const OBJECTIVE_CATALOG := {
	"rescue_pickup": {
		"title": "Rescue Pickup",
		"description": "Grab the rescue beacon.",
		"action": "rescue_pickup",
		"completion_mode": "action",
		"target": 1,
		"duration": 18.0,
		"reward_score": 160,
		"reward": "powerup",
		"spawn_pickup": true,
	},
	"reactor_chain": {
		"title": "Reactor Chain",
		"description": "Destroy 3 threats quickly.",
		"action": "reactor_chain_kill",
		"completion_mode": "action",
		"target": 3,
		"duration": 24.0,
		"reward_score": 220,
		"reward": "upgrade",
	},
	"black_box_recovery": {
		"title": "Black Box Recovery",
		"description": "Collect 2 black boxes.",
		"action": "black_box_pickup",
		"completion_mode": "action",
		"target": 2,
		"duration": 28.0,
		"reward_score": 240,
		"reward": "powerup",
		"spawn_pickup": true,
		"spawn_y_modes": ["lane_top", "lane_bottom"],
	},
	"signal_gates": {
		"title": "Signal Gates",
		"description": "Fly through 3 signal gates.",
		"action": "signal_gate",
		"completion_mode": "action",
		"target": 3,
		"duration": 26.0,
		"reward_score": 260,
		"reward": "score_rush",
		"spawn_pickup": true,
		"spawn_y_modes": ["lane_top", "lane_mid", "lane_bottom"],
	},
	"no_fire_signal": {
		"title": "No-Fire Signal",
		"description": "Survive without firing.",
		"action": "no_fire_timer",
		"completion_mode": "timer",
		"target": 18,
		"duration": 18.0,
		"reward_score": 220,
		"reward": "upgrade",
		"fail_actions": ["missile_fired"],
	},
	"barrage_intercept": {
		"title": "Barrage Intercept",
		"description": "Intercept 2 projectiles.",
		"action": "projectile_intercept",
		"completion_mode": "action",
		"target": 2,
		"duration": 24.0,
		"reward_score": 260,
		"reward": "ammo_refill",
		"start_event": "barrage_intercept_wave",
	},
	"bounty_drone": {
		"title": "Bounty Drone",
		"description": "Destroy the marked elite.",
		"action": "bounty_drone_kill",
		"completion_mode": "action",
		"target": 1,
		"duration": 30.0,
		"reward_score": 340,
		"reward": "upgrade",
		"requires_elapsed": 75.0,
		"start_event": "bounty_drone",
	},
	"clean_flight": {
		"title": "Clean Flight",
		"description": "Avoid boundary recovery.",
		"action": "clean_flight_timer",
		"completion_mode": "timer",
		"target": 20,
		"duration": 20.0,
		"reward_score": 240,
		"reward": "combo_boost",
		"fail_actions": ["boundary_recovery"],
	},
}

const DEFAULT_UNLOCKED_OBJECTIVES := [
	"rescue_pickup",
	"reactor_chain",
	"black_box_recovery",
	"signal_gates",
	"no_fire_signal",
	"barrage_intercept",
	"bounty_drone",
	"clean_flight",
]

var _rng := RandomNumberGenerator.new()
var _elapsed_seconds: float = 0.0
var _last_objective_time: float = -999.0
var _objectives_started: int = 0
var _objectives_completed: int = 0
var _objective_rewards_claimed: int = 0
var _active_objective: Dictionary = {}
var _completed_objective_ids: Array[String] = []
var _started_objective_ids: Array[String] = []

func start_run() -> void:
	_rng.seed = int(Time.get_ticks_usec() & 0x7fffffff)
	_elapsed_seconds = 0.0
	_last_objective_time = -999.0
	_objectives_started = 0
	_objectives_completed = 0
	_objective_rewards_claimed = 0
	_active_objective.clear()
	_completed_objective_ids.clear()
	_started_objective_ids.clear()

func update_run(delta: float) -> void:
	_elapsed_seconds += maxf(delta, 0.0)
	if not _active_objective.is_empty():
		_active_objective["remaining"] = maxf(float(_active_objective.get("remaining", 0.0)) - delta, 0.0)
		if str(_active_objective.get("completion_mode", "action")) == "timer":
			var duration := float(_active_objective.get("duration", 1.0))
			var target := int(_active_objective.get("target", int(ceil(duration))))
			var elapsed := duration - float(_active_objective.get("remaining", 0.0))
			_active_objective["progress"] = mini(target, int(floor(elapsed)))
		if float(_active_objective.get("remaining", 0.0)) <= 0.0:
			if str(_active_objective.get("completion_mode", "action")) == "timer":
				_active_objective["progress"] = int(_active_objective.get("target", 1))
				complete_objective(str(_active_objective.get("id", "")))
			else:
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

	var ids := _get_available_objective_ids()
	if ids.is_empty():
		return
	begin_objective(ids[_rng.randi_range(0, ids.size() - 1)])

func begin_objective(objective_id: String) -> bool:
	if not OBJECTIVE_CATALOG.has(objective_id) or not _active_objective.is_empty():
		return false
	var data: Dictionary = OBJECTIVE_CATALOG[objective_id]
	if _elapsed_seconds < float(data.get("requires_elapsed", 0.0)):
		return false
	_active_objective = data.duplicate(true)
	_active_objective["id"] = objective_id
	_active_objective["progress"] = 0
	_active_objective["remaining"] = float(data.get("duration", 20.0))
	_objectives_started += 1
	_last_objective_time = _elapsed_seconds
	_started_objective_ids.append(objective_id)
	objective_started.emit(_active_objective.duplicate(true))
	return true

func record_objective_action(action: String, amount: int = 1) -> void:
	if _active_objective.is_empty():
		return
	var fail_actions: Array = _active_objective.get("fail_actions", [])
	if fail_actions.has(action):
		fail_objective(str(_active_objective.get("id", "")))
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
	var ids: Array[String] = []
	for objective_id in DEFAULT_UNLOCKED_OBJECTIVES:
		if OBJECTIVE_CATALOG.has(objective_id) and not ids.has(objective_id):
			ids.append(objective_id)
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile != null and profile.has_method("get_unlocked_objective_ids"):
		for id_variant in profile.get_unlocked_objective_ids():
			var id := str(id_variant)
			if OBJECTIVE_CATALOG.has(id) and not ids.has(id):
				ids.append(id)
	return ids

func _get_available_objective_ids() -> Array[String]:
	var eligible: Array[String] = []
	var fresh: Array[String] = []
	for objective_id in get_unlocked_objective_ids():
		var data: Dictionary = OBJECTIVE_CATALOG.get(objective_id, {})
		if data.is_empty():
			continue
		if _elapsed_seconds < float(data.get("requires_elapsed", 0.0)):
			continue
		eligible.append(objective_id)
		if not _started_objective_ids.has(objective_id):
			fresh.append(objective_id)
	return fresh if not fresh.is_empty() else eligible

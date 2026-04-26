extends Node

signal powerup_collected(powerup_id: String, summary: Dictionary)
signal powerup_activated(powerup_id: String, data: Dictionary)
signal powerup_expired(powerup_id: String)
signal active_effects_changed(effects: Array[Dictionary])

const POWERUP_CATALOG := {
	"shield_bubble": {
		"name": "Shield Bubble",
		"description": "Absorbs the next crash hit.",
		"duration": 12.0,
		"power": 1.5,
		"effect": "shield",
	},
	"score_rush": {
		"name": "Score Rush",
		"description": "Skill and survival score surge.",
		"duration": 9.0,
		"power": 1.5,
		"effect": "score",
	},
	"missile_overdrive": {
		"name": "Missile Overdrive",
		"description": "Missiles fire fast and ignore ammo.",
		"duration": 8.0,
		"power": 2.0,
		"effect": "missile",
	},
	"ammo_magnet": {
		"name": "Ammo Magnet",
		"description": "Pull nearby pickups into reach.",
		"duration": 10.0,
		"power": 1.0,
		"effect": "utility",
	},
	"emp_burst": {
		"name": "EMP Burst",
		"description": "Clears projectiles and shocks enemies.",
		"duration": 0.4,
		"power": 1.5,
		"effect": "burst",
	},
	"afterburner_burst": {
		"name": "Afterburner Burst",
		"description": "Punch forward with extra lift control.",
		"duration": 5.5,
		"power": 1.0,
		"effect": "movement",
	},
}

const DEFAULT_UNLOCKED_POWERUPS := [
	"shield_bubble",
	"score_rush",
	"missile_overdrive",
	"ammo_magnet",
	"emp_burst",
	"afterburner_burst",
]

var _rng := RandomNumberGenerator.new()
var _active_effects: Dictionary = {}
var _collected_counts: Dictionary = {}
var _used_counts: Dictionary = {}
var _effect_seconds: Dictionary = {}
var _shield_hits_absorbed: int = 0
var _emp_activations: int = 0

func start_run() -> void:
	_rng.seed = int(Time.get_ticks_usec() & 0x7fffffff)
	_active_effects.clear()
	_collected_counts.clear()
	_used_counts.clear()
	_effect_seconds.clear()
	_shield_hits_absorbed = 0
	_emp_activations = 0
	active_effects_changed.emit(get_active_effects())

func update_run(delta: float) -> void:
	var expired: Array[String] = []
	for powerup_id in _active_effects.keys():
		var effect: Dictionary = _active_effects[powerup_id]
		var previous_remaining := float(effect.get("remaining", 0.0))
		var elapsed_active_time := minf(maxf(delta, 0.0), previous_remaining)
		var remaining := maxf(previous_remaining - delta, 0.0)
		effect["remaining"] = remaining
		_active_effects[powerup_id] = effect
		_effect_seconds[powerup_id] = float(_effect_seconds.get(powerup_id, 0.0)) + elapsed_active_time
		if remaining <= 0.0:
			expired.append(str(powerup_id))

	for powerup_id in expired:
		_active_effects.erase(powerup_id)
		powerup_expired.emit(powerup_id)

	if not expired.is_empty():
		active_effects_changed.emit(get_active_effects())

func activate_powerup(powerup_id: String) -> bool:
	if not POWERUP_CATALOG.has(powerup_id):
		return false

	var data: Dictionary = POWERUP_CATALOG[powerup_id]
	var duration := float(data.get("duration", 0.0))
	_collected_counts[powerup_id] = int(_collected_counts.get(powerup_id, 0)) + 1
	_used_counts[powerup_id] = int(_used_counts.get(powerup_id, 0)) + 1
	if powerup_id == "emp_burst":
		_emp_activations += 1
		_record_live_mission_progress("emp_activations", 1.0)
	_record_live_mission_progress("powerups_collected", 1.0)
	_record_live_mission_progress("powerups_used", 1.0)

	_active_effects[powerup_id] = {
		"id": powerup_id,
		"name": str(data.get("name", powerup_id.capitalize())),
		"remaining": duration,
		"duration": duration,
		"effect": str(data.get("effect", "")),
	}

	powerup_collected.emit(powerup_id, get_summary())
	powerup_activated.emit(powerup_id, data.duplicate(true))
	active_effects_changed.emit(get_active_effects())
	return true

func has_active_effect(powerup_id: String) -> bool:
	return _active_effects.has(powerup_id)

func consume_shield_hit() -> bool:
	if not has_active_effect("shield_bubble"):
		return false
	_active_effects.erase("shield_bubble")
	_shield_hits_absorbed += 1
	powerup_expired.emit("shield_bubble")
	active_effects_changed.emit(get_active_effects())
	return true

func get_active_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for powerup_id in _active_effects.keys():
		effects.append((_active_effects[powerup_id] as Dictionary).duplicate(true))
	effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return effects

func get_effect_modifiers() -> Dictionary:
	var modifiers := {
		"score_multiplier": 1.0,
		"survival_score_multiplier": 1.0,
		"missile_cooldown_multiplier": 1.0,
		"free_missiles": false,
		"ammo_magnet": false,
		"afterburner": false,
	}
	if has_active_effect("score_rush"):
		modifiers["score_multiplier"] = 1.75
		modifiers["survival_score_multiplier"] = 1.5
	if has_active_effect("missile_overdrive"):
		modifiers["missile_cooldown_multiplier"] = 0.35
		modifiers["free_missiles"] = true
	if has_active_effect("ammo_magnet"):
		modifiers["ammo_magnet"] = true
	if has_active_effect("afterburner_burst"):
		modifiers["afterburner"] = true
	return modifiers

func get_power_score() -> float:
	var score := 0.0
	for powerup_id in _active_effects.keys():
		var data: Dictionary = POWERUP_CATALOG.get(str(powerup_id), {})
		score += float(data.get("power", 1.0))
	return minf(score, 6.0)

func get_summary() -> Dictionary:
	var total_collected := 0
	var total_used := 0
	for value in _collected_counts.values():
		total_collected += int(value)
	for value in _used_counts.values():
		total_used += int(value)
	return {
		"powerups_collected": total_collected,
		"powerups_used": total_used,
		"powerup_counts": _collected_counts.duplicate(true),
		"powerup_used_counts": _used_counts.duplicate(true),
		"powerup_shield_hits_absorbed": _shield_hits_absorbed,
		"score_rush_seconds": float(_effect_seconds.get("score_rush", 0.0)),
		"overdrive_seconds": float(_effect_seconds.get("missile_overdrive", 0.0)),
		"emp_activations": _emp_activations,
		"active_powerups": get_active_effects(),
	}

func get_powerup_catalog() -> Dictionary:
	return POWERUP_CATALOG.duplicate(true)

func get_random_powerup_id() -> String:
	var ids := get_unlocked_powerup_ids()
	if ids.is_empty():
		return "shield_bubble"
	return ids[_rng.randi_range(0, ids.size() - 1)]

func get_unlocked_powerup_ids() -> Array[String]:
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile != null and profile.has_method("get_unlocked_powerup_ids"):
		var ids: Array[String] = []
		for id_variant in profile.get_unlocked_powerup_ids():
			var id := str(id_variant)
			if POWERUP_CATALOG.has(id):
				ids.append(id)
		if not ids.is_empty():
			return ids
	return DEFAULT_UNLOCKED_POWERUPS.duplicate()

func _record_live_mission_progress(mission_type: String, amount: float) -> void:
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null and mission_manager.has_method("record_live_mission_progress"):
		mission_manager.record_live_mission_progress(mission_type, amount)

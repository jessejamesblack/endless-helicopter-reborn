extends Node

signal choice_ready(offers: Array[Dictionary], reason: String)
signal upgrade_chosen(upgrade_id: String, summary: Dictionary)

const CHOICE_TIMES_SECONDS: Array[float] = [35.0, 75.0, 120.0, 170.0]
const MAX_CHOICES_PER_RUN := 4
const MIN_SECONDS_BETWEEN_CHOICES := 20.0
const DEFAULT_OFFER_COUNT := 3
const SCOUT_FIRST_OFFER_COUNT := 4

const UPGRADE_CATALOG := {
	"twin_missiles": {
		"name": "Twin Missiles",
		"description": "Fire a paired spread shot.",
		"category": "missile",
		"max_level": 1,
		"power": 2.0,
		"modifiers": {"extra_missiles": 1},
	},
	"homing_missiles": {
		"name": "Homing Missiles",
		"description": "Missiles gently steer toward enemies.",
		"category": "missile",
		"max_level": 1,
		"power": 2.0,
		"modifiers": {"homing_missiles": true},
	},
	"bigger_magazine": {
		"name": "Bigger Magazine",
		"description": "Carry more missiles this run.",
		"category": "missile",
		"max_level": 3,
		"power": 1.0,
		"modifiers": {"max_ammo_bonus": 2},
	},
	"faster_fire_rate": {
		"name": "Faster Fire Rate",
		"description": "Missile shots recover faster.",
		"category": "missile",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"missile_cooldown_multiplier": -0.14},
	},
	"bigger_blast": {
		"name": "Bigger Blast",
		"description": "Missile kills are worth more.",
		"category": "missile",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"missile_score_bonus": 18},
	},
	"refund_chamber": {
		"name": "Refund Chamber",
		"description": "Missile hits can refund ammo.",
		"category": "missile",
		"max_level": 2,
		"power": 1.5,
		"modifiers": {"ammo_refund_chance": 0.24},
	},
	"temporary_shield": {
		"name": "Temporary Shield",
		"description": "Gain a one-hit crash shield.",
		"category": "survival",
		"max_level": 2,
		"power": 1.5,
		"modifiers": {"run_shield_charges": 1},
	},
	"stronger_recovery": {
		"name": "Stronger Recovery",
		"description": "Boundary bounces recover harder.",
		"category": "survival",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"boundary_recovery_multiplier": 0.12},
	},
	"stabilizers": {
		"name": "Stabilizers",
		"description": "Handling gets steadier after taps.",
		"category": "survival",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"gravity_multiplier": -0.05, "tilt_speed_bonus": 0.25},
	},
	"rotor_wash": {
		"name": "Rotor Wash",
		"description": "Near misses score more and help control.",
		"category": "survival",
		"max_level": 1,
		"power": 1.0,
		"modifiers": {"near_miss_multiplier": 0.18, "boundary_chain_bonus": 1},
	},
	"near_miss_amplifier": {
		"name": "Near-Miss Amplifier",
		"description": "Threading danger pays better.",
		"category": "score",
		"max_level": 3,
		"power": 1.0,
		"modifiers": {"near_miss_multiplier": 0.22},
	},
	"combo_battery": {
		"name": "Combo Battery",
		"description": "Combos last longer.",
		"category": "score",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"combo_timeout_bonus": 0.55},
	},
	"interceptor_bonus": {
		"name": "Interceptor Bonus",
		"description": "Projectile intercepts pay better.",
		"category": "score",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"interceptor_bonus": 25},
	},
	"precision_payoff": {
		"name": "Precision Payoff",
		"description": "Hit streaks add more score.",
		"category": "score",
		"max_level": 2,
		"power": 1.0,
		"modifiers": {"precision_bonus": 20},
	},
}

const DEFAULT_UNLOCKED_UPGRADES := [
	"twin_missiles",
	"bigger_magazine",
	"faster_fire_rate",
	"temporary_shield",
	"stronger_recovery",
	"near_miss_amplifier",
	"combo_battery",
	"interceptor_bonus",
	"precision_payoff",
	"rotor_wash",
]

const VEHICLE_PASSIVES := {
	"default_scout": {
		"passive_id": "reliable_frame",
		"name": "Reliable Frame",
		"modifiers": {"first_choice_offer_bonus": 1},
	},
	"bubble_chopper": {
		"passive_id": "near_miss_specialist",
		"name": "Needle Threader",
		"modifiers": {"near_miss_multiplier": 0.18, "combo_timeout_bonus": 0.25},
	},
	"huey_runner": {
		"passive_id": "ammo_utility",
		"name": "Utility Loader",
		"modifiers": {"max_ammo_bonus": 1, "ammo_refund_chance": 0.08},
	},
	"blackhawk_shadow": {
		"passive_id": "shield_recovery",
		"name": "Shadow Plating",
		"modifiers": {"run_shield_charges": 1, "boundary_recovery_multiplier": 0.08},
	},
	"apache_strike": {
		"passive_id": "missile_striker",
		"name": "Strike Package",
		"modifiers": {"missile_score_bonus": 12, "missile_cooldown_multiplier": -0.08},
	},
	"chinook_lift": {
		"passive_id": "combo_stabilizer",
		"name": "Long-Haul Rhythm",
		"modifiers": {"combo_timeout_bonus": 0.45, "gravity_multiplier": -0.04},
	},
	"crazytaxi": {
		"passive_id": "chaotic_scoring",
		"name": "Fare Rush",
		"modifiers": {"near_miss_multiplier": 0.12, "precision_bonus": 15},
	},
	"pottercar": {
		"passive_id": "prestige_oddity",
		"name": "Prestige Oddity",
		"modifiers": {"choice_weight_bonus": 0.08, "combo_timeout_bonus": 0.2},
	},
}

var _rng := RandomNumberGenerator.new()
var _elapsed_seconds: float = 0.0
var _next_choice_index: int = 0
var _choices_made: int = 0
var _last_choice_time: float = -999.0
var _vehicle_id: String = "default_scout"
var _levels: Dictionary = {}
var _pending_offers: Array[Dictionary] = []
var _pending_reason: String = ""
var _chosen_history: Array[String] = []
var _run_shield_charges: int = 0
var _ammo_refunds: int = 0

func start_run(vehicle_id: String = "default_scout") -> void:
	_rng.seed = int(Time.get_ticks_usec() & 0x7fffffff)
	_elapsed_seconds = 0.0
	_next_choice_index = 0
	_choices_made = 0
	_last_choice_time = -999.0
	_vehicle_id = vehicle_id
	_levels.clear()
	_pending_offers.clear()
	_pending_reason = ""
	_chosen_history.clear()
	_run_shield_charges = int(_get_vehicle_passive_modifiers().get("run_shield_charges", 0))
	_ammo_refunds = 0

func update_run(delta: float) -> void:
	if _choices_made >= MAX_CHOICES_PER_RUN or not _pending_offers.is_empty():
		return
	_elapsed_seconds += maxf(delta, 0.0)
	if _next_choice_index >= CHOICE_TIMES_SECONDS.size():
		return
	if _elapsed_seconds >= CHOICE_TIMES_SECONDS[_next_choice_index]:
		_next_choice_index += 1
		request_choice("milestone")

func request_choice(reason: String = "reward") -> bool:
	if _choices_made >= MAX_CHOICES_PER_RUN:
		return false
	if not _pending_offers.is_empty():
		return false
	if reason != "milestone" and (_elapsed_seconds - _last_choice_time) < MIN_SECONDS_BETWEEN_CHOICES:
		return false

	var offers := _build_offer_set(_get_offer_count_for_next_choice())
	if offers.is_empty():
		return false

	_pending_offers = offers
	_pending_reason = reason
	choice_ready.emit(_pending_offers.duplicate(true), reason)
	return true

func choose_upgrade(upgrade_id: String) -> bool:
	if _pending_offers.is_empty():
		return false
	var allowed := false
	for offer in _pending_offers:
		if str(offer.get("id", "")) == upgrade_id:
			allowed = true
			break
	if not allowed:
		return false

	var next_level := get_upgrade_level(upgrade_id) + 1
	var data: Dictionary = UPGRADE_CATALOG.get(upgrade_id, {})
	var max_level := int(data.get("max_level", 1))
	if next_level > max_level:
		return false

	_levels[upgrade_id] = next_level
	_chosen_history.append(upgrade_id)
	_choices_made += 1
	_last_choice_time = _elapsed_seconds
	_pending_offers.clear()
	_pending_reason = ""

	var run_shields := int(data.get("modifiers", {}).get("run_shield_charges", 0))
	if run_shields > 0:
		_run_shield_charges += run_shields

	upgrade_chosen.emit(upgrade_id, get_summary())
	return true

func has_pending_choice() -> bool:
	return not _pending_offers.is_empty()

func get_pending_offers() -> Array[Dictionary]:
	return _pending_offers.duplicate(true)

func get_upgrade_level(upgrade_id: String) -> int:
	return int(_levels.get(upgrade_id, 0))

func consume_run_shield_charge() -> bool:
	if _run_shield_charges <= 0:
		return false
	_run_shield_charges -= 1
	return true

func get_run_modifiers() -> Dictionary:
	var modifiers := _get_vehicle_passive_modifiers()
	for upgrade_id in _levels.keys():
		var level := int(_levels[upgrade_id])
		var data: Dictionary = UPGRADE_CATALOG.get(str(upgrade_id), {})
		var upgrade_modifiers: Dictionary = data.get("modifiers", {})
		for key in upgrade_modifiers.keys():
			var value = upgrade_modifiers[key]
			if value is bool:
				modifiers[key] = bool(modifiers.get(key, false)) or value
			elif value is int or value is float:
				modifiers[key] = float(modifiers.get(key, 0.0)) + float(value) * float(level)
			else:
				modifiers[key] = value
	modifiers["run_shield_charges"] = _run_shield_charges
	modifiers["vehicle_passive_id"] = get_vehicle_passive_id()
	return modifiers

func get_run_power_score() -> float:
	var score := 0.0
	for upgrade_id in _levels.keys():
		var data: Dictionary = UPGRADE_CATALOG.get(str(upgrade_id), {})
		score += float(data.get("power", 1.0)) * float(_levels[upgrade_id])
	score += minf(float(_run_shield_charges) * 0.75, 2.0)
	return minf(score, 10.0)

func get_vehicle_passive_id() -> String:
	var passive: Dictionary = VEHICLE_PASSIVES.get(_vehicle_id, VEHICLE_PASSIVES["default_scout"])
	return str(passive.get("passive_id", "reliable_frame"))

func get_vehicle_passive_name() -> String:
	var passive: Dictionary = VEHICLE_PASSIVES.get(_vehicle_id, VEHICLE_PASSIVES["default_scout"])
	return str(passive.get("name", "Reliable Frame"))

func get_vehicle_passive_data(vehicle_id: String) -> Dictionary:
	var passive: Dictionary = VEHICLE_PASSIVES.get(vehicle_id, VEHICLE_PASSIVES["default_scout"])
	return passive.duplicate(true)

func get_summary() -> Dictionary:
	return {
		"upgrades_chosen": _choices_made,
		"run_upgrades_chosen": _choices_made,
		"upgrade_levels": _levels.duplicate(true),
		"chosen_upgrades": _chosen_history.duplicate(),
		"vehicle_passive_id": get_vehicle_passive_id(),
		"vehicle_passive_name": get_vehicle_passive_name(),
		"run_shield_charges_remaining": _run_shield_charges,
		"ammo_refunds": _ammo_refunds,
	}

func record_ammo_refund() -> void:
	_ammo_refunds += 1

func get_upgrade_catalog() -> Dictionary:
	return UPGRADE_CATALOG.duplicate(true)

func get_unlocked_upgrade_ids() -> Array[String]:
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile != null and profile.has_method("get_unlocked_upgrade_ids"):
		var ids: Array[String] = []
		for id_variant in profile.get_unlocked_upgrade_ids():
			var id := str(id_variant)
			if UPGRADE_CATALOG.has(id):
				ids.append(id)
		if ids.size() >= 3:
			return ids
	return DEFAULT_UNLOCKED_UPGRADES.duplicate()

func _build_offer_set(offer_count: int = DEFAULT_OFFER_COUNT) -> Array[Dictionary]:
	var available: Array[String] = []
	for upgrade_id in get_unlocked_upgrade_ids():
		var data: Dictionary = UPGRADE_CATALOG.get(upgrade_id, {})
		if data.is_empty():
			continue
		if get_upgrade_level(upgrade_id) >= int(data.get("max_level", 1)):
			continue
		available.append(upgrade_id)

	if available.is_empty():
		return []

	available.shuffle()
	var chosen_categories: Dictionary = {}
	var offers: Array[Dictionary] = []
	for upgrade_id in available:
		var data: Dictionary = UPGRADE_CATALOG[upgrade_id]
		var category := str(data.get("category", "misc"))
		if offers.size() < 2 and chosen_categories.has(category):
			continue
		offers.append(_build_offer(upgrade_id, data))
		chosen_categories[category] = true
		if offers.size() >= offer_count:
			break

	if offers.size() < offer_count:
		for upgrade_id in available:
			if _offers_include(offers, upgrade_id):
				continue
			offers.append(_build_offer(upgrade_id, UPGRADE_CATALOG[upgrade_id]))
			if offers.size() >= offer_count:
				break

	return offers

func _get_offer_count_for_next_choice() -> int:
	if _vehicle_id != "default_scout" or _choices_made > 0:
		return DEFAULT_OFFER_COUNT
	var bonus := int(_get_vehicle_passive_modifiers().get("first_choice_offer_bonus", 0))
	return clampi(DEFAULT_OFFER_COUNT + bonus, DEFAULT_OFFER_COUNT, SCOUT_FIRST_OFFER_COUNT)

func _build_offer(upgrade_id: String, data: Dictionary) -> Dictionary:
	var next_level := get_upgrade_level(upgrade_id) + 1
	return {
		"id": upgrade_id,
		"name": str(data.get("name", upgrade_id.capitalize())),
		"description": str(data.get("description", "")),
		"category": str(data.get("category", "misc")),
		"level": next_level,
		"max_level": int(data.get("max_level", 1)),
	}

func _offers_include(offers: Array[Dictionary], upgrade_id: String) -> bool:
	for offer in offers:
		if str(offer.get("id", "")) == upgrade_id:
			return true
	return false

func _get_vehicle_passive_modifiers() -> Dictionary:
	var passive: Dictionary = VEHICLE_PASSIVES.get(_vehicle_id, VEHICLE_PASSIVES["default_scout"])
	return (passive.get("modifiers", {}) as Dictionary).duplicate(true)

extends Node2D

const EncounterCatalog = preload("res://scenes/game/main/encounter_catalog.gd")

@export var obstacle_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://scenes/pickups/missile_pickup.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy_unit.tscn")
@export var spawn_interval: float = 2.0
@export var spawn_y_min: float = 100.0
@export var spawn_y_max: float = 500.0
@export var use_encounter_director: bool = true
@export var debug_seed: int = 0
@export var show_director_debug: bool = false

const ENEMY_VARIANTS := [
	{"kind": "large_spiky_rock", "weight": 0.58},
	{"kind": "alien_drone", "weight": 0.24},
	{"kind": "stationary_turret", "weight": 0.12},
	{"kind": "glowing_rock", "weight": 0.06},
]
const SAFE_OPENING_SECONDS := 12.0
const FIRST_TURRET_SECONDS := 60.0
const FIRST_GLOWING_SECONDS := 30.0
const MIN_GLOWING_INTERVAL_SECONDS := 35.0
const MAX_AMMO_DROUGHT_SECONDS := 28.0
const MAX_ACTIVE_HOSTILES_OPENING := 1
const MAX_ACTIVE_HOSTILES_WARMUP := 2
const MAX_ACTIVE_HOSTILES_COMBAT_INTRO := 3
const MAX_ACTIVE_HOSTILES_PRESSURE := 5
const MAX_ACTIVE_PROJECTILES := 5
const TURRET_BOTTOM_INSET := 34.0

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _director_seed: int = 0
var _current_encounter: Dictionary = {}
var _current_spawn_index: int = 0
var _encounter_elapsed: float = 0.0
var _encounter_cooldowns: Dictionary = {}
var _last_breather_elapsed: float = 0.0
var _next_breather_after: float = 28.0
var _last_ammo_elapsed: float = -999.0
var _last_glowing_elapsed: float = -999.0
var _encounters_started: int = 0
var _encounters_completed: int = 0
var _breathers_seen: int = 0
var _highest_director_difficulty: int = 0
var _forced_rescue_ammo_spawns: int = 0

func _ready() -> void:
	_reset_director()

func reset_for_run() -> void:
	_reset_director()

func _process(delta: float) -> void:
	var main := _get_main()
	if main != null and bool(main.get("is_crashed")):
		return

	if not use_encounter_director:
		_process_legacy_random_spawning(delta)
		return

	_elapsed += delta
	_tick_cooldowns(delta)

	if _should_spawn_rescue_ammo():
		_spawn_director_request({"type": "pickup", "y_mode": "random_mid"})
		_last_ammo_elapsed = _elapsed
		_forced_rescue_ammo_spawns += 1
		var run_stats := _get_run_stats()
		if run_stats != null and run_stats.has_method("record_forced_rescue_ammo_spawn"):
			run_stats.record_forced_rescue_ammo_spawn()
		return

	if _current_encounter.is_empty():
		_start_next_encounter()

	_process_current_encounter(delta)

func _process_legacy_random_spawning(delta: float) -> void:
	var current_interval := spawn_interval
	var main := _get_main()
	if main != null:
		current_interval /= float(main.get("speed_multiplier"))

	_timer += delta
	if _timer < current_interval:
		return

	_timer -= current_interval
	if _rng.randf() < 0.2:
		spawn_scene(pickup_scene)
	else:
		spawn_enemy()

func _reset_director() -> void:
	_timer = 0.0
	_elapsed = 0.0
	_current_encounter = {}
	_current_spawn_index = 0
	_encounter_elapsed = 0.0
	_encounter_cooldowns.clear()
	_last_breather_elapsed = 0.0
	_next_breather_after = 24.0
	_last_ammo_elapsed = -999.0
	_last_glowing_elapsed = -999.0
	_encounters_started = 0
	_encounters_completed = 0
	_breathers_seen = 0
	_highest_director_difficulty = 0
	_forced_rescue_ammo_spawns = 0

	if debug_seed != 0:
		_director_seed = debug_seed
	else:
		_director_seed = int(Time.get_ticks_usec() & 0x7fffffff)

	_rng.seed = _director_seed

	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("record_director_seed"):
		run_stats.record_director_seed(_director_seed)

func spawn_enemy() -> void:
	var roll := _rng.randf()
	var running_total := 0.0

	for variant in ENEMY_VARIANTS:
		running_total += float(variant["weight"])
		if roll <= running_total:
			var kind := str(variant["kind"])
			if kind == "large_spiky_rock":
				spawn_scene(obstacle_scene)
			elif kind == "stationary_turret" and _has_active_turret():
				spawn_scene(obstacle_scene)
			else:
				spawn_enemy_variant(kind)
			return

	spawn_scene(obstacle_scene)

func spawn_scene_at_y(scene_to_spawn: PackedScene, y: float) -> void:
	if scene_to_spawn == null:
		push_error("Scene is not assigned in the Spawner!")
		return

	var item := scene_to_spawn.instantiate()
	item.position = Vector2(0.0, clampf(y, spawn_y_min, spawn_y_max))
	add_child(item)

func spawn_enemy_variant_at_y(kind: String, y: float) -> void:
	if enemy_scene == null:
		push_error("Enemy scene is not assigned in the Spawner!")
		return

	var enemy := enemy_scene.instantiate()
	enemy.position = Vector2(0.0, clampf(y, spawn_y_min, spawn_y_max))
	if kind == "stationary_turret":
		enemy.position.y = get_viewport_rect().size.y - TURRET_BOTTOM_INSET

	if enemy.has_method("configure"):
		enemy.configure(kind)

	add_child(enemy)

func spawn_scene(scene_to_spawn: PackedScene) -> void:
	spawn_scene_at_y(scene_to_spawn, _resolve_spawn_y({"y_mode": "random_any"}))

func spawn_enemy_variant(kind: String) -> void:
	spawn_enemy_variant_at_y(kind, _get_spawn_y_for_kind(kind))

func _get_spawn_y_for_kind(kind: String) -> float:
	if kind == "stationary_turret":
		return get_viewport_rect().size.y - TURRET_BOTTOM_INSET
	return _resolve_spawn_y({"y_mode": "random_any"})

func _start_next_encounter() -> void:
	var phase := EncounterCatalog.get_phase_for_time(_elapsed)
	var candidates := _get_valid_encounter_candidates(phase)

	if candidates.is_empty():
		_current_encounter = _make_fallback_breather()
	else:
		_current_encounter = _weighted_pick(candidates)

	_current_spawn_index = 0
	_encounter_elapsed = 0.0
	_encounters_started += 1

	var difficulty := int(_current_encounter.get("difficulty", 0))
	_highest_director_difficulty = maxi(_highest_director_difficulty, difficulty)

	if _has_tag(_current_encounter, "breather"):
		_breathers_seen += 1
		_last_breather_elapsed = _elapsed
		_next_breather_after = _rng.randf_range(22.0, 30.0)
		var run_stats := _get_run_stats()
		if run_stats != null and run_stats.has_method("record_breather_seen"):
			run_stats.record_breather_seen()

	_set_encounter_cooldown(_current_encounter)

	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("record_encounter_started"):
		run_stats.record_encounter_started(str(_current_encounter.get("id", "")), phase, difficulty)

func _get_valid_encounter_candidates(phase: String) -> Array[Dictionary]:
	var all := EncounterCatalog.get_encounters()
	var valid: Array[Dictionary] = []
	var force_breather := (_elapsed - _last_breather_elapsed) >= _next_breather_after

	for encounter in all:
		if not _encounter_matches_phase(encounter, phase):
			continue
		if force_breather and not _has_tag(encounter, "breather"):
			continue
		if not _passes_elapsed_requirement(encounter):
			continue
		if _is_on_cooldown(encounter):
			continue
		if not _passes_fairness_caps(encounter):
			continue
		valid.append(encounter)

	return valid

func _encounter_matches_phase(encounter: Dictionary, phase: String) -> bool:
	var phases: Array = encounter.get("phases", [])
	return phases.has(phase)

func _passes_elapsed_requirement(encounter: Dictionary) -> bool:
	return _elapsed >= float(encounter.get("requires_elapsed", 0.0))

func _is_on_cooldown(encounter: Dictionary) -> bool:
	return float(_encounter_cooldowns.get(str(encounter.get("id", "")), 0.0)) > 0.0

func _set_encounter_cooldown(encounter: Dictionary) -> void:
	var encounter_id := str(encounter.get("id", ""))
	var cooldown := float(encounter.get("cooldown", 0.0))
	if encounter_id.is_empty() or cooldown <= 0.0:
		return
	_encounter_cooldowns[encounter_id] = cooldown

func _tick_cooldowns(delta: float) -> void:
	for encounter_id in _encounter_cooldowns.keys().duplicate():
		var remaining := maxf(float(_encounter_cooldowns[encounter_id]) - delta, 0.0)
		if remaining <= 0.0:
			_encounter_cooldowns.erase(encounter_id)
		else:
			_encounter_cooldowns[encounter_id] = remaining

func _has_tag(encounter: Dictionary, tag: String) -> bool:
	var tags: Array = encounter.get("tags", [])
	return tags.has(tag)

func _weighted_pick(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}

	var total_weight := 0.0
	for encounter in candidates:
		total_weight += float(encounter.get("weight", 1.0))

	if total_weight <= 0.0:
		return candidates[0]

	var roll := _rng.randf() * total_weight
	var running_total := 0.0
	for encounter in candidates:
		running_total += float(encounter.get("weight", 1.0))
		if roll <= running_total:
			return encounter

	return candidates[candidates.size() - 1]

func _make_fallback_breather() -> Dictionary:
	return {
		"id": "fallback_breather_ammo",
		"phases": [EncounterCatalog.get_phase_for_time(_elapsed)],
		"difficulty": 0,
		"weight": 1.0,
		"duration": 4.0,
		"cooldown": 0.0,
		"tags": ["breather", "ammo", "fallback"],
		"spawns": [
			{"at": 1.0, "type": "pickup", "y_mode": "lane_mid"}
		]
	}

func _process_current_encounter(delta: float) -> void:
	if _current_encounter.is_empty():
		return

	_encounter_elapsed += delta
	var spawns: Array = _current_encounter.get("spawns", [])
	while _current_spawn_index < spawns.size():
		var request: Dictionary = spawns[_current_spawn_index]
		var spawn_at := float(request.get("at", 0.0))
		if _encounter_elapsed < spawn_at:
			break
		if _can_spawn_request(request):
			_spawn_director_request(request)
		_current_spawn_index += 1

	var duration := float(_current_encounter.get("duration", 0.0))
	if _encounter_elapsed >= duration and _current_spawn_index >= spawns.size():
		_complete_current_encounter()

func _complete_current_encounter() -> void:
	_encounters_completed += 1
	var run_stats := _get_run_stats()
	if run_stats != null and run_stats.has_method("record_encounter_completed"):
		run_stats.record_encounter_completed(str(_current_encounter.get("id", "")))

	_current_encounter = {}
	_current_spawn_index = 0
	_encounter_elapsed = 0.0

func _spawn_director_request(request: Dictionary) -> void:
	var spawn_type := str(request.get("type", ""))
	var y := _resolve_spawn_y(request)

	match spawn_type:
		"obstacle":
			spawn_scene_at_y(obstacle_scene, y)
		"pickup":
			spawn_scene_at_y(pickup_scene, y)
			_last_ammo_elapsed = _elapsed
		"enemy":
			var kind := str(request.get("kind", "large_spiky_rock"))
			if kind == "large_spiky_rock":
				spawn_scene_at_y(obstacle_scene, y)
			else:
				spawn_enemy_variant_at_y(kind, y)
				if kind == "glowing_rock":
					_last_glowing_elapsed = _elapsed
		_:
			push_warning("Unknown director spawn type: %s" % spawn_type)

func _resolve_spawn_y(request: Dictionary) -> float:
	if request.has("y"):
		return float(request["y"])

	var y_mode := str(request.get("y_mode", "random_any"))
	var top_mid := lerpf(spawn_y_min, spawn_y_max, 0.35)
	var middle_min := lerpf(spawn_y_min, spawn_y_max, 0.30)
	var middle_max := lerpf(spawn_y_min, spawn_y_max, 0.70)
	var bottom_mid := lerpf(spawn_y_min, spawn_y_max, 0.65)

	match y_mode:
		"random_high":
			return _rng.randf_range(spawn_y_min, top_mid)
		"random_mid":
			return _rng.randf_range(middle_min, middle_max)
		"random_low":
			return _rng.randf_range(bottom_mid, spawn_y_max)
		"bottom_turret":
			return get_viewport_rect().size.y - TURRET_BOTTOM_INSET
		"lane_top":
			return 160.0
		"lane_mid":
			return 300.0
		"lane_bottom":
			return 440.0
		_:
			return _rng.randf_range(spawn_y_min, spawn_y_max)

func _passes_fairness_caps(encounter: Dictionary) -> bool:
	if _elapsed < SAFE_OPENING_SECONDS:
		if _encounter_contains_kind(encounter, "stationary_turret"):
			return false
		if _encounter_contains_kind(encounter, "alien_drone"):
			return false

	if _encounter_contains_kind(encounter, "stationary_turret"):
		if _elapsed < FIRST_TURRET_SECONDS:
			return false
		if _has_active_turret():
			return false

	if _encounter_contains_kind(encounter, "glowing_rock"):
		if _elapsed < FIRST_GLOWING_SECONDS:
			return false
		if (_elapsed - _last_glowing_elapsed) < MIN_GLOWING_INTERVAL_SECONDS:
			return false
		if _has_active_glowing_rock():
			return false

	var active_hostiles := _count_active_group("hostile_units")
	var active_projectiles := _count_active_group("enemy_projectiles")
	var phase := EncounterCatalog.get_phase_for_time(_elapsed)
	var max_hostiles := _get_max_active_hostiles_for_phase(phase)

	if active_projectiles >= MAX_ACTIVE_PROJECTILES:
		return false

	if active_hostiles + _get_hostile_spawn_count(encounter) > max_hostiles and not _has_tag(encounter, "breather"):
		return false

	return true

func _can_spawn_request(request: Dictionary) -> bool:
	var spawn_type := str(request.get("type", ""))
	if spawn_type == "enemy" and str(request.get("kind", "")) == "stationary_turret":
		return not _has_active_turret()
	if spawn_type == "enemy" and str(request.get("kind", "")) == "glowing_rock":
		return not _has_active_glowing_rock()

	if spawn_type != "pickup":
		var phase := EncounterCatalog.get_phase_for_time(_elapsed)
		if _count_active_group("hostile_units") >= _get_max_active_hostiles_for_phase(phase):
			return false

	return true

func _encounter_contains_kind(encounter: Dictionary, kind: String) -> bool:
	var spawns: Array = encounter.get("spawns", [])
	for spawn in spawns:
		if spawn is Dictionary and str(spawn.get("kind", "")) == kind:
			return true
	return false

func _get_hostile_spawn_count(encounter: Dictionary) -> int:
	var count := 0
	var spawns: Array = encounter.get("spawns", [])
	for spawn_variant in spawns:
		var spawn := spawn_variant as Dictionary
		var spawn_type := str(spawn.get("type", ""))
		if spawn_type == "obstacle":
			count += 1
		elif spawn_type == "enemy":
			count += 1
	return count

func _count_active_group(group_name: String) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node):
			continue
		if not node.is_inside_tree():
			continue
		if node.is_queued_for_deletion():
			continue
		count += 1
	return count

func _has_active_turret() -> bool:
	for unit in get_tree().get_nodes_in_group("hostile_units"):
		if not is_instance_valid(unit):
			continue
		if not unit.is_inside_tree() or unit.is_queued_for_deletion():
			continue
		if str(unit.get("enemy_kind")) == "stationary_turret":
			return true
	return false

func _has_active_glowing_rock() -> bool:
	for unit in get_tree().get_nodes_in_group("hostile_units"):
		if not is_instance_valid(unit):
			continue
		if not unit.is_inside_tree() or unit.is_queued_for_deletion():
			continue
		if str(unit.get("enemy_kind")) == "glowing_rock":
			return true
	return false

func _get_max_active_hostiles_for_phase(phase: String) -> int:
	match phase:
		EncounterCatalog.PHASE_OPENING:
			return MAX_ACTIVE_HOSTILES_OPENING
		EncounterCatalog.PHASE_WARMUP:
			return MAX_ACTIVE_HOSTILES_WARMUP
		EncounterCatalog.PHASE_COMBAT_INTRO:
			return MAX_ACTIVE_HOSTILES_COMBAT_INTRO
		_:
			return MAX_ACTIVE_HOSTILES_PRESSURE

func _should_spawn_rescue_ammo() -> bool:
	if _elapsed < 18.0:
		return false
	if (_elapsed - _last_ammo_elapsed) < MAX_AMMO_DROUGHT_SECONDS:
		return false

	var main := _get_main()
	if main == null:
		return false

	var player := main.get_node_or_null("Player")
	if player == null:
		return false
	if "ammo" in player:
		return int(player.ammo) <= 1
	return false

func get_debug_snapshot() -> Dictionary:
	var encounter_id := str(_current_encounter.get("id", "idle"))
	var phase := EncounterCatalog.get_phase_for_time(_elapsed)
	return {
		"enabled": show_director_debug and use_encounter_director and OS.is_debug_build(),
		"phase": phase,
		"encounter_id": encounter_id,
		"seed": _director_seed,
		"active_hostiles": _count_active_group("hostile_units"),
	}

func _get_main() -> Node:
	return get_tree().current_scene

func _get_run_stats() -> Node:
	return get_node_or_null("/root/RunStats")

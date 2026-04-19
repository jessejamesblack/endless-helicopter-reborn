extends SceneTree

const ENCOUNTER_CATALOG := preload("res://scenes/game/main/encounter_catalog.gd")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")

const VALID_SPAWN_TYPES := ["obstacle", "enemy", "pickup"]
const VALID_ENEMY_KINDS := ["large_spiky_rock", "alien_drone", "stationary_turret", "glowing_rock"]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_catalog_shape()
	_validate_phase_coverage()
	await _validate_spawner_runtime()
	_validate_run_stats_methods()

	if _failures.is_empty():
		print("Encounter director validation completed successfully.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _validate_catalog_shape() -> void:
	var encounters := ENCOUNTER_CATALOG.get_encounters()
	_assert(encounters.size() >= 20, "EncounterCatalog should contain at least 20 encounters.")

	var ids: Dictionary = {}
	var breather_count := 0
	var glowing_count := 0
	for encounter in encounters:
		var encounter_id := str(encounter.get("id", ""))
		_assert(not encounter_id.is_empty(), "Every encounter should have a non-empty id.")
		_assert(not ids.has(encounter_id), "Encounter ids should be unique: %s." % encounter_id)
		ids[encounter_id] = true

		var phases: Array = encounter.get("phases", [])
		_assert(not phases.is_empty(), "Encounter %s should have at least one phase." % encounter_id)
		_assert(float(encounter.get("duration", -1.0)) >= 0.0, "Encounter %s should have a non-negative duration." % encounter_id)
		_assert(float(encounter.get("weight", 0.0)) > 0.0, "Encounter %s should have a positive weight." % encounter_id)

		if (encounter.get("tags", []) as Array).has("breather"):
			breather_count += 1
		if _encounter_contains_kind(encounter, "glowing_rock"):
			glowing_count += 1

		var spawns: Array = encounter.get("spawns", [])
		_assert(not spawns.is_empty(), "Encounter %s should define at least one spawn request." % encounter_id)
		for spawn_variant in spawns:
			var spawn := spawn_variant as Dictionary
			_assert(spawn.has("at"), "Encounter %s spawn requests should define 'at'." % encounter_id)
			var spawn_type := str(spawn.get("type", ""))
			_assert(VALID_SPAWN_TYPES.has(spawn_type), "Encounter %s uses an invalid spawn type %s." % [encounter_id, spawn_type])
			if spawn_type == "enemy":
				var kind := str(spawn.get("kind", ""))
				_assert(VALID_ENEMY_KINDS.has(kind), "Encounter %s uses an invalid enemy kind %s." % [encounter_id, kind])

	_assert(breather_count >= 3, "EncounterCatalog should include at least three breather encounters.")
	_assert(glowing_count >= 2, "EncounterCatalog should include at least two glowing-rock encounters.")

func _validate_phase_coverage() -> void:
	var encounters := ENCOUNTER_CATALOG.get_encounters()
	var phase_samples := {
		ENCOUNTER_CATALOG.PHASE_OPENING: 6.0,
		ENCOUNTER_CATALOG.PHASE_WARMUP: 20.0,
		ENCOUNTER_CATALOG.PHASE_COMBAT_INTRO: 45.0,
		ENCOUNTER_CATALOG.PHASE_PRESSURE: 80.0,
		ENCOUNTER_CATALOG.PHASE_ADVANCED: 130.0,
		ENCOUNTER_CATALOG.PHASE_ENDURANCE: 190.0,
	}

	for phase in phase_samples.keys():
		var elapsed := float(phase_samples[phase])
		var count := 0
		for encounter in encounters:
			if not (encounter.get("phases", []) as Array).has(phase):
				continue
			if elapsed < float(encounter.get("requires_elapsed", 0.0)):
				continue
			if float(encounter.get("weight", 0.0)) <= 0.0:
				continue
			count += 1
		_assert(count >= 3, "Phase %s should have at least three valid encounters." % phase)

func _validate_spawner_runtime() -> void:
	var main := await _create_runtime_main()
	var spawner := main.get_node_or_null("Spawner")
	_assert(spawner != null, "Main scene should still include the Spawner node.")
	if spawner == null:
		await _destroy_node(main)
		return

	_assert(bool(spawner.get("use_encounter_director")), "Spawner should use the encounter director by default.")
	await _reset_spawner_runtime(main, spawner)

	var opening_candidates := _get_candidates_for_elapsed(spawner, 5.0)
	_assert(not opening_candidates.is_empty(), "Opening phase should have selectable encounters.")
	for encounter_variant in opening_candidates:
		var encounter := encounter_variant as Dictionary
		_assert(not _encounter_contains_kind(encounter, "stationary_turret"), "Opening candidates should not include turret encounters.")
		_assert(not _encounter_contains_kind(encounter, "alien_drone"), "Opening candidates should not include drone encounters.")

	var pre_turret_candidates := _get_candidates_for_elapsed(spawner, 59.0)
	for encounter_variant in pre_turret_candidates:
		var encounter := encounter_variant as Dictionary
		_assert(not _encounter_contains_kind(encounter, "stationary_turret"), "No encounter eligible before 60 seconds should contain a turret.")

	var same_seed_a := await _simulate_sequence(1337, 10)
	var same_seed_b := await _simulate_sequence(1337, 10)
	_assert(JSON.stringify(same_seed_a) == JSON.stringify(same_seed_b), "Encounter selection should be deterministic for the same seed.")

	var different_seed := await _simulate_sequence(7331, 10)
	_assert(JSON.stringify(same_seed_a) != JSON.stringify(different_seed), "Different director seeds should be able to produce different encounter sequences.")

	await _destroy_node(main)

func _validate_run_stats_methods() -> void:
	var run_stats := get_root().get_node_or_null("RunStats")
	_assert(run_stats != null, "RunStats autoload should exist during validation.")
	if run_stats == null:
		return

	_assert(run_stats.has_method("record_director_seed"), "RunStats should expose record_director_seed().")
	_assert(run_stats.has_method("record_encounter_started"), "RunStats should expose record_encounter_started().")
	_assert(run_stats.has_method("record_encounter_completed"), "RunStats should expose record_encounter_completed().")
	_assert(run_stats.has_method("record_breather_seen"), "RunStats should expose record_breather_seen().")
	_assert(run_stats.has_method("record_forced_rescue_ammo_spawn"), "RunStats should expose record_forced_rescue_ammo_spawn().")

func _get_candidates_for_elapsed(spawner: Node, elapsed: float) -> Array:
	spawner.set("_elapsed", elapsed)
	spawner.set("_last_breather_elapsed", elapsed)
	spawner.set("_next_breather_after", 999.0)
	spawner.set("_encounter_cooldowns", {})
	return spawner.call("_get_valid_encounter_candidates", ENCOUNTER_CATALOG.get_phase_for_time(elapsed))

func _simulate_sequence(seed: int, count: int) -> Array[String]:
	var main := await _create_runtime_main()
	var spawner := main.get_node_or_null("Spawner")
	var sequence: Array[String] = []
	if spawner == null:
		_failures.append("Spawner should exist for deterministic sequence validation.")
		await _destroy_node(main)
		return sequence

	await _reset_spawner_runtime(main, spawner)
	spawner.set("debug_seed", seed)
	spawner.call("reset_for_run")
	spawner.set("_last_breather_elapsed", 0.0)
	spawner.set("_next_breather_after", 28.0)
	for _i in count:
		spawner.call("_start_next_encounter")
		var encounter: Dictionary = spawner.get("_current_encounter")
		sequence.append(str(encounter.get("id", "")))
		var duration := float(encounter.get("duration", 0.0))
		spawner.call("_complete_current_encounter")
		spawner.set("_elapsed", float(spawner.get("_elapsed")) + duration)
		spawner.call("_tick_cooldowns", duration)

	await _destroy_node(main)
	return sequence

func _encounter_contains_kind(encounter: Dictionary, kind: String) -> bool:
	for spawn_variant in encounter.get("spawns", []):
		var spawn := spawn_variant as Dictionary
		if str(spawn.get("kind", "")) == kind:
			return true
	return false

func _create_runtime_main() -> Node:
	var main := MAIN_SCENE.instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	return main

func _reset_spawner_runtime(main: Node, spawner: Node) -> void:
	for group_name in ["hostile_units", "enemy_projectiles", "screen_pickups"]:
		for node in main.get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()
	await process_frame
	spawner.call("reset_for_run")
	spawner.set("_current_encounter", {})
	spawner.set("_current_spawn_index", 0)
	spawner.set("_encounter_elapsed", 0.0)

func _destroy_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

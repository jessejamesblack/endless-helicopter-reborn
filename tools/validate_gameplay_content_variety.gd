extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const ENEMY_UNIT_SCENE := preload("res://scenes/enemies/enemy_unit.tscn")
const OBJECTIVE_PICKUP_SCENE := preload("res://scenes/pickups/objective_pickup.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/projectiles/enemy_projectile.tscn")
const RunObjectiveManagerScript := preload("res://systems/run_objective_manager.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_objective_catalog()
	await _validate_objective_pickup_visuals()
	await _validate_mine_layer_runtime()
	_validate_encounter_content()
	_validate_profile_unlock_pool()
	Helper.finish(self, _failures, "Gameplay content variety validation completed successfully.")

func _validate_objective_catalog() -> void:
	var manager := get_root().get_node_or_null("RunObjectiveManager")
	_assert(manager != null, "RunObjectiveManager autoload should exist for content validation.")
	if manager == null:
		return

	_assert(absf(RunObjectiveManagerScript.FIRST_OBJECTIVE_SECONDS - 42.0) < 0.001, "First objective should be eligible at 42 seconds.")
	_assert(absf(RunObjectiveManagerScript.MIN_SECONDS_BETWEEN_OBJECTIVES - 32.0) < 0.001, "Objective spacing should be 32 seconds.")
	_assert(RunObjectiveManagerScript.MAX_OBJECTIVES_PER_RUN == 3, "Runs should allow up to 3 objectives.")

	var catalog: Dictionary = manager.call("get_objective_catalog")
	for objective_id in ["rescue_pickup", "reactor_chain", "black_box_recovery", "signal_gates", "no_fire_signal", "barrage_intercept", "bounty_drone", "clean_flight"]:
		_assert(catalog.has(objective_id), "Objective catalog should include %s." % objective_id)
	_assert(catalog.size() >= 8, "Objective catalog should include the full v1.7 deck.")
	_assert(int((catalog["black_box_recovery"] as Dictionary).get("target", 0)) == 2, "Black Box Recovery should require 2 boxes.")
	_assert(str((catalog["signal_gates"] as Dictionary).get("reward", "")) == "score_rush", "Signal Gates should reward Score Rush.")
	_assert(float((catalog["bounty_drone"] as Dictionary).get("requires_elapsed", 0.0)) >= 75.0, "Bounty Drone should be elapsed-gated.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "black_box_recovery")), "black_box_recovery objective should begin.")
	for _index in range(2):
		manager.call("record_objective_action", "black_box_pickup", 1)
	var black_box_summary: Dictionary = manager.call("get_summary")
	_assert(int(black_box_summary.get("objective_events_completed", 0)) == 1, "Black box recovery should complete after 2 pickups.")
	_assert((black_box_summary.get("completed_objective_ids", []) as Array).has("black_box_recovery"), "Black box completion should be summarized by id.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "signal_gates")), "signal_gates objective should begin.")
	for _index in range(3):
		manager.call("record_objective_action", "signal_gate", 1)
	var gate_summary: Dictionary = manager.call("get_summary")
	_assert(int(gate_summary.get("objective_rewards_claimed", 0)) == 1, "Signal gates should claim a reward after completion.")
	_assert((gate_summary.get("completed_objective_ids", []) as Array).has("signal_gates"), "Signal gate completion should be summarized by id.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "no_fire_signal")), "no_fire_signal objective should begin.")
	manager.call("record_objective_action", "missile_fired", 1)
	_assert((manager.call("get_active_objective") as Dictionary).is_empty(), "Missile fire should fail No-Fire Signal.")
	_assert(int((manager.call("get_summary") as Dictionary).get("objective_events_completed", 0)) == 0, "Failed No-Fire Signal should not complete.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "clean_flight")), "clean_flight objective should begin.")
	manager.call("record_objective_action", "boundary_recovery", 1)
	_assert((manager.call("get_active_objective") as Dictionary).is_empty(), "Boundary recovery should fail Clean Flight.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "clean_flight")), "clean_flight objective should begin for timer completion.")
	manager.call("update_run", 20.1)
	var clean_summary: Dictionary = manager.call("get_summary")
	_assert((clean_summary.get("completed_objective_ids", []) as Array).has("clean_flight"), "Clean Flight should complete when its timer expires cleanly.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "barrage_intercept")), "barrage_intercept objective should begin.")
	manager.call("record_objective_action", "projectile_intercept", 1)
	manager.call("record_objective_action", "projectile_intercept", 1)
	var barrage_summary: Dictionary = manager.call("get_summary")
	_assert((barrage_summary.get("completed_objective_ids", []) as Array).has("barrage_intercept"), "Barrage Intercept should complete after projectile intercepts.")

	manager.call("start_run")
	_assert(not bool(manager.call("begin_objective", "bounty_drone")), "Bounty Drone should not begin before its elapsed gate.")
	manager.set("_elapsed_seconds", 75.0)
	_assert(bool(manager.call("begin_objective", "bounty_drone")), "Bounty Drone should begin after its elapsed gate.")
	manager.call("record_objective_action", "bounty_drone_kill", 1)
	var bounty_summary: Dictionary = manager.call("get_summary")
	_assert((bounty_summary.get("completed_objective_ids", []) as Array).has("bounty_drone"), "Bounty Drone should complete after the marked elite dies.")

	manager.call("start_run")
	var started_ids: Array[String] = []
	for index in range(3):
		manager.set("_elapsed_seconds", 42.0 + float(index) * 34.0)
		manager.call("update_run", 0.0)
		var active: Dictionary = manager.call("get_active_objective")
		_assert(not active.is_empty(), "Automatic objective %d should start." % (index + 1))
		if active.is_empty():
			continue
		var active_id := str(active.get("id", ""))
		_assert(not started_ids.has(active_id), "Automatic objective selection should avoid repeats before the deck is exhausted.")
		started_ids.append(active_id)
		manager.call("fail_objective", active_id)

func _validate_objective_pickup_visuals() -> void:
	var expected_labels := {
		"rescue_pickup": "OBJ",
		"black_box_pickup": "BOX",
		"signal_gate": "GATE",
	}
	for action in expected_labels.keys():
		var pickup := OBJECTIVE_PICKUP_SCENE.instantiate()
		get_root().add_child(pickup)
		await process_frame
		pickup.call("configure", str(action))
		await process_frame
		var label := pickup.get_node_or_null("Label") as Label
		_assert(label != null, "Objective pickup should include a label for %s." % action)
		if label != null:
			_assert(label.text == str(expected_labels[action]), "%s pickup label should be %s." % [action, expected_labels[action]])
		pickup.free()
		await process_frame

func _validate_mine_layer_runtime() -> void:
	var enemy := ENEMY_UNIT_SCENE.instantiate()
	get_root().add_child(enemy)
	await process_frame
	enemy.call("configure", "mine_layer", "armored")
	await process_frame
	_assert(str(enemy.get("enemy_kind")) == "mine_layer", "EnemyUnit should store mine_layer kind.")
	_assert(int(enemy.call("_get_modifier_hit_count")) == 2, "Armored mine layers should use modifier durability.")
	_assert(int(enemy.call("get_destroy_score")) >= 140, "Mine layers should be worth role plus modifier score.")
	enemy.free()
	await process_frame

	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	get_root().add_child(projectile)
	await process_frame
	projectile.call("configure", "ion_mine")
	await process_frame
	_assert(str(projectile.get("projectile_kind")) == "ion_mine", "EnemyProjectile should configure ion mines.")
	_assert(int(projectile.call("get_destroy_score")) >= 35, "Ion mines should be score-interceptable.")
	projectile.free()
	await process_frame

func _validate_encounter_content() -> void:
	var catalog_text := Helper.read_text("res://scenes/game/main/encounter_catalog.gd")
	for token in ["pressure_ion_mine_layer", "advanced_storm_pocket_reward", "endurance_elite_minefield", '"kind": "mine_layer"', '"tags": ["biome_event"']:
		_assert(catalog_text.contains(token), "Encounter catalog should include %s content." % token)

	var spawner_text := Helper.read_text("res://scenes/game/main/spawner.gd")
	_assert(spawner_text.contains('"kind": "mine_layer"'), "Legacy/director spawner weights should know about mine_layer.")
	_assert(spawner_text.contains("spawn_objective_start_event"), "Spawner should support objective start events.")
	_assert(spawner_text.contains('"barrage_intercept_wave"'), "Spawner should support the Barrage Intercept start wave.")
	_assert(spawner_text.contains('"bounty_drone"'), "Spawner should support the Bounty Drone start event.")
	_assert(spawner_text.contains("objective_destroy_action"), "Spawner should pass objective destroy actions into enemies.")
	_assert(spawner_text.contains("spawn_objective_pickup(action: String = \"rescue_pickup\", y_mode: String"), "Objective pickups should support requested lane modes.")

func _validate_profile_unlock_pool() -> void:
	var profile_text := Helper.read_text("res://systems/player_profile.gd")
	for token in ["\"black_box_recovery\"", "\"signal_gates\"", "\"no_fire_signal\"", "\"barrage_intercept\"", "\"bounty_drone\"", "\"clean_flight\""]:
		_assert(profile_text.contains(token), "PlayerProfile should include objective unlock pool token %s." % token)

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

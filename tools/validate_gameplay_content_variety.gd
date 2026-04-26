extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const ENEMY_UNIT_SCENE := preload("res://scenes/enemies/enemy_unit.tscn")
const OBJECTIVE_PICKUP_SCENE := preload("res://scenes/pickups/objective_pickup.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/projectiles/enemy_projectile.tscn")

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

	var catalog: Dictionary = manager.call("get_objective_catalog")
	for objective_id in ["rescue_pickup", "reactor_chain", "black_box_recovery", "signal_gates"]:
		_assert(catalog.has(objective_id), "Objective catalog should include %s." % objective_id)

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "black_box_recovery")), "black_box_recovery objective should begin.")
	for _index in range(3):
		manager.call("record_objective_action", "black_box_pickup", 1)
	var black_box_summary: Dictionary = manager.call("get_summary")
	_assert(int(black_box_summary.get("objective_events_completed", 0)) == 1, "Black box recovery should complete after 3 pickups.")
	_assert((black_box_summary.get("completed_objective_ids", []) as Array).has("black_box_recovery"), "Black box completion should be summarized by id.")

	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "signal_gates")), "signal_gates objective should begin.")
	for _index in range(3):
		manager.call("record_objective_action", "signal_gate", 1)
	var gate_summary: Dictionary = manager.call("get_summary")
	_assert(int(gate_summary.get("objective_rewards_claimed", 0)) == 1, "Signal gates should claim a reward after completion.")
	_assert((gate_summary.get("completed_objective_ids", []) as Array).has("signal_gates"), "Signal gate completion should be summarized by id.")

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

func _validate_profile_unlock_pool() -> void:
	var profile_text := Helper.read_text("res://systems/player_profile.gd")
	for token in ["\"black_box_recovery\"", "\"signal_gates\"", "objectives_completed\", 0)) >= 2", "objectives_completed\", 0)) >= 4"]:
		_assert(profile_text.contains(token), "PlayerProfile should include objective unlock pool token %s." % token)

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

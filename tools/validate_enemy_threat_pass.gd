extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const ENEMY_UNIT_SCENE := preload("res://scenes/enemies/enemy_unit.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_enemy_modifier_code()
	await _validate_enemy_modifier_runtime()
	_validate_spawner_pressure_code()
	_validate_catalog_pressure()
	Helper.finish(self, _failures, "Enemy threat pass validation completed successfully.")

func _validate_enemy_modifier_code() -> void:
	var enemy_text := Helper.read_text("res://scenes/enemies/enemy_unit.gd")
	for token in ["enemy_modifier", "armored", "shielded", "elite", "_get_effective_fire_interval", "_get_effective_retry_seconds", "_get_projectile_cap"]:
		_assert(enemy_text.contains(token), "EnemyUnit should include %s support." % token)
	_assert(enemy_text.contains('"fire_interval": 1.95'), "Turrets should use a quicker base fire interval.")
	_assert(enemy_text.contains('"fire_interval": 1.45'), "Alien drones should use a quicker base fire interval.")
	_assert(enemy_text.contains("TURRET_MIN_FIRE_INTERVAL_SECONDS := 1.05"), "Turret late-game fire interval minimum should be faster but readable.")
	_assert(enemy_text.contains("DRONE_MIN_FIRE_INTERVAL_SECONDS := 0.72"), "Drone late-game fire interval minimum should be faster but readable.")
	_assert(enemy_text.contains("FIRST_SHOT_SCREEN_LEAD_PIXELS"), "Enemies should prime a first shot as they enter the screen.")
	_assert(enemy_text.contains("_try_fire_initial_screen_entry_shot"), "Enemies should fire an entry shot before normal cadence starts.")
	_assert(enemy_text.contains("record_elite_kill"), "Elite kills should be recorded.")
	_assert(enemy_text.contains("record_special_enemy_kill"), "Special enemy kills should be recorded.")

func _validate_enemy_modifier_runtime() -> void:
	var enemy := ENEMY_UNIT_SCENE.instantiate()
	get_root().add_child(enemy)
	await process_frame
	enemy.call("configure", "alien_drone", "elite")
	await process_frame
	_assert(str(enemy.get("enemy_modifier")) == "elite", "Enemy configure() should store elite modifier.")
	_assert(int(enemy.call("_get_modifier_hit_count")) == 3, "Elite enemies should take extra hits.")
	_assert(int(enemy.call("get_destroy_score")) >= 180, "Elite enemies should be worth bonus score.")
	_assert(not bool(enemy.call("destroy", false, true)), "Partial elite hits should report that the target survived.")
	enemy.call("configure", "alien_drone", "shielded")
	await process_frame
	_assert(int(enemy.call("_get_modifier_hit_count")) == 2, "Shielded enemies should take extra hits.")
	enemy.free()
	await process_frame

func _validate_spawner_pressure_code() -> void:
	var spawner_text := Helper.read_text("res://scenes/game/main/spawner.gd")
	for token in ["_choose_enemy_modifier", "get_player_run_power_score", "elite", "armored", "shielded", "POWERUP_MIN_INTERVAL_SECONDS", "_get_effective_spawn_bounds"]:
		_assert(spawner_text.contains(token), "Spawner should include %s integration." % token)
	var main_text := Helper.read_text("res://scenes/game/main/main.gd")
	for token in ["get_enemy_fire_pressure_scale", "get_enemy_projectile_cap", "get_enemy_fire_retry_seconds", "get_player_run_power_score"]:
		_assert(main_text.contains(token), "Main should expose %s for enemy scaling." % token)

func _validate_catalog_pressure() -> void:
	var catalog_text := Helper.read_text("res://scenes/game/main/encounter_catalog.gd")
	_assert(catalog_text.contains('"advanced_shielded_drone_mix"'), "Encounter catalog should include a shielded pressure encounter.")
	_assert(catalog_text.contains('"endurance_elite_drone_pressure"'), "Encounter catalog should include an elite endurance encounter.")
	_assert(catalog_text.contains('"modifier": "shielded"'), "Encounter catalog should use shielded modifiers.")
	_assert(catalog_text.contains('"modifier": "elite"'), "Encounter catalog should use elite modifiers.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

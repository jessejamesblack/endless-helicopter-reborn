extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_autoloads_and_files()
	_validate_upgrade_manager()
	_validate_powerup_manager()
	_validate_objective_manager()
	await _validate_main_upgrade_overlay_runtime()
	Helper.finish(self, _failures, "Depth retention validation completed successfully.")

func _validate_autoloads_and_files() -> void:
	var project_text := Helper.read_text("res://project.godot")
	_assert(project_text.contains('RunUpgradeManager="*res://systems/run_upgrade_manager.gd"'), "RunUpgradeManager should be registered as an autoload.")
	_assert(project_text.contains('PowerupManager="*res://systems/powerup_manager.gd"'), "PowerupManager should be registered as an autoload.")
	_assert(project_text.contains('RunObjectiveManager="*res://systems/run_objective_manager.gd"'), "RunObjectiveManager should be registered as an autoload.")

	for path in [
		"res://systems/run_upgrade_manager.gd",
		"res://systems/powerup_manager.gd",
		"res://systems/run_objective_manager.gd",
		"res://scenes/ui/upgrades/run_upgrade_choice.tscn",
		"res://scenes/ui/upgrades/run_upgrade_choice.gd",
		"res://scenes/pickups/powerup_pickup.tscn",
		"res://scenes/pickups/powerup_pickup.gd",
		"res://scenes/pickups/objective_pickup.tscn",
		"res://scenes/pickups/objective_pickup.gd",
	]:
		Helper.assert_file_exists(_failures, path)

func _validate_upgrade_manager() -> void:
	var manager := get_root().get_node_or_null("RunUpgradeManager")
	_assert(manager != null, "RunUpgradeManager autoload should exist during validation.")
	if manager == null:
		return

	var catalog: Dictionary = manager.call("get_upgrade_catalog")
	_assert(catalog.size() >= 10, "Upgrade catalog should contain at least 10 upgrades.")
	for upgrade_id in ["twin_missiles", "homing_missiles", "bigger_magazine", "faster_fire_rate", "temporary_shield", "near_miss_amplifier", "combo_battery"]:
		_assert(catalog.has(upgrade_id), "Upgrade catalog should include %s." % upgrade_id)

	manager.call("start_run", "apache_strike")
	var requested := bool(manager.call("request_choice", "milestone"))
	var offers: Array = manager.call("get_pending_offers")
	_assert(requested, "RunUpgradeManager should allow a milestone choice request.")
	_assert(offers.size() == 3, "Upgrade choice should offer exactly 3 cards.")
	if not offers.is_empty():
		var first_id := str((offers[0] as Dictionary).get("id", ""))
		_assert(bool(manager.call("choose_upgrade", first_id)), "Choosing one offered upgrade should succeed.")
		_assert(int(manager.call("get_upgrade_level", first_id)) == 1, "Chosen upgrade level should increment.")
	_assert(float(manager.call("get_run_power_score")) > 0.0, "Chosen upgrades should contribute to run power.")
	_assert(not (manager.call("get_run_modifiers") as Dictionary).is_empty(), "Run modifiers should include vehicle passive data.")

func _validate_powerup_manager() -> void:
	var manager := get_root().get_node_or_null("PowerupManager")
	_assert(manager != null, "PowerupManager autoload should exist during validation.")
	if manager == null:
		return

	var catalog: Dictionary = manager.call("get_powerup_catalog")
	_assert(catalog.size() == 6, "Powerup catalog should contain the initial 6 powerups.")
	for powerup_id in ["shield_bubble", "score_rush", "missile_overdrive", "ammo_magnet", "emp_burst", "afterburner_burst"]:
		_assert(catalog.has(powerup_id), "Powerup catalog should include %s." % powerup_id)
		_assert(float((catalog[powerup_id] as Dictionary).get("duration", 0.0)) > 0.0, "%s should have a positive duration." % powerup_id)

	manager.call("start_run")
	_assert(bool(manager.call("activate_powerup", "score_rush")), "Score Rush should activate successfully.")
	manager.call("update_run", 1.25)
	var summary: Dictionary = manager.call("get_summary")
	_assert(bool(manager.call("has_active_effect", "score_rush")), "Score Rush should remain active after a short update.")
	_assert(float(summary.get("score_rush_seconds", 0.0)) >= 1.2, "Score Rush active seconds should be tracked.")

func _validate_objective_manager() -> void:
	var manager := get_root().get_node_or_null("RunObjectiveManager")
	_assert(manager != null, "RunObjectiveManager autoload should exist during validation.")
	if manager == null:
		return

	var catalog: Dictionary = manager.call("get_objective_catalog")
	_assert(catalog.has("rescue_pickup"), "Objective catalog should include rescue_pickup.")
	_assert(catalog.has("reactor_chain"), "Objective catalog should include reactor_chain.")
	manager.call("start_run")
	_assert(bool(manager.call("begin_objective", "rescue_pickup")), "rescue_pickup objective should begin.")
	manager.call("record_objective_action", "rescue_pickup", 1)
	var summary: Dictionary = manager.call("get_summary")
	_assert(int(summary.get("objective_events_completed", 0)) == 1, "Completing an objective should update summary stats.")
	_assert(int(summary.get("objective_rewards_claimed", 0)) == 1, "Completing an objective should track claimed rewards.")

func _validate_main_upgrade_overlay_runtime() -> void:
	var root_window := get_root()
	root_window.size = Vector2i(1152, 648)
	paused = false
	await process_frame

	var main := MAIN_SCENE.instantiate()
	root_window.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var manager := get_root().get_node_or_null("RunUpgradeManager")
	if manager == null:
		_failures.append("RunUpgradeManager should exist for main runtime validation.")
		await _destroy_node(main)
		return

	_assert(bool(manager.call("request_choice", "milestone")), "Main runtime should accept an upgrade choice trigger.")
	await process_frame
	_assert(bool(main.get("_upgrade_choice_active")), "Main should mark upgrade choice as active.")
	_assert(paused, "Upgrade choice should pause gameplay.")
	var offers: Array = manager.call("get_pending_offers")
	if not offers.is_empty():
		main.call("_on_upgrade_card_selected", str((offers[0] as Dictionary).get("id", "")))
		await process_frame
		_assert(not paused, "Selecting an upgrade should resume gameplay.")
		_assert(not bool(main.get("_upgrade_choice_active")), "Selecting an upgrade should clear the active choice flag.")

	await _destroy_node(main)
	paused = false

func _destroy_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
	current_scene = null
	await process_frame

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const MAIN_SCENE := preload("res://scenes/game/main/main.tscn")
const POWERUP_PICKUP_SCENE := preload("res://scenes/pickups/powerup_pickup.tscn")
const UPGRADE_CHOICE_SCENE := preload("res://scenes/ui/upgrades/run_upgrade_choice.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_autoloads_and_files()
	_validate_upgrade_manager()
	_validate_powerup_manager()
	_validate_objective_manager()
	await _validate_powerup_pickup_visuals_runtime()
	await _validate_main_upgrade_overlay_runtime()
	await _validate_four_card_upgrade_overlay_layout()
	await _validate_score_rush_skill_window_runtime()
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

	manager.call("start_run", "default_scout")
	_assert(bool(manager.call("request_choice", "milestone")), "Scout should allow a first milestone choice request.")
	var scout_first_offers: Array = manager.call("get_pending_offers")
	_assert(scout_first_offers.size() == 4, "Scout Reliable Frame should offer 4 cards on the first choice.")
	if not scout_first_offers.is_empty():
		var scout_first_id := str((scout_first_offers[0] as Dictionary).get("id", ""))
		_assert(bool(manager.call("choose_upgrade", scout_first_id)), "Scout should be able to choose one of the 4 first offers.")
	_assert(bool(manager.call("request_choice", "milestone")), "Scout should allow a later milestone choice request.")
	var scout_second_offers: Array = manager.call("get_pending_offers")
	_assert(scout_second_offers.size() == 3, "Scout should return to 3 cards after the first choice.")

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

func _validate_powerup_pickup_visuals_runtime() -> void:
	var expected_labels := {
		"shield_bubble": "SHLD",
		"score_rush": "RUSH",
		"missile_overdrive": "OVR",
		"ammo_magnet": "MAG",
		"emp_burst": "EMP",
		"afterburner_burst": "BURN",
	}
	for powerup_id in expected_labels.keys():
		var pickup := POWERUP_PICKUP_SCENE.instantiate()
		get_root().add_child(pickup)
		await process_frame
		pickup.call("configure", str(powerup_id))
		await process_frame
		_assert(pickup.get_node_or_null("Border") != null, "Powerup pickup should include a HUD-style border.")
		_assert(pickup.get_node_or_null("Backplate") != null, "Powerup pickup should include a dark UI backplate.")
		_assert(pickup.get_node_or_null("Accent") != null, "Powerup pickup should include a colored accent chip.")
		var label := pickup.get_node_or_null("Label") as Label
		_assert(label != null, "Powerup pickup should include a readable label.")
		if label != null:
			_assert(label.text == str(expected_labels[powerup_id]), "%s pickup label should be %s." % [powerup_id, expected_labels[powerup_id]])
		pickup.free()
		await process_frame

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

func _validate_four_card_upgrade_overlay_layout() -> void:
	var root_window := get_root()
	root_window.size = Vector2i(820, 460)
	await process_frame

	var canvas := CanvasLayer.new()
	root_window.add_child(canvas)
	var overlay := UPGRADE_CHOICE_SCENE.instantiate() as Control
	canvas.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = float(root_window.size.x)
	overlay.offset_bottom = float(root_window.size.y)
	await process_frame
	var offers: Array[Dictionary] = []
	for index in range(4):
		offers.append({
			"id": "test_%d" % index,
			"name": "Upgrade %d" % (index + 1),
			"description": "Compact card layout check.",
			"level": 1,
			"max_level": 1,
		})
	overlay.call("open_choice", offers, "milestone")
	await process_frame
	var panel := overlay.get_node_or_null("Overlay/Panel") as Control
	var card_row := overlay.get_node_or_null("Overlay/Panel/MarginContainer/VBoxContainer/CardRow") as HBoxContainer
	_assert(panel != null, "Upgrade choice overlay should expose a panel.")
	_assert(card_row != null, "Upgrade choice overlay should expose a card row.")
	if panel != null:
		_assert(Rect2(Vector2.ZERO, Vector2(root_window.size)).encloses(panel.get_global_rect()), "Four-card upgrade overlay should fit inside a phone/tablet viewport.")
	if card_row != null:
		_assert(card_row.get_child_count() == 4, "Four-card upgrade overlay should render all 4 Scout offers.")
	canvas.free()
	await process_frame

func _validate_score_rush_skill_window_runtime() -> void:
	var root_window := get_root()
	root_window.size = Vector2i(1152, 648)
	paused = false
	await process_frame

	var main := MAIN_SCENE.instantiate()
	root_window.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var spawner := main.get_node_or_null("Spawner")
	if spawner == null:
		_failures.append("Main scene should include Spawner for Score Rush skill window validation.")
		await _destroy_node(main)
		return

	spawner.set("_elapsed", 45.0)
	main.call("_on_powerup_activated", "score_rush", {})
	await process_frame
	_assert(_count_active_group("hostile_units") > 0, "Score Rush should immediately create a skill-scoring opportunity when the screen is quiet.")

	await _destroy_node(main)
	paused = false

func _destroy_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
	current_scene = null
	await process_frame

func _count_active_group(group_name: String) -> int:
	var count := 0
	for node in get_root().get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node):
			continue
		if not node.is_inside_tree() or node.is_queued_for_deletion():
			continue
		count += 1
	return count

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

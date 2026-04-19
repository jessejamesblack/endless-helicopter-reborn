extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen/start_screen.tscn")
const LEADERBOARD_SCENE := preload("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var feature_discovery_manager := get_root().get_node_or_null("FeatureDiscoveryManager")
	var hangar_navigation_state := get_root().get_node_or_null("HangarNavigationState")
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	_assert(feature_discovery_manager != null, "FeatureDiscoveryManager autoload should exist.")
	_assert(hangar_navigation_state != null, "HangarNavigationState autoload should exist.")
	_assert(player_profile != null, "PlayerProfile autoload should exist for feature discovery validation.")

	if feature_discovery_manager != null:
		feature_discovery_manager.replay_all_tips()
		var tip: Dictionary = feature_discovery_manager.get_active_tip()
		_assert(str(tip.get("id", "")) == "missions", "Feature discovery should surface the Missions tip first.")
		feature_discovery_manager.mark_tip_seen("missions")
		tip = feature_discovery_manager.get_active_tip()
		_assert(str(tip.get("id", "")) == "hangar", "Feature discovery should surface the Hangar tip second.")
		feature_discovery_manager.replay_all_tips()

	if player_profile != null:
		player_profile.apply_validation_state({
			"unlocked_vehicles": ["default_scout", "bubble_chopper"],
			"equipped_vehicle_id": "default_scout",
			"unlocked_vehicle_skins": {
				"default_scout": ["factory"],
				"bubble_chopper": ["factory"],
			},
			"equipped_vehicle_skins": {
				"default_scout": "factory",
				"bubble_chopper": "factory",
			},
			"seen_vehicle_lore": [],
			"seen_skin_lore": [],
		})

	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(start_screen)
	await process_frame
	await process_frame
	_assert(start_screen.get_node_or_null("HangarButton") != null, "Start screen should expose Hangar in one tap.")
	_assert(start_screen.get_node_or_null("NextUnlockCard") != null, "Start screen should expose a Next Unlock card.")
	_assert(start_screen.get_node_or_null("TipCard") != null, "Start screen should expose a one-time tip card.")
	start_screen.free()
	await process_frame

	var leaderboard_screen := LEADERBOARD_SCENE.instantiate() as Control
	get_root().add_child(leaderboard_screen)
	await process_frame
	await process_frame
	_assert(leaderboard_screen.get_node_or_null("Panel/MarginContainer/VBoxContainer/ResultsButtonRow/OpenHangarButton") != null, "Results screen should expose an Open Hangar CTA.")
	leaderboard_screen.free()
	await process_frame

	var start_screen_text := Helper.read_text("res://scenes/ui/start_screen/start_screen.gd")
	_assert(start_screen_text.contains("get_next_unlock_preview"), "Start screen should render next-unlock preview data.")
	_assert(start_screen_text.contains("_decorate_button_text"), "Start screen should decorate menu buttons with NEW badges.")

	var settings_text := Helper.read_text("res://scenes/ui/settings/settings_menu.gd")
	_assert(settings_text.contains("replay_all_tips"), "Settings should let players replay feature discovery tips.")

	var discovery_text := Helper.read_text("res://systems/feature_discovery_manager.gd")
	_assert(discovery_text.contains("Daily Missions unlock vehicles and paint styles."), "Feature discovery should teach what Missions unlock.")
	_assert(discovery_text.contains("Hangar is where you equip vehicles and skins."), "Feature discovery should teach what the Hangar is for.")

	Helper.finish(self, _failures, "Sprint 7 feature discovery validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

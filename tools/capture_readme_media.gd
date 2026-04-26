extends SceneTree

const OUTPUT_DIR := "res://docs/media"
const CAPTURE_SIZE := Vector2i(1152, 648)
const CAPTURES := [
	{
		"scene": "res://scenes/ui/title_screen/title_screen.tscn",
		"output": "readme-title.png",
		"frames": 12,
	},
	{
		"scene": "res://scenes/game/main/main.tscn",
		"output": "readme-run.png",
		"frames": 36,
	},
	{
		"scene": "res://scenes/game/main/main.tscn",
		"output": "readme-upgrades.png",
		"frames": 18,
	},
	{
		"scene": "res://scenes/ui/leaderboard/leaderboard_screen.tscn",
		"output": "readme-results.png",
		"frames": 18,
	},
	{
		"scene": "res://scenes/ui/hangar/hangar_screen.tscn",
		"output": "readme-hangar.png",
		"frames": 18,
	},
	{
		"scene": "res://scenes/ui/missions/mission_screen.tscn",
		"output": "readme-missions.png",
		"frames": 18,
		"mission_preview": true,
	},
	{
		"scene": "res://scenes/ui/pause/pause_menu.tscn",
		"output": "readme-pause.png",
		"frames": 12,
	},
	{
		"scene": "res://scenes/ui/settings/settings_menu.tscn",
		"output": "readme-settings.png",
		"frames": 12,
	},
]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = CAPTURE_SIZE
	_ensure_output_dir()

	for capture in CAPTURES:
		await _capture_scene(capture)

	if _failures.is_empty():
		print("README media captured in %s." % OUTPUT_DIR)
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _ensure_output_dir() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK:
		_failures.append("Could not create README media directory %s: %s" % [output_path, error_string(error)])

func _capture_scene(capture: Dictionary) -> void:
	var scene_path := str(capture.get("scene", ""))
	var output_name := str(capture.get("output", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_failures.append("Could not load capture scene: %s" % scene_path)
		return

	var node := packed.instantiate()
	if bool(capture.get("mission_preview", false)):
		node.set("validation_mode_enabled", true)
		node.set("_validation_summary", _build_mission_preview_summary())
	if output_name == "readme-run.png":
		node.set_process(false)
		var spawner := node.get_node_or_null("Spawner")
		if spawner != null:
			spawner.set_process(false)

	get_root().add_child(node)
	current_scene = node
	await process_frame
	_prepare_scene_for_capture(node, output_name)
	await _wait_frames(int(capture.get("frames", 8)))

	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		_failures.append("Could not capture %s because the viewport texture is unavailable. Run this tool without --headless." % output_name)
		node.free()
		current_scene = null
		return
	var image := viewport_texture.get_image()
	if image == null:
		_failures.append("Could not capture %s because the renderer returned no image. Run this tool without --headless." % output_name)
		node.free()
		current_scene = null
		return
	var output_path := "%s/%s" % [OUTPUT_DIR, output_name]
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_failures.append("Could not save %s: %s" % [output_path, error_string(save_error)])
	else:
		print("Captured %s" % output_path)

	node.free()
	current_scene = null
	paused = false
	await process_frame

func _prepare_scene_for_capture(node: Node, output_name: String) -> void:
	match output_name:
		"readme-run.png":
			_prepare_run_capture(node)
		"readme-upgrades.png":
			_prepare_upgrade_capture(node)
		"readme-results.png":
			_prepare_results_capture(node)
		"readme-pause.png":
			if node.has_method("open_menu"):
				node.call("open_menu")
		"readme-settings.png":
			if node.has_method("open_menu"):
				node.call("open_menu")

func _prepare_run_capture(node: Node) -> void:
	var powerup_manager := get_root().get_node_or_null("PowerupManager")
	if powerup_manager != null and powerup_manager.has_method("activate_powerup"):
		powerup_manager.activate_powerup("score_rush")
		powerup_manager.activate_powerup("missile_overdrive")

	var objective_manager := get_root().get_node_or_null("RunObjectiveManager")
	if objective_manager != null and objective_manager.has_method("begin_objective"):
		objective_manager.begin_objective("reactor_chain")

	if node.has_method("award_skill_score"):
		node.award_skill_score(225, "INTERCEPT", Vector2(760, 270), true)
		node.award_skill_score(325, "ELITE HIT", Vector2(850, 220), true)

func _prepare_upgrade_capture(node: Node) -> void:
	if node.has_method("_on_upgrade_choice_ready"):
		node.call("_on_upgrade_choice_ready", _build_upgrade_preview_offers(), "milestone")

func _prepare_results_capture(node: Node) -> void:
	if node.has_method("apply_validation_state"):
		node.call("apply_validation_state", 0, _build_results_preview_summary(), false, false, false)

func _wait_frames(frame_count: int) -> void:
	for _index in range(maxi(frame_count, 1)):
		await process_frame

func _build_mission_preview_summary() -> Dictionary:
	return {
		"completed": 1,
		"total": 5,
		"core_completed": 1,
		"core_total": 3,
		"bonus_completed": 0,
		"bonus_total": 2,
		"daily_streak": 3,
		"perfect_day": false,
		"next_unlock": {
			"display_name": "Hind Strike",
			"progress_text": "3 missions to unlock",
		},
		"missions": [
			{
				"title": "Collect 5 ammo pickups",
				"description": "Grab missile crates during today's runs.",
				"type": "ammo_pickups",
				"progress": 5,
				"target": 5,
				"completed": true,
				"bonus": false,
			},
			{
				"title": "Pick 2 run upgrades",
				"description": "Choose upgrades when milestone cards appear.",
				"type": "run_upgrades_chosen",
				"progress": 1,
				"target": 2,
				"completed": false,
				"bonus": false,
			},
			{
				"title": "Defeat 2 elite enemies",
				"description": "Clear armored, shielded, or elite threats.",
				"type": "elite_kills",
				"progress": 1,
				"target": 2,
				"completed": false,
				"bonus": false,
			},
			{
				"title": "Complete 1 objective",
				"description": "Finish a rescue pickup or reactor chain.",
				"type": "objective_events_completed",
				"progress": 0,
				"target": 1,
				"completed": false,
				"bonus": true,
				"badge_text": "BONUS",
			},
			{
				"title": "Spend 10s in Score Rush",
				"description": "Collect Score Rush and keep flying.",
				"type": "score_rush_seconds",
				"progress": 6,
				"target": 10,
				"completed": false,
				"bonus": true,
				"badge_text": "BONUS",
			},
		],
	}

func _build_upgrade_preview_offers() -> Array[Dictionary]:
	return [
		{
			"id": "twin_missiles",
			"name": "Twin Missiles",
			"description": "Fire an extra missile in a tight spread.",
			"level": 1,
			"max_level": 1,
		},
		{
			"id": "score_battery",
			"name": "Combo Battery",
			"description": "Keep your combo alive a little longer.",
			"level": 2,
			"max_level": 3,
		},
		{
			"id": "temporary_shield",
			"name": "Temporary Shield",
			"description": "Start holding a one-hit shield charge.",
			"level": 1,
			"max_level": 2,
		},
		{
			"id": "near_miss_amplifier",
			"name": "Near-Miss Amplifier",
			"description": "Threading danger pays more score.",
			"level": 1,
			"max_level": 3,
		},
	]

func _build_results_preview_summary() -> Dictionary:
	return {
		"score": 6840,
		"best_score_before_run": 5100,
		"best_score_after_run": 6840,
		"is_new_best": true,
		"distance_to_best_before_run": 0,
		"time_survived": 138.2,
		"time_survived_seconds": 138.2,
		"survival_score": 1382,
		"skill_score": 5458,
		"missiles_fired": 28,
		"hostiles_destroyed": 17,
		"ammo_pickups_collected": 6,
		"glowing_rocks_triggered": 2,
		"boundary_bounces": 1,
		"near_misses": 14,
		"max_combo_multiplier": 2.2,
		"projectile_intercepts": 5,
		"upgrades_chosen": 3,
		"powerups_collected": 4,
		"objective_events_completed": 2,
		"elite_kills": 1,
		"vehicle_passive_name": "Reliable Frame",
		"equipped_vehicle_id": "default_scout",
		"post_run_unlocks": [
			{
				"unlock_type": "vehicle",
				"vehicle_id": "bubble_chopper",
			},
		],
	}

extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen/start_screen.tscn")
const MISSION_SCREEN_SCENE := preload("res://scenes/ui/missions/mission_screen.tscn")
const HANGAR_SCREEN_SCENE := preload("res://scenes/ui/hangar/hangar_screen.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_autoloads()
	await _validate_screen_assets()
	_validate_skin_library()
	_validate_profile_defaults_and_fallbacks()
	_validate_mission_generation_and_progress()
	_validate_supabase_assets()

	if _failures.is_empty():
		print("Sprint 3 missions and cosmetics validation completed successfully.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _validate_autoloads() -> void:
	var player_profile: Node = _get_autoload("PlayerProfile")
	var helicopter_skins: Node = _get_autoload("HelicopterSkins")
	var mission_manager: Node = _get_autoload("MissionManager")
	var sync_queue: Node = _get_autoload("SupabaseSyncQueue")
	var push_notifications: Node = _get_autoload("PushNotifications")

	_assert(player_profile != null, "PlayerProfile autoload should exist.")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist.")
	_assert(mission_manager != null, "MissionManager autoload should exist.")
	_assert(sync_queue != null, "SupabaseSyncQueue autoload should exist.")
	_assert(push_notifications != null, "PushNotifications autoload should exist.")

	if player_profile != null:
		_assert(player_profile.has_method("get_profile_summary"), "PlayerProfile should expose get_profile_summary().")
		_assert(player_profile.has_method("merge_remote_profile"), "PlayerProfile should expose merge_remote_profile().")
		_assert(player_profile.has_method("has_skin_access"), "PlayerProfile should expose has_skin_access().")
		_assert(player_profile.has_method("apply_leaderboard_top_status"), "PlayerProfile should expose apply_leaderboard_top_status().")

	if mission_manager != null:
		_assert(mission_manager.has_method("get_daily_sync_summary"), "MissionManager should expose get_daily_sync_summary().")
		_assert(mission_manager.has_method("merge_remote_daily_progress"), "MissionManager should expose merge_remote_daily_progress().")
		_assert(mission_manager.has_method("consume_recent_run_result"), "MissionManager should expose consume_recent_run_result().")

	if sync_queue != null:
		_assert(sync_queue.has_method("enqueue_submit_score_v2"), "SupabaseSyncQueue should expose enqueue_submit_score_v2().")
		_assert(sync_queue.has_method("enqueue_sync_player_profile"), "SupabaseSyncQueue should expose enqueue_sync_player_profile().")
		_assert(sync_queue.has_method("enqueue_sync_daily_mission_progress"), "SupabaseSyncQueue should expose enqueue_sync_daily_mission_progress().")
		_assert(sync_queue.has_method("flush"), "SupabaseSyncQueue should expose flush().")

	if push_notifications != null:
		_assert(push_notifications.has_method("consume_open_missions_request"), "PushNotifications should expose consume_open_missions_request().")
		_assert(push_notifications.has_method("consume_open_leaderboard_request"), "PushNotifications should still expose consume_open_leaderboard_request().")

func _validate_screen_assets() -> void:
	_assert(ResourceLoader.exists("res://scenes/ui/missions/mission_screen.tscn"), "Mission screen scene should exist.")
	_assert(ResourceLoader.exists("res://scenes/ui/hangar/hangar_screen.tscn"), "Hangar screen scene should exist.")

	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(start_screen)
	await process_frame
	await process_frame

	var scores_button := start_screen.get_node_or_null("ScoresButton") as Control
	var missions_button := start_screen.get_node_or_null("MissionsButton") as Control
	_assert(scores_button != null, "Start screen should still include ScoresButton.")
	_assert(missions_button != null, "Start screen should include MissionsButton.")
	if scores_button != null and missions_button != null:
		_assert(missions_button.get_global_rect().position.y >= scores_button.get_global_rect().end.y - 1.0, "MissionsButton should sit below ScoresButton.")

	start_screen.free()
	await process_frame

	var mission_screen := MISSION_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(mission_screen)
	await process_frame
	_assert(mission_screen.get_node_or_null("Panel/MarginContainer/VBoxContainer/ButtonRow/ReminderButton") != null, "Mission screen should include the reminder button.")
	mission_screen.free()
	await process_frame

	var hangar_screen := HANGAR_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(hangar_screen)
	await process_frame
	_assert(hangar_screen.get_node_or_null("Panel/MarginContainer/VBoxContainer/ButtonRow/EquipButton") != null, "Hangar screen should include the equip button.")
	if hangar_screen.has_method("get_preview_state"):
		var preview_state: Dictionary = hangar_screen.get_preview_state()
		var preview_position: Vector2 = preview_state.get("position", Vector2.ZERO)
		var preview_scale: Vector2 = preview_state.get("scale", Vector2.ZERO)
		_assert(preview_position.x >= 120.0 and preview_position.y >= 80.0, "Hangar preview should stay centered in the preview card.")
		_assert(preview_scale.x >= 0.04 and preview_scale.y >= 0.04, "Hangar preview should be scaled up enough to read clearly.")
	hangar_screen.free()
	await process_frame

func _validate_skin_library() -> void:
	var helicopter_skins: Node = _get_autoload("HelicopterSkins")
	if helicopter_skins == null:
		return

	_assert(helicopter_skins.has_skin("pottercar"), "Pottercar should exist in the skin library.")
	for skin_id in helicopter_skins.get_skin_ids():
		var texture_path := str(helicopter_skins.get_texture_path(skin_id))
		_assert(ResourceLoader.exists(texture_path), "Skin texture should exist for %s." % skin_id)
		if helicopter_skins.has_method("get_collision_polygon"):
			var polygon: PackedVector2Array = helicopter_skins.get_collision_polygon(skin_id)
			_assert(not polygon.is_empty(), "Skin collision polygon should exist for %s." % skin_id)

	_validate_imported_skin_transparency(helicopter_skins)

	if helicopter_skins.has_method("get_unlocks_for_completed_missions"):
		_assert(not (helicopter_skins.get_unlocks_for_completed_missions(999) as Array).has("pottercar"), "Mission unlock helpers should exclude Pottercar.")
	if helicopter_skins.has_method("get_next_locked_skin"):
		var next_unlock: Dictionary = helicopter_skins.get_next_locked_skin(999)
		_assert(str(next_unlock.get("skin_id", "")) != "pottercar", "Next mission unlock should never be Pottercar.")

func _validate_imported_skin_transparency(helicopter_skins: Node) -> void:
	var probe_points := {
		"bubble_chopper": [Vector2i(170, 225), Vector2i(2359, 1459)],
		"huey_runner": [Vector2i(120, 225), Vector2i(2359, 1484)],
		"blackhawk_shadow": [Vector2i(110, 95), Vector2i(2789, 1274)],
		"apache_strike": [Vector2i(250, 300), Vector2i(2200, 1350)],
		"chinook_lift": [Vector2i(250, 150), Vector2i(2300, 1150)],
		"pottercar": [Vector2i(400, 290), Vector2i(2359, 1529)],
	}

	for skin_id in probe_points.keys():
		var texture_path := str(helicopter_skins.get_texture_path(skin_id))
		var png_bytes := FileAccess.get_file_as_bytes(texture_path)
		_assert(not png_bytes.is_empty(), "Imported skin bytes should be readable for %s." % skin_id)
		if png_bytes.is_empty():
			continue

		var image := Image.new()
		var load_error := image.load_png_from_buffer(png_bytes)
		_assert(load_error == OK, "Imported skin PNG should load for %s." % skin_id)
		if load_error != OK:
			continue

		var points: Array = probe_points[skin_id]
		for point_variant in points:
			var point := point_variant as Vector2i
			_assert(
				point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height(),
				"Imported skin probe point should be inside image bounds for %s." % skin_id
			)
			if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
				continue

			var pixel := image.get_pixelv(point)
			_assert(pixel.a < 0.05, "Imported skin matte should be transparent near the crop edge for %s." % skin_id)

func _validate_profile_defaults_and_fallbacks() -> void:
	var player_profile: Node = _get_autoload("PlayerProfile")
	if player_profile == null:
		return

	player_profile.apply_validation_state({
		"unlocked_skins": ["default_scout"],
		"equipped_skin_id": "default_scout",
		"total_daily_missions_completed": 0,
		"daily_streak": 0,
	})
	_assert(player_profile.is_skin_unlocked("default_scout"), "Default Scout should be unlocked by default.")
	_assert(player_profile.get_equipped_skin_id() == "default_scout", "Default Scout should be equipped by default.")
	_assert(not player_profile.has_skin_access("pottercar"), "Pottercar should start unavailable without verified top access.")
	_assert(not (player_profile.get_unlocked_skins() as Array).has("pottercar"), "Pottercar should not be stored as a permanent unlock.")
	_assert(not player_profile.equip_skin("pottercar"), "Pottercar should not be equippable while unavailable.")

	player_profile.apply_validation_state({
		"unlocked_skins": ["default_scout"],
		"equipped_skin_id": "blackhawk_shadow",
		"total_daily_missions_completed": 0,
		"daily_streak": 0,
	})
	_assert(player_profile.get_equipped_skin_id() == "default_scout", "Locked equipped skin should fall back to default_scout.")
	_assert(not player_profile.equip_skin("apache_strike"), "Locked skins should not be equippable.")

	var local_player_id := OnlineLeaderboard.load_or_create_player_id()
	player_profile.apply_validation_state({
		"unlocked_skins": ["default_scout"],
		"equipped_skin_id": "default_scout",
		"pottercar_access": false,
	})
	player_profile.apply_leaderboard_entries([
		{"player_id": "other-player", "score": 900, "created_at": "2026-04-18T00:00:00Z"},
		{"player_id": local_player_id, "score": 900, "created_at": "2026-04-18T00:00:01Z"},
	])
	_assert(not player_profile.has_skin_access("pottercar"), "Matching the top score without being the first row should not grant Pottercar.")

	player_profile.apply_leaderboard_entries([
		{"player_id": local_player_id, "score": 900, "created_at": "2026-04-18T00:00:00Z"},
		{"player_id": "other-player", "score": 800, "created_at": "2026-04-18T00:00:01Z"},
	])
	_assert(player_profile.has_skin_access("pottercar"), "Top row ownership should grant Pottercar.")
	_assert(player_profile.equip_skin("pottercar"), "Pottercar should be equippable while the player is verified as #1.")
	_assert(not (player_profile.get_unlocked_skins() as Array).has("pottercar"), "Pottercar should still stay out of the permanent unlock list.")
	player_profile.apply_leaderboard_top_status(false)
	_assert(not player_profile.has_skin_access("pottercar"), "Losing #1 should revoke Pottercar.")
	_assert(player_profile.get_equipped_skin_id() == "default_scout", "Equipped Pottercar should fall back to Scout when access is revoked.")

func _validate_mission_generation_and_progress() -> void:
	var mission_manager: Node = _get_autoload("MissionManager")
	var player_profile: Node = _get_autoload("PlayerProfile")
	if mission_manager == null or player_profile == null:
		return

	var first_set: Array[Dictionary] = mission_manager.build_daily_missions_for_key("2026-04-18")
	var second_set: Array[Dictionary] = mission_manager.build_daily_missions_for_key("2026-04-18")
	_assert(first_set.size() == 3, "Daily mission generation should return exactly 3 missions.")
	_assert(JSON.stringify(first_set) == JSON.stringify(second_set), "Daily mission generation should be deterministic for a date key.")

	player_profile.apply_validation_state({
		"unlocked_skins": ["default_scout"],
		"equipped_skin_id": "default_scout",
		"total_daily_missions_completed": 0,
		"daily_streak": 0,
	})
	var first_validation_missions: Array[Dictionary] = [
		{"id": "daily_2026-04-18_play_runs", "type": "play_runs", "title": "Fly 1 Run", "description": "Complete 1 run today.", "target": 1, "progress": 0, "completed": false, "reward_text": "Daily progress"},
		{"id": "daily_2026-04-18_near_misses", "type": "near_misses", "title": "Get 2 Near Misses", "description": "Get 2 near misses today.", "target": 2, "progress": 0, "completed": false, "reward_text": "Daily progress"},
		{"id": "daily_2026-04-18_max_combo", "type": "max_combo", "title": "Reach Combo x1.25", "description": "Reach combo x1.25 today.", "target": 125, "progress": 0, "completed": false, "reward_text": "Daily progress"},
	]
	mission_manager.apply_validation_state("2026-04-18", first_validation_missions)

	var result: Dictionary = mission_manager.apply_run_summary({
		"score": 1200,
		"time_survived_seconds": 12.5,
		"near_misses": 2,
		"max_combo_multiplier": 1.25,
	})
	_assert((result.get("missions_completed_this_run", []) as Array).size() == 3, "Applying a fake run summary should complete the expected missions.")
	_assert(player_profile.get_total_daily_missions_completed() == 3, "Mission completion should increment total daily missions completed.")
	_assert(player_profile.is_skin_unlocked("bubble_chopper"), "Bubble Chopper should unlock after the first completed daily mission.")
	_assert(player_profile.is_skin_unlocked("huey_runner"), "Huey Runner should unlock after three completed daily missions.")

	var second_validation_missions: Array[Dictionary] = [
		{"id": "daily_2026-04-19_skill_score", "type": "skill_score", "title": "Earn Skill Score", "description": "Earn 5 skill score today.", "target": 5, "progress": 0, "completed": false, "reward_text": "Daily progress"},
		{"id": "daily_2026-04-19_glowing_clears", "type": "glowing_clears", "title": "Trigger 1 Glowing Clear", "description": "Trigger one glowing clear today.", "target": 1, "progress": 0, "completed": false, "reward_text": "Daily progress"},
		{"id": "daily_2026-04-19_ammo_pickups", "type": "ammo_pickups", "title": "Collect Ammo", "description": "Collect one ammo pickup today.", "target": 1, "progress": 0, "completed": false, "reward_text": "Daily progress"},
	]
	mission_manager.apply_validation_state("2026-04-19", second_validation_missions)
	var missing_keys_result: Dictionary = mission_manager.apply_run_summary({})
	_assert(missing_keys_result is Dictionary, "MissionManager should handle missing Sprint 2 keys safely.")

func _validate_supabase_assets() -> void:
	_assert(FileAccess.file_exists("res://backend/supabase_player_progress_setup.sql"), "Supabase player progress setup SQL should exist.")
	_assert(FileAccess.file_exists("res://backend/supabase_daily_mission_push_setup.sql"), "Daily mission push setup SQL should exist.")
	_assert(FileAccess.file_exists("res://backend/supabase/functions/send-daily-mission-push/index.ts"), "Daily mission push function should exist.")

	var sql_text := FileAccess.get_file_as_string("res://backend/supabase_player_progress_setup.sql")
	_assert(sql_text.contains("family_player_profiles"), "Supabase player progress SQL should include family_player_profiles.")
	_assert(sql_text.contains("family_daily_mission_progress"), "Supabase player progress SQL should include family_daily_mission_progress.")
	_assert(sql_text.contains("family_run_history"), "Supabase player progress SQL should include family_run_history.")
	_assert(sql_text.contains("submit_family_score_v2"), "Supabase player progress SQL should include submit_family_score_v2.")
	_assert(sql_text.contains("sync_player_profile"), "Supabase player progress SQL should include sync_player_profile.")
	_assert(sql_text.contains("sync_daily_mission_progress"), "Supabase player progress SQL should include sync_daily_mission_progress.")

	_assert(OnlineLeaderboard.get_submit_v2_url().contains("submit_family_score_v2"), "OnlineLeaderboard should expose submit v2 URL.")
	_assert(OnlineLeaderboard.get_sync_player_profile_url().contains("sync_player_profile"), "OnlineLeaderboard should expose player profile sync URL.")
	_assert(OnlineLeaderboard.get_sync_daily_mission_progress_url().contains("sync_daily_mission_progress"), "OnlineLeaderboard should expose mission sync URL.")
	_assert(OnlineLeaderboard.get_legacy_fetch_url().contains("select=player_id,name,score,created_at,updated_at"), "OnlineLeaderboard should expose a legacy leaderboard fetch URL.")
	_assert(not OnlineLeaderboard.get_legacy_fetch_url().contains("equipped_skin_id"), "Legacy leaderboard fetch URL should avoid Sprint 3-only columns.")
	_assert(OnlineLeaderboard.should_fallback_to_legacy_fetch("column family_leaderboard.equipped_skin_id does not exist"), "OnlineLeaderboard should detect when leaderboard fetch must fall back to legacy columns.")

	var body := OnlineLeaderboard.make_submit_v2_body("Pilot", 100, {"skill_score": 50}, "default_scout")
	_assert(body.contains("\"p_run_summary\""), "Submit v2 body should include run_summary.")
	_assert(body.contains("\"p_equipped_skin_id\""), "Submit v2 body should include equipped_skin_id.")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _get_autoload(name: String) -> Node:
	return get_root().get_node_or_null(name)

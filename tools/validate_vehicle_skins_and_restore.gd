extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	var player_profile := get_root().get_node_or_null("PlayerProfile")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist for Sprint 5 validation.")
	_assert(player_profile != null, "PlayerProfile autoload should exist for Sprint 5 validation.")
	if helicopter_skins == null or player_profile == null:
		_finish()
		return

	player_profile.apply_validation_state({
		"unlocked_skins": ["default_scout", "bubble_chopper"],
		"equipped_skin_id": "bubble_chopper",
		"unlocked_vehicle_skins": {"default_scout": ["factory"]},
		"equipped_vehicle_skins": {"default_scout": "factory", "bubble_chopper": "factory"},
	})
	_assert(player_profile.get_equipped_vehicle_id() == "bubble_chopper", "Legacy equipped_skin_id should migrate to equipped_vehicle_id.")
	_assert((player_profile.get_unlocked_vehicles() as Array).has("bubble_chopper"), "Legacy unlocked_skins should migrate to unlocked_vehicles.")
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "factory"), "Factory should unlock for migrated default vehicle.")
	_assert(player_profile.is_vehicle_skin_unlocked("bubble_chopper", "factory"), "Factory should unlock for migrated vehicles.")
	_assert(helicopter_skins.has_vehicle("crazytaxi"), "Crazy Taxi bonus vehicle should exist in the vehicle catalog.")
	_assert(not helicopter_skins.get_vehicle_unlocks_for_completed_missions(999).has("crazytaxi"), "Crazy Taxi should stay out of the mission unlock ladder.")
	_assert(str(helicopter_skins.get_vehicle_unlock_requirement("crazytaxi")) == "Unlock Gold on 3 vehicles.", "Crazy Taxi should describe its Gold-on-three-vehicles unlock rule.")
	_assert(JSON.stringify(helicopter_skins.get_vehicle_skin_ids("crazytaxi")) == JSON.stringify(["factory"]), "Crazy Taxi should not expose alternate skins.")
	_assert(JSON.stringify(helicopter_skins.get_vehicle_skin_ids("pottercar")) == JSON.stringify(["factory"]), "Pottercar should not expose alternate skins.")

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout"],
		"equipped_vehicle_id": "default_scout",
		"unlocked_vehicle_skins": {"default_scout": ["factory"]},
		"equipped_vehicle_skins": {"default_scout": "factory"},
		"vehicle_skin_progress": {"default_scout": {"runs_completed": 4, "daily_missions_completed": 2, "near_misses": 24, "projectile_intercepts": 9, "best_score": 4900}},
		"best_score_milestones": {"score_10000": false},
		"global_skin_unlocks": [],
	})
	var unlocks: Array[Dictionary] = player_profile.apply_run_skin_progress("default_scout", {
		"score": 10000,
		"near_misses": 1,
		"projectile_intercepts": 1,
	})
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "desert"), "Five runs should unlock Desert.")
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "neon"), "Twenty-five near misses should unlock Neon.")
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "prototype"), "Ten projectile intercepts should unlock Prototype.")
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "gold"), "Five-thousand score with a vehicle should unlock Gold.")
	_assert(player_profile.has_score_milestone("score_10000"), "Ten-thousand score should mark the Original Icon milestone.")
	_assert((player_profile.get_profile_sync_summary().get("global_skin_unlocks", []) as Array).has("original_icon"), "Original Icon should persist in the profile sync summary.")
	var reported_global_icon_unlock := false
	for entry in unlocks:
		if str(entry.get("unlock_type", "")) == "global_skin_set":
			reported_global_icon_unlock = true
			break
	_assert(reported_global_icon_unlock, "Ten-thousand score should report the Original Icon set unlock.")

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout", "bubble_chopper", "huey_runner"],
		"equipped_vehicle_id": "huey_runner",
		"unlocked_vehicle_skins": {
			"default_scout": ["factory", "gold"],
			"bubble_chopper": ["factory", "gold"],
			"huey_runner": ["factory"]
		},
		"equipped_vehicle_skins": {
			"default_scout": "gold",
			"bubble_chopper": "gold",
			"huey_runner": "factory"
		},
		"vehicle_skin_progress": {
			"default_scout": {"runs_completed": 7, "daily_missions_completed": 3, "near_misses": 25, "projectile_intercepts": 10, "best_score": 5500},
			"bubble_chopper": {"runs_completed": 8, "daily_missions_completed": 3, "near_misses": 28, "projectile_intercepts": 11, "best_score": 6100},
			"huey_runner": {"runs_completed": 4, "daily_missions_completed": 1, "near_misses": 6, "projectile_intercepts": 2, "best_score": 4900}
		},
	})
	var bonus_unlocks: Array[Dictionary] = player_profile.apply_run_skin_progress("huey_runner", {
		"score": 5000,
		"near_misses": 0,
		"projectile_intercepts": 0,
	})
	_assert(player_profile.is_vehicle_skin_unlocked("huey_runner", "gold"), "Five-thousand score should still unlock Gold on the third qualifying vehicle.")
	_assert(player_profile.is_vehicle_unlocked("crazytaxi"), "Gold on three vehicles should unlock Crazy Taxi.")
	_assert(player_profile.has_method("get_gold_mastery_vehicle_count") and int(player_profile.get_gold_mastery_vehicle_count()) >= 3, "Gold mastery count helper should report at least three gold vehicles after the bonus unlock.")
	var reported_crazytaxi_unlock := false
	for entry in bonus_unlocks:
		if str(entry.get("unlock_type", "")) == "vehicle" and str(entry.get("vehicle_id", "")) == "crazytaxi":
			reported_crazytaxi_unlock = true
			break
	_assert(reported_crazytaxi_unlock, "Crossing the third Gold vehicle should report Crazy Taxi as a vehicle unlock.")

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout"],
		"equipped_vehicle_id": "default_scout",
		"unlocked_vehicle_skins": {"default_scout": ["factory"]},
		"equipped_vehicle_skins": {"default_scout": "factory"},
		"vehicle_skin_progress": {"default_scout": {"runs_completed": 0, "daily_missions_completed": 2, "near_misses": 0, "projectile_intercepts": 0, "best_score": 0}},
	})
	var arctic_unlocks: Array[Dictionary] = player_profile.apply_daily_mission_vehicle_credit("default_scout", 1)
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "arctic"), "Three credited daily missions should unlock Arctic.")
	_assert((arctic_unlocks as Array).size() == 1, "Arctic unlock should report exactly one unlock entry when crossing the threshold.")

	player_profile.apply_validation_state({
		"unlocked_vehicles": ["default_scout"],
		"equipped_vehicle_id": "default_scout",
		"unlocked_vehicle_skins": {"default_scout": ["factory", "gold"]},
		"equipped_vehicle_skins": {"default_scout": "gold"},
		"global_skin_unlocks": ["original_icon"],
		"best_score_milestones": {"score_10000": true},
	})
	var remote_changed: bool = player_profile.apply_remote_profile_summary({
		"unlocked_vehicles": ["default_scout", "bubble_chopper"],
		"equipped_vehicle_id": "bubble_chopper",
		"unlocked_vehicle_skins": {
			"default_scout": ["factory"],
			"bubble_chopper": ["factory", "desert"]
		},
		"equipped_vehicle_skins": {
			"default_scout": "factory",
			"bubble_chopper": "desert"
		},
		"vehicle_skin_progress": {
			"default_scout": {"runs_completed": 2, "daily_missions_completed": 1, "near_misses": 5, "projectile_intercepts": 2, "best_score": 3200},
			"bubble_chopper": {"runs_completed": 5, "daily_missions_completed": 3, "near_misses": 12, "projectile_intercepts": 4, "best_score": 5400}
		},
		"global_skin_unlocks": [],
		"best_score_milestones": {"score_10000": false},
		"seen_vehicle_lore": ["bubble_chopper"],
		"seen_skin_lore": ["bubble_chopper:desert"],
	})
	_assert(remote_changed, "Remote profile merge should report changes when new vehicles or lore arrive.")
	_assert(player_profile.is_vehicle_unlocked("bubble_chopper"), "Remote merge should add newly unlocked vehicles.")
	_assert(player_profile.is_vehicle_skin_unlocked("default_scout", "gold"), "Remote merge should never remove local skin unlocks.")
	_assert(player_profile.has_score_milestone("score_10000"), "Remote merge should never clear a local score milestone.")
	_assert(player_profile.has_seen_vehicle_lore("bubble_chopper"), "Remote merge should restore seen vehicle lore.")
	_assert(player_profile.has_seen_skin_lore("bubble_chopper", "desert"), "Remote merge should restore seen skin lore.")

	_assert(not helicopter_skins.get_vehicle_skin_ids("pottercar").has("gold"), "Pottercar should stay out of the standard skin progression ladder.")
	_assert(not helicopter_skins.get_vehicle_skin_ids("pottercar").has("arctic"), "Pottercar should stay out of the standard mission skin ladder.")
	_assert(not helicopter_skins.get_vehicle_skin_ids("crazytaxi").has("gold"), "Crazy Taxi should stay out of the standard skin progression ladder.")

	var identity_text := Helper.read_text("res://systems/android_identity.gd")
	_assert(identity_text.contains("has_pending_remote_identity_migration"), "AndroidIdentity should expose pending remote migration checks.")
	_assert(identity_text.contains("finalize_remote_identity_migration"), "AndroidIdentity should persist canonical Android identities after migration.")
	_assert(identity_text.contains("\"remote_ready\""), "AndroidIdentity should track when remote identities are safe to use.")
	_assert(identity_text.contains("android.provider.Settings$Secure"), "AndroidIdentity should include a direct Android ID fallback for stable identity resolution.")
	_assert(identity_text.contains("OS.get_unique_id()"), "AndroidIdentity should try Godot's Android unique ID before lower-level Android ID wrappers.")
	_assert(identity_text.contains("HashingContext.HASH_SHA256"), "AndroidIdentity should hash stable Android identities deterministically.")
	_assert(identity_text.contains("IDENTITY_SOURCE_ANDROID_PENDING"), "AndroidIdentity should expose a pending Android identity source while stable IDs are still starting.")
	_assert(not identity_text.contains("var fallback_value := _generate_random_id()"), "AndroidIdentity should no longer generate random Android fallback IDs for remote identity.")

	var leaderboard_text := Helper.read_text("res://systems/online_leaderboard.gd")
	_assert(leaderboard_text.contains("migrate_player_identity"), "OnlineLeaderboard should expose the identity migration RPC.")
	_assert(leaderboard_text.contains("load_canonical_player_id"), "OnlineLeaderboard should expose the canonical player ID for permanent restore rebinding.")
	_assert(leaderboard_text.contains("profile_summary"), "OnlineLeaderboard should still parse profile summaries.")
	_assert(leaderboard_text.contains("if not parsed.has(resolved_key)"), "OnlineLeaderboard should flatten nested profile_summary fields for restore merges.")
	_assert(leaderboard_text.contains("Waiting for Android-backed ID"), "OnlineLeaderboard should surface Android-backed identity wait states clearly.")

	var settings_text := Helper.read_text("res://scenes/ui/settings/settings_menu.gd")
	_assert(settings_text.contains("migrate_player_identity_async"), "Settings restore should migrate pasted legacy player IDs onto the phone's canonical player ID.")
	_assert(settings_text.contains("permanently linked to this phone's player ID"), "Settings restore should tell the user when a pasted player ID was permanently rebound to this phone.")

	var queue_text := Helper.read_text("res://systems/supabase_sync_queue.gd")
	_assert(queue_text.contains("_ensure_remote_identity_ready"), "SupabaseSyncQueue should wait for a stable remote identity before syncing.")
	_assert(queue_text.contains("notify_identity_state_changed"), "SupabaseSyncQueue should allow identity changes to restart startup restore.")
	_assert(queue_text.contains("func migrate_player_identity_async"), "SupabaseSyncQueue should expose a reusable identity migration helper for manual restore rebinding.")

	var sql_text := Helper.read_text("res://backend/supabase_vehicle_skins_setup.sql")
	_assert(sql_text.contains("create or replace function public.migrate_player_identity"), "Supabase restore SQL should define migrate_player_identity.")
	_assert(sql_text.contains("family_push_devices"), "Identity migration should update push device ownership.")
	_assert(sql_text.contains("family_daily_mission_progress"), "Identity migration should merge daily mission progress.")
	_assert(sql_text.contains("set player_id = p_new_player_id"), "Identity migration should rebind leaderboard rows in place when the old row wins.")
	_assert(sql_text.contains("delete from public.family_leaderboard"), "Identity migration should clear conflicting target leaderboard rows before rebinding the old row.")
	_assert(sql_text.contains("where fcm_token = device_row.fcm_token"), "Identity migration should clear conflicting push-device rows that already own the same FCM token.")
	_assert(sql_text.contains("update public.family_push_devices"), "Identity migration should rebind push-device rows in place instead of inserting duplicate token rows.")
	_assert(sql_text.contains("where id = device_row.id"), "Identity migration should update the existing push-device row by id during migration.")

	var build_info_text := Helper.read_text("res://systems/build_info.gd")
	_assert(build_info_text.contains("APP_PACKAGE_NAME"), "BuildInfo should expose the canonical Android package name for stable identity fallback.")

	var push_registration_text := Helper.read_text("res://backend/supabase/functions/register-push-device/index.ts")
	_assert(push_registration_text.contains(".eq(\"device_id\", deviceId)"), "register-push-device should reconcile existing rows for the current device ID.")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Vehicle skins and restore validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

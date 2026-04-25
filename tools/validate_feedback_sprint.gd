extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const MainScript = preload("res://scenes/game/main/main.gd")
const PlayerScript = preload("res://scenes/player/player.gd")
const RunStatsScript = preload("res://systems/run_stats.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_boundary_protection()
	_validate_pause_protection()
	_validate_background_continuity()
	_validate_run_stats_expansion()
	Helper.finish(self, _failures, "Feedback sprint validation completed successfully.")

func _validate_boundary_protection() -> void:
	_assert(absf(PlayerScript.BOUNDARY_STALL_TIMEOUT_SECONDS - 0.65) < 0.001, "Boundary stall timeout should be 0.65 seconds.")
	_assert(absf(PlayerScript.BOUNDARY_ZONE_EXTRA_MARGIN - 6.0) < 0.001, "Boundary zone margin should be 6 pixels.")
	_assert(absf(PlayerScript.BOUNDARY_CHAIN_WINDOW_SECONDS - 1.5) < 0.001, "Boundary chain window should be 1.5 seconds.")
	_assert(PlayerScript.MAX_BOUNDARY_CHAIN_RECOVERIES == 3, "Boundary chain recovery cap should be 3.")
	var player_text := Helper.read_text("res://scenes/player/player.gd")
	_assert(player_text.contains("_crash_from_boundary"), "Player should hand boundary abuse to a crash path.")
	_assert(player_text.contains("record_boundary_timeout_death"), "Boundary timeout deaths should be tracked.")
	_assert(player_text.contains("record_boundary_chain_crash"), "Boundary chain crashes should be tracked.")

func _validate_pause_protection() -> void:
	_assert(absf(MainScript.PAUSE_TOGGLE_COOLDOWN_SECONDS - 0.35) < 0.001, "Pause toggle cooldown should be 0.35 seconds.")
	_assert(absf(MainScript.PAUSE_RESUME_GRACE_SECONDS - 0.15) < 0.001, "Pause resume grace should be 0.15 seconds.")
	var main_text := Helper.read_text("res://scenes/game/main/main.gd")
	_assert(main_text.contains("_pause_toggle_msec_history"), "Main should track pause toggle history.")
	_assert(main_text.contains("_pause_lockout_until_msec"), "Main should lock out repeated pause abuse briefly.")

func _validate_background_continuity() -> void:
	var manager_text := Helper.read_text("res://scenes/background/background_manager.gd")
	_assert(manager_text.contains("_apply_forward_parallax_layer"), "BackgroundManager should preserve the main-branch forward parallax look.")
	_assert(manager_text.contains("safe_travel_width"), "Textured background travel should be capped to safe overlap.")
	_assert(manager_text.contains("extra_width * 0.5"), "Textured background travel should not exceed the visible texture overlap.")
	_assert(not manager_text.contains("_scroll_textured_layer"), "Textured backgrounds should not use tiled strip scrolling.")

func _validate_run_stats_expansion() -> void:
	var stats := RunStatsScript.new()
	stats.start_run()
	stats.record_shield_hit_absorbed()
	stats.record_elite_kill()
	stats.record_special_enemy_kill("armored")
	stats.record_boundary_timeout_death()
	stats.record_boundary_chain_crash()
	stats.record_ammo_refund()
	var summary := stats.complete_run(0, {
		"upgrades_chosen": 2,
		"powerups_collected": 1,
		"objective_events_completed": 1,
		"vehicle_passive_id": "flexible_baseline",
	})
	for key in [
		"shield_hits_absorbed",
		"elite_kills",
		"special_enemy_kills",
		"armored_enemy_kills",
		"boundary_timeout_deaths",
		"boundary_chain_crashes",
		"ammo_refunds",
		"upgrades_chosen",
		"powerups_collected",
		"objective_events_completed",
		"vehicle_passive_id",
	]:
		_assert(summary.has(key), "RunStats summary should include %s." % key)

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

extends Node

const PRESETS := {
	"ui_tap": {"duration_ms": 12, "amplitude": 0.20, "cooldown_ms": 40},
	"missile_fire": {"duration_ms": 18, "amplitude": 0.25, "cooldown_ms": 80},
	"missile_hit": {"duration_ms": 28, "amplitude": 0.45, "cooldown_ms": 90},
	"near_miss": {"duration_ms": 16, "amplitude": 0.30, "cooldown_ms": 120},
	"combo_up": {"duration_ms": 22, "amplitude": 0.38, "cooldown_ms": 200},
	"projectile_intercept": {"duration_ms": 34, "amplitude": 0.55, "cooldown_ms": 120},
	"boundary_recovery": {"duration_ms": 24, "amplitude": 0.35, "cooldown_ms": 180},
	"glowing_clear": {"duration_ms": 55, "amplitude": 0.70, "cooldown_ms": 500},
	"mission_complete": {"duration_ms": 45, "amplitude": 0.60, "cooldown_ms": 500},
	"unlock": {"duration_ms": 70, "amplitude": 0.75, "cooldown_ms": 700},
	"crash": {"duration_ms": 85, "amplitude": 0.85, "cooldown_ms": 700},
	"new_best": {"duration_ms": 75, "amplitude": 0.80, "cooldown_ms": 700},
}

var _last_played_at_ms: Dictionary = {}

func play(preset_id: String) -> void:
	var settings: Node = _get_settings()
	if settings == null or not settings.is_haptics_enabled() or not PRESETS.has(preset_id):
		return

	var preset: Dictionary = PRESETS[preset_id]
	var now_ms := Time.get_ticks_msec()
	var cooldown_ms := int(preset.get("cooldown_ms", 0))
	var last_played_ms := int(_last_played_at_ms.get(preset_id, -cooldown_ms))
	if now_ms - last_played_ms < cooldown_ms:
		return

	_last_played_at_ms[preset_id] = now_ms
	var intensity := clampf(settings.get_haptics_intensity(), 0.0, 1.0)
	var amplitude := clampf(float(preset.get("amplitude", 0.0)) * intensity, 0.0, 1.0)
	Input.vibrate_handheld(int(preset.get("duration_ms", 0)), amplitude)

func vibrate_legacy(duration_ms: int) -> void:
	var settings: Node = _get_settings()
	if settings == null or not settings.is_haptics_enabled():
		return
	Input.vibrate_handheld(maxi(duration_ms, 0), clampf(settings.get_haptics_intensity(), 0.0, 1.0))

func _get_settings() -> Node:
	return get_node_or_null("/root/GameSettings")

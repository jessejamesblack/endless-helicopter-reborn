extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const MainScript = preload("res://scenes/game/main/main.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_validate_combo_window()
	_validate_score_feedback()
	Helper.finish(self, _failures, "Score feedback and combo validation completed successfully.")

func _validate_combo_window() -> void:
	_assert(absf(MainScript.COMBO_TIMEOUT_SECONDS - 4.25) < 0.001, "Combo timeout should be 4.25 seconds.")
	var main_text := Helper.read_text("res://scenes/game/main/main.gd")
	_assert(main_text.contains("_get_combo_timeout_bonus"), "Combo window should support run upgrade bonuses.")
	_assert(main_text.contains('COMBO x%.2f'), "Combo UI should still show multiplier text.")

func _validate_score_feedback() -> void:
	var floating_text := Helper.read_text("res://scenes/effects/floating_score_text.gd")
	var floating_scene_text := Helper.read_text("res://scenes/effects/floating_score_text.tscn")
	var main_text := Helper.read_text("res://scenes/game/main/main.gd")
	_assert(floating_text.contains("FLOAT_DURATION_SECONDS := 0.72"), "Floating score lifetime should be slightly longer.")
	_assert(floating_scene_text.contains("font_size = 22"), "Floating score font should be slightly larger.")
	_assert(floating_scene_text.contains("outline_size = 5"), "Floating score should have a stronger outline.")
	_assert(main_text.contains("INTERCEPT"), "Projectile intercept feedback should be visibly distinct.")
	_assert(main_text.contains("OBJECTIVE"), "Objective reward score feedback should be visible.")
	_assert(main_text.contains("ELITE HIT"), "Elite kill score feedback should be visibly distinct.")
	_assert(main_text.contains("ARMOR"), "Partial armored hits should have distinct feedback.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

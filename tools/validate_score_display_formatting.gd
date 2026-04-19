extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var main_text := Helper.read_text("res://scenes/game/main/main.gd")
	_assert(main_text.contains("AmmoLabel.text = str(ammo)"), "Ammo HUD should show plain numbers with no padding.")
	_assert(main_text.contains("ScoreLabel.text = str(int(score))"), "Score HUD should show plain numbers with no padding.")
	_assert(not main_text.contains("pad_zeros"), "Gameplay HUD should not use padded zero formatting.")

	Helper.finish(self, _failures, "Sprint 7 score display validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

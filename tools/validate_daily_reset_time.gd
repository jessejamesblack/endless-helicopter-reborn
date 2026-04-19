extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var eastern_time_text := Helper.read_text("res://systems/eastern_time.gd")
	Helper.assert_condition(_failures, eastern_time_text.contains('DAILY_RESET_HOUR := 8'), "EasternTime should use an 8:00 AM reset hour.")
	Helper.assert_condition(_failures, eastern_time_text.contains('America/New_York'), "EasternTime should target America/New_York.")
	var mission_manager_text := Helper.read_text("res://systems/mission_manager.gd")
	Helper.assert_condition(_failures, mission_manager_text.contains("EasternTimeScript.get_current_business_day_key"), "MissionManager should use the EasternTime helper for mission keys.")
	var mission_screen_text := Helper.read_text("res://scenes/ui/missions/mission_screen.gd")
	Helper.assert_condition(_failures, mission_screen_text.contains("8:00 AM ET"), "Mission screen should mention the 8:00 AM ET reset.")
	Helper.finish(self, _failures, "Daily reset validation completed successfully.")

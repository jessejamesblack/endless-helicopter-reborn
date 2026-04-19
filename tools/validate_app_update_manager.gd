extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://systems/build_info.gd")
	Helper.assert_file_exists(_failures, "res://systems/app_update_manager.gd")
	Helper.assert_file_exists(_failures, "res://scenes/ui/update/update_prompt.tscn")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/get-app-release-info/index.ts")
	var project_text := Helper.read_text("res://project.godot")
	Helper.assert_condition(_failures, project_text.contains("AppUpdateManager"), "AppUpdateManager should be autoloaded in project.godot.")
	Helper.assert_condition(_failures, project_text.contains("systems/app_update_manager.gd"), "AppUpdateManager autoload should point to the runtime script.")
	var start_screen_text := Helper.read_text("res://scenes/ui/start_screen/start_screen.gd")
	Helper.assert_condition(_failures, start_screen_text.contains("Update Required"), "Start screen should enforce required updates.")
	Helper.finish(self, _failures, "App update manager validation completed successfully.")

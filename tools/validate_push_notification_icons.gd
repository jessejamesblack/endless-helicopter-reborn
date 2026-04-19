extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	_assert(FileAccess.file_exists("res://android/plugins/fcm_push_bridge/src/main/res/drawable/ic_stat_helicopter.xml"), "Helicopter push icon should exist.")
	_assert(FileAccess.file_exists("res://android/plugins/fcm_push_bridge/src/main/res/drawable/ic_stat_daily_missions.xml"), "Daily missions push icon should exist.")

	var service_source := FileAccess.get_file_as_string("res://android/plugins/fcm_push_bridge/src/main/java/com/endlesshelicopter/push/ScoreBeatenFirebaseMessagingService.kt")
	_assert(service_source.contains("\"daily_missions\" -> R.drawable.ic_stat_daily_missions"), "Daily mission push should use the daily missions icon.")
	_assert(service_source.contains("\"score_beaten\" -> R.drawable.ic_stat_helicopter"), "Score-beaten push should use the helicopter icon.")
	_assert(service_source.contains("else -> R.drawable.ic_stat_helicopter"), "Fallback push icon should use the helicopter icon.")
	_assert(service_source.contains(".setSmallIcon(notificationIcon)"), "Android notifications should set the chosen small icon.")

	var push_notifications_source := FileAccess.get_file_as_string("res://systems/push_notifications.gd")
	_assert(push_notifications_source.contains("\"score_beaten\""), "Push notification routing should still handle score_beaten payloads.")
	_assert(push_notifications_source.contains("\"daily_missions\""), "Push notification routing should still handle daily_missions payloads.")
	_assert(push_notifications_source.contains("MISSION_SCENE_PATH"), "Daily mission pushes should still route to the missions screen.")
	_assert(push_notifications_source.contains("LEADERBOARD_SCENE_PATH"), "Score-beaten pushes should still route to the leaderboard.")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Push notification icon validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

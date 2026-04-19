extends Control

signal closed
signal feedback_submitted

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const BuildInfoScript = preload("res://systems/build_info.gd")

const CATEGORY_VALUES := [
	"bug",
	"idea",
	"controls",
	"visual",
	"leaderboard",
	"missions",
	"update/install",
	"audio",
	"background/music",
]

@onready var category_option: OptionButton = $Overlay/Panel/MarginContainer/VBoxContainer/CategoryRow/CategoryOption
@onready var message_edit: TextEdit = $Overlay/Panel/MarginContainer/VBoxContainer/MessageEdit
@onready var summary_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SummaryLabel
@onready var status_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var send_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/SendButton
@onready var copy_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CopyButton
@onready var close_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

var _request: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_request = HTTPRequest.new()
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_populate_categories()
	category_option.item_selected.connect(_on_category_selected)
	send_button.pressed.connect(_on_send_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	close_button.pressed.connect(_on_close_pressed)
	_refresh_summary()

func open_menu() -> void:
	status_label.text = ""
	_refresh_summary()
	visible = true
	message_edit.grab_focus()

func close_menu() -> void:
	visible = false
	closed.emit()

func _populate_categories() -> void:
	if category_option.item_count > 0:
		return
	for category in CATEGORY_VALUES:
		category_option.add_item(category.capitalize())

func _on_category_selected(_index: int) -> void:
	_refresh_summary()

func _on_send_pressed() -> void:
	var message := message_edit.text.strip_edges()
	if message.is_empty():
		status_label.text = "Write a short note before sending."
		return
	if not OnlineLeaderboardScript.is_configured():
		status_label.text = "Feedback can be copied here, but online sending needs Supabase config."
		return
	send_button.disabled = true
	status_label.text = "Sending feedback..."
	var error := _request.request(
		OnlineLeaderboardScript.get_edge_function_url("report-feedback"),
		OnlineLeaderboardScript.get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"category": get_selected_category(),
			"message": message,
			"bug_report": _build_bug_report_text(),
			"context": _build_feedback_context(),
		})
	)
	if error != OK:
		send_button.disabled = false
		status_label.text = "Could not start the feedback request."

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	send_button.disabled = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		status_label.text = "Feedback sent. Thanks for helping tune the game."
		feedback_submitted.emit()
		message_edit.text = ""
		_refresh_summary()
		return
	status_label.text = "Feedback could not be sent right now. Copy the report and keep flying."

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_build_bug_report_text())
	status_label.text = "Bug report copied."

func _on_close_pressed() -> void:
	close_menu()

func get_selected_category() -> String:
	var index := clampi(category_option.selected, 0, CATEGORY_VALUES.size() - 1)
	return CATEGORY_VALUES[index]

func _refresh_summary() -> void:
	summary_label.text = _build_bug_report_text()

func _build_bug_report_text() -> String:
	var reporter = get_node_or_null("/root/ErrorReporter")
	if reporter != null and reporter.has_method("build_bug_report_text"):
		return reporter.build_bug_report_text(get_selected_category())
	return "Version: %s\nBuild: %s" % [BuildInfoScript.VERSION_NAME, BuildInfoScript.BUILD_SHA]

func _build_feedback_context() -> Dictionary:
	var player_profile = get_node_or_null("/root/PlayerProfile")
	var run_stats = get_node_or_null("/root/RunStats")
	var game_settings = get_node_or_null("/root/GameSettings")
	var update_manager = get_node_or_null("/root/AppUpdateManager")
	var equipped_vehicle := "unknown"
	var equipped_skin := "factory"
	if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
		equipped_vehicle = str(player_profile.get_equipped_vehicle_id())
	if player_profile != null and player_profile.has_method("get_equipped_vehicle_skin_id"):
		equipped_skin = str(player_profile.get_equipped_vehicle_skin_id(equipped_vehicle))
	return {
		"build": BuildInfoScript.get_summary(),
		"platform": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"frame_rate_setting": game_settings.get_frame_rate_setting() if game_settings != null and game_settings.has_method("get_frame_rate_setting") else "",
		"equipped_vehicle": equipped_vehicle,
		"equipped_skin": equipped_skin,
		"last_run_summary": run_stats.get_last_run_summary() if run_stats != null and run_stats.has_method("get_last_run_summary") else {},
		"update_state": update_manager.get_update_state() if update_manager != null and update_manager.has_method("get_update_state") else {},
	}

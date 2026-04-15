extends Control

func _ready() -> void:
    $VBoxContainer/HighScoreLabel.text = "Family Leaderboard"
    $VBoxContainer/LeaderboardLabel.text = "Loading..."
    $VBoxContainer/AlertLabel.text = ""
    $VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
    $ScoresButton.pressed.connect(_on_scores_pressed)
    $LeaderboardRequest.request_completed.connect(_on_leaderboard_request_completed)
    $NotificationRequest.request_completed.connect(_on_notification_request_completed)
    $MarkNotificationsReadRequest.request_completed.connect(_on_mark_notifications_read_completed)
    
    if OnlineLeaderboard.is_configured():
        $LeaderboardRequest.request(
            OnlineLeaderboard.get_fetch_url(5),
            OnlineLeaderboard.get_headers(),
            HTTPClient.METHOD_GET
        )
        $NotificationRequest.request(
            OnlineLeaderboard.get_notifications_url(3),
            OnlineLeaderboard.get_headers(),
            HTTPClient.METHOD_GET
        )
    else:
        $VBoxContainer/LeaderboardLabel.text = "Configure online_leaderboard.gd to enable shared scores"
        $VBoxContainer/AlertLabel.text = "Name saving still works locally while online play is off."

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://main.tscn")

func _on_scores_pressed() -> void:
    get_tree().change_scene_to_file("res://leaderboard_screen.tscn")

func _on_leaderboard_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        $VBoxContainer/LeaderboardLabel.text = "Could not load family scores"
        return

    var entries := OnlineLeaderboard.parse_entries(body)
    $VBoxContainer/LeaderboardLabel.text = OnlineLeaderboard.format_entries(entries, 5)

func _on_notification_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        return

    var notifications := OnlineLeaderboard.parse_notifications(body)
    if notifications.is_empty():
        $VBoxContainer/AlertLabel.text = ""
        return

    $VBoxContainer/AlertLabel.text = OnlineLeaderboard.format_notifications(notifications, 2)
    var ids: Array[int] = []
    for notification in notifications:
        ids.append(int(notification.get("id", 0)))

    $MarkNotificationsReadRequest.request(
        OnlineLeaderboard.get_mark_notifications_read_url(ids),
        OnlineLeaderboard.get_headers() + PackedStringArray(["Prefer: return=minimal"]),
        HTTPClient.METHOD_PATCH,
        OnlineLeaderboard.make_mark_notifications_read_body()
    )

func _on_mark_notifications_read_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    pass

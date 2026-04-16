extends Control

@onready var settings_menu = $SettingsMenu

func _ready() -> void:
    var push_notifications := get_node_or_null("/root/PushNotifications")
    if push_notifications != null and push_notifications.has_method("consume_open_leaderboard_request"):
        if bool(push_notifications.consume_open_leaderboard_request()):
            get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
            return

    $PlayButton.pressed.connect(_on_start_pressed)
    $ScoresButton.pressed.connect(_on_scores_pressed)
    $SettingsButton.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/game/main/main.tscn")

func _on_scores_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

func _on_settings_pressed() -> void:
    settings_menu.open_menu()

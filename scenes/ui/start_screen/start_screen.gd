extends Control

@onready var settings_menu = $SettingsMenu
@onready var debug_menu = $DebugMenu
@onready var debug_button = $DebugButton
@onready var missions_button = $MissionsButton
@onready var play_button = $PlayButton
@onready var update_prompt = $UpdatePrompt

func _ready() -> void:
    get_tree().paused = false
    var music_player = get_node_or_null("/root/MusicPlayer")
    if music_player != null and music_player.has_method("play_menu_music"):
        music_player.play_menu_music()

    var push_notifications := get_node_or_null("/root/PushNotifications")
    if push_notifications != null and push_notifications.has_method("consume_open_missions_request"):
        if bool(push_notifications.consume_open_missions_request()):
            get_tree().change_scene_to_file("res://scenes/ui/missions/mission_screen.tscn")
            return
    if push_notifications != null and push_notifications.has_method("consume_open_leaderboard_request"):
        if bool(push_notifications.consume_open_leaderboard_request()):
            get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
            return
    if push_notifications != null and push_notifications.has_method("consume_open_update_request"):
        if bool(push_notifications.consume_open_update_request()):
            var update_manager = get_node_or_null("/root/AppUpdateManager")
            if update_manager != null and update_manager.has_method("request_open_prompt"):
                update_manager.request_open_prompt()

    play_button.pressed.connect(_on_start_pressed)
    $ScoresButton.pressed.connect(_on_scores_pressed)
    missions_button.pressed.connect(_on_missions_pressed)
    $SettingsButton.pressed.connect(_on_settings_pressed)
    if debug_button != null:
        debug_button.visible = OS.is_debug_build()
        debug_button.pressed.connect(_on_debug_pressed)
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_manager != null and update_manager.has_signal("update_state_changed"):
        var callback := Callable(self, "_on_update_state_changed")
        if not update_manager.is_connected("update_state_changed", callback):
            update_manager.connect("update_state_changed", callback)
        _apply_update_state(update_manager.get_update_state() if update_manager.has_method("get_update_state") else {})
    _update_missions_button()
    _refresh_bonus_skin_access()

func _on_start_pressed() -> void:
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_manager != null and update_manager.has_method("has_required_update") and bool(update_manager.has_required_update()):
        if update_prompt != null and update_manager.has_method("get_update_state") and update_prompt.has_method("open_for_state"):
            update_prompt.open_for_state(update_manager.get_update_state())
        return
    get_tree().change_scene_to_file("res://scenes/game/main/main.tscn")

func _on_scores_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

func _on_missions_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/missions/mission_screen.tscn")

func _on_settings_pressed() -> void:
    settings_menu.open_menu()

func _on_debug_pressed() -> void:
    if debug_menu != null:
        debug_menu.open_menu()

func _update_missions_button() -> void:
    var mission_manager := get_node_or_null("/root/MissionManager")
    if mission_manager != null and mission_manager.has_method("get_daily_progress_summary"):
        var summary: Dictionary = mission_manager.get_daily_progress_summary()
        missions_button.text = "Missions %d/%d" % [
            int(summary.get("completed", 0)),
            int(summary.get("total", 3))
        ]
    else:
        missions_button.text = "Missions"

func _refresh_bonus_skin_access() -> void:
    var player_profile := get_node_or_null("/root/PlayerProfile")
    if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
        player_profile.refresh_top_player_skin_access()

func _on_update_state_changed(state: Dictionary) -> void:
    _apply_update_state(state)

func _apply_update_state(state: Dictionary) -> void:
    var required := bool(state.get("required", false))
    play_button.disabled = required
    play_button.text = "Update Required" if required else "Play Game"
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_prompt == null or update_manager == null or not update_manager.has_method("get_update_state"):
        return
    if required and update_prompt.has_method("open_for_state"):
        update_prompt.open_for_state(state)
        return
    if update_manager.has_method("consume_open_prompt_request") and bool(update_manager.consume_open_prompt_request()):
        update_prompt.open_for_state(state)
        return
    if update_manager.has_method("should_auto_prompt_optional_update") and bool(update_manager.should_auto_prompt_optional_update()):
        update_prompt.open_for_state(state)

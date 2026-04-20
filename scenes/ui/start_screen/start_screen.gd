extends Control

@onready var settings_menu = $SettingsMenu
@onready var debug_menu = $DebugMenu
@onready var debug_button = $DebugButton
@onready var scores_button = $ScoresButton
@onready var missions_button = $MissionsButton
@onready var hangar_button = $HangarButton
@onready var play_button = $PlayButton
@onready var update_prompt = $UpdatePrompt
@onready var next_unlock_title_label = $NextUnlockCard/NextUnlockMargin/NextUnlockVBox/NextUnlockTitleLabel
@onready var next_unlock_body_label = $NextUnlockCard/NextUnlockMargin/NextUnlockVBox/NextUnlockBodyLabel
@onready var tip_card = $TipCard
@onready var tip_title_label = $TipCard/TipMargin/TipVBox/TipTitleLabel
@onready var tip_message_label = $TipCard/TipMargin/TipVBox/TipMessageLabel
@onready var tip_action_button = $TipCard/TipMargin/TipVBox/TipButtonRow/TipActionButton
@onready var tip_dismiss_button = $TipCard/TipMargin/TipVBox/TipButtonRow/TipDismissButton

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
    scores_button.pressed.connect(_on_scores_pressed)
    missions_button.pressed.connect(_on_missions_pressed)
    hangar_button.pressed.connect(_on_hangar_pressed)
    $SettingsButton.pressed.connect(_on_settings_pressed)
    tip_action_button.pressed.connect(_on_tip_action_pressed)
    tip_dismiss_button.pressed.connect(_on_tip_dismiss_pressed)
    if debug_button != null:
        debug_button.visible = OS.is_debug_build()
        debug_button.pressed.connect(_on_debug_pressed)
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_manager != null and update_manager.has_signal("update_state_changed"):
        var callback := Callable(self, "_on_update_state_changed")
        if not update_manager.is_connected("update_state_changed", callback):
            update_manager.connect("update_state_changed", callback)
        _apply_update_state(update_manager.get_update_state() if update_manager.has_method("get_update_state") else {})
    _connect_progress_signals()
    _refresh_progress_discovery()
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

func _on_hangar_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/hangar/hangar_screen.tscn")

func _on_settings_pressed() -> void:
    settings_menu.open_menu()

func _on_debug_pressed() -> void:
    if debug_menu != null:
        debug_menu.open_menu()

func _connect_progress_signals() -> void:
    var mission_manager := get_node_or_null("/root/MissionManager")
    if mission_manager != null and mission_manager.has_signal("missions_changed"):
        var mission_callback := Callable(self, "_on_progress_state_changed")
        if not mission_manager.is_connected("missions_changed", mission_callback):
            mission_manager.connect("missions_changed", mission_callback)
    var player_profile := get_node_or_null("/root/PlayerProfile")
    if player_profile != null and player_profile.has_signal("profile_changed"):
        var profile_callback := Callable(self, "_on_progress_state_changed")
        if not player_profile.is_connected("profile_changed", profile_callback):
            player_profile.connect("profile_changed", profile_callback)

func _refresh_progress_discovery() -> void:
    _update_missions_button()
    _update_next_unlock_card()
    _refresh_tip_card()

func _update_missions_button() -> void:
    var mission_manager := get_node_or_null("/root/MissionManager")
    var completed := 0
    var total := 5
    if mission_manager != null and mission_manager.has_method("get_daily_progress_summary"):
        var summary: Dictionary = mission_manager.get_daily_progress_summary()
        completed = int(summary.get("completed", 0))
        total = int(summary.get("total", 5))
    missions_button.text = "Missions %d/%d" % [completed, total]
    hangar_button.text = "Hangar"

func _update_next_unlock_card() -> void:
    var player_profile := get_node_or_null("/root/PlayerProfile")
    if player_profile == null or not player_profile.has_method("get_next_unlock_preview"):
        next_unlock_body_label.text = "Collection progress is loading..."
        return
    var preview: Dictionary = player_profile.get_next_unlock_preview()
    next_unlock_title_label.text = "Next Unlock"
    next_unlock_body_label.text = "%s\n%s" % [
        str(preview.get("title", "Collection Progress")),
        str(preview.get("progress_text", "Keep flying")),
    ]

func _refresh_tip_card() -> void:
    var discovery_manager := get_node_or_null("/root/FeatureDiscoveryManager")
    if discovery_manager == null or not discovery_manager.has_method("get_active_tip"):
        tip_card.visible = false
        return
    var tip: Dictionary = discovery_manager.get_active_tip()
    if tip.is_empty():
        tip_card.visible = false
        return
    tip_title_label.text = str(tip.get("title", "Tip"))
    tip_message_label.text = str(tip.get("message", ""))
    tip_action_button.text = str(tip.get("button_text", "Open"))
    tip_card.set_meta("tip_id", str(tip.get("id", "")))
    tip_card.set_meta("tip_target", str(tip.get("target", "")))
    tip_card.visible = true

func _on_tip_action_pressed() -> void:
    var tip_target := str(tip_card.get_meta("tip_target", "")).strip_edges()
    _dismiss_current_tip()
    if tip_target == "missions":
        _on_missions_pressed()
    elif tip_target == "hangar":
        _on_hangar_pressed()

func _on_tip_dismiss_pressed() -> void:
    _dismiss_current_tip()
    _refresh_progress_discovery()

func _dismiss_current_tip() -> void:
    var tip_id := str(tip_card.get_meta("tip_id", "")).strip_edges()
    if tip_id.is_empty():
        return
    var discovery_manager := get_node_or_null("/root/FeatureDiscoveryManager")
    if discovery_manager != null and discovery_manager.has_method("mark_tip_seen"):
        discovery_manager.mark_tip_seen(tip_id)

func _on_progress_state_changed(_summary: Dictionary = {}) -> void:
    _refresh_progress_discovery()

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

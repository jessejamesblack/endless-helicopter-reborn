extends Control

const OnlineLeaderboardScript = preload("res://systems/online_leaderboard.gd")
const CREDITS_PANEL_MIN_WIDTH := 320.0
const CREDITS_PANEL_MAX_WIDTH := 640.0
const CREDITS_PANEL_MIN_HEIGHT := 260.0
const CREDITS_PANEL_MAX_HEIGHT := 380.0
const NAME_GATE_PANEL_MIN_WIDTH := 320.0
const NAME_GATE_PANEL_MAX_WIDTH := 560.0
const NAME_GATE_PANEL_MIN_HEIGHT := 300.0
const NAME_GATE_PANEL_MAX_HEIGHT := 420.0

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
@onready var credits_button = $CreditsButton
@onready var credits_overlay = $CreditsOverlay
@onready var credits_panel = $CreditsOverlay/CreditsPanel
@onready var credits_title_label = $CreditsOverlay/CreditsPanel/CreditsMargin/CreditsVBox/CreditsTitleLabel
@onready var credits_creator_label = $CreditsOverlay/CreditsPanel/CreditsMargin/CreditsVBox/CreditsCreatorLabel
@onready var credits_notice_label = $CreditsOverlay/CreditsPanel/CreditsMargin/CreditsVBox/CreditsNoticeLabel
@onready var credits_close_button = $CreditsOverlay/CreditsPanel/CreditsMargin/CreditsVBox/CreditsCloseButton
@onready var name_gate_overlay = $NameGateOverlay
@onready var name_gate_panel = $NameGateOverlay/NameGatePanel
@onready var name_gate_title_label = $NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateTitleLabel
@onready var name_gate_body_label = $NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateBodyLabel
@onready var name_gate_entry = $NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateEntry
@onready var name_gate_error_label = $NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateErrorLabel
@onready var name_gate_save_button = $NameGateOverlay/NameGatePanel/NameGateMargin/NameGateVBox/NameGateSaveButton

var validation_force_online_name_gate := false
var _pending_protected_scene_path := ""

func _ready() -> void:
    get_tree().paused = false
    var size_changed_callback := Callable(self, "_refresh_start_screen_layout")
    if not get_viewport().is_connected("size_changed", size_changed_callback):
        get_viewport().size_changed.connect(size_changed_callback)
    var music_player = get_node_or_null("/root/MusicPlayer")
    if music_player != null and music_player.has_method("play_menu_music"):
        music_player.play_menu_music()

    play_button.pressed.connect(_on_start_pressed)
    scores_button.pressed.connect(_on_scores_pressed)
    missions_button.pressed.connect(_on_missions_pressed)
    hangar_button.pressed.connect(_on_hangar_pressed)
    credits_button.pressed.connect(_on_credits_pressed)
    credits_close_button.pressed.connect(_on_credits_close_pressed)
    name_gate_save_button.pressed.connect(_on_name_gate_save_pressed)
    name_gate_entry.text_submitted.connect(_on_name_gate_text_submitted)
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
    _connect_startup_sync_signal()
    _connect_progress_signals()
    _refresh_progress_discovery()
    _refresh_bonus_skin_access()
    _refresh_start_screen_layout()
    _refresh_name_gate_state()
    _consume_push_open_requests()

func _on_start_pressed() -> void:
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_manager != null and update_manager.has_method("has_required_update") and bool(update_manager.has_required_update()):
        if update_prompt != null and update_manager.has_method("get_update_state") and update_prompt.has_method("open_for_state"):
            update_prompt.open_for_state(update_manager.get_update_state())
        return
    _request_protected_navigation("res://scenes/game/main/main.tscn")

func _on_scores_pressed() -> void:
    _request_protected_navigation("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

func _on_missions_pressed() -> void:
    _request_protected_navigation("res://scenes/ui/missions/mission_screen.tscn")

func _on_hangar_pressed() -> void:
    _request_protected_navigation("res://scenes/ui/hangar/hangar_screen.tscn")

func _on_credits_pressed() -> void:
    credits_overlay.move_to_front()
    credits_overlay.visible = true
    credits_close_button.grab_focus()

func _on_credits_close_pressed() -> void:
    _close_credits_overlay()

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

func _connect_startup_sync_signal() -> void:
    var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
    if sync_queue == null or not sync_queue.has_signal("startup_sync_state_changed"):
        return
    var sync_callback := Callable(self, "_on_startup_sync_state_changed")
    if not sync_queue.is_connected("startup_sync_state_changed", sync_callback):
        sync_queue.connect("startup_sync_state_changed", sync_callback)

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

func _unhandled_input(event: InputEvent) -> void:
    if not credits_overlay.visible:
        return
    if event.is_action_pressed("ui_cancel"):
        _close_credits_overlay()
        get_viewport().set_input_as_handled()

func _refresh_start_screen_layout() -> void:
    var viewport_size := get_viewport_rect().size
    var compact := viewport_size.x < 900.0 or viewport_size.y < 720.0

    credits_button.offset_left = 24.0
    credits_button.offset_right = 156.0 if compact else 168.0
    credits_button.offset_top = -96.0 if compact else -100.0
    credits_button.offset_bottom = -48.0
    credits_button.add_theme_font_size_override("font_size", 17 if compact else 18)

    var panel_width: float = clampf(viewport_size.x - 72.0, CREDITS_PANEL_MIN_WIDTH, CREDITS_PANEL_MAX_WIDTH)
    var panel_height: float = clampf(viewport_size.y - 120.0, CREDITS_PANEL_MIN_HEIGHT, CREDITS_PANEL_MAX_HEIGHT)
    credits_panel.offset_left = -panel_width * 0.5
    credits_panel.offset_right = panel_width * 0.5
    credits_panel.offset_top = -panel_height * 0.5
    credits_panel.offset_bottom = panel_height * 0.5
    credits_title_label.add_theme_font_size_override("font_size", 24 if compact else 30)
    credits_creator_label.add_theme_font_size_override("font_size", 17 if compact else 20)
    credits_notice_label.add_theme_font_size_override("font_size", 14 if compact else 16)
    credits_close_button.custom_minimum_size = Vector2(160.0 if compact else 180.0, 48.0 if compact else 52.0)
    credits_close_button.add_theme_font_size_override("font_size", 17 if compact else 18)

    var name_panel_width: float = clampf(viewport_size.x - 72.0, NAME_GATE_PANEL_MIN_WIDTH, NAME_GATE_PANEL_MAX_WIDTH)
    var name_panel_height: float = clampf(viewport_size.y - 120.0, NAME_GATE_PANEL_MIN_HEIGHT, NAME_GATE_PANEL_MAX_HEIGHT)
    name_gate_panel.offset_left = -name_panel_width * 0.5
    name_gate_panel.offset_right = name_panel_width * 0.5
    name_gate_panel.offset_top = -name_panel_height * 0.5
    name_gate_panel.offset_bottom = name_panel_height * 0.5
    name_gate_title_label.add_theme_font_size_override("font_size", 24 if compact else 30)
    name_gate_body_label.add_theme_font_size_override("font_size", 15 if compact else 17)
    name_gate_entry.add_theme_font_size_override("font_size", 18 if compact else 20)
    name_gate_error_label.add_theme_font_size_override("font_size", 14 if compact else 16)
    name_gate_save_button.custom_minimum_size = Vector2(180.0 if compact else 208.0, 48.0 if compact else 52.0)
    name_gate_save_button.add_theme_font_size_override("font_size", 17 if compact else 18)

func _close_credits_overlay() -> void:
    credits_overlay.visible = false
    credits_button.grab_focus()

func _refresh_bonus_skin_access() -> void:
    var player_profile := get_node_or_null("/root/PlayerProfile")
    if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
        player_profile.refresh_top_player_skin_access()

func _on_update_state_changed(state: Dictionary) -> void:
    _apply_update_state(state)

func _apply_update_state(state: Dictionary) -> void:
    var required := bool(state.get("required", false))
    _refresh_protected_button_state()
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

func _consume_push_open_requests() -> void:
    var push_notifications := get_node_or_null("/root/PushNotifications")
    if push_notifications == null:
        return
    if push_notifications.has_method("consume_open_update_request") and bool(push_notifications.consume_open_update_request()):
        var update_manager = get_node_or_null("/root/AppUpdateManager")
        if update_manager != null and update_manager.has_method("request_open_prompt"):
            update_manager.request_open_prompt()
    if push_notifications.has_method("consume_open_missions_request") and bool(push_notifications.consume_open_missions_request()):
        _request_protected_navigation("res://scenes/ui/missions/mission_screen.tscn")
        return
    if push_notifications.has_method("consume_open_leaderboard_request") and bool(push_notifications.consume_open_leaderboard_request()):
        _request_protected_navigation("res://scenes/ui/leaderboard/leaderboard_screen.tscn")

func _request_protected_navigation(scene_path: String) -> void:
    if _is_protected_navigation_blocked():
        _pending_protected_scene_path = scene_path
        _refresh_name_gate_state(true)
        return
    get_tree().change_scene_to_file(scene_path)

func _is_name_gate_online_configured() -> bool:
    if validation_force_online_name_gate:
        return true
    return OnlineLeaderboardScript.is_configured() and not OnlineLeaderboardScript.is_validation_run()

func _is_waiting_for_name_restore() -> bool:
    if not _is_name_gate_online_configured():
        return false
    if not OnlineLeaderboardScript.get_valid_cached_name().is_empty():
        return false
    var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
    if sync_queue != null and sync_queue.has_method("has_completed_startup_sync"):
        return not bool(sync_queue.has_completed_startup_sync())
    return false

func _should_require_name_setup() -> bool:
    if not _is_name_gate_online_configured():
        return false
    if not OnlineLeaderboardScript.get_valid_cached_name().is_empty():
        return false
    var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
    if sync_queue != null and sync_queue.has_method("has_completed_startup_sync"):
        return bool(sync_queue.has_completed_startup_sync())
    return true

func _is_protected_navigation_blocked() -> bool:
    return _is_waiting_for_name_restore() or _should_require_name_setup()

func _refresh_name_gate_state(force_prompt: bool = false) -> void:
    var should_prompt := _should_require_name_setup()
    _refresh_protected_button_state()
    if OnlineLeaderboardScript.get_valid_cached_name().is_empty() and (should_prompt or (force_prompt and not _is_waiting_for_name_restore())):
        name_gate_overlay.visible = true
        name_gate_error_label.text = ""
        name_gate_entry.grab_focus()
        return
    name_gate_overlay.visible = false
    _open_pending_protected_scene_if_ready()

func _refresh_protected_button_state() -> void:
    var update_required := false
    var update_manager = get_node_or_null("/root/AppUpdateManager")
    if update_manager != null and update_manager.has_method("has_required_update"):
        update_required = bool(update_manager.has_required_update())
    var waiting_for_restore := _is_waiting_for_name_restore()
    var requires_name := _should_require_name_setup()
    var gate_blocked := waiting_for_restore or requires_name
    scores_button.disabled = gate_blocked
    missions_button.disabled = gate_blocked
    hangar_button.disabled = gate_blocked
    play_button.disabled = update_required or gate_blocked
    if update_required:
        play_button.text = "Update Required"
    elif waiting_for_restore:
        play_button.text = "Restoring..."
    elif requires_name:
        play_button.text = "Choose Name"
    else:
        play_button.text = "Play Game"

func _on_startup_sync_state_changed() -> void:
    _refresh_name_gate_state()

func _on_name_gate_text_submitted(_text: String) -> void:
    _on_name_gate_save_pressed()

func _on_name_gate_save_pressed() -> void:
    var validation := OnlineLeaderboardScript.validate_player_name(name_gate_entry.text)
    if not bool(validation.get("ok", false)):
        name_gate_error_label.text = str(validation.get("error", "Choose another name."))
        return

    var clean_name := str(validation.get("name", ""))
    OnlineLeaderboardScript.save_cached_name(clean_name)
    name_gate_entry.text = clean_name
    name_gate_error_label.text = ""
    _queue_profile_sync_after_name_save()
    _refresh_name_gate_state()

func _queue_profile_sync_after_name_save() -> void:
    var player_profile := get_node_or_null("/root/PlayerProfile")
    var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
    if player_profile == null or sync_queue == null or not sync_queue.has_method("enqueue_sync_player_profile"):
        return

    if player_profile.has_method("get_profile_sync_summary"):
        sync_queue.enqueue_sync_player_profile(player_profile.get_profile_sync_summary())
    elif player_profile.has_method("get_profile_summary"):
        sync_queue.enqueue_sync_player_profile(player_profile.get_profile_summary())

    if sync_queue.has_method("flush") and not OnlineLeaderboardScript.is_validation_run():
        sync_queue.flush()

func _open_pending_protected_scene_if_ready() -> void:
    if _pending_protected_scene_path.is_empty() or _is_protected_navigation_blocked():
        return
    var scene_path := _pending_protected_scene_path
    _pending_protected_scene_path = ""
    get_tree().change_scene_to_file(scene_path)

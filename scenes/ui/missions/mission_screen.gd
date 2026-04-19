extends Control

const HANGAR_SCENE_PATH := "res://scenes/ui/hangar/hangar_screen.tscn"
const START_SCREEN_SCENE_PATH := "res://scenes/ui/start_screen/start_screen.tscn"
const PANEL_MARGIN := 4.0
const PANEL_DEFAULT_RECT := Rect2(-360.0, -332.0, 720.0, 664.0)
const PANEL_COMPACT_RECT := Rect2(-336.0, -296.0, 672.0, 592.0)
const TOUCH_SCROLL_DEADZONE := 10.0
const TOUCH_SCROLL_AXIS_BIAS := 1.2
const MOUSE_POINTER_ID := -1000
const CORE_MISSION_COUNT := 3
const BONUS_MISSION_COUNT := 2

var validation_mode_enabled: bool = false
var _validation_summary: Dictionary = {}
var _scroll_pointer_active: bool = false
var _scroll_dragging: bool = false
var _scroll_pointer_id: int = -1
var _scroll_press_position: Vector2 = Vector2.ZERO
var _scroll_origin: float = 0.0

@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var content_vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var progress_label: Label = $Panel/MarginContainer/VBoxContainer/ProgressLabel
@onready var reset_label: Label = $Panel/MarginContainer/VBoxContainer/ResetLabel
@onready var mission_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionScroll
@onready var mission_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/MissionCard/MissionScroll/MissionList
@onready var next_unlock_label: Label = $Panel/MarginContainer/VBoxContainer/NextUnlockCard/NextUnlockLabel
@onready var reward_help_label: Label = $Panel/MarginContainer/VBoxContainer/RewardHelpLabel
@onready var streak_label: Label = $Panel/MarginContainer/VBoxContainer/StreakLabel
@onready var button_row: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ButtonRow
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/BackButton
@onready var hangar_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/HangarButton

func _ready() -> void:
	var music_player = get_node_or_null("/root/MusicPlayer")
	if not validation_mode_enabled and music_player != null and music_player.has_method("play_menu_music"):
		music_player.play_menu_music()

	back_button.pressed.connect(_on_back_pressed)
	hangar_button.pressed.connect(_on_hangar_pressed)

	if not validation_mode_enabled:
		var mission_manager: Node = _get_mission_manager()
		if mission_manager != null and mission_manager.has_signal("missions_changed"):
			var callback := Callable(self, "_on_missions_changed")
			if not mission_manager.is_connected("missions_changed", callback):
				mission_manager.connect("missions_changed", callback)

		var player_profile: Node = _get_player_profile()
		if player_profile != null and player_profile.has_signal("profile_changed"):
			var profile_callback := Callable(self, "_on_profile_changed")
			if not player_profile.is_connected("profile_changed", profile_callback):
				player_profile.connect("profile_changed", profile_callback)
			if player_profile.has_method("has_seen_missions_intro") and not player_profile.has_seen_missions_intro():
				player_profile.mark_missions_intro_seen()
		var discovery_manager := get_node_or_null("/root/FeatureDiscoveryManager")
		if discovery_manager != null and discovery_manager.has_method("mark_tip_seen"):
			discovery_manager.mark_tip_seen("missions")

		var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
		if sync_queue != null and sync_queue.has_method("flush"):
			sync_queue.flush()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout_profile()
	_configure_touch_scroll()

	_refresh_view()

func _refresh_view() -> void:
	var summary: Dictionary = {}
	var mission_manager: Node = _get_mission_manager()
	if validation_mode_enabled and not _validation_summary.is_empty():
		summary = _validation_summary.duplicate(true)
	else:
		if mission_manager == null:
			return
		if mission_manager.has_method("refresh_daily_missions"):
			mission_manager.refresh_daily_missions()
		summary = mission_manager.get_daily_progress_summary() if mission_manager.has_method("get_daily_progress_summary") else {}
	progress_label.text = "%d / %d complete" % [int(summary.get("completed", 0)), int(summary.get("total", 5))]
	subtitle_label.text = "Core %d/%d  •  Bonus %d/%d" % [
		int(summary.get("core_completed", 0)),
		int(summary.get("core_total", CORE_MISSION_COUNT)),
		int(summary.get("bonus_completed", 0)),
		int(summary.get("bonus_total", BONUS_MISSION_COUNT)),
	]
	reset_label.text = mission_manager.get_reset_label() if mission_manager != null and mission_manager.has_method("get_reset_label") else "Resets daily at 8:00 AM ET"
	reward_help_label.text = "Complete missions to unlock vehicles, paint styles, and Hangar content."
	streak_label.text = "Daily Streak: %d%s" % [
		int(summary.get("daily_streak", 0)),
		"  •  Perfect day ready" if bool(summary.get("perfect_day", false)) else "",
	]

	var next_unlock: Dictionary = summary.get("next_unlock", {})
	if next_unlock.is_empty():
		next_unlock_label.text = "Next Reward\nCollection complete"
	else:
		next_unlock_label.text = "Next Reward\n%s\n%s" % [
			str(next_unlock.get("display_name", "Scout")),
			str(next_unlock.get("progress_text", "")),
		]

	_render_mission_rows(summary.get("missions", []))

func _render_mission_rows(missions_variant) -> void:
	for child in mission_list.get_children():
		child.queue_free()

	if missions_variant is not Array or missions_variant.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Missions are loading..."
		_apply_body_label_theme(empty_label)
		mission_list.add_child(empty_label)
		return

	var core_missions: Array[Dictionary] = []
	var bonus_missions: Array[Dictionary] = []
	for mission_variant in missions_variant:
		if mission_variant is not Dictionary:
			continue
		var mission := mission_variant as Dictionary
		if bool(mission.get("bonus", false)):
			bonus_missions.append(mission)
		else:
			core_missions.append(mission)

	mission_list.add_child(_create_section_label("Core Missions"))
	for mission in core_missions:
		mission_list.add_child(_create_mission_row(mission))
	mission_list.add_child(_create_section_label("Bonus Missions"))
	for mission in bonus_missions:
		mission_list.add_child(_create_mission_row(mission))

func _create_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.964706, 0.843137, 0.54902, 1))
	label.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 17 if _is_compact_layout() else 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_mission_row(mission: Dictionary) -> PanelContainer:
	var compact := _is_compact_layout()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 84 if compact else 92)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12 if compact else 14)
	margin.add_theme_constant_override("margin_top", 10 if compact else 12)
	margin.add_theme_constant_override("margin_right", 12 if compact else 14)
	margin.add_theme_constant_override("margin_bottom", 10 if compact else 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4 if compact else 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title_label := Label.new()
	var mission_title := str(mission.get("title", "Daily Mission"))
	if bool(mission.get("bonus", false)):
		mission_title = "%s  •  %s" % [str(mission.get("badge_text", "BONUS")), mission_title]
	title_label.text = mission_title
	title_label.add_theme_color_override("font_color", Color(0.964706, 0.843137, 0.54902, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_font_size_override("font_size", 17 if compact else 18)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	var description_label := Label.new()
	description_label.text = str(mission.get("description", ""))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_label_theme(description_label)
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description_label)

	var progress_label := Label.new()
	progress_label.text = _format_progress_text(mission)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_color_override("font_color", Color(0.921569, 0.94902, 1, 1))
	progress_label.add_theme_font_size_override("font_size", 15 if compact else 16)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_label)

	return card

func _format_progress_text(mission: Dictionary) -> String:
	if str(mission.get("type", "")) == "max_combo":
		var progress := float(mission.get("progress", 0.0)) / 100.0
		var target := float(mission.get("target", 100.0)) / 100.0
		return "x%.2f / x%.2f%s" % [progress, target, " COMPLETE" if bool(mission.get("completed", false)) else ""]

	var progress_value := int(round(float(mission.get("progress", 0.0))))
	var target_value := int(round(float(mission.get("target", 1.0))))
	return "%d / %d%s" % [progress_value, target_value, " COMPLETE" if bool(mission.get("completed", false)) else ""]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(START_SCREEN_SCENE_PATH)

func _on_hangar_pressed() -> void:
	get_tree().change_scene_to_file(HANGAR_SCENE_PATH)

func _on_missions_changed(_summary: Dictionary) -> void:
	_refresh_view()

func _on_profile_changed(_summary: Dictionary) -> void:
	_refresh_view()

func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0823529, 0.113725, 0.196078, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.356863, 0.54902, 0.772549, 0.7)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _apply_body_label_theme(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(0.921569, 0.94902, 1, 1))
	label.add_theme_font_size_override("font_size", 14 if _is_compact_layout() else 15)

func _apply_layout_profile() -> void:
	var compact := _is_compact_layout()
	margin_container.add_theme_constant_override("margin_left", 22 if compact else 26)
	margin_container.add_theme_constant_override("margin_top", 18 if compact else 24)
	margin_container.add_theme_constant_override("margin_right", 22 if compact else 26)
	margin_container.add_theme_constant_override("margin_bottom", 24 if compact else 30)
	content_vbox.add_theme_constant_override("separation", 8 if compact else 10)
	title_label.add_theme_font_size_override("font_size", 26 if compact else 32)
	title_label.add_theme_constant_override("outline_size", 3 if compact else 5)
	subtitle_label.add_theme_font_size_override("font_size", 15 if compact else 17)
	progress_label.add_theme_font_size_override("font_size", 18 if compact else 22)
	reset_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	mission_scroll.custom_minimum_size = Vector2(0, 198 if compact else 258)
	mission_list.add_theme_constant_override("separation", 8 if compact else 10)
	next_unlock_label.custom_minimum_size = Vector2(0, 48 if compact else 56)
	next_unlock_label.add_theme_font_size_override("font_size", 16 if compact else 18)
	streak_label.add_theme_font_size_override("font_size", 16 if compact else 18)
	button_row.add_theme_constant_override("separation", 8 if compact else 10)
	for button in [back_button, hangar_button]:
		button.custom_minimum_size = Vector2(0, 36 if compact else 46)
		button.add_theme_font_size_override("font_size", 15 if compact else 18)
	_apply_responsive_panel_rect(PANEL_COMPACT_RECT if compact else PANEL_DEFAULT_RECT)

func _apply_responsive_panel_rect(rect: Rect2) -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(280.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(300.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var target_size := Vector2(
		min(rect.size.x, max_size.x),
		min(rect.size.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

func _is_compact_layout() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.y <= 680.0 or viewport_size.x <= 1024.0

func _on_viewport_size_changed() -> void:
	_apply_layout_profile()
	_refresh_view()

func apply_validation_state(summary: Dictionary) -> void:
	validation_mode_enabled = true
	_validation_summary = summary.duplicate(true)
	if is_node_ready():
		_apply_layout_profile()
		_refresh_view()

func _get_player_profile() -> Node:
	return get_node_or_null("/root/PlayerProfile")

func _get_mission_manager() -> Node:
	return get_node_or_null("/root/MissionManager")

func _configure_touch_scroll() -> void:
	mission_scroll.scroll_deadzone = int(TOUCH_SCROLL_DEADZONE)
	mission_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_scroll_touch(event.position, event.index, event.pressed)
		return
	if event is InputEventScreenDrag:
		_handle_scroll_drag(event.position, event.index)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_scroll_touch(event.position, MOUSE_POINTER_ID, event.pressed)
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_scroll_drag(event.position, MOUSE_POINTER_ID)

func _handle_scroll_touch(position: Vector2, pointer_id: int, pressed: bool) -> void:
	if pressed:
		if not _is_touch_inside_scroll(position) or not _can_scroll_content():
			return
		_scroll_pointer_active = true
		_scroll_dragging = false
		_scroll_pointer_id = pointer_id
		_scroll_press_position = position
		_scroll_origin = float(mission_scroll.scroll_vertical)
		return
	if _scroll_pointer_active and _scroll_pointer_id == pointer_id:
		if _scroll_dragging:
			get_viewport().set_input_as_handled()
		_reset_touch_scroll_state()

func _handle_scroll_drag(position: Vector2, pointer_id: int) -> void:
	if not _scroll_pointer_active or _scroll_pointer_id != pointer_id:
		return
	var drag_delta := position - _scroll_press_position
	if not _scroll_dragging:
		if abs(drag_delta.y) < TOUCH_SCROLL_DEADZONE:
			return
		if abs(drag_delta.y) < abs(drag_delta.x) * TOUCH_SCROLL_AXIS_BIAS:
			return
		_scroll_dragging = true
	if _scroll_dragging:
		var next_scroll := _scroll_origin - drag_delta.y
		mission_scroll.scroll_vertical = int(round(next_scroll))
		get_viewport().set_input_as_handled()

func _is_touch_inside_scroll(position: Vector2) -> bool:
	return mission_scroll.get_global_rect().has_point(position)

func _can_scroll_content() -> bool:
	var scroll_bar := mission_scroll.get_v_scroll_bar()
	return scroll_bar != null and scroll_bar.max_value > 0.0

func _reset_touch_scroll_state() -> void:
	_scroll_pointer_active = false
	_scroll_dragging = false
	_scroll_pointer_id = -1
	_scroll_press_position = Vector2.ZERO
	_scroll_origin = 0.0

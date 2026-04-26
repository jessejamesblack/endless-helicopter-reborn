extends Control

const START_SCREEN_SCENE_PATH := "res://scenes/ui/start_screen/start_screen.tscn"
const TouchScrollButtonScript = preload("res://systems/touch_scroll_button.gd")
const PlayerScript = preload("res://scenes/player/player.gd")
const PREVIEW_CENTER := Vector2(140, 80)
const PREVIEW_SCALE_MULTIPLIER := 2.55
const TOUCH_SCROLL_DEADZONE := 10.0
const TOUCH_SCROLL_AXIS_BIAS := 1.2
const MOUSE_POINTER_ID := -1000
const LIST_BUTTON_HEIGHT := 38.0
const LIST_BUTTON_FONT_SIZE := 14

var _selected_vehicle_id: String = "default_scout"
var _selected_skin_id: String = "factory"
var _active_scroll: ScrollContainer = null
var _scroll_pointer_active: bool = false
var _scroll_dragging: bool = false
var _scroll_pointer_id: int = -1
var _scroll_press_position: Vector2 = Vector2.ZERO
var _scroll_origin: float = 0.0

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var preview_sprite: Sprite2D = $Panel/MarginContainer/VBoxContainer/ContentRow/PreviewCard/PreviewMargin/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewSprite
@onready var vehicle_list_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/VehicleListCard/VehicleListScroll
@onready var vehicle_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/VehicleListCard/VehicleListScroll/VehicleList
@onready var skin_list_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/SkinListCard/SkinListScroll
@onready var skin_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/SkinListCard/SkinListScroll/SkinList
@onready var vehicle_lore_label: Label = $Panel/MarginContainer/VBoxContainer/VehicleLoreCard/VehicleLoreLabel
@onready var vehicle_stats_label: Label = $Panel/MarginContainer/VBoxContainer/VehicleStatsCard/VehicleStatsMargin/VehicleStatsLabel
@onready var skin_lore_label: Label = $Panel/MarginContainer/VBoxContainer/SkinLoreCard/SkinLoreLabel
@onready var requirement_label: Label = $Panel/MarginContainer/VBoxContainer/RequirementLabel
@onready var equip_vehicle_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/EquipVehicleButton
@onready var equip_skin_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/EquipSkinButton

func _ready() -> void:
	var music_player = get_node_or_null("/root/MusicPlayer")
	if music_player != null and music_player.has_method("play_menu_music"):
		music_player.play_menu_music()

	$Panel/MarginContainer/VBoxContainer/ButtonRow/BackButton.pressed.connect(_on_back_pressed)
	equip_vehicle_button.pressed.connect(_on_equip_vehicle_pressed)
	equip_skin_button.pressed.connect(_on_equip_skin_pressed)

	var player_profile := _get_player_profile()
	if player_profile != null and player_profile.has_signal("profile_changed"):
		var callback := Callable(self, "_on_profile_changed")
		if not player_profile.is_connected("profile_changed", callback):
			player_profile.connect("profile_changed", callback)

	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("flush"):
		sync_queue.flush()
	if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
		player_profile.refresh_top_player_skin_access()

	if player_profile != null and player_profile.has_method("get_equipped_vehicle_id"):
		_selected_vehicle_id = str(player_profile.get_equipped_vehicle_id())
	if player_profile != null and player_profile.has_method("get_equipped_vehicle_skin_id"):
		_selected_skin_id = str(player_profile.get_equipped_vehicle_skin_id(_selected_vehicle_id))
	var hangar_navigation_state := get_node_or_null("/root/HangarNavigationState")
	if hangar_navigation_state != null and hangar_navigation_state.has_method("consume_focus"):
		var focus: Dictionary = hangar_navigation_state.consume_focus()
		var focus_vehicle_id := str(focus.get("vehicle_id", "")).strip_edges()
		var focus_skin_id := str(focus.get("skin_id", "")).strip_edges()
		if player_profile != null and not focus_vehicle_id.is_empty() and player_profile.has_method("has_vehicle_access") and player_profile.has_vehicle_access(focus_vehicle_id):
			_selected_vehicle_id = focus_vehicle_id
			_selected_skin_id = focus_skin_id if not focus_skin_id.is_empty() and player_profile.has_method("is_vehicle_skin_unlocked") and player_profile.is_vehicle_skin_unlocked(_selected_vehicle_id, focus_skin_id) else _get_selected_vehicle_skin(player_profile, _selected_vehicle_id)
	var discovery_manager := get_node_or_null("/root/FeatureDiscoveryManager")
	if discovery_manager != null and discovery_manager.has_method("mark_tip_seen"):
		discovery_manager.mark_tip_seen("hangar")

	_configure_touch_scroll()
	_refresh_view()

func _refresh_view() -> void:
	title_label.text = "Vehicles"
	subtitle_label.text = "Choose a vehicle, tune its finish, and read the hangar dossier."
	_render_vehicle_list()
	_render_skin_list()
	_update_preview()
	_update_details()

func _render_vehicle_list() -> void:
	for child in vehicle_list.get_children():
		child.queue_free()

	var helicopter_skins := _get_helicopter_skins()
	var player_profile := _get_player_profile()
	if helicopter_skins == null or player_profile == null:
		return

	for vehicle_id in helicopter_skins.get_vehicle_ids():
		var button := TouchScrollButtonScript.new()
		button.custom_minimum_size = Vector2(0, LIST_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _build_vehicle_button_text(vehicle_id, player_profile, helicopter_skins)
		button.add_theme_font_size_override("font_size", LIST_BUTTON_FONT_SIZE)
		button.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.564706, 1))
		button.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
		button.add_theme_constant_override("outline_size", 2)
		button.touch_activated.connect(func() -> void:
			_selected_vehicle_id = vehicle_id
			_selected_skin_id = _get_selected_vehicle_skin(player_profile, vehicle_id)
			_refresh_view()
		)
		vehicle_list.add_child(button)

func _render_skin_list() -> void:
	for child in skin_list.get_children():
		child.queue_free()

	var helicopter_skins := _get_helicopter_skins()
	var player_profile := _get_player_profile()
	if helicopter_skins == null or player_profile == null:
		return

	for skin_id in helicopter_skins.get_vehicle_skin_ids(_selected_vehicle_id):
		var button := TouchScrollButtonScript.new()
		button.custom_minimum_size = Vector2(0, LIST_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _build_skin_button_text(_selected_vehicle_id, skin_id, player_profile, helicopter_skins)
		button.add_theme_font_size_override("font_size", LIST_BUTTON_FONT_SIZE)
		button.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.564706, 1))
		button.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
		button.add_theme_constant_override("outline_size", 2)
		button.touch_activated.connect(func() -> void:
			_selected_skin_id = skin_id
			_update_preview()
			_update_details()
			_render_skin_list()
		)
		skin_list.add_child(button)

func _build_vehicle_button_text(vehicle_id: String, player_profile: Node, helicopter_skins: Node) -> String:
	var label := str(helicopter_skins.get_display_name(vehicle_id))
	var has_access: bool = player_profile.is_vehicle_unlocked(vehicle_id) if player_profile.has_method("is_vehicle_unlocked") else player_profile.has_skin_access(vehicle_id)
	if not has_access:
		return "%s  -  Locked" % label
	if player_profile.get_equipped_vehicle_id() == vehicle_id:
		return "%s  -  Equipped" % label
	return "%s  -  Unlocked" % label

func _build_skin_button_text(vehicle_id: String, skin_id: String, player_profile: Node, helicopter_skins: Node) -> String:
	var skin_data: Dictionary = helicopter_skins.get_vehicle_skin_data(vehicle_id, skin_id)
	var label := str(skin_data.get("display_name", skin_id.capitalize()))
	if skin_id == "original_icon" and not bool(skin_data.get("available", false)):
		return "%s  -  Unavailable" % label
	var unlocked: bool = player_profile.is_vehicle_skin_unlocked(vehicle_id, skin_id)
	if not unlocked:
		return "%s  -  Locked" % label
	var equipped: bool = player_profile.get_equipped_vehicle_skin_id(vehicle_id) == skin_id
	if equipped:
		return "%s  -  Equipped" % label
	return "%s  -  Unlocked" % label

func _update_preview() -> void:
	var helicopter_skins := _get_helicopter_skins()
	if helicopter_skins == null or preview_sprite == null:
		return

	preview_sprite.rotation = 0.0
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if helicopter_skins.has_method("apply_vehicle_and_skin_to_sprite"):
		helicopter_skins.apply_vehicle_and_skin_to_sprite(preview_sprite, _selected_vehicle_id, _selected_skin_id)
	elif helicopter_skins.has_method("apply_skin_to_sprite"):
		helicopter_skins.apply_skin_to_sprite(preview_sprite, _selected_vehicle_id)
	var base_scale := preview_sprite.scale
	preview_sprite.scale = base_scale * PREVIEW_SCALE_MULTIPLIER
	preview_sprite.position = PREVIEW_CENTER

func _update_details() -> void:
	var helicopter_skins := _get_helicopter_skins()
	var player_profile := _get_player_profile()
	if helicopter_skins == null or player_profile == null:
		return

	var vehicle_data: Dictionary = helicopter_skins.get_vehicle_data(_selected_vehicle_id)
	var skin_data: Dictionary = helicopter_skins.get_vehicle_skin_data(_selected_vehicle_id, _selected_skin_id)
	var dossier_parts: Array[String] = []

	var vehicle_lines: Array[String] = [
		str(vehicle_data.get("display_name", "Vehicle")),
		str(vehicle_data.get("short_lore", "")),
		str(vehicle_data.get("flavor_quote", "")),
	]
	for entry in vehicle_data.get("dossier", []):
		var text := str(entry).strip_edges()
		if not text.is_empty():
			dossier_parts.append(text)
	if not dossier_parts.is_empty():
		vehicle_lines.append(" • ".join(dossier_parts))
	vehicle_lore_label.text = _join_non_empty_lines(vehicle_lines)
	vehicle_stats_label.text = _build_vehicle_stats_text(_selected_vehicle_id, vehicle_data)

	var skin_lines: Array[String] = [
		str(skin_data.get("display_name", "Factory")),
		str(skin_data.get("short_lore", "")),
		str(skin_data.get("unlock_lore", "")),
	]
	skin_lore_label.text = _join_non_empty_lines(skin_lines)

	var vehicle_unlocked: bool = player_profile.is_vehicle_unlocked(_selected_vehicle_id)
	var skin_unlocked: bool = player_profile.is_vehicle_skin_unlocked(_selected_vehicle_id, _selected_skin_id)
	var vehicle_equipped: bool = player_profile.get_equipped_vehicle_id() == _selected_vehicle_id
	var skin_equipped: bool = player_profile.get_equipped_vehicle_skin_id(_selected_vehicle_id) == _selected_skin_id

	requirement_label.text = _build_requirement_text(player_profile, helicopter_skins)

	equip_vehicle_button.disabled = not vehicle_unlocked or vehicle_equipped
	equip_vehicle_button.text = "EQUIPPED VEHICLE" if vehicle_equipped else ("EQUIP VEHICLE" if vehicle_unlocked else "VEHICLE LOCKED")

	var skin_available := not (_selected_skin_id == "original_icon" and not bool(skin_data.get("available", false)))
	equip_skin_button.disabled = not skin_available or not vehicle_unlocked or not skin_unlocked or skin_equipped
	if not skin_available:
		equip_skin_button.text = "SKIN UNAVAILABLE"
	elif skin_equipped:
		equip_skin_button.text = "EQUIPPED SKIN"
	elif skin_unlocked:
		equip_skin_button.text = "EQUIP SKIN"
	else:
		equip_skin_button.text = "SKIN LOCKED"

func _build_requirement_text(player_profile: Node, helicopter_skins: Node) -> String:
	if not player_profile.is_vehicle_unlocked(_selected_vehicle_id):
		return str(helicopter_skins.get_vehicle_unlock_requirement(_selected_vehicle_id))

	var skin_data: Dictionary = helicopter_skins.get_vehicle_skin_data(_selected_vehicle_id, _selected_skin_id)
	if _selected_skin_id == "original_icon" and not bool(skin_data.get("available", false)):
		return "Original Icon is not available for this vehicle."
	if player_profile.is_vehicle_skin_unlocked(_selected_vehicle_id, _selected_skin_id):
		return str(skin_data.get("unlock_lore", "Ready for launch."))

	var progress: Dictionary = player_profile.get_vehicle_skin_progress(_selected_vehicle_id)
	match _selected_skin_id:
		"factory":
			return "Factory finish ships with every unlocked vehicle."
		"arctic":
			return "Arctic: %d / 3 daily missions" % int(progress.get("daily_missions_completed", 0))
		"desert":
			return "Desert: %d / 5 runs" % int(progress.get("runs_completed", 0))
		"neon":
			return "Neon: %d / 25 near misses" % int(progress.get("near_misses", 0))
		"prototype":
			return "Prototype: %d / 10 intercepts" % int(progress.get("projectile_intercepts", 0))
		"gold":
			return "Gold: Best %d / 5000" % int(progress.get("best_score", 0))
		"original_icon":
			return "Original Icon: Score 10,000+ in one run."
	return str(skin_data.get("unlock_requirement", "Unlock this skin by flying more runs."))

func _build_vehicle_stats_text(vehicle_id: String, vehicle_data: Dictionary) -> String:
	var profile: Dictionary = vehicle_data.get("profile", {})
	var passive_data := _get_vehicle_passive_data(vehicle_id)
	var passive_name := str(passive_data.get("name", _format_passive_id(str(profile.get("passive_id", "")))))
	var passive_modifiers: Dictionary = passive_data.get("modifiers", {})
	var ammo_capacity := PlayerScript.BASE_AMMO_CAPACITY + int(round(float(passive_modifiers.get("max_ammo_bonus", 0.0))))
	ammo_capacity = maxi(ammo_capacity, PlayerScript.BASE_AMMO_CAPACITY)

	var stat_line := "STATS  AMMO %d | LIFT %s | HANDLING %s | GRAVITY %s | RECOVERY %s" % [
		ammo_capacity,
		_get_lift_rating(float(profile.get("jump_velocity", -400.0))),
		_get_handling_rating(float(profile.get("tilt_speed", 5.0)), float(profile.get("max_tilt", 0.5))),
		_get_gravity_rating(float(profile.get("gravity_scale", 1.0))),
		_get_recovery_rating(profile, passive_modifiers),
	]
	var modifier_line := "PASSIVE %s | %s" % [passive_name, _format_modifier_summary(passive_modifiers)]
	return "\n".join([stat_line, modifier_line])

func _get_lift_rating(jump_velocity_value: float) -> String:
	var lift_strength := absf(jump_velocity_value)
	if lift_strength >= 420.0:
		return "High"
	if lift_strength <= 375.0:
		return "Heavy"
	return "Balanced"

func _get_handling_rating(tilt_speed_value: float, max_tilt_value: float) -> String:
	var handling_score := tilt_speed_value + max_tilt_value * 4.0
	if handling_score >= 7.6:
		return "Agile"
	if handling_score <= 6.1:
		return "Steady"
	return "Balanced"

func _get_gravity_rating(gravity_scale: float) -> String:
	if gravity_scale <= 0.96:
		return "Light"
	if gravity_scale >= 1.08:
		return "Heavy"
	return "Standard"

func _get_recovery_rating(profile: Dictionary, passive_modifiers: Dictionary) -> String:
	if int(passive_modifiers.get("run_shield_charges", 0)) > 0:
		return "Shielded"
	var recovery_bonus := float(passive_modifiers.get("boundary_recovery_multiplier", 0.0))
	if recovery_bonus > 0.0:
		return "Strong"
	var bounce_score := float(profile.get("boundary_bounce_up_speed", 360.0)) + float(profile.get("boundary_bounce_down_speed", 300.0))
	if bounce_score >= 700.0:
		return "Strong"
	if bounce_score <= 640.0:
		return "Gentle"
	return "Standard"

func _format_modifier_summary(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	var ammo_bonus := int(round(float(modifiers.get("max_ammo_bonus", 0.0))))
	if ammo_bonus > 0:
		parts.append("+%d ammo" % ammo_bonus)
	var refund_chance := float(modifiers.get("ammo_refund_chance", 0.0))
	if refund_chance > 0.0:
		parts.append("%d%% refund chance" % int(round(refund_chance * 100.0)))
	var shield_charges := int(modifiers.get("run_shield_charges", 0))
	if shield_charges > 0:
		parts.append("%d shield" % shield_charges)
	var near_miss_bonus := float(modifiers.get("near_miss_multiplier", 0.0))
	if near_miss_bonus > 0.0:
		parts.append("+%d%% near misses" % int(round(near_miss_bonus * 100.0)))
	var combo_bonus := float(modifiers.get("combo_timeout_bonus", 0.0))
	if combo_bonus > 0.0:
		parts.append("+%.2fs combo" % combo_bonus)
	var recovery_bonus := float(modifiers.get("boundary_recovery_multiplier", 0.0))
	if recovery_bonus > 0.0:
		parts.append("+%d%% recovery" % int(round(recovery_bonus * 100.0)))
	var missile_score_bonus := int(round(float(modifiers.get("missile_score_bonus", 0.0))))
	if missile_score_bonus > 0:
		parts.append("+%d missile score" % missile_score_bonus)
	var missile_cooldown_multiplier := float(modifiers.get("missile_cooldown_multiplier", 0.0))
	if missile_cooldown_multiplier < 0.0:
		parts.append("%d%% faster fire" % int(round(absf(missile_cooldown_multiplier) * 100.0)))
	var precision_bonus := int(round(float(modifiers.get("precision_bonus", 0.0))))
	if precision_bonus > 0:
		parts.append("+%d precision" % precision_bonus)
	var gravity_multiplier := float(modifiers.get("gravity_multiplier", 0.0))
	if gravity_multiplier < 0.0:
		parts.append("lighter gravity")
	elif gravity_multiplier > 0.0:
		parts.append("heavier gravity")
	var choice_weight_bonus := float(modifiers.get("choice_weight_bonus", 0.0))
	if choice_weight_bonus > 0.0:
		parts.append("upgrade choice bias")
	if parts.is_empty():
		return "No passive modifier."
	return ", ".join(parts)

func _get_vehicle_passive_data(vehicle_id: String) -> Dictionary:
	var run_upgrade_manager := get_node_or_null("/root/RunUpgradeManager")
	if run_upgrade_manager != null and run_upgrade_manager.has_method("get_vehicle_passive_data"):
		return run_upgrade_manager.get_vehicle_passive_data(vehicle_id)
	var helicopter_skins := _get_helicopter_skins()
	var passive_id := "flexible_baseline"
	if helicopter_skins != null and helicopter_skins.has_method("get_vehicle_profile"):
		passive_id = str(helicopter_skins.get_vehicle_profile(vehicle_id).get("passive_id", passive_id))
	return {
		"passive_id": passive_id,
		"name": _format_passive_id(passive_id),
		"modifiers": {},
	}

func _format_passive_id(passive_id: String) -> String:
	var words := passive_id.replace("_", " ").split(" ", false)
	var formatted: Array[String] = []
	for word in words:
		formatted.append(word.capitalize())
	return " ".join(formatted)

func _get_selected_vehicle_skin(player_profile: Node, vehicle_id: String) -> String:
	if player_profile != null and player_profile.has_method("get_equipped_vehicle_skin_id"):
		return str(player_profile.get_equipped_vehicle_skin_id(vehicle_id))
	return "factory"

func _mark_lore_seen() -> void:
	var player_profile := _get_player_profile()
	if player_profile == null:
		return
	if player_profile.has_method("mark_vehicle_lore_seen"):
		player_profile.mark_vehicle_lore_seen(_selected_vehicle_id)
	if player_profile.has_method("mark_skin_lore_seen"):
		player_profile.mark_skin_lore_seen(_selected_vehicle_id, _selected_skin_id)

func _on_back_pressed() -> void:
	_play_ui_tap()
	get_tree().change_scene_to_file(START_SCREEN_SCENE_PATH)

func _on_equip_vehicle_pressed() -> void:
	var player_profile := _get_player_profile()
	if player_profile == null:
		return
	if player_profile.equip_vehicle(_selected_vehicle_id):
		_play_ui_tap()
		_refresh_view()

func _on_equip_skin_pressed() -> void:
	var player_profile := _get_player_profile()
	if player_profile == null:
		return
	if player_profile.equip_vehicle_skin(_selected_vehicle_id, _selected_skin_id):
		_play_ui_tap()
		_refresh_view()

func _on_profile_changed(_summary: Dictionary) -> void:
	var player_profile := _get_player_profile()
	if player_profile != null and not player_profile.is_vehicle_unlocked(_selected_vehicle_id):
		_selected_skin_id = "factory"
	else:
		_selected_skin_id = _get_selected_vehicle_skin(player_profile, _selected_vehicle_id)
	_refresh_view()

func _get_player_profile() -> Node:
	return get_node_or_null("/root/PlayerProfile")

func _get_helicopter_skins() -> Node:
	return get_node_or_null("/root/HelicopterSkins")

func _play_ui_tap() -> void:
	var haptics_manager := get_node_or_null("/root/HapticsManager")
	if haptics_manager != null and haptics_manager.has_method("play"):
		haptics_manager.play("ui_tap")

func _configure_touch_scroll() -> void:
	for scroll in [vehicle_list_scroll, skin_list_scroll]:
		if scroll == null:
			continue
		scroll.scroll_deadzone = int(TOUCH_SCROLL_DEADZONE)
	vehicle_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		var touched_scroll := _get_scroll_at_position(position)
		if touched_scroll == null or not _can_scroll_content(touched_scroll):
			return
		_active_scroll = touched_scroll
		_scroll_pointer_active = true
		_scroll_dragging = false
		_scroll_pointer_id = pointer_id
		_scroll_press_position = position
		_scroll_origin = float(touched_scroll.scroll_vertical)
		return
	if _scroll_pointer_active and _scroll_pointer_id == pointer_id:
		if _scroll_dragging:
			get_viewport().set_input_as_handled()
		_reset_touch_scroll_state()

func _handle_scroll_drag(position: Vector2, pointer_id: int) -> void:
	if not _scroll_pointer_active or _scroll_pointer_id != pointer_id or _active_scroll == null:
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
		_active_scroll.scroll_vertical = int(round(next_scroll))
		get_viewport().set_input_as_handled()

func _get_scroll_at_position(position: Vector2) -> ScrollContainer:
	for scroll in [vehicle_list_scroll, skin_list_scroll]:
		if scroll != null and scroll.get_global_rect().has_point(position):
			return scroll
	return null

func _can_scroll_content(scroll: ScrollContainer) -> bool:
	var scroll_bar := scroll.get_v_scroll_bar()
	return scroll_bar != null and scroll_bar.max_value > 0.0

func _reset_touch_scroll_state() -> void:
	_active_scroll = null
	_scroll_pointer_active = false
	_scroll_dragging = false
	_scroll_pointer_id = -1
	_scroll_press_position = Vector2.ZERO
	_scroll_origin = 0.0

func get_preview_state() -> Dictionary:
	return {
		"vehicle_id": _selected_vehicle_id,
		"skin_id": _selected_skin_id,
		"position": preview_sprite.position if preview_sprite != null else Vector2.ZERO,
		"scale": preview_sprite.scale if preview_sprite != null else Vector2.ZERO,
	}

func get_vehicle_stats_text() -> String:
	return vehicle_stats_label.text if vehicle_stats_label != null else ""

func _join_non_empty_lines(lines: Array[String]) -> String:
	var filtered: Array[String] = []
	for line in lines:
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			filtered.append(trimmed)
	return "\n".join(filtered)

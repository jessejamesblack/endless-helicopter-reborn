extends Control

const MISSION_SCREEN_SCENE_PATH := "res://scenes/ui/missions/mission_screen.tscn"
const PREVIEW_CENTER := Vector2(146, 96)
const PREVIEW_SCALE_MULTIPLIER := 1.6

var _selected_skin_id: String = "default_scout"

@onready var preview_sprite: Sprite2D = $Panel/MarginContainer/VBoxContainer/ContentRow/PreviewCard/PreviewMargin/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewSprite
@onready var skin_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentRow/SkinListCard/SkinListScroll/SkinList
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionCard/DescriptionLabel
@onready var requirement_label: Label = $Panel/MarginContainer/VBoxContainer/RequirementLabel
@onready var equip_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/EquipButton

func _ready() -> void:
	var music_player = get_node_or_null("/root/MusicPlayer")
	if music_player != null and music_player.has_method("play_menu_music"):
		music_player.play_menu_music()

	$Panel/MarginContainer/VBoxContainer/ButtonRow/BackButton.pressed.connect(_on_back_pressed)
	equip_button.pressed.connect(_on_equip_pressed)

	var player_profile: Node = _get_player_profile()
	if player_profile != null and player_profile.has_signal("profile_changed"):
		var callback := Callable(self, "_on_profile_changed")
		if not player_profile.is_connected("profile_changed", callback):
			player_profile.connect("profile_changed", callback)

	var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
	if sync_queue != null and sync_queue.has_method("flush"):
		sync_queue.flush()
	if player_profile != null and player_profile.has_method("refresh_top_player_skin_access"):
		player_profile.refresh_top_player_skin_access()

	_selected_skin_id = player_profile.get_equipped_skin_id() if player_profile != null and player_profile.has_method("get_equipped_skin_id") else "default_scout"
	_refresh_view()

func _refresh_view() -> void:
	_render_skin_list()
	_update_preview()
	_update_selection_details()

func _render_skin_list() -> void:
	for child in skin_list.get_children():
		child.queue_free()

	var helicopter_skins: Node = _get_helicopter_skins()
	var player_profile: Node = _get_player_profile()
	if helicopter_skins == null or player_profile == null:
		return

	for skin_id in helicopter_skins.get_skin_ids():
		skin_list.add_child(_create_skin_button(skin_id, player_profile, helicopter_skins))

func _create_skin_button(skin_id: String, player_profile: Node, helicopter_skins: Node) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = _build_skin_button_text(skin_id, player_profile, helicopter_skins)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.564706, 1))
	button.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
	button.add_theme_constant_override("outline_size", 2)
	button.pressed.connect(func() -> void:
		_selected_skin_id = skin_id
		_update_preview()
		_update_selection_details()
	)
	return button

func _build_skin_button_text(skin_id: String, player_profile: Node, helicopter_skins: Node) -> String:
	var label: String = helicopter_skins.get_display_name(skin_id)
	var has_access: bool = player_profile.has_skin_access(skin_id) if player_profile.has_method("has_skin_access") else player_profile.is_skin_unlocked(skin_id)
	if has_access:
		if player_profile.get_equipped_skin_id() == skin_id:
			return "%s  -  Equipped" % label
		return "%s  -  Unlocked" % label
	return "%s  -  Locked" % label

func _update_preview() -> void:
	var helicopter_skins: Node = _get_helicopter_skins()
	if helicopter_skins == null or preview_sprite == null:
		return

	preview_sprite.rotation = 0.0
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	helicopter_skins.apply_skin_to_sprite(preview_sprite, _selected_skin_id)
	var data: Dictionary = helicopter_skins.get_skin_data(_selected_skin_id)
	var base_scale := preview_sprite.scale
	var offset: Vector2 = data.get("offset", Vector2.ZERO)
	preview_sprite.scale = base_scale * PREVIEW_SCALE_MULTIPLIER
	preview_sprite.position = PREVIEW_CENTER + offset * 4.0

func _update_selection_details() -> void:
	var helicopter_skins: Node = _get_helicopter_skins()
	var player_profile: Node = _get_player_profile()
	if helicopter_skins == null or player_profile == null:
		return

	var data: Dictionary = helicopter_skins.get_skin_data(_selected_skin_id)
	description_label.text = "%s\n\n%s" % [
		str(data.get("display_name", "Scout")),
		str(data.get("description", "")),
	]

	var unlocked: bool = player_profile.has_skin_access(_selected_skin_id) if player_profile.has_method("has_skin_access") else player_profile.is_skin_unlocked(_selected_skin_id)
	var equipped: bool = player_profile.get_equipped_skin_id() == _selected_skin_id
	requirement_label.text = str(data.get("unlock_requirement", "Unlocked by default."))

	if not unlocked:
		equip_button.text = "LOCKED"
		equip_button.disabled = true
	elif equipped:
		equip_button.text = "EQUIPPED"
		equip_button.disabled = true
	else:
		equip_button.text = "EQUIP"
		equip_button.disabled = false

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MISSION_SCREEN_SCENE_PATH)

func _on_equip_pressed() -> void:
	var player_profile: Node = _get_player_profile()
	if player_profile == null:
		return

	if player_profile.equip_skin(_selected_skin_id):
		var sync_queue := get_node_or_null("/root/SupabaseSyncQueue")
		if sync_queue != null and sync_queue.has_method("flush"):
			sync_queue.flush()
		_refresh_view()

func _on_profile_changed(_summary: Dictionary) -> void:
	_refresh_view()

func _get_player_profile() -> Node:
	return get_node_or_null("/root/PlayerProfile")

func _get_helicopter_skins() -> Node:
	return get_node_or_null("/root/HelicopterSkins")

func get_preview_state() -> Dictionary:
	return {
		"skin_id": _selected_skin_id,
		"position": preview_sprite.position if preview_sprite != null else Vector2.ZERO,
		"scale": preview_sprite.scale if preview_sprite != null else Vector2.ZERO,
	}

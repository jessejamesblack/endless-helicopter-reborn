extends Control

signal upgrade_selected(upgrade_id: String)

const PANEL_DESIRED_SIZE := Vector2(680.0, 340.0)
const FOUR_CARD_PANEL_DESIRED_SIZE := Vector2(820.0, 340.0)
const PANEL_MARGIN := 24.0

@onready var panel: Panel = $Overlay/Panel
@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var card_row: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/CardRow

var _offers: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_fit_panel_to_viewport()
	get_viewport().size_changed.connect(_fit_panel_to_viewport)

func open_choice(offers: Array[Dictionary], reason: String = "milestone") -> void:
	_offers = offers.duplicate(true)
	visible = true
	title_label.text = "Choose An Upgrade"
	subtitle_label.text = "Milestone reward" if reason == "milestone" else "Run reward"
	_fit_panel_to_viewport()
	_render_cards()

func close_choice() -> void:
	visible = false
	for child in card_row.get_children():
		child.queue_free()

func _render_cards() -> void:
	for child in card_row.get_children():
		child.queue_free()

	var compact_cards := _offers.size() >= 4
	card_row.add_theme_constant_override("separation", 8 if compact_cards else 12)
	for offer in _offers:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150 if compact_cards else 184, 170)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _format_offer_text(offer)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14 if compact_cards else 16)
		button.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.564706, 1))
		button.add_theme_color_override("font_focus_color", Color(1, 0.92549, 0.705882, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 0.92549, 0.705882, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 0.94902, 0.8, 1))
		button.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
		button.add_theme_constant_override("outline_size", 3)
		button.add_theme_stylebox_override("normal", _create_button_style(false, false))
		button.add_theme_stylebox_override("hover", _create_button_style(true, false))
		button.add_theme_stylebox_override("focus", _create_button_style(true, false))
		button.add_theme_stylebox_override("pressed", _create_button_style(false, true))
		var upgrade_id := str(offer.get("id", ""))
		button.pressed.connect(func() -> void:
			upgrade_selected.emit(upgrade_id)
		)
		card_row.add_child(button)

func _format_offer_text(offer: Dictionary) -> String:
	var level_text := ""
	var max_level := int(offer.get("max_level", 1))
	if max_level > 1:
		level_text = "\nLv %d/%d" % [int(offer.get("level", 1)), max_level]
	return "%s%s\n\n%s" % [
		str(offer.get("name", "Upgrade")),
		level_text,
		str(offer.get("description", "")),
	]

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return

	var viewport_size := get_viewport_rect().size
	var max_size := Vector2(
		max(280.0, viewport_size.x - PANEL_MARGIN * 2.0),
		max(260.0, viewport_size.y - PANEL_MARGIN * 2.0)
	)
	var desired_size := FOUR_CARD_PANEL_DESIRED_SIZE if _offers.size() >= 4 else PANEL_DESIRED_SIZE
	var target_size := Vector2(
		min(desired_size.x, max_size.x),
		min(desired_size.y, max_size.y)
	)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

func _create_button_style(is_hover: bool, is_pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105882, 0.156863, 0.27451, 0.98) if is_hover else Color(0.0705882, 0.105882, 0.196078, 0.95)
	if is_pressed:
		style.bg_color = Color(0.0392157, 0.0745098, 0.14902, 0.98)
	style.border_width_left = 2
	style.border_width_top = 3 if is_pressed else 2
	style.border_width_right = 2
	style.border_width_bottom = 1 if is_pressed else 2
	style.border_color = Color(0.964706, 0.788235, 0.403922, 0.95) if is_pressed else Color(0.560784, 0.807843, 0.988235, 1.0) if is_hover else Color(0.360784, 0.611765, 0.858824, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0 if is_pressed else 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 6.0 if is_pressed else 8.0
	return style

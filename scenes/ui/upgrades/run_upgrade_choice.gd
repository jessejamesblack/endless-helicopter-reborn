extends Control

signal upgrade_selected(upgrade_id: String)

@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var card_row: HBoxContainer = $Overlay/Panel/MarginContainer/VBoxContainer/CardRow

var _offers: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open_choice(offers: Array[Dictionary], reason: String = "milestone") -> void:
	_offers = offers.duplicate(true)
	visible = true
	title_label.text = "Choose An Upgrade"
	subtitle_label.text = "Milestone reward" if reason == "milestone" else "Run reward"
	_render_cards()

func close_choice() -> void:
	visible = false
	for child in card_row.get_children():
		child.queue_free()

func _render_cards() -> void:
	for child in card_row.get_children():
		child.queue_free()

	for offer in _offers:
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 178)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _format_offer_text(offer)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color(0.952941, 0.835294, 0.564706, 1))
		button.add_theme_color_override("font_outline_color", Color(0.0156863, 0.0313726, 0.0823529, 1))
		button.add_theme_constant_override("outline_size", 2)
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

extends Control

const BuildInfoScript = preload("res://systems/build_info.gd")

@onready var title_label: Label = $SafeArea/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $SafeArea/Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var details_label: Label = $SafeArea/Panel/MarginContainer/VBoxContainer/DetailsLabel
@onready var footer_label: Label = $SafeArea/Panel/MarginContainer/VBoxContainer/FooterLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(item: Dictionary) -> void:
	title_label.text = str(item.get("title", "Achievement unlocked"))
	description_label.text = str(item.get("description", ""))
	details_label.text = _build_details_text(item.get("details", {}) as Dictionary)
	footer_label.text = "Endless Helicopter Reborn • %s" % BuildInfoScript.get_version_label()

func _build_details_text(details: Dictionary) -> String:
	if details.is_empty():
		return "Family sprint highlight"
	var lines := PackedStringArray()
	for key_variant in details.keys():
		lines.append("%s: %s" % [str(key_variant).capitalize().replace("_", " "), str(details[key_variant])])
	return "\n".join(lines)

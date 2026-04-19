extends Control

signal closed

@onready var title_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var details_label: Label = $Overlay/Panel/MarginContainer/VBoxContainer/DetailsLabel
@onready var release_notes_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/ReleaseNotesButton
@onready var later_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/LaterButton
@onready var update_button: Button = $Overlay/Panel/MarginContainer/VBoxContainer/ButtonRow/UpdateButton

var _state: Dictionary = {}

func _ready() -> void:
	visible = false
	release_notes_button.pressed.connect(_on_release_notes_pressed)
	later_button.pressed.connect(_on_later_pressed)
	update_button.pressed.connect(_on_update_pressed)

func open_for_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	var release_info := _state.get("release_info", {}) as Dictionary
	var required := bool(_state.get("required", false))
	title_label.text = "Update Required" if required else "Update Available"
	description_label.text = str(_state.get("force_message", "")) if required else str(_state.get("message", "A new build is ready."))
	details_label.text = "Current: %s (%d)\nLatest: %s (%d)\nChannel: %s" % [
		str(_state.get("current_version_name", "")),
		int(_state.get("current_version_code", 0)),
		str(release_info.get("latest_version_name", "unknown")),
		int(release_info.get("latest_version_code", 0)),
		str(_state.get("channel", "")),
	]
	later_button.visible = not required
	release_notes_button.visible = not str(release_info.get("release_notes_url", "")).strip_edges().is_empty()
	visible = true
	update_button.grab_focus()

func close_prompt() -> void:
	visible = false
	closed.emit()

func _on_release_notes_pressed() -> void:
	var release_info := _state.get("release_info", {}) as Dictionary
	var url := str(release_info.get("release_notes_url", release_info.get("release_page_url", ""))).strip_edges()
	if not url.is_empty():
		OS.shell_open(url)

func _on_later_pressed() -> void:
	close_prompt()

func _on_update_pressed() -> void:
	var release_info := _state.get("release_info", {}) as Dictionary
	var url := str(release_info.get("apk_download_url", release_info.get("release_page_url", ""))).strip_edges()
	if not url.is_empty():
		OS.shell_open(url)
	if not bool(_state.get("required", false)):
		close_prompt()

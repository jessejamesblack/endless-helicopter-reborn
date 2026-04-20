extends VBoxContainer

signal play_offline_requested()

@export var allow_play_offline: bool = false

@onready var header_label: Label = $AccountHeader
@onready var status_label: Label = $AccountStatusLabel
@onready var email_entry: LineEdit = $EmailEntry
@onready var code_entry: LineEdit = $CodeEntry
@onready var action_row: HBoxContainer = $ActionRow
@onready var send_code_button: Button = $ActionRow/SendCodeButton
@onready var verify_code_button: Button = $ActionRow/VerifyCodeButton
@onready var secondary_row: HBoxContainer = $SecondaryRow
@onready var play_offline_button: Button = $SecondaryRow/PlayOfflineButton
@onready var sign_out_button: Button = $SecondaryRow/SignOutButton

func _ready() -> void:
	send_code_button.pressed.connect(_on_send_code_pressed)
	verify_code_button.pressed.connect(_on_verify_code_pressed)
	play_offline_button.pressed.connect(_on_play_offline_pressed)
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	email_entry.text_submitted.connect(_on_email_submitted)
	code_entry.text_submitted.connect(_on_code_submitted)

	var account_manager = _get_account_manager()
	if account_manager != null and account_manager.has_signal("account_state_changed"):
		var callback := Callable(self, "_on_account_state_changed")
		if not account_manager.is_connected("account_state_changed", callback):
			account_manager.connect("account_state_changed", callback)

	_refresh_from_state()

func _on_account_state_changed(_summary: Dictionary) -> void:
	_refresh_from_state()

func _refresh_from_state() -> void:
	var summary := _get_account_summary()
	var signed_in := bool(summary.get("signed_in", false))
	var linked := bool(summary.get("linked", false))
	var request_busy := bool(summary.get("request_in_flight", false))
	var busy := request_busy or bool(summary.get("bootstrap_in_progress", false))
	var pending_email := str(summary.get("pending_email", "")).strip_edges()
	var email := str(summary.get("email", "")).strip_edges().to_lower()
	var status_text := str(summary.get("status_text", "")).strip_edges()
	var claimable_local_profile := bool(summary.get("local_profile_claimable", false))

	header_label.text = "Account"
	if linked:
		status_label.text = "Connected as %s\nProgress backup active." % email
	elif signed_in:
		status_label.text = "Connected as %s\n%s" % [email, status_text if not status_text.is_empty() else "This device is still using local progress until a profile is linked."]
	elif claimable_local_profile:
		status_label.text = "Protect your progress\nLink an email so this profile restores after reinstall or on a new device."
	else:
		status_label.text = "Quick email backup\nLink an email now, or keep playing offline."

	email_entry.visible = not signed_in
	action_row.visible = not signed_in
	code_entry.visible = not signed_in and not pending_email.is_empty()
	verify_code_button.visible = not signed_in and not pending_email.is_empty()
	play_offline_button.visible = allow_play_offline and not signed_in
	sign_out_button.visible = signed_in

	if not email_entry.has_focus() and not signed_in:
		email_entry.text = pending_email if not pending_email.is_empty() else email_entry.text.strip_edges().to_lower()
	if not code_entry.has_focus():
		code_entry.placeholder_text = "Enter email code"

	email_entry.editable = not busy and not signed_in
	code_entry.editable = not busy and not signed_in
	send_code_button.disabled = busy or signed_in
	verify_code_button.disabled = busy or signed_in
	play_offline_button.disabled = busy and not signed_in
	sign_out_button.disabled = busy
	send_code_button.text = "Sending..." if request_busy and not signed_in and pending_email.is_empty() else "Continue with Email"
	verify_code_button.text = "Verifying..." if request_busy and not signed_in and not pending_email.is_empty() else "Verify Code"

func _on_send_code_pressed() -> void:
	call_deferred("_send_code_async")

func _on_verify_code_pressed() -> void:
	call_deferred("_verify_code_async")

func _on_play_offline_pressed() -> void:
	play_offline_requested.emit()

func _on_sign_out_pressed() -> void:
	var account_manager = _get_account_manager()
	if account_manager != null and account_manager.has_method("sign_out"):
		account_manager.sign_out()

func _on_email_submitted(_text: String) -> void:
	call_deferred("_send_code_async")

func _on_code_submitted(_text: String) -> void:
	call_deferred("_verify_code_async")

func _send_code_async() -> void:
	var account_manager = _get_account_manager()
	if account_manager == null or not account_manager.has_method("send_email_otp_async"):
		return
	await account_manager.send_email_otp_async(email_entry.text)
	_refresh_from_state()
	if code_entry.visible:
		code_entry.grab_focus()

func _verify_code_async() -> void:
	var account_manager = _get_account_manager()
	if account_manager == null or not account_manager.has_method("verify_email_otp_async"):
		return
	var email := email_entry.text.strip_edges().to_lower()
	if email.is_empty() and account_manager.has_method("get_pending_email"):
		email = str(account_manager.get_pending_email())
	await account_manager.verify_email_otp_async(email, code_entry.text)
	_refresh_from_state()

func _get_account_summary() -> Dictionary:
	var account_manager = _get_account_manager()
	if account_manager == null or not account_manager.has_method("get_state_summary"):
		return {}
	return account_manager.get_state_summary()

func _get_account_manager():
	return get_node_or_null("/root/AccountManager")

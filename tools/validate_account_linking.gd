extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")
const START_SCREEN_SCENE := preload("res://scenes/ui/start_screen/start_screen.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings/settings_menu.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var account_manager := get_root().get_node_or_null("AccountManager")
	_assert(account_manager != null, "AccountManager autoload should exist.")
	if account_manager != null:
		_assert(account_manager.has_method("send_email_otp_async"), "AccountManager should expose email OTP send flow.")
		_assert(account_manager.has_method("verify_email_otp_async"), "AccountManager should expose OTP verification flow.")
		_assert(account_manager.has_method("get_state_summary"), "AccountManager should expose account state summary.")

	Helper.assert_file_exists(_failures, "res://systems/account_manager.gd")
	Helper.assert_file_exists(_failures, "res://backend/supabase_account_linking_setup.sql")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/_shared/account_linking.ts")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/link-account-profile/index.ts")
	Helper.assert_file_exists(_failures, "res://backend/supabase/functions/get-account-profile/index.ts")
	Helper.assert_file_exists(_failures, "res://scenes/ui/account/account_panel.tscn")
	Helper.assert_file_exists(_failures, "res://scenes/ui/account/account_panel.gd")

	var account_sql := Helper.read_text("res://backend/supabase_account_linking_setup.sql")
	_assert(account_sql.contains("player_account_links"), "Account linking SQL should create the player_account_links table.")
	_assert(account_sql.contains("auth.users"), "Account linking SQL should reference Supabase auth.users.")
	_assert(account_sql.contains("enable row level security"), "Account linking SQL should keep RLS enabled.")

	var helper_text := Helper.read_text("res://backend/supabase/functions/_shared/account_linking.ts")
	_assert(helper_text.contains("resolvePlayerContext"), "Account linking helper should resolve canonical player context.")
	_assert(helper_text.contains("getAuthenticatedUser"), "Account linking helper should authenticate Supabase users.")

	var online_text := Helper.read_text("res://systems/online_leaderboard.gd")
	_assert(online_text.contains("PLAYER_ID_SOURCE_LINKED_ACCOUNT"), "OnlineLeaderboard should expose a linked-account identity source.")
	_assert(online_text.contains("get_account_profile_url"), "OnlineLeaderboard should expose the get-account-profile endpoint.")
	_assert(online_text.contains("get_link_account_profile_url"), "OnlineLeaderboard should expose the link-account-profile endpoint.")
	_assert(online_text.contains("AccountManager"), "OnlineLeaderboard should be able to read account session state.")

	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(start_screen)
	await process_frame
	await process_frame
	_assert(start_screen.get_node_or_null("AccountCard/AccountMargin/AccountPanel") != null, "Start screen should expose the account panel.")
	start_screen.free()
	await process_frame

	var settings_menu := SETTINGS_MENU_SCENE.instantiate() as Control
	get_root().add_child(settings_menu)
	await process_frame
	await process_frame
	_assert(settings_menu.get_node_or_null("Overlay/Panel/MarginContainer/VBoxContainer/ContentScroll/ContentColumns/AudioCard/AudioColumn/AccountSection") != null, "Settings should expose the account panel.")
	settings_menu.free()
	await process_frame

	Helper.finish(self, _failures, "Account linking validation completed successfully.")

func _assert(condition: bool, message: String) -> void:
	Helper.assert_condition(_failures, condition, message)

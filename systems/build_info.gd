extends RefCounted
class_name BuildInfo

const VERSION_CODE := 160
const VERSION_NAME := "1.6.6"
const BUILD_SHA := "dev"
const BUILD_DATE := "2026-04-20T00:00:00Z"
const RELEASE_CHANNEL := "dev"
const APP_PACKAGE_NAME := "com.jessejamesblack.endlesshelicopterreborn"
const SIGNING_MODE := "local_unspecified"

static func get_summary() -> Dictionary:
	return {
		"version_code": VERSION_CODE,
		"version_name": VERSION_NAME,
		"build_sha": BUILD_SHA,
		"build_date": BUILD_DATE,
		"release_channel": RELEASE_CHANNEL,
		"app_package_name": APP_PACKAGE_NAME,
		"signing_mode": SIGNING_MODE,
	}

static func get_version_label() -> String:
	return "%s (%d)" % [VERSION_NAME, VERSION_CODE]

static func get_signing_label() -> String:
	match SIGNING_MODE:
		"release_stable":
			return "Stable release key"
		"debug_stable":
			return "Stable debug key"
		"temporary_debug":
			return "Temporary debug key"
		"local_unspecified":
			return "Local/unspecified key"
	return SIGNING_MODE.replace("_", " ").capitalize()

static func is_identity_continuity_safe() -> bool:
	return SIGNING_MODE == "release_stable" or SIGNING_MODE == "debug_stable"

static func get_debug_label() -> String:
	return "%s | %s | %s | %s" % [get_version_label(), BUILD_SHA, RELEASE_CHANNEL, SIGNING_MODE]

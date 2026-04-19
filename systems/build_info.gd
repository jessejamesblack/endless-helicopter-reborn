extends RefCounted
class_name BuildInfo

const VERSION_CODE := 154
const VERSION_NAME := "1.6.0"
const BUILD_SHA := "dev"
const BUILD_DATE := "2026-04-19T00:00:00Z"
const RELEASE_CHANNEL := "dev"

static func get_summary() -> Dictionary:
	return {
		"version_code": VERSION_CODE,
		"version_name": VERSION_NAME,
		"build_sha": BUILD_SHA,
		"build_date": BUILD_DATE,
		"release_channel": RELEASE_CHANNEL,
	}

static func get_version_label() -> String:
	return "%s (%d)" % [VERSION_NAME, VERSION_CODE]

static func get_debug_label() -> String:
	return "%s | %s | %s" % [get_version_label(), BUILD_SHA, RELEASE_CHANNEL]

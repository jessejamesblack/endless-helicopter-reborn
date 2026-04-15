@tool
extends EditorExportPlugin

const AAR_DEBUG_PATH := "addons/fcm_push_bridge/libs/FcmPushBridge-debug.aar"
const AAR_RELEASE_PATH := "addons/fcm_push_bridge/libs/FcmPushBridge-release.aar"
const MAVEN_REPOS = [
	"https://dl.google.com/dl/android/maven2/",
	"https://repo.maven.apache.org/maven2/",
]
const ANDROID_DEPENDENCIES = [
	"androidx.core:core-ktx:1.13.1",
	"androidx.lifecycle:lifecycle-process:2.8.7",
	"com.google.firebase:firebase-messaging:24.1.0",
	"org.jetbrains.kotlin:kotlin-stdlib:2.1.0",
]

func _get_name() -> String:
	return "FCMPushBridge"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var library_path := AAR_DEBUG_PATH if debug else AAR_RELEASE_PATH
	var resource_path := "res://%s" % library_path
	if not FileAccess.file_exists(resource_path):
		push_warning("FCM Push Bridge AAR not found at %s. Build the Android plugin before exporting." % resource_path)
		return PackedStringArray()
	return PackedStringArray([library_path])

func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(ANDROID_DEPENDENCIES)

func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(MAVEN_REPOS)

class_name AndroidIdentity
extends RefCounted

const PLUGIN_SINGLETON := "FCMPushBridge"
const ANDROID_RUNTIME_SINGLETON := "AndroidRuntime"
const JAVA_CLASS_WRAPPER_SINGLETON := "JavaClassWrapper"
const COMPAT_BRIDGE_CLASS := "com.endlesshelicopter.push.FcmPushBridgeCompat"

const PLAYER_ID_CACHE_PATH := "user://player_id.save"
const PLAYER_ID_SOURCE_CACHE_PATH := "user://player_id_source.save"
const DEVICE_ID_CACHE_PATH := "user://push_device_id.save"
const DEVICE_ID_SOURCE_CACHE_PATH := "user://push_device_id_source.save"

const IDENTITY_SOURCE_LEGACY_CACHE := "legacy_cache"
const IDENTITY_SOURCE_ANDROID_STABLE := "android_stable"
const IDENTITY_SOURCE_LOCAL_FALLBACK := "local_fallback"

const PLAYER_ID_PREFIX := "android-player-"
const DEVICE_ID_PREFIX := "android-device-"

static func load_or_create_player_id() -> String:
	var resolved := _load_or_create_identity(
		PLAYER_ID_CACHE_PATH,
		PLAYER_ID_SOURCE_CACHE_PATH,
		PLAYER_ID_PREFIX,
		PackedStringArray(["getStablePlayerId", "get_stable_player_id"])
	)
	return str(resolved["value"])

static func load_or_create_device_id() -> String:
	var resolved := _load_or_create_identity(
		DEVICE_ID_CACHE_PATH,
		DEVICE_ID_SOURCE_CACHE_PATH,
		DEVICE_ID_PREFIX,
		PackedStringArray(["getStableDeviceId", "get_stable_device_id"])
	)
	return str(resolved["value"])

static func get_player_identity_source() -> String:
	return _peek_identity_source(
		PLAYER_ID_CACHE_PATH,
		PLAYER_ID_SOURCE_CACHE_PATH,
		PLAYER_ID_PREFIX,
		PackedStringArray(["getStablePlayerId", "get_stable_player_id"])
	)

static func get_device_identity_source() -> String:
	return _peek_identity_source(
		DEVICE_ID_CACHE_PATH,
		DEVICE_ID_SOURCE_CACHE_PATH,
		DEVICE_ID_PREFIX,
		PackedStringArray(["getStableDeviceId", "get_stable_device_id"])
	)

static func get_cached_device_id_for_debug() -> String:
	if not FileAccess.file_exists(DEVICE_ID_CACHE_PATH):
		return "(not created yet)"

	var file := FileAccess.open(DEVICE_ID_CACHE_PATH, FileAccess.READ)
	if file == null:
		return "(unreadable)"

	var device_id := file.get_as_text().strip_edges()
	if device_id.is_empty():
		return "(empty)"
	return device_id

static func _load_or_create_identity(cache_path: String, source_path: String, stable_prefix: String, stable_method_names: PackedStringArray) -> Dictionary:
	var cached_value := _read_cached_value(cache_path)
	if not cached_value.is_empty():
		var existing_source := _read_cached_value(source_path)
		if existing_source.is_empty():
			existing_source = _infer_cached_source(cached_value, stable_prefix)
			_write_cached_value(source_path, existing_source)
		return {
			"value": cached_value,
			"source": existing_source,
		}

	var stable_value := _resolve_android_stable_id(stable_method_names)
	if not stable_value.is_empty():
		_write_cached_value(cache_path, stable_value)
		_write_cached_value(source_path, IDENTITY_SOURCE_ANDROID_STABLE)
		return {
			"value": stable_value,
			"source": IDENTITY_SOURCE_ANDROID_STABLE,
		}

	var fallback_value := _generate_random_id()
	_write_cached_value(cache_path, fallback_value)
	_write_cached_value(source_path, IDENTITY_SOURCE_LOCAL_FALLBACK)
	return {
		"value": fallback_value,
		"source": IDENTITY_SOURCE_LOCAL_FALLBACK,
	}

static func _peek_identity_source(cache_path: String, source_path: String, stable_prefix: String, stable_method_names: PackedStringArray) -> String:
	var cached_value := _read_cached_value(cache_path)
	if not cached_value.is_empty():
		var existing_source := _read_cached_value(source_path)
		if not existing_source.is_empty():
			return existing_source
		return _infer_cached_source(cached_value, stable_prefix)

	var stable_value := _resolve_android_stable_id(stable_method_names)
	if not stable_value.is_empty():
		return IDENTITY_SOURCE_ANDROID_STABLE
	return IDENTITY_SOURCE_LOCAL_FALLBACK

static func _infer_cached_source(cached_value: String, stable_prefix: String) -> String:
	if cached_value.begins_with(stable_prefix):
		return IDENTITY_SOURCE_ANDROID_STABLE
	if OS.get_name() != "Android":
		return IDENTITY_SOURCE_LOCAL_FALLBACK
	return IDENTITY_SOURCE_LEGACY_CACHE

static func _resolve_android_stable_id(method_names: PackedStringArray) -> String:
	if OS.get_name() != "Android":
		return ""

	var compat_bridge = _get_compat_bridge()
	if compat_bridge != null:
		var context = _get_android_context()
		for method_name in method_names:
			if compat_bridge.has_method(method_name):
				var compat_value = str(
					compat_bridge.callv(method_name, [context]) if context != null else compat_bridge.callv(method_name, [])
				).strip_edges()
				if not compat_value.is_empty():
					return compat_value

	var plugin = _get_plugin_singleton()
	if plugin != null:
		for method_name in method_names:
			if plugin.has_method(method_name):
				var plugin_value := str(plugin.callv(method_name, [])).strip_edges()
				if not plugin_value.is_empty():
					return plugin_value

	return ""

static func _get_plugin_singleton():
	if Engine.has_singleton(PLUGIN_SINGLETON):
		return Engine.get_singleton(PLUGIN_SINGLETON)
	return null

static func _get_android_runtime():
	if Engine.has_singleton(ANDROID_RUNTIME_SINGLETON):
		return Engine.get_singleton(ANDROID_RUNTIME_SINGLETON)
	return null

static func _get_java_class_wrapper():
	if Engine.has_singleton(JAVA_CLASS_WRAPPER_SINGLETON):
		return Engine.get_singleton(JAVA_CLASS_WRAPPER_SINGLETON)
	return null

static func _get_compat_bridge():
	var java_class_wrapper = _get_java_class_wrapper()
	if java_class_wrapper != null and java_class_wrapper.has_method("wrap"):
		return java_class_wrapper.wrap(COMPAT_BRIDGE_CLASS)
	return null

static func _get_android_context():
	var android_runtime = _get_android_runtime()
	if android_runtime != null and android_runtime.has_method("getApplicationContext"):
		var application_context = android_runtime.getApplicationContext()
		if application_context != null:
			return application_context

	if android_runtime != null and android_runtime.has_method("getActivity"):
		var activity = android_runtime.getActivity()
		if activity != null and activity.has_method("getApplicationContext"):
			return activity.getApplicationContext()

	return null

static func _read_cached_value(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	return file.get_as_text().strip_edges()

static func _write_cached_value(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)

static func _generate_random_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%08x" % [int(Time.get_unix_time_from_system()), rng.randi()]

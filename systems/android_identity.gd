class_name AndroidIdentity
extends RefCounted

const BuildInfoScript = preload("res://systems/build_info.gd")
const PLUGIN_SINGLETON := "FCMPushBridge"
const ANDROID_RUNTIME_SINGLETON := "AndroidRuntime"
const JAVA_CLASS_WRAPPER_SINGLETON := "JavaClassWrapper"
const COMPAT_BRIDGE_CLASS := "com.endlesshelicopter.push.FcmPushBridgeCompat"
const SETTINGS_SECURE_CLASS := "android.provider.Settings$Secure"

const PLAYER_ID_CACHE_PATH := "user://player_id.save"
const PLAYER_ID_SOURCE_CACHE_PATH := "user://player_id_source.save"
const DEVICE_ID_CACHE_PATH := "user://push_device_id.save"
const DEVICE_ID_SOURCE_CACHE_PATH := "user://push_device_id_source.save"

const IDENTITY_SOURCE_LEGACY_CACHE := "legacy_cache"
const IDENTITY_SOURCE_ANDROID_STABLE := "android_stable"
const IDENTITY_SOURCE_ANDROID_PENDING := "android_pending"
const IDENTITY_SOURCE_LOCAL_FALLBACK := "local_fallback"

const PLAYER_ID_PREFIX := "android-player-"
const DEVICE_ID_PREFIX := "android-device-"
const INVALID_ANDROID_ID := "9774d56d682e549c"

static func load_or_create_player_id() -> String:
	var resolved := get_player_identity_info()
	_persist_resolved_identity_if_needed(resolved, PLAYER_ID_CACHE_PATH, PLAYER_ID_SOURCE_CACHE_PATH)
	return str(resolved.get("value", ""))

static func load_or_create_device_id() -> String:
	var resolved := get_device_identity_info()
	_persist_resolved_identity_if_needed(resolved, DEVICE_ID_CACHE_PATH, DEVICE_ID_SOURCE_CACHE_PATH)
	return str(resolved.get("value", ""))

static func get_player_identity_source() -> String:
	var fallback_source := IDENTITY_SOURCE_ANDROID_PENDING if OS.get_name() == "Android" else IDENTITY_SOURCE_LOCAL_FALLBACK
	return str(get_player_identity_info().get("source", fallback_source))

static func get_device_identity_source() -> String:
	var fallback_source := IDENTITY_SOURCE_ANDROID_PENDING if OS.get_name() == "Android" else IDENTITY_SOURCE_LOCAL_FALLBACK
	return str(get_device_identity_info().get("source", fallback_source))

static func get_player_identity_info() -> Dictionary:
	return _build_identity_info(
		PLAYER_ID_CACHE_PATH,
		PLAYER_ID_SOURCE_CACHE_PATH,
		PLAYER_ID_PREFIX,
		PackedStringArray(["getStablePlayerId", "get_stable_player_id"]),
		"player"
	)

static func get_device_identity_info() -> Dictionary:
	return _build_identity_info(
		DEVICE_ID_CACHE_PATH,
		DEVICE_ID_SOURCE_CACHE_PATH,
		DEVICE_ID_PREFIX,
		PackedStringArray(["getStableDeviceId", "get_stable_device_id"]),
		"device"
	)

static func is_remote_identity_ready() -> bool:
	if OS.get_name() != "Android":
		return true
	var player_info := get_player_identity_info()
	var device_info := get_device_identity_info()
	return bool(player_info.get("remote_ready", false)) and bool(device_info.get("remote_ready", false))

static func has_pending_remote_identity_migration() -> bool:
	if OS.get_name() != "Android":
		return false
	var player_info := get_player_identity_info()
	var device_info := get_device_identity_info()
	return bool(player_info.get("needs_migration", false)) or bool(device_info.get("needs_migration", false))

static func get_pending_remote_identity_migration() -> Dictionary:
	var player_info := get_player_identity_info()
	var device_info := get_device_identity_info()
	return {
		"old_player_id": str(player_info.get("cached_value", "")),
		"new_player_id": str(player_info.get("stable_value", player_info.get("value", ""))),
		"old_device_id": str(device_info.get("cached_value", "")),
		"new_device_id": str(device_info.get("stable_value", device_info.get("value", ""))),
		"player_needs_migration": bool(player_info.get("needs_migration", false)),
		"device_needs_migration": bool(device_info.get("needs_migration", false)),
	}

static func finalize_remote_identity_migration() -> void:
	if OS.get_name() != "Android":
		return
	var player_info := get_player_identity_info()
	var device_info := get_device_identity_info()
	_persist_canonical_identity(player_info, PLAYER_ID_CACHE_PATH, PLAYER_ID_SOURCE_CACHE_PATH)
	_persist_canonical_identity(device_info, DEVICE_ID_CACHE_PATH, DEVICE_ID_SOURCE_CACHE_PATH)

static func get_cached_device_id_for_debug() -> String:
	var device_id := _read_cached_value(DEVICE_ID_CACHE_PATH)
	if device_id.is_empty():
		device_id = str(get_device_identity_info().get("value", "")).strip_edges()
	if device_id.is_empty():
		return "(not created yet)"
	return device_id

static func _build_identity_info(cache_path: String, source_path: String, stable_prefix: String, stable_method_names: PackedStringArray, identity_purpose: String) -> Dictionary:
	var cached_value := _read_cached_value(cache_path)
	var existing_source := _read_cached_value(source_path)
	if existing_source.is_empty() and not cached_value.is_empty():
		existing_source = _infer_cached_source(cached_value, stable_prefix)
	elif OS.get_name() == "Android" and not cached_value.is_empty() and existing_source != IDENTITY_SOURCE_ANDROID_STABLE:
		existing_source = IDENTITY_SOURCE_LEGACY_CACHE

	if OS.get_name() != "Android":
		if cached_value.is_empty():
			cached_value = _generate_random_id()
			existing_source = IDENTITY_SOURCE_LOCAL_FALLBACK
			return {
				"value": cached_value,
				"cached_value": cached_value,
				"stable_value": "",
				"source": existing_source,
				"remote_ready": true,
				"needs_migration": false,
				"should_persist": true,
			}
		if existing_source.is_empty():
			existing_source = IDENTITY_SOURCE_LOCAL_FALLBACK
		return {
			"value": cached_value,
			"cached_value": cached_value,
			"stable_value": "",
			"source": existing_source,
			"remote_ready": true,
			"needs_migration": false,
			"should_persist": _read_cached_value(source_path).is_empty(),
		}

	var stable_value := _resolve_android_stable_id(stable_method_names, identity_purpose, stable_prefix)
	if not stable_value.is_empty():
		if cached_value.is_empty():
			return {
				"value": stable_value,
				"cached_value": "",
				"stable_value": stable_value,
				"source": IDENTITY_SOURCE_ANDROID_STABLE,
				"remote_ready": true,
				"needs_migration": false,
				"should_persist": true,
			}
		if cached_value == stable_value:
			return {
				"value": stable_value,
				"cached_value": cached_value,
				"stable_value": stable_value,
				"source": IDENTITY_SOURCE_ANDROID_STABLE,
				"remote_ready": true,
				"needs_migration": false,
				"should_persist": existing_source != IDENTITY_SOURCE_ANDROID_STABLE,
			}
		return {
			"value": stable_value,
			"cached_value": cached_value,
			"stable_value": stable_value,
			"source": existing_source if not existing_source.is_empty() else _infer_cached_source(cached_value, stable_prefix),
			"remote_ready": false,
			"needs_migration": true,
			"should_persist": false,
		}

	if not cached_value.is_empty() and existing_source == IDENTITY_SOURCE_ANDROID_STABLE:
		return {
			"value": cached_value,
			"cached_value": cached_value,
			"stable_value": cached_value,
			"source": existing_source,
			"remote_ready": true,
			"needs_migration": false,
			"should_persist": false,
		}
	if not cached_value.is_empty():
		if existing_source.is_empty():
			existing_source = _infer_cached_source(cached_value, stable_prefix)
		return {
			"value": cached_value,
			"cached_value": cached_value,
			"stable_value": "",
			"source": existing_source,
			"remote_ready": false,
			"needs_migration": false,
			"should_persist": _read_cached_value(source_path).is_empty(),
		}
	return {
		"value": "",
		"cached_value": "",
		"stable_value": "",
		"source": IDENTITY_SOURCE_ANDROID_PENDING,
		"remote_ready": false,
		"needs_migration": false,
		"should_persist": false,
	}

static func _persist_resolved_identity_if_needed(info: Dictionary, cache_path: String, source_path: String) -> void:
	if not bool(info.get("should_persist", false)):
		return
	var value := str(info.get("value", "")).strip_edges()
	var source := str(info.get("source", "")).strip_edges()
	if value.is_empty() or source.is_empty():
		return
	_write_cached_value(cache_path, value)
	_write_cached_value(source_path, source)

static func _persist_canonical_identity(info: Dictionary, cache_path: String, source_path: String) -> void:
	var value := str(info.get("stable_value", info.get("value", ""))).strip_edges()
	if value.is_empty():
		return
	_write_cached_value(cache_path, value)
	_write_cached_value(source_path, IDENTITY_SOURCE_ANDROID_STABLE)

static func _infer_cached_source(cached_value: String, stable_prefix: String) -> String:
	if cached_value.begins_with(stable_prefix):
		return IDENTITY_SOURCE_ANDROID_STABLE
	if OS.get_name() != "Android":
		return IDENTITY_SOURCE_LOCAL_FALLBACK
	return IDENTITY_SOURCE_LEGACY_CACHE

static func _resolve_android_stable_id(method_names: PackedStringArray, identity_purpose: String, stable_prefix: String) -> String:
	if OS.get_name() != "Android":
		return ""

	var compat_bridge = _get_compat_bridge()
	if compat_bridge != null:
		var context = _get_android_context()
		var compat_value := _resolve_stable_id_from_compat_bridge(compat_bridge, method_names, context)
		if not compat_value.is_empty():
			return compat_value

	var plugin = _get_plugin_singleton()
	if plugin != null:
		var plugin_value := _resolve_stable_id_from_plugin(plugin, method_names)
		if not plugin_value.is_empty():
			return plugin_value

	return _build_gdscript_stable_id(identity_purpose, stable_prefix)

static func _resolve_stable_id_from_compat_bridge(compat_bridge, method_names: PackedStringArray, context) -> String:
	for method_name in method_names:
		if not compat_bridge.has_method(method_name):
			continue
		if context != null:
			var context_value := str(compat_bridge.callv(method_name, [context])).strip_edges()
			if not context_value.is_empty():
				return context_value
		var plain_value := str(compat_bridge.callv(method_name, [])).strip_edges()
		if not plain_value.is_empty():
			return plain_value

	return ""

static func _resolve_stable_id_from_plugin(plugin, method_names: PackedStringArray) -> String:
	for method_name in method_names:
		if not plugin.has_method(method_name):
			continue
		var plugin_value := str(plugin.callv(method_name, [])).strip_edges()
		if not plugin_value.is_empty():
			return plugin_value

	return ""

static func _build_gdscript_stable_id(identity_purpose: String, stable_prefix: String) -> String:
	var android_id := _resolve_android_id_via_gdscript()
	if android_id.is_empty():
		return ""

	var package_name := _get_canonical_android_package_name()
	if package_name.is_empty():
		var context = _get_android_context()
		if context != null and context.has_method("getPackageName"):
			package_name = str(context.getPackageName()).strip_edges()
	if package_name.is_empty():
		return ""

	var hashing_context := HashingContext.new()
	if hashing_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing_context.update(("%s:%s:%s" % [identity_purpose, package_name, android_id]).to_utf8_buffer()) != OK:
		return ""

	return stable_prefix + hashing_context.finish().hex_encode().substr(0, 24)

static func _resolve_android_id_via_gdscript() -> String:
	var engine_unique_id := _sanitize_android_id(str(OS.get_unique_id()).strip_edges())
	if not engine_unique_id.is_empty():
		return engine_unique_id

	var context = _get_android_context()
	if context == null or not context.has_method("getContentResolver"):
		return ""

	var content_resolver = context.getContentResolver()
	if content_resolver == null:
		return ""

	var java_class_wrapper = _get_java_class_wrapper()
	if java_class_wrapper == null or not java_class_wrapper.has_method("wrap"):
		return ""

	var settings_secure = java_class_wrapper.wrap(SETTINGS_SECURE_CLASS)
	if settings_secure == null or not settings_secure.has_method("getString"):
		return ""

	return _sanitize_android_id(str(settings_secure.getString(content_resolver, "android_id")).strip_edges())

static func _sanitize_android_id(android_id: String) -> String:
	if android_id.is_empty():
		return ""
	if android_id == "0000000000000000":
		return ""
	if android_id.to_lower() == "unknown":
		return ""
	if android_id == INVALID_ANDROID_ID:
		return ""
	return android_id

static func _get_canonical_android_package_name() -> String:
	return str(BuildInfoScript.APP_PACKAGE_NAME).strip_edges()

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

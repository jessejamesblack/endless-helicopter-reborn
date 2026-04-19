extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var helicopter_skins := get_root().get_node_or_null("HelicopterSkins")
	_assert(helicopter_skins != null, "HelicopterSkins autoload should exist for lore validation.")
	if helicopter_skins == null:
		_finish()
		return

	for vehicle_id in helicopter_skins.get_vehicle_ids():
		var vehicle_data: Dictionary = helicopter_skins.get_vehicle_data(vehicle_id)
		_assert(not str(vehicle_data.get("display_name", "")).is_empty(), "Vehicle %s should have a display_name." % vehicle_id)
		_assert(not str(vehicle_data.get("vehicle_class", "")).is_empty(), "Vehicle %s should have a vehicle_class." % vehicle_id)
		_assert(not str(vehicle_data.get("short_lore", "")).is_empty(), "Vehicle %s should have short_lore." % vehicle_id)
		_assert(not str(vehicle_data.get("unlock_lore", "")).is_empty(), "Vehicle %s should have unlock_lore." % vehicle_id)
		_assert(not str(vehicle_data.get("flavor_quote", "")).is_empty(), "Vehicle %s should have a flavor_quote." % vehicle_id)
		_assert((vehicle_data.get("dossier", []) as Array).size() >= 2, "Vehicle %s should have dossier entries." % vehicle_id)
		_assert(str(vehicle_data.get("art_quality_status", "")) == "final", "Vehicle %s should be marked final quality." % vehicle_id)
		_assert(helicopter_skins.get_vehicle_skin_ids(vehicle_id).has("factory"), "Vehicle %s should expose Factory." % vehicle_id)

		for skin_id in helicopter_skins.get_vehicle_skin_ids(vehicle_id):
			var skin_data: Dictionary = helicopter_skins.get_vehicle_skin_data(vehicle_id, skin_id)
			_assert(not str(skin_data.get("display_name", "")).is_empty(), "%s/%s should have a display_name." % [vehicle_id, skin_id])
			_assert(not str(skin_data.get("short_lore", "")).is_empty(), "%s/%s should have short_lore." % [vehicle_id, skin_id])
			_assert(not str(skin_data.get("unlock_lore", "")).is_empty(), "%s/%s should have unlock_lore." % [vehicle_id, skin_id])
			_assert(not str(skin_data.get("unlock_requirement", "")).is_empty(), "%s/%s should have unlock_requirement." % [vehicle_id, skin_id])
			_assert(str(skin_data.get("art_quality_status", "")) == "final", "%s/%s should be marked final quality." % [vehicle_id, skin_id])
			if skin_id == "original_icon":
				_assert(str(skin_data.get("skin_type", "")) == "texture_swap", "%s/%s should be the only texture-swap skin type." % [vehicle_id, skin_id])
				if bool(skin_data.get("available", false)):
					var texture_path := str(skin_data.get("texture", ""))
					_assert(texture_path.ends_with(".svg"), "%s/%s should use an SVG when available." % [vehicle_id, skin_id])
					_assert(ResourceLoader.exists(texture_path), "%s/%s SVG should exist." % [vehicle_id, skin_id])
			else:
				_assert(str(skin_data.get("skin_type", "")) == "color", "%s/%s should be a color-only skin." % [vehicle_id, skin_id])
				_assert(not skin_data.has("texture"), "%s/%s should not point to a replacement texture." % [vehicle_id, skin_id])

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Vehicle lore validation completed successfully.")
		quit()
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

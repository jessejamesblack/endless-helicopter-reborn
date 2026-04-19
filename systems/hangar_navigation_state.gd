extends Node

const DEFAULT_VEHICLE_ID := "default_scout"
const DEFAULT_SKIN_ID := "factory"

var _pending_vehicle_id: String = ""
var _pending_skin_id: String = ""

func set_focus(vehicle_id: String, skin_id: String = DEFAULT_SKIN_ID) -> void:
	_pending_vehicle_id = vehicle_id.strip_edges()
	_pending_skin_id = skin_id.strip_edges()

func set_focus_from_unlock(unlock_entry: Dictionary) -> void:
	match str(unlock_entry.get("unlock_type", "")):
		"vehicle":
			set_focus(str(unlock_entry.get("vehicle_id", DEFAULT_VEHICLE_ID)), DEFAULT_SKIN_ID)
		"vehicle_skin":
			set_focus(str(unlock_entry.get("vehicle_id", DEFAULT_VEHICLE_ID)), str(unlock_entry.get("skin_id", DEFAULT_SKIN_ID)))
		"global_skin_set":
			set_focus(DEFAULT_VEHICLE_ID, str(unlock_entry.get("skin_id", DEFAULT_SKIN_ID)))
		_:
			clear_focus()

func consume_focus() -> Dictionary:
	var focus := {
		"vehicle_id": _pending_vehicle_id,
		"skin_id": _pending_skin_id,
	}
	clear_focus()
	return focus

func clear_focus() -> void:
	_pending_vehicle_id = ""
	_pending_skin_id = ""

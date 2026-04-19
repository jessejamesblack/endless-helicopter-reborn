extends Node

const STATE_PATH := "user://feature_discovery.cfg"
const STATE_SECTION := "feature_discovery"
const TIP_MISSIONS := "missions"
const TIP_HANGAR := "hangar"

var _seen_tips: Array[String] = []

func _ready() -> void:
	_load_state()

func has_seen_tip(tip_id: String) -> bool:
	return _seen_tips.has(tip_id.strip_edges())

func mark_tip_seen(tip_id: String) -> void:
	var clean_tip_id := tip_id.strip_edges()
	if clean_tip_id.is_empty() or _seen_tips.has(clean_tip_id):
		return
	_seen_tips.append(clean_tip_id)
	_save_state()

func replay_all_tips() -> void:
	_seen_tips.clear()
	_save_state()

func get_active_tip() -> Dictionary:
	if not has_seen_tip(TIP_MISSIONS):
		return {
			"id": TIP_MISSIONS,
			"title": "Daily Missions",
			"message": "Daily Missions unlock vehicles and paint styles.",
			"button_text": "Open Missions",
			"target": TIP_MISSIONS,
		}
	if not has_seen_tip(TIP_HANGAR):
		return {
			"id": TIP_HANGAR,
			"title": "Hangar",
			"message": "Hangar is where you equip vehicles and skins.",
			"button_text": "Open Hangar",
			"target": TIP_HANGAR,
		}
	return {}

func get_menu_badges() -> Dictionary:
	var player_profile := get_node_or_null("/root/PlayerProfile")
	var missions_new := not has_seen_tip(TIP_MISSIONS)
	var hangar_new := not has_seen_tip(TIP_HANGAR)
	if player_profile != null and player_profile.has_method("has_unseen_hangar_content"):
		hangar_new = hangar_new or bool(player_profile.has_unseen_hangar_content())
	return {
		"missions": missions_new,
		"hangar": hangar_new,
	}

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return
	var seen_value: Variant = config.get_value(STATE_SECTION, "seen_tips", [])
	_seen_tips.clear()
	if seen_value is Array:
		for tip_id in seen_value:
			var clean_tip_id := str(tip_id).strip_edges()
			if clean_tip_id.is_empty() or _seen_tips.has(clean_tip_id):
				continue
			_seen_tips.append(clean_tip_id)

func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value(STATE_SECTION, "seen_tips", _seen_tips.duplicate())
	config.save(STATE_PATH)

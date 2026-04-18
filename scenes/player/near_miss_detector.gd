extends Area2D

const KIND_HOSTILE := "hostile"
const KIND_PROJECTILE := "projectile"

var _active_candidates: Dictionary = {}
var _awarded_ids: Dictionary = {}

func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	for id in _active_candidates.keys():
		var candidate: Dictionary = _active_candidates[id]
		var area: Area2D = candidate.get("area", null)
		if area == null or not is_instance_valid(area) or not area.is_inside_tree() or area.is_queued_for_deletion():
			_active_candidates.erase(id)

func _get_near_miss_kind(area: Area2D) -> String:
	if area == null:
		return ""
	if area.is_in_group("enemy_projectiles"):
		return KIND_PROJECTILE
	if area.is_in_group("hostile_units"):
		return KIND_HOSTILE
	return ""

func _on_area_entered(area: Area2D) -> void:
	var kind := _get_near_miss_kind(area)
	if kind == "":
		return

	var id := area.get_instance_id()
	if _awarded_ids.has(id):
		return

	_active_candidates[id] = {
		"area": area,
		"kind": kind,
	}

func _on_area_exited(area: Area2D) -> void:
	if area == null:
		return

	var id := area.get_instance_id()
	if not _active_candidates.has(id):
		return

	var candidate: Dictionary = _active_candidates[id]
	_active_candidates.erase(id)

	if _awarded_ids.has(id) or _is_game_crashed():
		return
	if not is_instance_valid(area) or area.is_queued_for_deletion():
		return

	_awarded_ids[id] = true

	var main := get_tree().current_scene
	if main != null and main.has_method("record_near_miss"):
		main.record_near_miss(str(candidate.get("kind", KIND_HOSTILE)), area.global_position)

func _is_game_crashed() -> bool:
	var main := get_tree().current_scene
	if main == null:
		return true
	if "is_crashed" in main and main.is_crashed:
		return true
	if "is_transitioning_to_game_over" in main and main.is_transitioning_to_game_over:
		return true
	return false

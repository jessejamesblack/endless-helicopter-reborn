extends Node

const DEFAULT_SKIN_ID := "default_scout"
const POTTERCAR_SKIN_ID := "pottercar"
const EXTERNAL_SKIN_BACKGROUND_KEY := preload("res://assets/shaders/helicopter_background_key.gdshader")

const SKINS := {
	"default_scout": {
		"display_name": "Scout",
		"description": "The original endless flyer.",
		"texture": "res://assets/art/sprites/pixel_art_sheet.svg",
		"uses_region": true,
		"region_rect": Rect2(1169.1538, 181.79488, 705.4358, 311.79486),
		"scale": Vector2(0.10042553, 0.11961415),
		"offset": Vector2(-0.5, -2.5),
		"flip_h": false,
		"use_background_key": false,
		"unlock_type": "default",
		"collision_points": [
			Vector2(-42, -14),
			Vector2(-32, -24),
			Vector2(-10, -30),
			Vector2(18, -28),
			Vector2(42, -16),
			Vector2(56, -2),
			Vector2(48, 10),
			Vector2(28, 18),
			Vector2(2, 20),
			Vector2(-22, 16),
			Vector2(-38, 8),
			Vector2(-50, -2),
		],
		"unlock_requirement": "Unlocked by default.",
		"required_completed_missions": 0,
	},
	"bubble_chopper": {
		"display_name": "Little Bird",
		"description": "Complete 1 daily mission.",
		"texture": "res://assets/art/sprites/helicopters/littlebird.png",
		"uses_region": true,
		"region_rect": Rect2(170, 225, 2190, 1235),
		"scale": Vector2(0.0365, 0.0365),
		"offset": Vector2(0.0, -3.0),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"collision_points": [
			Vector2(-34, -14),
			Vector2(-22, -23),
			Vector2(-2, -28),
			Vector2(16, -26),
			Vector2(30, -18),
			Vector2(38, -6),
			Vector2(34, 8),
			Vector2(16, 16),
			Vector2(-4, 18),
			Vector2(-24, 12),
			Vector2(-36, 2),
		],
		"unlock_requirement": "Complete 1 daily mission.",
		"required_completed_missions": 1,
	},
	"huey_runner": {
		"display_name": "Huey Runner",
		"description": "Complete 3 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/huey.png",
		"uses_region": true,
		"region_rect": Rect2(120, 225, 2240, 1260),
		"scale": Vector2(0.0355, 0.0355),
		"offset": Vector2(0.0, -3.2),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"collision_points": [
			Vector2(-46, -18),
			Vector2(-32, -28),
			Vector2(-8, -31),
			Vector2(20, -29),
			Vector2(42, -17),
			Vector2(56, -4),
			Vector2(50, 12),
			Vector2(24, 20),
			Vector2(-4, 22),
			Vector2(-26, 16),
			Vector2(-44, 4),
			Vector2(-52, -8),
		],
		"unlock_requirement": "Complete 3 daily missions.",
		"required_completed_missions": 3,
	},
	"blackhawk_shadow": {
		"display_name": "Shadow Hawk",
		"description": "Complete 7 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/blackhawk.png",
		"uses_region": true,
		"region_rect": Rect2(110, 95, 2680, 1180),
		"scale": Vector2(0.0298, 0.0298),
		"offset": Vector2(0.0, -3.4),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"collision_points": [
			Vector2(-52, -18),
			Vector2(-38, -30),
			Vector2(-10, -34),
			Vector2(22, -32),
			Vector2(48, -20),
			Vector2(64, -2),
			Vector2(56, 14),
			Vector2(28, 22),
			Vector2(-2, 24),
			Vector2(-28, 18),
			Vector2(-48, 6),
			Vector2(-58, -8),
		],
		"unlock_requirement": "Complete 7 daily missions.",
		"required_completed_missions": 7,
	},
	"apache_strike": {
		"display_name": "Hind Strike",
		"description": "Complete 12 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/mi24.png",
		"uses_region": true,
		"region_rect": Rect2(120, 225, 2230, 1225),
		"scale": Vector2(0.0355, 0.0355),
		"offset": Vector2(0.0, -3.1),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"collision_points": [
			Vector2(-48, -18),
			Vector2(-36, -30),
			Vector2(-12, -34),
			Vector2(18, -30),
			Vector2(42, -20),
			Vector2(56, -6),
			Vector2(52, 10),
			Vector2(30, 18),
			Vector2(2, 22),
			Vector2(-24, 18),
			Vector2(-42, 8),
			Vector2(-52, -2),
		],
		"unlock_requirement": "Complete 12 daily missions.",
		"required_completed_missions": 12,
	},
	"chinook_lift": {
		"display_name": "Twin-Lift",
		"description": "Complete 20 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/chinook.png",
		"uses_region": true,
		"region_rect": Rect2(120, 85, 2710, 1185),
		"scale": Vector2(0.0295, 0.0295),
		"offset": Vector2(0.0, -3.5),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"collision_points": [
			Vector2(-60, -18),
			Vector2(-46, -30),
			Vector2(-18, -34),
			Vector2(18, -34),
			Vector2(52, -26),
			Vector2(74, -12),
			Vector2(78, 4),
			Vector2(66, 16),
			Vector2(40, 24),
			Vector2(6, 28),
			Vector2(-24, 26),
			Vector2(-48, 18),
			Vector2(-64, 2),
		],
		"unlock_requirement": "Complete 20 daily missions.",
		"required_completed_missions": 20,
	},
	"pottercar": {
		"display_name": "Pottercar",
		"description": "Hold #1 on the leaderboard. Lose it when you lose the top spot.",
		"texture": "res://assets/art/sprites/helicopters/pottercar.png",
		"uses_region": true,
		"region_rect": Rect2(400, 290, 1960, 1240),
		"scale": Vector2(0.0405, 0.0405),
		"offset": Vector2(0.0, -3.2),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "leaderboard_top",
		"collision_points": [
			Vector2(-58, -18),
			Vector2(-44, -30),
			Vector2(-12, -34),
			Vector2(20, -32),
			Vector2(48, -20),
			Vector2(62, -2),
			Vector2(58, 14),
			Vector2(34, 24),
			Vector2(2, 28),
			Vector2(-28, 22),
			Vector2(-50, 8),
			Vector2(-62, -4),
		],
		"unlock_requirement": "Hold #1 on the leaderboard. Lose it when you lose the top spot.",
		"required_completed_missions": 0,
	},
}

const SKIN_ORDER := [
	DEFAULT_SKIN_ID,
	"bubble_chopper",
	"huey_runner",
	"blackhawk_shadow",
	"apache_strike",
	"chinook_lift",
	POTTERCAR_SKIN_ID,
]

var _background_key_material: ShaderMaterial

func get_skin_ids() -> Array[String]:
	var ids: Array[String] = []
	for skin_id in SKIN_ORDER:
		ids.append(skin_id)
	return ids

func has_skin(skin_id: String) -> bool:
	return SKINS.has(skin_id)

func get_skin_data(skin_id: String) -> Dictionary:
	var resolved_skin_id := skin_id if SKINS.has(skin_id) else DEFAULT_SKIN_ID
	return (SKINS.get(resolved_skin_id, SKINS[DEFAULT_SKIN_ID]) as Dictionary).duplicate(true)

func get_display_name(skin_id: String) -> String:
	return str(get_skin_data(skin_id).get("display_name", "Scout"))

func get_texture_path(skin_id: String) -> String:
	return str(get_skin_data(skin_id).get("texture", ""))

func get_unlock_type(skin_id: String) -> String:
	return str(get_skin_data(skin_id).get("unlock_type", "missions"))

func is_dynamic_skin(skin_id: String) -> bool:
	return get_unlock_type(skin_id) == "leaderboard_top"

func get_next_locked_skin(total_daily_missions_completed: int) -> Dictionary:
	for skin_id in get_skin_ids():
		if skin_id == DEFAULT_SKIN_ID:
			continue
		var data := get_skin_data(skin_id)
		if str(data.get("unlock_type", "missions")) != "missions":
			continue
		var required := int(data.get("required_completed_missions", 0))
		if total_daily_missions_completed < required:
			data["skin_id"] = skin_id
			data["completed_missions"] = total_daily_missions_completed
			data["remaining_missions"] = maxi(required - total_daily_missions_completed, 0)
			return data
	return {}

func get_unlocks_for_completed_missions(total_daily_missions_completed: int) -> Array[String]:
	var unlocked: Array[String] = []
	for skin_id in get_skin_ids():
		if skin_id == DEFAULT_SKIN_ID:
			continue
		var data := get_skin_data(skin_id)
		if str(data.get("unlock_type", "missions")) != "missions":
			continue
		var required := int(data.get("required_completed_missions", 0))
		if total_daily_missions_completed >= required:
			unlocked.append(skin_id)
	return unlocked

func apply_skin_to_sprite(sprite: Sprite2D, skin_id: String) -> void:
	if sprite == null:
		return

	var data := get_skin_data(skin_id)
	var texture_path := str(data.get("texture", ""))
	if texture_path.is_empty():
		data = get_skin_data(DEFAULT_SKIN_ID)
		texture_path = str(data.get("texture", ""))

	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)

	var uses_region := bool(data.get("uses_region", false))
	sprite.region_enabled = uses_region
	if uses_region:
		sprite.region_rect = data.get("region_rect", Rect2())
	else:
		sprite.region_rect = Rect2()

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = bool(data.get("flip_h", false))
	sprite.scale = data.get("scale", Vector2.ONE)
	sprite.position = data.get("offset", Vector2.ZERO)
	sprite.material = _get_skin_material(data)

func apply_skin_to_player(sprite: Sprite2D, collision_polygon: CollisionPolygon2D, skin_id: String) -> void:
	apply_skin_to_sprite(sprite, skin_id)
	if collision_polygon == null:
		return

	var polygon: PackedVector2Array = get_collision_polygon(skin_id)
	if not polygon.is_empty():
		collision_polygon.polygon = polygon

func get_collision_polygon(skin_id: String) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var point_variants = get_skin_data(skin_id).get("collision_points", [])
	if point_variants is Array:
		for point_variant in point_variants:
			if point_variant is Vector2:
				polygon.append(point_variant)
	return polygon

func _get_skin_material(data: Dictionary) -> Material:
	if not bool(data.get("use_background_key", false)):
		return null
	if _background_key_material == null:
		_background_key_material = ShaderMaterial.new()
		_background_key_material.shader = EXTERNAL_SKIN_BACKGROUND_KEY
	return _background_key_material

extends RefCounted
class_name BackgroundCatalog

const BIOMES := {
	"classic_night_city": {
		"id": "classic_night_city",
		"display_name": "Classic Night City",
		"art_quality_status": "final",
		"layers": ["sky", "stars", "far", "mid", "near"],
		"sky_texture": "res://assets/art/backgrounds/biomes/classic_night_city/sky.png",
		"far_texture": "res://assets/art/backgrounds/biomes/classic_night_city/far.png",
		"mid_texture": "res://assets/art/backgrounds/biomes/classic_night_city/mid.png",
		"near_texture": "res://assets/art/backgrounds/biomes/classic_night_city/near.png",
		"star_color": Color(0.87451, 0.94902, 1.0, 0.95),
		"star_count": 0,
	},
	"canyon_run": {
		"id": "canyon_run",
		"display_name": "Canyon Run",
		"art_quality_status": "final",
		"layers": ["sky", "stars", "far", "mid", "near"],
		"sky_texture": "res://assets/art/backgrounds/biomes/canyon_run/sky.png",
		"far_texture": "res://assets/art/backgrounds/biomes/canyon_run/far.png",
		"mid_texture": "res://assets/art/backgrounds/biomes/canyon_run/mid.png",
		"near_texture": "res://assets/art/backgrounds/biomes/canyon_run/near.png",
		"star_color": Color(1.0, 0.870588, 0.721569, 0.28),
		"star_count": 0,
	},
	"alien_cavern": {
		"id": "alien_cavern",
		"display_name": "Alien Cavern",
		"art_quality_status": "final",
		"layers": ["sky", "stars", "far", "mid", "near"],
		"sky_texture": "res://assets/art/backgrounds/biomes/alien_cavern/sky.png",
		"far_texture": "res://assets/art/backgrounds/biomes/alien_cavern/far.png",
		"mid_texture": "res://assets/art/backgrounds/biomes/alien_cavern/mid.png",
		"near_texture": "res://assets/art/backgrounds/biomes/alien_cavern/near.png",
		"star_color": Color(0.721569, 1.0, 0.960784, 0.34),
		"star_count": 0,
	},
}

static func get_biome_ids() -> Array[String]:
	var ids: Array[String] = []
	for biome_id in BIOMES.keys():
		ids.append(str(biome_id))
	ids.sort()
	return ids

static func get_biome_data(biome_id: String) -> Dictionary:
	if BIOMES.has(biome_id):
		return (BIOMES[biome_id] as Dictionary).duplicate(true)
	return (BIOMES["classic_night_city"] as Dictionary).duplicate(true)

static func get_visible_biomes() -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for biome_id in get_biome_ids():
		var biome := get_biome_data(biome_id)
		if str(biome.get("art_quality_status", "")) == "final":
			visible.append(biome)
	return visible

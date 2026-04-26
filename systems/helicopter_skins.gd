extends Node

const DEFAULT_VEHICLE_ID := "default_scout"
const DEFAULT_SKIN_ID := "factory"
const CRAZYTAXI_VEHICLE_ID := "crazytaxi"
const POTTERCAR_VEHICLE_ID := "pottercar"
const VEHICLE_CATALOG_VERSION := 1

const VEHICLE_ORDER := [
	DEFAULT_VEHICLE_ID,
	"bubble_chopper",
	"huey_runner",
	"blackhawk_shadow",
	"apache_strike",
	"chinook_lift",
	CRAZYTAXI_VEHICLE_ID,
	POTTERCAR_VEHICLE_ID,
]

const STANDARD_SKIN_ORDER := [
	"factory",
	"arctic",
	"desert",
	"neon",
	"prototype",
	"gold",
	"original_icon",
]

const FACTORY_ONLY_SKIN_ORDER := [
	"factory",
]

const COLOR_SKIN_THEMES := {
	"factory": {
		"display_name": "Factory",
		"skin_type": "color",
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"unlock_requirement": "Unlocked with the vehicle.",
		"short_lore": "The original hangar finish, clean enough to identify and cheap enough to repair.",
		"unlock_lore": "Factory finish ready.",
		"theme": "Core",
		"rarity": "Common",
		"art_quality_status": "final",
	},
	"arctic": {
		"display_name": "Arctic",
		"skin_type": "color",
		"modulate": Color(1.08, 1.06, 1.12, 1.0),
		"unlock_requirement": "Complete 3 daily missions with this vehicle.",
		"short_lore": "A cold-weather paint kit for pilots who want their mistakes to look professional.",
		"unlock_lore": "Arctic paint unlocked.",
		"theme": "Cold Weather",
		"rarity": "Uncommon",
		"art_quality_status": "final",
	},
	"desert": {
		"display_name": "Desert",
		"skin_type": "color",
		"modulate": Color(0.96, 0.8, 0.6, 1.0),
		"unlock_requirement": "Complete 5 runs with this vehicle.",
		"short_lore": "Dust-toned plating from long routes, hot engines, and questionable landing zones.",
		"unlock_lore": "Desert paint unlocked.",
		"theme": "Route Worn",
		"rarity": "Uncommon",
		"art_quality_status": "final",
	},
	"neon": {
		"display_name": "Neon",
		"skin_type": "color",
		"modulate": Color(1.0, 0.34, 1.2, 1.0),
		"unlock_requirement": "Get 25 near misses with this vehicle.",
		"short_lore": "A glowing night-run finish for pilots who believe stealth is less important than style.",
		"unlock_lore": "Neon paint unlocked.",
		"theme": "Night Run",
		"rarity": "Rare",
		"art_quality_status": "final",
	},
	"prototype": {
		"display_name": "Prototype",
		"skin_type": "color",
		"modulate": Color(0.6, 0.62, 0.53, 1.0),
		"unlock_requirement": "Intercept 10 projectiles with this vehicle.",
		"short_lore": "Experimental markings from a hangar crew that stopped answering follow-up questions.",
		"unlock_lore": "Prototype paint unlocked.",
		"theme": "Experimental",
		"rarity": "Rare",
		"art_quality_status": "final",
	},
	"gold": {
		"display_name": "Gold",
		"skin_type": "color",
		"modulate": Color(1.24, 0.9, 0.18, 1.0),
		"unlock_requirement": "Score 5,000+ in one run with this vehicle.",
		"short_lore": "A victory polish reserved for pilots who have already proven they can survive without it.",
		"unlock_lore": "Gold paint unlocked.",
		"theme": "Prestige",
		"rarity": "Epic",
		"art_quality_status": "final",
	},
}

const VEHICLES := {
	"default_scout": {
		"display_name": "Scout",
		"vehicle_class": "Scout",
		"role": "Balanced baseline",
		"description": "Unlocked by default.",
		"texture": "res://assets/art/sprites/pixel_art_sheet.svg",
		"uses_region": true,
		"region_rect": Rect2(1169.1538, 181.79488, 705.4358, 311.79486),
		"scale": Vector2(0.10042553, 0.11961415),
		"offset": Vector2(-0.5, -2.5),
		"flip_h": false,
		"use_background_key": false,
		"unlock_type": "default",
		"required_completed_missions": 0,
		"unlock_requirement": "Unlocked by default.",
		"unlock_lore": "Scout is ready by default.",
		"short_lore": "The original hangar bird. Light, familiar, and stubborn enough to survive more crashes than anyone admits.",
		"flavor_quote": "Small frame. Big mistakes. Bigger comebacks.",
		"dossier": [
			"Class: Scout",
			"Known for: balanced handling",
			"Pilot rumor: every ace starts by denting this one",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "reliable_frame",
			"jump_velocity": -400.0,
			"gravity_scale": 1.0,
			"tilt_speed": 5.0,
			"max_tilt": 0.5,
			"boundary_bounce_down_speed": 300.0,
			"boundary_bounce_up_speed": 360.0,
			"boundary_recovery_seconds": 0.18,
			"boundary_inset": 44.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/helicopter.svg",
		"original_icon_scale": Vector2(1.72, 1.72),
		"original_icon_offset": Vector2(0.0, -2.0),
	},
	"bubble_chopper": {
		"display_name": "Bubble Chopper",
		"flavor_name": "Little Bird",
		"vehicle_class": "Light Scout",
		"role": "Quick visual response",
		"description": "Complete 1 daily mission.",
		"texture": "res://assets/art/sprites/helicopters/littlebird.png",
		"uses_region": true,
		"region_rect": Rect2(170, 225, 2190, 1235),
		"scale": Vector2(0.0365, 0.0365),
		"offset": Vector2(0.0, -3.0),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"required_completed_missions": 1,
		"unlock_requirement": "Complete 1 daily mission.",
		"unlock_lore": "Little Bird joins the flight line.",
		"short_lore": "A compact city-runner built for pilots who squeeze through danger instead of steering around it.",
		"flavor_quote": "Thread the needle. Then do it again.",
		"dossier": [
			"Class: Light Scout",
			"Known for: small profile and quick visual response",
			"Pilot rumor: it can fit through gaps that were never meant to be gaps",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "near_miss_specialist",
			"jump_velocity": -430.0,
			"gravity_scale": 0.94,
			"tilt_speed": 5.8,
			"max_tilt": 0.58,
			"boundary_bounce_down_speed": 318.0,
			"boundary_bounce_up_speed": 388.0,
			"boundary_recovery_seconds": 0.16,
			"boundary_inset": 44.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/bubble_chopper.svg",
		"original_icon_scale": Vector2(0.70, 0.70),
		"original_icon_offset": Vector2(0.0, -2.6),
	},
	"huey_runner": {
		"display_name": "Huey Runner",
		"vehicle_class": "Utility Runner",
		"role": "Stable midline cruiser",
		"description": "Complete 3 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/huey.png",
		"uses_region": true,
		"region_rect": Rect2(120, 225, 2240, 1260),
		"scale": Vector2(0.0355, 0.0355),
		"offset": Vector2(0.0, -3.2),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"required_completed_missions": 3,
		"unlock_requirement": "Complete 3 daily missions.",
		"unlock_lore": "Huey Runner is cleared for launch.",
		"short_lore": "A boxy, dependable utility craft with old-school charm and a habit of making risky routes look routine.",
		"flavor_quote": "Reliable does not mean boring.",
		"dossier": [
			"Class: Utility Runner",
			"Known for: steady profile and classic silhouette",
			"Pilot rumor: the engine hums better after a near miss",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "ammo_utility",
			"jump_velocity": -392.0,
			"gravity_scale": 1.0,
			"tilt_speed": 4.8,
			"max_tilt": 0.46,
			"boundary_bounce_down_speed": 306.0,
			"boundary_bounce_up_speed": 366.0,
			"boundary_recovery_seconds": 0.18,
			"boundary_inset": 44.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/huey_runner.svg",
		"original_icon_scale": Vector2(0.70, 0.70),
		"original_icon_offset": Vector2(0.0, -2.8),
	},
	"blackhawk_shadow": {
		"display_name": "Blackhawk Shadow",
		"flavor_name": "Shadow Hawk",
		"vehicle_class": "Heavy Utility",
		"role": "Steady heavy carrier",
		"description": "Complete 7 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/blackhawk.png",
		"uses_region": true,
		"region_rect": Rect2(110, 95, 2680, 1180),
		"scale": Vector2(0.0298, 0.0298),
		"offset": Vector2(0.0, -3.4),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"required_completed_missions": 7,
		"unlock_requirement": "Complete 7 daily missions.",
		"unlock_lore": "Shadow Hawk rolls out of the hangar.",
		"short_lore": "A heavy utility aircraft built for night routes, hard turns, and pilots who stay calm when the screen gets crowded.",
		"flavor_quote": "The sky gets quieter when it shows up.",
		"dossier": [
			"Class: Heavy Utility",
			"Known for: broad silhouette and confident presence",
			"Pilot rumor: it casts a shadow before it arrives",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "shield_recovery",
			"jump_velocity": -372.0,
			"gravity_scale": 1.08,
			"tilt_speed": 4.4,
			"max_tilt": 0.43,
			"boundary_bounce_down_speed": 294.0,
			"boundary_bounce_up_speed": 350.0,
			"boundary_recovery_seconds": 0.2,
			"boundary_inset": 46.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/blackhawk_shadow.svg",
		"original_icon_scale": Vector2(0.68, 0.68),
		"original_icon_offset": Vector2(0.0, -2.9),
	},
	"apache_strike": {
		"display_name": "Hind Strike",
		"vehicle_class": "Armored Striker",
		"role": "Punchy forward attacker",
		"description": "Complete 12 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/mi24.png",
		"uses_region": true,
		"region_rect": Rect2(120, 225, 2230, 1225),
		"scale": Vector2(0.0355, 0.0355),
		"offset": Vector2(0.0, -3.1),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"required_completed_missions": 12,
		"unlock_requirement": "Complete 12 daily missions.",
		"unlock_lore": "Hind Strike is armed for arcade duty.",
		"short_lore": "An angular bruiser with a cockpit-forward stance and a reputation for turning missile runs into punctuation marks.",
		"flavor_quote": "Subtlety was never installed.",
		"dossier": [
			"Class: Armored Striker",
			"Known for: aggressive silhouette",
			"Pilot rumor: it does not dodge obstacles; it negotiates with them loudly",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "missile_striker",
			"jump_velocity": -414.0,
			"gravity_scale": 1.03,
			"tilt_speed": 5.2,
			"max_tilt": 0.54,
			"boundary_bounce_down_speed": 314.0,
			"boundary_bounce_up_speed": 374.0,
			"boundary_recovery_seconds": 0.17,
			"boundary_inset": 44.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/apache_strike.svg",
		"original_icon_scale": Vector2(0.72, 0.72),
		"original_icon_offset": Vector2(0.0, -2.8),
	},
	"chinook_lift": {
		"display_name": "Chinook Lift",
		"flavor_name": "Twin-Lift",
		"vehicle_class": "Tandem Heavy",
		"role": "Long-frame momentum machine",
		"description": "Complete 20 daily missions.",
		"texture": "res://assets/art/sprites/helicopters/chinook.png",
		"uses_region": true,
		"region_rect": Rect2(120, 85, 2710, 1185),
		"scale": Vector2(0.0295, 0.0295),
		"offset": Vector2(0.0, -3.5),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "missions",
		"required_completed_missions": 20,
		"unlock_requirement": "Complete 20 daily missions.",
		"unlock_lore": "Twin-Lift enters the rotation.",
		"short_lore": "A long-frame tandem-rotor oddity that turns every tunnel into a commitment.",
		"flavor_quote": "Twice the rotors. Twice the confidence. Twice the excuses.",
		"dossier": [
			"Class: Tandem Heavy",
			"Known for: long body and unmistakable rotor profile",
			"Pilot rumor: landing it is easy; convincing it to stop is not",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "combo_stabilizer",
			"jump_velocity": -360.0,
			"gravity_scale": 1.12,
			"tilt_speed": 4.0,
			"max_tilt": 0.4,
			"boundary_bounce_down_speed": 286.0,
			"boundary_bounce_up_speed": 344.0,
			"boundary_recovery_seconds": 0.21,
			"boundary_inset": 48.0,
		},
		"available_skins": STANDARD_SKIN_ORDER,
		"original_icon_texture": "res://assets/art/sprites/helicopters/chinook_lift.svg",
		"original_icon_scale": Vector2(0.66, 0.66),
		"original_icon_offset": Vector2(0.0, -3.0),
	},
	"crazytaxi": {
		"display_name": "Crazy Taxi",
		"vehicle_class": "Fare Evader",
		"role": "Gold-tier joyride menace",
		"description": "Unlock Gold on 3 vehicles.",
		"texture": "res://assets/art/sprites/helicopters/crazytaxi.png",
		"uses_region": true,
		"region_rect": Rect2(0, 62, 2516, 1550),
		"scale": Vector2(0.0305, 0.0305),
		"offset": Vector2(0.0, -3.25),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "gold_mastery",
		"required_completed_missions": 0,
		"unlock_requirement": "Unlock Gold on 3 vehicles.",
		"unlock_lore": "Crazy Taxi screeches into the hangar with zero regard for flight plans or fare laws.",
		"short_lore": "A yellow cab with rotor debt, rocket fumes, and the exact energy of a driver who treats every route like a time bonus.",
		"flavor_quote": "Yeah yeah yeah. Do not ask where the meter went.",
		"dossier": [
			"Class: Fare Evader",
			"Known for: impossible shortcuts and louder landings",
			"Pilot rumor: five-star ratings earned through sheer survival instinct",
		],
		"art_quality_status": "final",
		"collision_points": [
			Vector2(-58, -20),
			Vector2(-46, -32),
			Vector2(-16, -36),
			Vector2(18, -34),
			Vector2(50, -24),
			Vector2(64, -6),
			Vector2(60, 12),
			Vector2(36, 24),
			Vector2(2, 28),
			Vector2(-28, 24),
			Vector2(-52, 10),
			Vector2(-64, -4),
		],
		"profile": {
			"passive_id": "chaotic_scoring",
			"jump_velocity": -408.0,
			"gravity_scale": 0.98,
			"tilt_speed": 5.25,
			"max_tilt": 0.52,
			"boundary_bounce_down_speed": 304.0,
			"boundary_bounce_up_speed": 368.0,
			"boundary_recovery_seconds": 0.18,
			"boundary_inset": 44.0,
		},
		"available_skins": FACTORY_ONLY_SKIN_ORDER,
		"exclude_standard_skin_progress": true,
		"original_icon_texture": "",
		"original_icon_scale": Vector2(0.036, 0.036),
		"original_icon_offset": Vector2(0.0, -3.25),
	},
	"pottercar": {
		"display_name": "Pottercar",
		"vehicle_class": "Prestige Oddity",
		"role": "Leaderboard flex",
		"description": "Hold #1 on the leaderboard. Lose it when you lose the top spot.",
		"texture": "res://assets/art/sprites/helicopters/pottercar.png",
		"uses_region": true,
		"region_rect": Rect2(400, 290, 1960, 1240),
		"scale": Vector2(0.0405, 0.0405),
		"offset": Vector2(0.0, -3.2),
		"flip_h": true,
		"use_background_key": false,
		"unlock_type": "leaderboard_top",
		"required_completed_missions": 0,
		"unlock_requirement": "Hold #1 on the leaderboard. Lose it when you lose the top spot.",
		"unlock_lore": "Pottercar privilege activated.",
		"short_lore": "A leaderboard oddity with wheels where questions should be. Nobody knows why it flies, only who earned it.",
		"flavor_quote": "Physics filed a complaint.",
		"dossier": [
			"Class: Prestige Oddity",
			"Known for: top-rank bragging rights",
			"Pilot rumor: it only wakes up when the leaderboard gets nervous",
		],
		"art_quality_status": "final",
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
		"profile": {
			"passive_id": "prestige_oddity",
			"jump_velocity": -405.0,
			"gravity_scale": 0.99,
			"tilt_speed": 5.1,
			"max_tilt": 0.5,
			"boundary_bounce_down_speed": 304.0,
			"boundary_bounce_up_speed": 364.0,
			"boundary_recovery_seconds": 0.18,
			"boundary_inset": 44.0,
		},
		"available_skins": FACTORY_ONLY_SKIN_ORDER,
		"exclude_standard_skin_progress": true,
		"original_icon_texture": "",
		"original_icon_scale": Vector2(0.0405, 0.0405),
		"original_icon_offset": Vector2(0.0, -3.2),
	},
}

func get_vehicle_ids() -> Array[String]:
	var ids: Array[String] = []
	for vehicle_id in VEHICLE_ORDER:
		ids.append(vehicle_id)
	return ids

func get_skin_ids() -> Array[String]:
	return get_vehicle_ids()

func has_vehicle(vehicle_id: String) -> bool:
	return VEHICLES.has(vehicle_id)

func has_skin(skin_id: String) -> bool:
	return has_vehicle(skin_id)

func get_vehicle_data(vehicle_id: String) -> Dictionary:
	var resolved_vehicle_id := vehicle_id if VEHICLES.has(vehicle_id) else DEFAULT_VEHICLE_ID
	return (VEHICLES.get(resolved_vehicle_id, VEHICLES[DEFAULT_VEHICLE_ID]) as Dictionary).duplicate(true)

func get_skin_data(skin_id: String) -> Dictionary:
	return get_vehicle_data(skin_id)

func get_display_name(vehicle_id: String) -> String:
	return str(get_vehicle_data(vehicle_id).get("display_name", "Scout"))

func get_texture_path(vehicle_id: String) -> String:
	return str(get_vehicle_data(vehicle_id).get("texture", ""))

func get_unlock_type(vehicle_id: String) -> String:
	return str(get_vehicle_data(vehicle_id).get("unlock_type", "missions"))

func is_dynamic_vehicle(vehicle_id: String) -> bool:
	return get_unlock_type(vehicle_id) == "leaderboard_top"

func is_dynamic_skin(skin_id: String) -> bool:
	return is_dynamic_vehicle(skin_id)

func get_vehicle_skin_ids(vehicle_id: String) -> Array[String]:
	var data := get_vehicle_data(vehicle_id)
	var ordered: Array[String] = []
	for skin_id in data.get("available_skins", []):
		ordered.append(str(skin_id))
	return ordered

func get_vehicle_skin_data(vehicle_id: String, skin_id: String) -> Dictionary:
	var data := get_vehicle_data(vehicle_id)
	var resolved_skin_id := skin_id if get_vehicle_skin_ids(vehicle_id).has(skin_id) else DEFAULT_SKIN_ID
	if resolved_skin_id == "original_icon":
		var icon_available := is_original_icon_available(vehicle_id)
		return {
			"display_name": "Original Icon",
			"skin_type": "texture_swap",
			"texture": str(data.get("original_icon_texture", "")),
			"available": icon_available,
			"unlock_requirement": "Score 10,000+ in one run." if icon_available else "Not available for this vehicle.",
			"short_lore": "A preserved hangar icon from the earliest flight tests.",
			"unlock_lore": "Original hangar icons restored.",
			"theme": "Archive",
			"rarity": "Legendary",
			"art_quality_status": "final",
			"scale": data.get("original_icon_scale", data.get("scale", Vector2.ONE)),
			"offset": data.get("original_icon_offset", data.get("offset", Vector2.ZERO)),
			"uses_region": false,
			"modulate": Color.WHITE,
			"collision_points": data.get("collision_points", []),
		}
	var theme := (COLOR_SKIN_THEMES.get(resolved_skin_id, COLOR_SKIN_THEMES[DEFAULT_SKIN_ID]) as Dictionary).duplicate(true)
	theme["available"] = true
	return theme

func get_next_locked_vehicle(total_daily_missions_completed: int) -> Dictionary:
	for vehicle_id in get_vehicle_ids():
		if vehicle_id == DEFAULT_VEHICLE_ID:
			continue
		var data := get_vehicle_data(vehicle_id)
		if str(data.get("unlock_type", "missions")) != "missions":
			continue
		var required := int(data.get("required_completed_missions", 0))
		if total_daily_missions_completed < required:
			data["vehicle_id"] = vehicle_id
			data["skin_id"] = vehicle_id
			data["completed_missions"] = total_daily_missions_completed
			data["remaining_missions"] = maxi(required - total_daily_missions_completed, 0)
			return data
	return {}

func get_next_locked_skin(total_daily_missions_completed: int) -> Dictionary:
	return get_next_locked_vehicle(total_daily_missions_completed)

func get_vehicle_unlocks_for_completed_missions(total_daily_missions_completed: int) -> Array[String]:
	var unlocked: Array[String] = []
	for vehicle_id in get_vehicle_ids():
		if vehicle_id == DEFAULT_VEHICLE_ID:
			continue
		var data := get_vehicle_data(vehicle_id)
		if str(data.get("unlock_type", "missions")) != "missions":
			continue
		var required := int(data.get("required_completed_missions", 0))
		if total_daily_missions_completed >= required:
			unlocked.append(vehicle_id)
	return unlocked

func get_unlocks_for_completed_missions(total_daily_missions_completed: int) -> Array[String]:
	return get_vehicle_unlocks_for_completed_missions(total_daily_missions_completed)

func get_collision_polygon(vehicle_id: String) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var point_variants = get_vehicle_data(vehicle_id).get("collision_points", [])
	if point_variants is Array:
		for point_variant in point_variants:
			if point_variant is Vector2:
				polygon.append(point_variant)
	return polygon

func get_vehicle_profile(vehicle_id: String) -> Dictionary:
	return (get_vehicle_data(vehicle_id).get("profile", {}) as Dictionary).duplicate(true)

func get_vehicle_unlock_requirement(vehicle_id: String) -> String:
	return str(get_vehicle_data(vehicle_id).get("unlock_requirement", "Unlocked by default."))

func apply_vehicle_and_skin_to_player(sprite: Sprite2D, collision_polygon: CollisionPolygon2D, vehicle_id: String, skin_id: String) -> void:
	_apply_vehicle_and_skin_to_sprite(sprite, vehicle_id, skin_id)
	if collision_polygon == null:
		return
	var polygon := _get_collision_polygon_for_skin(vehicle_id, skin_id)
	if not polygon.is_empty():
		collision_polygon.polygon = polygon

func apply_skin_to_player(sprite: Sprite2D, collision_polygon: CollisionPolygon2D, skin_id: String) -> void:
	apply_vehicle_and_skin_to_player(sprite, collision_polygon, skin_id, DEFAULT_SKIN_ID)

func apply_vehicle_and_skin_to_sprite(sprite: Sprite2D, vehicle_id: String, skin_id: String) -> void:
	_apply_vehicle_and_skin_to_sprite(sprite, vehicle_id, skin_id)

func apply_skin_to_sprite(sprite: Sprite2D, skin_id: String) -> void:
	_apply_vehicle_and_skin_to_sprite(sprite, skin_id, DEFAULT_SKIN_ID)

func is_original_icon_available(vehicle_id: String) -> bool:
	var data := get_vehicle_data(vehicle_id)
	var texture_path := str(data.get("original_icon_texture", "")).strip_edges()
	return not texture_path.is_empty() and ResourceLoader.exists(texture_path)

func is_vehicle_skin_theme_available(vehicle_id: String, skin_id: String) -> bool:
	if not get_vehicle_skin_ids(vehicle_id).has(skin_id):
		return false
	if skin_id == "original_icon":
		return is_original_icon_available(vehicle_id)
	return true

func _apply_vehicle_and_skin_to_sprite(sprite: Sprite2D, vehicle_id: String, skin_id: String) -> void:
	if sprite == null:
		return

	var vehicle_data := get_vehicle_data(vehicle_id)
	var skin_data := get_vehicle_skin_data(vehicle_id, skin_id)
	var texture_path := str(vehicle_data.get("texture", ""))
	var uses_region := bool(vehicle_data.get("uses_region", false))
	var region_rect: Rect2 = vehicle_data.get("region_rect", Rect2())
	var scale: Vector2 = vehicle_data.get("scale", Vector2.ONE)
	var offset: Vector2 = vehicle_data.get("offset", Vector2.ZERO)
	var sprite_modulate := Color.WHITE

	if str(skin_data.get("skin_type", "color")) == "texture_swap" and bool(skin_data.get("available", false)):
		texture_path = str(skin_data.get("texture", texture_path))
		uses_region = bool(skin_data.get("uses_region", false))
		region_rect = skin_data.get("region_rect", Rect2())
		scale = skin_data.get("scale", scale)
		offset = skin_data.get("offset", offset)
		sprite_modulate = Color.WHITE
	else:
		sprite_modulate = skin_data.get("modulate", Color.WHITE)

	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)

	sprite.region_enabled = uses_region
	sprite.region_rect = region_rect if uses_region else Rect2()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = bool(vehicle_data.get("flip_h", false))
	sprite.scale = scale
	sprite.position = offset
	sprite.material = null
	sprite.modulate = sprite_modulate

func get_vehicle_skin_requirement_text(vehicle_id: String, skin_id: String) -> String:
	var skin_data := get_vehicle_skin_data(vehicle_id, skin_id)
	return str(skin_data.get("unlock_requirement", "Unlocked."))

func _get_collision_polygon_for_skin(vehicle_id: String, skin_id: String) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var point_variants = get_vehicle_skin_data(vehicle_id, skin_id).get("collision_points", get_vehicle_data(vehicle_id).get("collision_points", []))
	if point_variants is Array:
		for point_variant in point_variants:
			if point_variant is Vector2:
				polygon.append(point_variant)
	return polygon

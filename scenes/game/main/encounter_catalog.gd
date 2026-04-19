extends RefCounted
class_name EncounterCatalog

const PHASE_OPENING := "opening"
const PHASE_WARMUP := "warmup"
const PHASE_COMBAT_INTRO := "combat_intro"
const PHASE_PRESSURE := "pressure"
const PHASE_ADVANCED := "advanced"
const PHASE_ENDURANCE := "endurance"

static func get_phase_for_time(elapsed: float) -> String:
	if elapsed < 12.0:
		return PHASE_OPENING
	if elapsed < 30.0:
		return PHASE_WARMUP
	if elapsed < 60.0:
		return PHASE_COMBAT_INTRO
	if elapsed < 100.0:
		return PHASE_PRESSURE
	if elapsed < 160.0:
		return PHASE_ADVANCED
	return PHASE_ENDURANCE

static func get_encounters() -> Array[Dictionary]:
	return [
		{
			"id": "opening_single_rock_high",
			"phases": [PHASE_OPENING, PHASE_WARMUP],
			"difficulty": 1,
			"weight": 1.0,
			"duration": 3.0,
			"cooldown": 0.0,
			"tags": ["obstacle", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_top"}
			]
		},
		{
			"id": "opening_single_rock_mid",
			"phases": [PHASE_OPENING, PHASE_WARMUP],
			"difficulty": 1,
			"weight": 1.0,
			"duration": 3.0,
			"cooldown": 0.0,
			"tags": ["obstacle", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "opening_single_rock_low",
			"phases": [PHASE_OPENING, PHASE_WARMUP],
			"difficulty": 1,
			"weight": 1.0,
			"duration": 3.0,
			"cooldown": 0.0,
			"tags": ["obstacle", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_bottom"}
			]
		},
		{
			"id": "warmup_double_rock_lanes",
			"phases": [PHASE_WARMUP],
			"difficulty": 2,
			"weight": 0.85,
			"duration": 4.6,
			"cooldown": 5.0,
			"tags": ["obstacle", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_top"},
				{"at": 2.0, "type": "obstacle", "y_mode": "lane_bottom"}
			]
		},
		{
			"id": "warmup_center_rock_then_ammo",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 1,
			"weight": 0.9,
			"duration": 4.5,
			"cooldown": 8.0,
			"tags": ["obstacle", "ammo", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_mid"},
				{"at": 2.2, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "ammo_intro",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 1,
			"weight": 0.9,
			"duration": 3.5,
			"cooldown": 10.0,
			"tags": ["pickup", "ammo"],
			"spawns": [
				{"at": 0.0, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "warmup_first_drone",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 2,
			"weight": 0.55,
			"duration": 4.0,
			"cooldown": 8.0,
			"requires_elapsed": 22.0,
			"tags": ["combat", "drone", "teaching"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "combat_single_drone",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 1.0,
			"duration": 4.0,
			"cooldown": 5.0,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "combat_drone_high",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.9,
			"duration": 4.0,
			"cooldown": 6.0,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"}
			]
		},
		{
			"id": "combat_drone_low",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.9,
			"duration": 4.0,
			"cooldown": 6.0,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "combat_obstacle_then_drone",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 3,
			"weight": 1.0,
			"duration": 5.4,
			"cooldown": 7.0,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 2.1, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "combat_double_rocks",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.85,
			"duration": 4.8,
			"cooldown": 6.0,
			"tags": ["obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.9, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "breather_ammo",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 0,
			"weight": 1.0,
			"duration": 5.0,
			"cooldown": 8.0,
			"tags": ["breather", "ammo"],
			"spawns": [
				{"at": 1.2, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "breather_double_ammo",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 0,
			"weight": 0.7,
			"duration": 5.5,
			"cooldown": 12.0,
			"tags": ["breather", "ammo"],
			"spawns": [
				{"at": 0.9, "type": "pickup", "y_mode": "lane_top"},
				{"at": 2.2, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "breather_center_pickup",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 0,
			"weight": 0.75,
			"duration": 4.8,
			"cooldown": 10.0,
			"tags": ["breather", "pickup"],
			"spawns": [
				{"at": 1.6, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "glowing_clear_reward",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.8,
			"duration": 5.0,
			"cooldown": 35.0,
			"requires_elapsed": 30.0,
			"tags": ["reward", "glowing_rock"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "glowing_rock", "y_mode": "random_mid"}
			]
		},
		{
			"id": "pressure_turret_intro",
			"phases": [PHASE_PRESSURE],
			"difficulty": 3,
			"weight": 0.65,
			"duration": 6.0,
			"cooldown": 20.0,
			"requires_elapsed": 60.0,
			"tags": ["combat", "turret"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 3.0, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "pressure_mixed_drone_rock",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 1.0,
			"duration": 6.0,
			"cooldown": 8.0,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 2.1, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "pressure_drone_then_rock",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 3,
			"weight": 0.95,
			"duration": 5.4,
			"cooldown": 7.0,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 2.2, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "ammo_after_turret",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 1,
			"weight": 0.85,
			"duration": 4.4,
			"cooldown": 14.0,
			"tags": ["ammo", "pickup"],
			"spawns": [
				{"at": 0.8, "type": "pickup", "y_mode": "lane_mid"},
				{"at": 2.4, "type": "obstacle", "y_mode": "random_high"}
			]
		},
		{
			"id": "glowing_after_pressure",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.7,
			"duration": 5.0,
			"cooldown": 40.0,
			"requires_elapsed": 75.0,
			"tags": ["reward", "glowing_rock"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "glowing_rock", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "advanced_double_drone",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 0.9,
			"duration": 6.2,
			"cooldown": 9.0,
			"tags": ["combat", "drone", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 2.4, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "advanced_rock_drone_rock",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 0.9,
			"duration": 6.4,
			"cooldown": 9.0,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.8, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"},
				{"at": 3.6, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "advanced_turret_then_drone",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 0.7,
			"duration": 6.2,
			"cooldown": 18.0,
			"requires_elapsed": 100.0,
			"tags": ["combat", "turret", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 2.8, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "ammo_after_mixed_wave",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 1,
			"weight": 0.8,
			"duration": 5.0,
			"cooldown": 14.0,
			"tags": ["ammo", "pickup", "breather"],
			"spawns": [
				{"at": 1.2, "type": "pickup", "y_mode": "lane_mid"},
				{"at": 2.6, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "endurance_triple_mixed",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.85,
			"duration": 7.2,
			"cooldown": 10.0,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 2.1, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"},
				{"at": 4.2, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "endurance_turret_pressure",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.65,
			"duration": 6.5,
			"cooldown": 20.0,
			"requires_elapsed": 160.0,
			"tags": ["combat", "turret", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 2.5, "type": "obstacle", "y_mode": "random_high"},
				{"at": 4.4, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "endurance_double_drone_rock",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.8,
			"duration": 7.0,
			"cooldown": 10.0,
			"tags": ["mixed", "combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 2.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"},
				{"at": 4.0, "type": "obstacle", "y_mode": "lane_mid"}
			]
		},
	]

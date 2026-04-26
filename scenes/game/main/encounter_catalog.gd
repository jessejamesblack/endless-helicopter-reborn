extends RefCounted
class_name EncounterCatalog

const PHASE_OPENING := "opening"
const PHASE_WARMUP := "warmup"
const PHASE_COMBAT_INTRO := "combat_intro"
const PHASE_PRESSURE := "pressure"
const PHASE_ADVANCED := "advanced"
const PHASE_ENDURANCE := "endurance"

static func get_phase_for_time(elapsed: float) -> String:
	if elapsed < 8.0:
		return PHASE_OPENING
	if elapsed < 22.0:
		return PHASE_WARMUP
	if elapsed < 48.0:
		return PHASE_COMBAT_INTRO
	if elapsed < 82.0:
		return PHASE_PRESSURE
	if elapsed < 120.0:
		return PHASE_ADVANCED
	return PHASE_ENDURANCE

static func get_encounters() -> Array[Dictionary]:
	return [
		{
			"id": "opening_single_rock_high",
			"phases": [PHASE_OPENING, PHASE_WARMUP],
			"difficulty": 1,
			"weight": 1.0,
			"duration": 2.2,
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
			"duration": 2.2,
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
			"duration": 2.2,
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
			"weight": 1.05,
			"duration": 3.2,
			"cooldown": 3.2,
			"tags": ["obstacle", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_top"},
				{"at": 1.25, "type": "obstacle", "y_mode": "lane_bottom"}
			]
		},
		{
			"id": "warmup_center_rock_then_ammo",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 1,
			"weight": 0.9,
			"duration": 3.6,
			"cooldown": 6.0,
			"tags": ["obstacle", "ammo", "safe"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "lane_mid"},
				{"at": 1.7, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "ammo_intro",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 1,
			"weight": 0.9,
			"duration": 3.0,
			"cooldown": 8.0,
			"tags": ["pickup", "ammo"],
			"spawns": [
				{"at": 0.0, "type": "pickup", "y_mode": "lane_mid"}
			]
		},
		{
			"id": "warmup_first_drone",
			"phases": [PHASE_WARMUP, PHASE_COMBAT_INTRO],
			"difficulty": 2,
			"weight": 1.25,
			"duration": 3.2,
			"cooldown": 4.5,
			"requires_elapsed": 9.0,
			"tags": ["combat", "drone", "teaching"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "combat_single_drone",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 0.9,
			"duration": 3.3,
			"cooldown": 3.8,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "combat_drone_high",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 1.0,
			"duration": 3.3,
			"cooldown": 4.2,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"}
			]
		},
		{
			"id": "combat_drone_low",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 1.0,
			"duration": 3.3,
			"cooldown": 4.2,
			"tags": ["combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "combat_obstacle_then_drone",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 3,
			"weight": 1.2,
			"duration": 4.3,
			"cooldown": 5.2,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.8, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "combat_double_rocks",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 2,
			"weight": 1.05,
			"duration": 3.8,
			"cooldown": 4.4,
			"tags": ["obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.6, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "breather_ammo",
			"phases": [PHASE_COMBAT_INTRO, PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 0,
			"weight": 0.55,
			"duration": 5.0,
			"cooldown": 12.0,
			"tags": ["breather", "ammo"],
			"spawns": [
				{"at": 1.2, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "breather_double_ammo",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 0,
			"weight": 0.3,
			"duration": 5.5,
			"cooldown": 18.0,
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
			"weight": 0.28,
			"duration": 4.8,
			"cooldown": 15.0,
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
			"weight": 0.85,
			"duration": 5.6,
			"cooldown": 15.0,
			"requires_elapsed": 60.0,
			"tags": ["combat", "turret"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 3.0, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "pressure_double_drone_crossfire",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 1.05,
			"duration": 4.8,
			"cooldown": 6.6,
			"requires_elapsed": 62.0,
			"tags": ["combat", "drone", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 1.8, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "pressure_mixed_drone_rock",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 1.25,
			"duration": 4.9,
			"cooldown": 5.8,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.7, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "pressure_drone_then_rock",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 3,
			"weight": 1.1,
			"duration": 4.5,
			"cooldown": 5.4,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 1.9, "type": "obstacle", "y_mode": "random_low"}
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
			"weight": 1.18,
			"duration": 5.0,
			"cooldown": 6.2,
			"tags": ["combat", "drone", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 2.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "advanced_powerup_reward_window",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 1,
			"weight": 0.35,
			"duration": 5.2,
			"cooldown": 24.0,
			"requires_elapsed": 95.0,
			"tags": ["reward", "powerup", "breather"],
			"spawns": [
				{"at": 1.4, "type": "powerup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "advanced_shielded_drone_mix",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.82,
			"duration": 5.4,
			"cooldown": 10.0,
			"requires_elapsed": 105.0,
			"tags": ["combat", "drone", "modifier", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "modifier": "shielded", "y_mode": "random_high"},
				{"at": 2.1, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "pressure_ion_mine_layer",
			"phases": [PHASE_PRESSURE, PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 0.78,
			"duration": 5.4,
			"cooldown": 10.5,
			"requires_elapsed": 72.0,
			"tags": ["combat", "mine_layer", "biome_event", "ion_storm"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "mine_layer", "y_mode": "random_mid"},
				{"at": 2.2, "type": "obstacle", "y_mode": "random_high"}
			]
		},
		{
			"id": "advanced_storm_pocket_reward",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 3,
			"weight": 0.46,
			"duration": 6.0,
			"cooldown": 18.0,
			"requires_elapsed": 104.0,
			"tags": ["biome_event", "ion_storm", "reward", "powerup"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_low"},
				{"at": 1.8, "type": "enemy", "kind": "mine_layer", "modifier": "armored", "y_mode": "random_high"},
				{"at": 3.9, "type": "powerup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "endurance_elite_drone_pressure",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 6,
			"weight": 0.72,
			"duration": 6.0,
			"cooldown": 18.0,
			"requires_elapsed": 150.0,
			"tags": ["combat", "elite", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "modifier": "elite", "y_mode": "random_mid"},
				{"at": 2.6, "type": "powerup", "y_mode": "random_low"}
			]
		},
		{
			"id": "endurance_elite_minefield",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 6,
			"weight": 0.58,
			"duration": 6.2,
			"cooldown": 18.0,
			"requires_elapsed": 165.0,
			"tags": ["combat", "elite", "mine_layer", "biome_event"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "mine_layer", "modifier": "elite", "y_mode": "random_mid"},
				{"at": 2.3, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 4.2, "type": "pickup", "y_mode": "random_low"}
			]
		},
		{
			"id": "advanced_rock_drone_rock",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 1.12,
			"duration": 5.2,
			"cooldown": 6.4,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.5, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"},
				{"at": 3.1, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "advanced_turret_then_drone",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 4,
			"weight": 1.0,
			"duration": 5.8,
			"cooldown": 13.0,
			"requires_elapsed": 92.0,
			"tags": ["combat", "turret", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 2.4, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"}
			]
		},
		{
			"id": "advanced_turret_double_drone",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.92,
			"duration": 6.2,
			"cooldown": 14.0,
			"requires_elapsed": 116.0,
			"tags": ["combat", "turret", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 2.1, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 4.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"}
			]
		},
		{
			"id": "ammo_after_mixed_wave",
			"phases": [PHASE_ADVANCED, PHASE_ENDURANCE],
			"difficulty": 1,
			"weight": 0.35,
			"duration": 5.0,
			"cooldown": 20.0,
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
			"weight": 1.15,
			"duration": 5.9,
			"cooldown": 7.2,
			"tags": ["mixed", "combat", "obstacle"],
			"spawns": [
				{"at": 0.0, "type": "obstacle", "y_mode": "random_high"},
				{"at": 1.8, "type": "enemy", "kind": "alien_drone", "y_mode": "random_mid"},
				{"at": 3.6, "type": "obstacle", "y_mode": "random_low"}
			]
		},
		{
			"id": "endurance_turret_pressure",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 0.95,
			"duration": 5.7,
			"cooldown": 13.0,
			"requires_elapsed": 140.0,
			"tags": ["combat", "turret", "mixed"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "stationary_turret", "y_mode": "bottom_turret"},
				{"at": 2.1, "type": "obstacle", "y_mode": "random_high"},
				{"at": 3.9, "type": "pickup", "y_mode": "random_mid"}
			]
		},
		{
			"id": "endurance_double_drone_rock",
			"phases": [PHASE_ENDURANCE],
			"difficulty": 5,
			"weight": 1.08,
			"duration": 5.8,
			"cooldown": 7.0,
			"tags": ["mixed", "combat", "drone"],
			"spawns": [
				{"at": 0.0, "type": "enemy", "kind": "alien_drone", "y_mode": "random_high"},
				{"at": 1.7, "type": "enemy", "kind": "alien_drone", "y_mode": "random_low"},
				{"at": 3.4, "type": "obstacle", "y_mode": "lane_mid"}
			]
		},
	]

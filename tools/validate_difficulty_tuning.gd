extends SceneTree

const EncounterCatalog = preload("res://scenes/game/main/encounter_catalog.gd")
const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_condition(_failures, EncounterCatalog.get_phase_for_time(35.0) == EncounterCatalog.PHASE_COMBAT_INTRO, "35 seconds should already be in combat_intro.")
	Helper.assert_condition(_failures, EncounterCatalog.get_phase_for_time(70.0) == EncounterCatalog.PHASE_PRESSURE, "70 seconds should already be in pressure.")
	Helper.assert_condition(_failures, EncounterCatalog.get_phase_for_time(145.0) == EncounterCatalog.PHASE_ENDURANCE, "145 seconds should already be in endurance.")
	var encounters := EncounterCatalog.get_encounters()
	var encounter_ids: Array[String] = []
	for encounter in encounters:
		encounter_ids.append(str(encounter.get("id", "")))
	Helper.assert_condition(_failures, encounter_ids.has("pressure_double_drone_crossfire"), "Difficulty tuning should add pressure_double_drone_crossfire.")
	Helper.assert_condition(_failures, encounter_ids.has("advanced_turret_double_drone"), "Difficulty tuning should add advanced_turret_double_drone.")
	var spawner_text := Helper.read_text("res://scenes/game/main/spawner.gd")
	Helper.assert_condition(_failures, spawner_text.contains("FIRST_TURRET_SECONDS := 60.0"), "Spawner should keep turrets gated until 60 seconds.")
	Helper.assert_condition(_failures, spawner_text.contains("MAX_ACTIVE_HOSTILES_PRESSURE := 6"), "Spawner should allow more active hostiles in pressure.")
	Helper.finish(self, _failures, "Difficulty tuning validation completed successfully.")

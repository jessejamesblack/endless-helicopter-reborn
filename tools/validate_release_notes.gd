extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	Helper.assert_file_exists(_failures, "res://docs/release_notes/latest.md")
	Helper.assert_file_exists(_failures, "res://docs/release_notes/discord_summary.md")
	var latest := Helper.read_text("res://docs/release_notes/latest.md").strip_edges()
	var summary := Helper.read_text("res://docs/release_notes/discord_summary.md").strip_edges()
	Helper.assert_condition(_failures, latest.length() >= 120, "Release notes latest.md should contain readable release notes.")
	var bullet_count := 0
	for line in summary.split("\n"):
		if line.strip_edges().begins_with("-"):
			bullet_count += 1
	Helper.assert_condition(_failures, bullet_count >= 3 and bullet_count <= 6, "Discord summary should contain 3 to 6 bullets.")
	Helper.finish(self, _failures, "Release note validation completed successfully.")

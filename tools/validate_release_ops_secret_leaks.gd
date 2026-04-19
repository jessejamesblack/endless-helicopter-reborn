extends SceneTree

const Helper = preload("res://tools/validate_sprint6_helpers.gd")

const PATTERNS := [
	"discord.com/api/webhooks/",
	"discordapp.com/api/webhooks/",
	"-----BEGIN PRIVATE KEY-----",
]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var paths := Helper.collect_text_files("res://", PackedStringArray([".gd", ".ts", ".sql", ".md", ".yml", ".ps1", ".cfg", ".tscn", ".json"]))
	for path in paths:
		if path.ends_with("tools/validate_release_ops_secret_leaks.gd"):
			continue
		var text := Helper.read_text(path)
		for pattern in PATTERNS:
			if text.contains(pattern):
				_failures.append("Potential secret leak pattern found in %s: %s" % [path, pattern])
	Helper.finish(self, _failures, "Release-ops secret leak validation completed successfully.")

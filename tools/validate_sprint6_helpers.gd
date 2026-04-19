extends RefCounted
class_name ValidateSprint6Helpers

static func assert_condition(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

static func assert_file_exists(failures: Array[String], path: String) -> void:
	assert_condition(failures, FileAccess.file_exists(path), "Missing required file: %s" % path)

static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

static func finish(tree: SceneTree, failures: Array[String], success_message: String) -> void:
	if failures.is_empty():
		print(success_message)
		tree.quit()
		return
	for failure in failures:
		push_error(failure)
	tree.quit(1)

static func collect_text_files(root_path: String, extensions: PackedStringArray) -> Array[String]:
	var results: Array[String] = []
	_collect_recursive(root_path, extensions, results)
	return results

static func _collect_recursive(path: String, extensions: PackedStringArray, results: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name.begins_with(".godot") or name == ".git" or name == "build":
			name = directory.get_next()
			continue
		var child_path := path.path_join(name)
		if directory.current_is_dir():
			_collect_recursive(child_path, extensions, results)
		else:
			if name == "google-services.json":
				name = directory.get_next()
				continue
			for extension in extensions:
				if child_path.ends_with(extension):
					results.append(child_path)
					break
		name = directory.get_next()
	directory.list_dir_end()

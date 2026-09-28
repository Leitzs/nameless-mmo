extends SceneTree
## Loads every script, scene, resource and shader of the project (compiling every script under the strict typing
## warnings) and instantiates every scene except the maps. Exits with 1 when anything fails:
##   godot --headless --path godot -s res://tools/check_project.gd

var _failures := 0


func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	for path in files:
		var resource := load(path)
		if resource == null:
			printerr("CHECK failed to load ", path)
			_failures += 1
			continue
		if resource is PackedScene and not path.begins_with("res://maps/"):
			var node := (resource as PackedScene).instantiate()
			if node == null:
				printerr("CHECK failed to instantiate ", path)
				_failures += 1
			else:
				node.free()
	print("CHECK done: %d files, %d failures" % [files.size(), _failures])
	quit(1 if _failures > 0 else 0)


func _collect(folder: String, files: Array[String]) -> void:
	for directory in DirAccess.get_directories_at(folder):
		if not directory.begins_with("."):
			_collect(folder.path_join(directory), files)
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "tscn", "tres", "gdshader"]:
			files.append(folder.path_join(file))

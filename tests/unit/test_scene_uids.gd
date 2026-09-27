extends GutTest

## Purpose: every ext_resource uid in this project's scenes names what its target declares.
##
## Godot keeps .godot/uid_cache.bin, which still maps a stale uid to its file on the machine that saved the scene,
## so a wrong uid loads there and fails, or falls back to the path with an error, on a fresh clone. A re-save of
## world.tscn and snow_demo.tscn once wrote nine uids that nothing in the project declares (a moved addon's, an
## older import's). The uid a target declares lives in a different place per kind: a scene or resource carries it
## in its own header, a script in its .uid sidecar, an imported asset in its .import file.

const SCENE_DIRS: PackedStringArray = ["res://scenes"]


func test_every_ext_resource_uid_matches_its_target() -> void:
	var wrong: PackedStringArray = []
	var pattern := RegEx.create_from_string("^\\[ext_resource type=\"[^\"]+\" uid=\"(uid://[^\"]+)\" path=\"([^\"]+)\"")
	for dir: String in SCENE_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".tscn"):
				continue
			var scene_path: String = dir.path_join(file)
			for line: String in FileAccess.get_file_as_string(scene_path).split("\n"):
				var match: RegExMatch = pattern.search(line)
				if match == null:
					continue
				var declared: String = _declared_uid(match.get_string(2))
				if not declared.is_empty() and declared != match.get_string(1):
					wrong.append("%s: %s has %s, target declares %s" % [file, match.get_string(2), match.get_string(1), declared])
	assert_eq(wrong.size(), 0, "ext_resource uids off their targets:\n" + "\n".join(wrong))


## The uid [param path] declares, or "" for a kind that declares none (a Dialogic timeline, HTerrain data).
func _declared_uid(path: String) -> String:
	if path.ends_with(".gd") or path.ends_with(".gdshader") or path.ends_with(".gdshaderinc"):
		return FileAccess.get_file_as_string(path + ".uid").strip_edges() if FileAccess.file_exists(path + ".uid") else ""
	if path.ends_with(".tscn") or path.ends_with(".tres"):
		return _uid_in(FileAccess.get_file_as_string(path).get_slice("\n", 0))
	if FileAccess.file_exists(path + ".import"):
		for line: String in FileAccess.get_file_as_string(path + ".import").split("\n"):
			if line.begins_with("uid="):
				return _uid_in(line)
	return ""


func _uid_in(text: String) -> String:
	var match: RegExMatch = RegEx.create_from_string("uid=\"(uid://[^\"]+)\"").search(text)
	return match.get_string(1) if match else ""

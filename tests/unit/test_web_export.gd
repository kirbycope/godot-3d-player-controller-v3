extends GutTest

## Purpose: the Web preset packs everything a script in scenes/ preloads by path.
##
## The Web preset exports selected resources and their dependencies (export_filter="resources").
## A preload in a script is not a dependency the exporter follows, so a scene a script names by
## path reaches the build only through export_files or through a scene that is exported and
## references it. title_screen.gd's save_slot_button.tscn was neither, and the preload of a missing
## file is a compile error that took the title screen and main.gd down with it in the web build.
## A stale entry is caught too: the exporter logs an error for each and buries the real ones.

const PRESET_PATH: String = "res://export_presets.cfg"
const SCENES_DIR: String = "res://scenes"

var _export_files: PackedStringArray = []


func before_all() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load(PRESET_PATH), OK, "export_presets.cfg should be readable")
	assert_eq(presets.get_value("preset.0", "name", ""), "Web", "preset.0 is the Web preset")
	_export_files = presets.get_value("preset.0", "export_files", PackedStringArray())


func test_every_scene_a_script_preloads_reaches_the_web_build() -> void:
	var referenced: PackedStringArray = _scene_paths_referenced_by_scenes()
	var missing: PackedStringArray = []
	for path: String in _scene_paths_preloaded_by_scripts():
		if not _export_files.has(path) and not referenced.has(path):
			missing.append(path)
	assert_eq(missing.size(), 0, "Preloaded but neither in export_files nor in an exported scene: %s" % ", ".join(missing))


func test_every_export_file_exists() -> void:
	var stale: PackedStringArray = []
	for path: String in _export_files:
		if not FileAccess.file_exists(path):
			stale.append(path)
	assert_eq(stale.size(), 0, "export_files names files that do not exist: %s" % ", ".join(stale))


## Every res://scenes/*.tscn a script under scenes/ preloads.
func _scene_paths_preloaded_by_scripts() -> PackedStringArray:
	var found: PackedStringArray = []
	var pattern := RegEx.create_from_string("preload\\(\"(res://scenes/[^\"]+\\.tscn)\"\\)")
	for file: String in DirAccess.get_files_at(SCENES_DIR):
		if not file.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string(SCENES_DIR.path_join(file))
		for match: RegExMatch in pattern.search_all(text):
			var path: String = match.get_string(1)
			if not found.has(path):
				found.append(path)
	return found


## Every res://scenes/*.tscn some scene under scenes/ names as an ext_resource. The scenes
## exported by path pull their ext_resources in with them, and world.tscn and main.tscn between
## them reach every scene in the folder that a script does not instance itself.
func _scene_paths_referenced_by_scenes() -> PackedStringArray:
	var found: PackedStringArray = []
	var pattern := RegEx.create_from_string("path=\"(res://scenes/[^\"]+\\.tscn)\"")
	for file: String in DirAccess.get_files_at(SCENES_DIR):
		if not file.ends_with(".tscn"):
			continue
		var text: String = FileAccess.get_file_as_string(SCENES_DIR.path_join(file))
		for match: RegExMatch in pattern.search_all(text):
			var path: String = match.get_string(1)
			if not found.has(path):
				found.append(path)
	return found

extends GutTest

## Purpose: every bone index saved in scenes/godot_plush.tscn still points at the bone it names.
##
## A SpringBoneSimulator3D setting stores a bone name and that bone's index side by side, and the
## engine is handed the index. assets/galacticlake/godou.blend reordered its armature on a reimport,
## trading the right arm chain for the left leg chain, and the scene kept the old indices. Loading
## it therefore handed the engine root "l.leg" with end "r.hand", which is not a chain, and printed
##
##     End bone must be the same as or a child of the root bone
##
## eight times on every run, a plain single player load of the game included. The engine rebuilds
## the chains from the names once the node is in the tree, so the plush still moved and still looked
## right, but the file was describing an armature that no longer exists and the errors buried real
## ones.
##
## The saved text is what this reads, not the loaded node, because by the time the node is in the
## tree it has already been repaired and shows nothing wrong. Only the file can show the drift.

const PLUSH_SCENE: String = "res://scenes/godot_plush.tscn"

## Four chains, each saving a root, an end and three joints.
const SAVED_BONE_REFERENCES: int = 20

var _skeleton: Skeleton3D
var _simulator: SpringBoneSimulator3D


## add_child_autofree releases after each test, so the plush is instantiated for each one.
func before_each() -> void:
	var plush: Node3D = (load(PLUSH_SCENE) as PackedScene).instantiate()
	add_child_autofree(plush)
	_skeleton = plush.get_node("godou/Armature/Skeleton3D")
	_simulator = _skeleton.get_node("SpringBoneSimulator3D")


func test_every_saved_bone_index_matches_the_bone_it_names() -> void:
	var saved: Dictionary = _saved_settings()
	assert_gt(saved.size(), 0, "scenes/godot_plush.tscn should carry spring bone settings")

	var checked: int = 0
	for key: String in saved:
		if not key.ends_with("_name"):
			continue
		var index_key: String = key.trim_suffix("_name")
		if not saved.has(index_key):
			continue
		var bone_name: String = (saved[key] as String).trim_prefix("\"").trim_suffix("\"")
		var actual: int = _skeleton.find_bone(bone_name)
		checked += 1
		assert_eq(
			int(saved[index_key]),
			actual,
			"%s is saved as %s, but %s is bone %d in the armature" % [index_key, saved[index_key], bone_name, actual]
		)

	assert_eq(checked, SAVED_BONE_REFERENCES, "the file should still save an index beside every bone name")


func test_every_spring_bone_chain_is_built() -> void:
	assert_eq(_simulator.get_setting_count(), 4, "an arm and a leg on each side")
	for setting: int in _simulator.get_setting_count():
		assert_eq(
			_simulator.get_joint_count(setting),
			3,
			"%s to %s should be a three bone chain" % [
				_simulator.get_root_bone_name(setting),
				_simulator.get_end_bone_name(setting),
			]
		)


## The [code]settings/...[/code] lines of the saved scene, as key to unparsed value.
func _saved_settings() -> Dictionary:
	var values: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(PLUSH_SCENE).split("\n"):
		if not line.begins_with("settings/"):
			continue
		var parts: PackedStringArray = line.split(" = ", true, 1)
		if parts.size() == 2:
			values[parts[0]] = parts[1]
	return values

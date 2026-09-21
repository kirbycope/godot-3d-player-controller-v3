extends GutTest

## Purpose: the world Player's held-object connector is wired as a scene resource, not a path string, so the
## web export packs it (a UID string is invisible to the exporter's dependency scan).

const WORLD_PLAYER: GDScript = preload("res://tests/world_player_template.gd")


func test_the_held_object_connector_is_a_packed_scene_dependency() -> void:
	var player: Player = WORLD_PLAYER.take()
	add_child_autofree(player)
	var held: HeldObject = player.get_node("HeldObject") as HeldObject
	assert_not_null(held)
	assert_true(held.connector_scene is PackedScene, "connector_scene is a PackedScene the exporter can follow")
	assert_eq(held.connector_scene.resource_path, "res://assets/loop_box/VFX.tscn")

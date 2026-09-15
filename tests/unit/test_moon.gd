extends GutTest

## Purpose: the moon's gravity well turns a character's up direction away from its centre while they are in range
## and puts it back to plain up when they leave.

const MOON_SCENE: PackedScene = preload("res://scenes/moon.tscn")


func test_up_points_away_from_the_moon_in_range_and_back_up_out_of_it() -> void:
	var moon: StaticBody3D = MOON_SCENE.instantiate() as StaticBody3D
	add_child_autofree(moon)
	var body := CharacterBody3D.new()
	add_child_autofree(body)
	body.global_position = moon.global_position + Vector3(10.0, 0.0, 0.0)
	moon._on_player_detection_body_entered(body)
	await wait_physics_frames(2)
	assert_almost_eq(body.up_direction, Vector3.RIGHT, Vector3.ONE * 0.01, "Up is away from the centre")
	moon._on_player_detection_body_exited(body)
	assert_eq(body.up_direction, Vector3.UP, "Leaving puts up back")
	await wait_physics_frames(2)
	assert_eq(body.up_direction, Vector3.UP, "and the well no longer pulls on it")


func test_the_moon_is_lit_by_its_normal_map_at_full_resolution() -> void:
	var moon: StaticBody3D = MOON_SCENE.instantiate() as StaticBody3D
	add_child_autofree(moon)
	var mesh: MeshInstance3D = moon.get_node("MeshInstance3D")
	var material: StandardMaterial3D = (mesh.mesh as SphereMesh).material as StandardMaterial3D

	# The scene carried a normal_texture and a normal_scale for a long time without this flag, and
	# StandardMaterial3D ignores the texture entirely until the feature is on, so the relief simply
	# was not there. Assigning the texture in the inspector sets it; assigning one in code does not.
	assert_true(material.normal_enabled, "The normal map has to be switched on to be used at all")
	assert_not_null(material.normal_texture, "and there has to be one")
	assert_not_null(material.albedo_texture, "and a colour map")
	assert_eq(
		material.normal_texture.get_size(),
		material.albedo_texture.get_size(),
		"Both NASA maps are the same equirectangular projection, so they share a size"
	)
	assert_gt(material.albedo_texture.get_width(), 2048, "Full resolution on disk; the web build caps itself")

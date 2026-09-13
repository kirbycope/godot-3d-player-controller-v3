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

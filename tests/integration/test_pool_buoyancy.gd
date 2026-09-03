extends GutTest

## Purpose: In the world, the pool floats the beach ball and the boat is moored on the pool's waves.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")


func test_beach_ball_floats_in_the_pool_and_the_boat_is_moored() -> void:
	var world: Node = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var pool: Buoyancy = world.get_node("Pool/WaterArea3D")
	var ball: RigidBody3D = world.get_node("BeachBall")
	ball.global_position = Vector3(4.0, 1.0, -24.0)
	await wait_seconds(3.0)
	assert_true(pool.bodies.has(ball), "The pool tracks the ball")
	assert_gt(ball.global_position.y, -1.0, "The ball floats instead of sinking to the pool floor")
	assert_lt(ball.global_position.y, 0.5)
	var boat: AnimatableBody3D = world.get_node("Boat")
	assert_eq(boat.water, pool, "The boat rides the pool's waves")
	assert_almost_eq(boat.global_position.y, 0.0, 0.1)

extends GutTest

## Purpose: A parked car stays put. Godot's wheel brake creeps a standing VehicleBody3D at a speed that
## scales with the brake force, so the car freezes once settled and wakes when driven.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")


func test_parked_car_freezes_and_wakes_for_a_driver() -> void:
	var world: Node = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_seconds(2.0)
	var car: VehicleBody3D = world.get_node("HondaCRV")
	assert_true(car.freeze, "A settled, driverless car is frozen")
	var parked: Vector3 = car.global_position
	await wait_seconds(2.0)
	assert_almost_eq(car.global_position.distance_to(parked), 0.0, 0.001, "The parked car does not creep")
	var player: Player = world.get_node("Players/1")
	car.set_driver(player)
	car.set_drive_input(true, false, false, 0.0)
	assert_false(car.freeze, "Drive input wakes the car")

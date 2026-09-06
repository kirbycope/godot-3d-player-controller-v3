extends GutTest

## Purpose: To test the actions and events related to the demo car scene.


## Shared base setup/teardown for test classes that inherit from _this_ one.
class CarTestBase:
	extends IntegrationTestBase

	var MainScene = load("res://tests/integration/test_car.tscn")
	var PlayerScene = load("res://addons/3d_player_controller/scenes/player.tscn")
	var main_instance = null
	var car_instance = null
	var player_instance = null

	## Runs before each test is executed.
	func before_each() -> void:
		main_instance = MainScene.instantiate()
		add_child_autofree(main_instance)
		car_instance = main_instance.get_node("CRV")

	## Runs after each test is executed.
	func after_each() -> void:
		if is_instance_valid(main_instance):
			main_instance.free()
			main_instance = null
			car_instance = null
			player_instance = null

	## Helper method to attach and configure a Player instance seated in the car.
	func setup_player_driving() -> void:
		if not player_instance:
			player_instance = PlayerScene.instantiate()
			main_instance.add_child(player_instance)

		player_instance.controls.current_input_type = 0
		player_instance.is_driving_in = car_instance
		car_instance.set_driver(player_instance)
		player_instance.state_machine.travel(player_instance.current_state, NodeStateMachine.States.DRIVING)
		player_instance.is_entering_vehicle = false
		for child in car_instance.get_children():
			if child is VehicleWheel3D:
				child.brake = 0.0

	## Helper getter to access the Driving state node on the player instance.
	var driving_state: Driving:
		get:
			return player_instance.state_machine.get_node("Driving") as Driving if player_instance and player_instance.state_machine else null


## Tests related to the function performed by an action.
class TestCarActions:
	extends CarTestBase

	## Test Case: The Driving state only forwards inputs; a mock vehicle receives them.
	func test_driving_passes_inputs_to_vehicle():
		var mock = MockVehicle.new()
		main_instance.add_child(mock)
		player_instance = PlayerScene.instantiate()
		main_instance.add_child(player_instance)
		player_instance.controls.current_input_type = 0
		player_instance.is_driving_in = mock
		player_instance.state_machine.travel(player_instance.current_state, NodeStateMachine.States.DRIVING)
		player_instance.is_entering_vehicle = false

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(driving_state.keyboard_accelerate_action)
		sender.action_down("move_left")
		await wait_physics_frames(3)

		assert_true(mock.accelerate, "Accelerate input should reach the vehicle.")
		assert_false(mock.brake_input, "Brake input should be false when not pressed.")
		assert_gt(mock.steer, 0.0, "Steer input should be positive when steering left.")
		assert_eq(player_instance.global_position, mock.get_node("DriverSeat").global_position, "Player should sit on the DriverSeat marker.")
		sender.action_up(driving_state.keyboard_accelerate_action)
		sender.action_up("move_left")

		player_instance.state_machine.travel(NodeStateMachine.States.DRIVING, NodeStateMachine.States.STANDING)
		assert_null(mock.driver, "Stopping the state hands set_driver(null) to the vehicle.")

	## Test Case: Testing the car being driven forward.
	func test_car_driven_forward():
		setup_player_driving()
		assert_eq(car_instance.get_node("VehicleWheel3D").engine_force, 0.0, "Car engine force should be 0.0 initially.")

		var action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(10)

		assert_true(car_instance.is_driving_this_car, "The first drive input seats the driver.")
		assert_gt(car_instance.get_node("VehicleWheel3D").engine_force, 0.0, "Car engine force should be positive when accelerating forward.")
		sender.action_up(action)

	## Test Case: Testing the car reversing.
	func test_car_reversing():
		setup_player_driving()
		car_instance.linear_velocity = Vector3.ZERO
		car_instance.angular_velocity = Vector3.ZERO
		assert_eq(car_instance.get_node("VehicleWheel3D").engine_force, 0.0, "Car engine force should be 0.0 initially.")

		var action: StringName = driving_state.keyboard_brake_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(10)

		assert_lt(car_instance.get_node("VehicleWheel3D").engine_force, 0.0, "Car engine force should be negative when reversing.")
		sender.action_up(action)

	## Test Case: Testing the car braking.
	func test_car_braking():
		setup_player_driving()
		car_instance.linear_velocity = Vector3(0.0, 0.0, 5.0)
		assert_eq(car_instance.get_node("VehicleWheel3D").brake, 0.0, "Car brake should be 0.0 initially.")

		var action: StringName = driving_state.keyboard_brake_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(10)

		assert_gt(car_instance.get_node("VehicleWheel3D").brake, 0.0, "Car brake force should be positive when braking.")
		sender.action_up(action)

	## Test Case: Testing the car handbrake action.
	func test_car_handbrake():
		setup_player_driving()
		assert_eq(car_instance.get_node("VehicleWheel3D2").brake, 0.0, "Rear brake should be 0.0 initially.")

		var action: StringName = driving_state.keyboard_handbrake_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(10)

		assert_gt(car_instance.get_node("VehicleWheel3D2").brake, 0.0, "Rear brake should be positive when handbrake is held.")
		assert_eq(car_instance.get_node("VehicleWheel3D2").engine_force, 0.0, "Rear engine force should be 0.0 when handbrake is held and not accelerating.")
		sender.action_up(action)

	## Test Case: Testing the car steering left.
	func test_car_steering_left():
		setup_player_driving()
		assert_eq(car_instance.steering, 0.0, "Car steering should be 0.0 initially.")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_left")
		await wait_physics_frames(5)

		assert_gt(car_instance.steering, 0.0, "Car steering should be positive when steering left.")
		sender.action_up("move_left")

	## Test Case: Testing the car steering right.
	func test_car_steering_right():
		setup_player_driving()
		assert_eq(car_instance.steering, 0.0, "Car steering should be 0.0 initially.")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_right")
		await wait_physics_frames(5)

		assert_lt(car_instance.steering, 0.0, "Car steering should be negative when steering right.")
		sender.action_up("move_right")

	## Test Case: Testing the car acceleration SFX with keyboard input.
	func test_car_accelerate_sfx_keyboard():
		setup_player_driving()
		player_instance.controls.current_input_type = 0

		var action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		var is_accel_sfx_playing: bool = car_instance.sfx_engine_speed_up_outside.playing or car_instance.sfx_engine_speed_up_inside.playing
		assert_true(is_accel_sfx_playing, "Acceleration engine SFX should play when holding keyboard accelerate action.")
		sender.action_up(action)

	## Test Case: Testing the car acceleration SFX with pad input.
	func test_car_accelerate_sfx_pad():
		setup_player_driving()
		player_instance.controls.current_input_type = 1

		var action: StringName = driving_state.pad_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		var is_accel_sfx_playing: bool = car_instance.sfx_engine_speed_up_outside.playing or car_instance.sfx_engine_speed_up_inside.playing
		assert_true(is_accel_sfx_playing, "Acceleration engine SFX should play when holding pad accelerate action.")
		sender.action_up(action)

	## Test Case: Testing that rev SFX plays once per acceleration press while holding brake.
	func test_car_rev_sfx_once_per_accel_press():
		setup_player_driving()
		car_instance.linear_velocity = Vector3.ZERO

		var brake_action: StringName = driving_state.keyboard_brake_action
		var accel_action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(brake_action)
		sender.action_down(accel_action)
		await wait_physics_frames(5)

		assert_true(car_instance._revved_current_accel, "Car should register rev state for current acceleration press.")

		if car_instance.sfx_engine_rev.playing:
			car_instance.sfx_engine_rev.stop()
		await wait_physics_frames(5)

		assert_false(car_instance.sfx_engine_rev.playing, "Rev SFX should not re-trigger after finishing.")
		assert_true(car_instance.sfx_engine_running_outside.playing or car_instance.sfx_engine_running_inside.playing, "Engine should revert to running SFX after rev finishes.")

		sender.action_up(accel_action)
		sender.action_up(brake_action)

	## Test Case: Testing that parked car tires are locked with brake force.
	func test_car_parked_tires_locked():
		await wait_physics_frames(5)
		for child in car_instance.get_children():
			if child is VehicleWheel3D:
				assert_eq(child.brake, car_instance.max_brake_force, "Parked car tires should be locked with max_brake_force.")


## Minimal vehicle implementing the Driving state's contract.
class MockVehicle extends RigidBody3D:
	var driver: Player
	var accelerate: bool = false
	var brake_input: bool = false
	var handbrake: bool = false
	var steer: float = 0.0

	func _init() -> void:
		freeze = true
		var seat = Marker3D.new()
		seat.name = "DriverSeat"
		seat.position = Vector3(0.5, 0.2, 0.0)
		add_child(seat)

	func set_driver(p: Player) -> void:
		driver = p

	func set_drive_input(accelerate_in: bool, brake_in: bool, handbrake_in: bool, steer_in: float) -> void:
		accelerate = accelerate_in
		brake_input = brake_in
		handbrake = handbrake_in
		steer = steer_in


## Tests related to the function performed by an event.
class TestCarEvents:
	extends CarTestBase

	## Test Case: Testing the car being flipped upside down; catching fire and exploding.
	func test_car_flipped_upside_down():
		assert_false(car_instance.is_flipped, "Car should not be flipped initially.")
		assert_false(car_instance.is_on_fire, "Car should not be on fire initially.")
		assert_false(car_instance.has_exploded, "Car should not have exploded initially.")
		assert_true(car_instance.flipped_timer.is_stopped(), "Flipped timer should not run initially.")
		assert_true(car_instance.fire_timer.is_stopped(), "Fire timer should not run initially.")
		assert_false(car_instance.fire.emitting, "Fire VFX should not be emitting initially.")
		assert_false(car_instance.fire_sfx.playing, "Fire SFX should not be playing initially.")
		assert_false(car_instance.explosion_sfx.playing, "Explosion SFX should not be playing initially.")

		# Act: Raise the car 2 units and rotate 180 degrees around the Z-axis with fast burn/explode timers.
		car_instance.global_position.y += 2.0
		car_instance.rotate_z(PI)
		car_instance.flipped_timer.wait_time = 0.5
		car_instance.fire_timer.wait_time = 0.5

		await wait_seconds(1.0)

		assert_true(car_instance.is_flipped, "Car should be detected as flipped.")
		assert_true(car_instance.is_on_fire, "Car should be on fire after reaching burn threshold.")
		assert_false(car_instance.has_exploded, "Car should not have exploded while still burning.")
		assert_true(car_instance.fire.emitting, "Fire VFX should be emitting while on fire.")
		assert_true(car_instance.fire_sfx.playing, "Fire SFX should be playing while on fire.")

		await wait_seconds(0.2)
		assert_false(car_instance.fire_timer.is_stopped(), "Fire timer should run while burning.")
		assert_false(car_instance.has_exploded, "Car should not explode before the fire timer elapses.")

		await wait_seconds(0.4)

		assert_true(car_instance.has_exploded, "Car should explode after burning for too long.")
		assert_false(car_instance.fire.emitting, "Fire VFX should stop emitting after explosion.")
		assert_false(car_instance.fire_sfx.playing, "Fire SFX should stop playing after explosion.")
		assert_true(car_instance.explosion_sfx.playing, "Explosion SFX should be playing after explosion.")

	## Test Case: Testing the car catching fire and exploding.
	func test_car_on_fire():
		assert_false(car_instance.is_on_fire, "Car should not be on fire initially.")
		assert_false(car_instance.has_exploded, "Car should not have exploded initially.")
		assert_true(car_instance.fire_timer.is_stopped(), "Fire timer should not run initially.")

		# Act: Set the car on fire directly with a fast explosion threshold (0.5 seconds).
		car_instance.fire_timer.wait_time = 0.5
		car_instance.is_on_fire = true

		assert_true(car_instance.is_on_fire, "Car should be on fire.")
		assert_false(car_instance.is_flipped, "Car should not be flipped.")
		assert_false(car_instance.has_exploded, "Car should not have exploded while still burning.")
		assert_true(car_instance.fire.emitting, "Fire VFX should be emitting while on fire.")
		assert_true(car_instance.fire_sfx.playing, "Fire SFX should be playing while on fire.")

		await wait_seconds(0.2)
		assert_false(car_instance.fire_timer.is_stopped(), "Fire timer should run while burning.")
		assert_false(car_instance.has_exploded, "Car should not explode before the fire timer elapses.")

		await wait_seconds(0.4)

		assert_true(car_instance.has_exploded, "Car should explode after burning for too long.")
		assert_false(car_instance.fire.emitting, "Fire VFX should stop emitting after explosion.")
		assert_false(car_instance.fire_sfx.playing, "Fire SFX should stop playing after explosion.")
		assert_true(car_instance.explosion_sfx.playing, "Explosion SFX should be playing after explosion.")

		# Verify the burned material was applied to a body mesh
		var found_burnt_mesh := false
		for mesh_node in car_instance.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh_node as MeshInstance3D
			if mi and not "glass" in mi.name.to_lower() and not "window" in mi.name.to_lower():
				if mi.get_surface_override_material(0) == car_instance.BURNED_MATERIAL:
					found_burnt_mesh = true
					break
		assert_true(found_burnt_mesh, "At least one car mesh should have the burned material applied.")

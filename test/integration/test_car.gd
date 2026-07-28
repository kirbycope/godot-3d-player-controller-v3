extends GutTest

const IntegrationTestBase = preload("res://test/integration/integration_test_base.gd")

## Purpose: To test the actions and events related to the car.


## Shared base setup/teardown for test classes that inherit from _this_ one.
class CarTestBase:
	extends IntegrationTestBase

	var MainScene = load("res://test/integration/test_car.tscn")
	var PlayerScene = load("res://addons/3d_player_controller/player.tscn")
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

	## Helper method to attach and configure a Player instance driving the car.
	func setup_player_driving() -> void:
		if not player_instance:
			player_instance = PlayerScene.instantiate()
			main_instance.add_child(player_instance)

		player_instance.is_driving = true
		player_instance.is_driving_in = car_instance
		player_instance.is_entering_vehicle = false
		player_instance.is_exiting_vehicle = false
		if player_instance.collision_shape:
			player_instance.collision_shape.disabled = true
		car_instance.player = player_instance

		# Enable driving state processing
		var driving_node = player_instance.get_node_or_null("NodeStateMachine/Driving")
		if driving_node:
			driving_node.process_mode = Node.PROCESS_MODE_INHERIT
			driving_node.player = player_instance



## Tests related to the function performed by an action.
class TestCarActions:
	extends CarTestBase

	## Test Case: Testing the car being driven forward.
	func test_car_driven_forward():
		# Arrange: Setup player driving and confirm initial engine force is 0.0.
		setup_player_driving()
		assert_eq(car_instance.engine_force, 0.0, "Car engine force should be 0.0 initially.")

		# Act: Press the accelerate action ("shoot").
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("shoot")
		await wait_physics_frames(5)

		# Assert: Confirm engine force is positive when accelerating.
		assert_gt(car_instance.engine_force, 0.0, "Car engine force should be positive when accelerating forward.")
		sender.action_up("shoot")

	## Test Case: Testing the car reversing.
	func test_car_reversing():
		# Arrange: Setup player driving while stopped and confirm initial engine force is 0.0.
		setup_player_driving()
		car_instance.linear_velocity = Vector3.ZERO
		car_instance.angular_velocity = Vector3.ZERO
		assert_eq(car_instance.engine_force, 0.0, "Car engine force should be 0.0 initially.")

		# Act: Press the brake/reverse action ("focus").
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("focus")
		await wait_physics_frames(5)

		# Assert: Confirm engine force is negative when reversing while stopped.
		assert_lt(car_instance.engine_force, 0.0, "Car engine force should be negative when reversing.")
		sender.action_up("focus")

	## Test Case: Testing the car braking.
	func test_car_braking():
		# Arrange: Setup player driving with forward linear velocity (+Z) and confirm initial brake is 0.0.
		setup_player_driving()
		car_instance.linear_velocity = Vector3(0.0, 0.0, 5.0)
		assert_eq(car_instance.brake, 0.0, "Car brake should be 0.0 initially.")

		# Act: Press the brake action ("focus") while moving forward.
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("focus")
		await wait_physics_frames(5)

		# Assert: Confirm brake force is positive when braking.
		assert_gt(car_instance.brake, 0.0, "Car brake force should be positive when braking.")
		sender.action_up("focus")

	## Test Case: Testing the car steering left.
	func test_car_steering_left():
		# Arrange: Setup player driving and confirm initial steering is 0.0.
		setup_player_driving()
		assert_eq(car_instance.steering, 0.0, "Car steering should be 0.0 initially.")

		# Act: Press the move left action ("move_left").
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_left")
		await wait_physics_frames(5)

		# Assert: Confirm steering angle is positive when steering left.
		assert_gt(car_instance.steering, 0.0, "Car steering should be positive when steering left.")
		sender.action_up("move_left")

	## Test Case: Testing the car steering right.
	func test_car_steering_right():
		# Arrange: Setup player driving and confirm initial steering is 0.0.
		setup_player_driving()
		assert_eq(car_instance.steering, 0.0, "Car steering should be 0.0 initially.")

		# Act: Press the move right action ("move_right").
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_right")
		await wait_physics_frames(5)

		# Assert: Confirm steering angle is negative when steering right.
		assert_lt(car_instance.steering, 0.0, "Car steering should be negative when steering right.")
		sender.action_up("move_right")
 


## Tests related to the function performed by an event.
class TestCarEvents:
	extends CarTestBase

	## Test Case: Testing the car being flipped upside down; catching fire and exploding.
	func test_car_flipped_upside_down():
		# Arrange: Confirm timers, initial state, and SFX/VFX have not yet started.
		assert_false(car_instance.is_flipped, "Car should not be flipped initially.")
		assert_false(car_instance.is_on_fire, "Car should not be on fire initially.")
		assert_false(car_instance.has_exploded, "Car should not have exploded initially.")
		assert_eq(car_instance.flipped_timer, 0.0, "Flipped timer should be 0.0 initially.")
		assert_eq(car_instance.fire_timer, 0.0, "Fire timer should be 0.0 initially.")
		if car_instance.fire:
			assert_false(car_instance.fire.emitting, "Fire VFX should not be emitting initially.")
		if car_instance.fire_sfx:
			assert_false(car_instance.fire_sfx.playing, "Fire SFX should not be playing initially.")
		if car_instance.explosion_sfx:
			assert_false(car_instance.explosion_sfx.playing, "Explosion SFX should not be playing initially.")

		# Act: Raise the car 2 units and rotate 180 degrees around the Z-axis.
		car_instance.global_position.y += 2.0
		car_instance.rotate_z(PI)

		# Act: Reduce burn and explosion thresholds for faster test execution.
		car_instance.flipped_time_to_burn = 0.5
		car_instance.time_to_explode = 0.5

		# Act: Wait for the car to hit the ground and settle upside down to catch fire.
		await wait_seconds(1.0)

		# Assert: Confirm the fire state has started after being flipped, fire VFX/SFX are active, but has not yet exploded.
		assert_true(car_instance.is_flipped, "Car should be detected as flipped.")
		assert_true(car_instance.is_on_fire, "Car should be on fire after reaching burn threshold.")
		assert_false(car_instance.has_exploded, "Car should not have exploded while still burning.")
		if car_instance.fire:
			assert_true(car_instance.fire.emitting, "Fire VFX should be emitting while on fire.")
		if car_instance.fire_sfx:
			assert_true(car_instance.fire_sfx.playing, "Fire SFX should be playing while on fire.")

		# Act: Wait part of the threshold time (0.2s) to verify fire timer accumulates without exploding early.
		await wait_seconds(0.2)
		assert_gt(car_instance.fire_timer, 0.0, "Fire timer should accumulate while burning.")
		assert_false(car_instance.has_exploded, "Car should not explode before time_to_explode threshold.")

		# Act: Wait for the remaining threshold time so total burn time exceeds time_to_explode.
		await wait_seconds(0.4)

		# Assert: Confirm the car explodes after burning for too long, fire VFX/SFX stop, and explosion SFX plays.
		assert_true(car_instance.has_exploded, "Car should explode after burning for too long (exceeding time_to_explode).")
		if car_instance.fire:
			assert_false(car_instance.fire.emitting, "Fire VFX should stop emitting after explosion.")
		if car_instance.fire_sfx:
			assert_false(car_instance.fire_sfx.playing, "Fire SFX should stop playing after explosion.")
		if car_instance.explosion_sfx:
			assert_true(car_instance.explosion_sfx.playing, "Explosion SFX should be playing after explosion.")

	## Test Case: Testing the car catching fire and exploding.
	func test_car_on_fire():
		# Arrange: Confirm initial state and SFX/VFX before setting car on fire.
		assert_false(car_instance.is_flipped, "Car should not be flipped initially.")
		assert_false(car_instance.is_on_fire, "Car should not be on fire initially.")
		assert_false(car_instance.has_exploded, "Car should not have exploded initially.")
		assert_eq(car_instance.fire_timer, 0.0, "Fire timer should be 0.0 initially.")
		if car_instance.fire:
			assert_false(car_instance.fire.emitting, "Fire VFX should not be emitting initially.")
		if car_instance.fire_sfx:
			assert_false(car_instance.fire_sfx.playing, "Fire SFX should not be playing initially.")
		if car_instance.explosion_sfx:
			assert_false(car_instance.explosion_sfx.playing, "Explosion SFX should not be playing initially.")

		# Act: Set the car on fire directly and set a fast explosion threshold (0.5 seconds).
		car_instance.is_on_fire = true
		car_instance.time_to_explode = 0.5

		# Assert: Confirm the car is on fire, emitting fire particles, fire SFX is playing, not flipped, and not yet exploded.
		assert_true(car_instance.is_on_fire, "Car should be on fire.")
		assert_false(car_instance.is_flipped, "Car should not be flipped.")
		assert_false(car_instance.has_exploded, "Car should not have exploded while still burning.")
		if car_instance.fire:
			assert_true(car_instance.fire.emitting, "Fire VFX should be emitting while on fire.")
		if car_instance.fire_sfx:
			assert_true(car_instance.fire_sfx.playing, "Fire SFX should be playing while on fire.")

		# Act: Wait part of the threshold time (0.2s) to verify fire timer accumulates without exploding early.
		await wait_seconds(0.2)
		assert_gt(car_instance.fire_timer, 0.0, "Fire timer should accumulate while burning.")
		assert_false(car_instance.has_exploded, "Car should not explode before time_to_explode threshold.")

		# Act: Wait the remaining threshold time so total burn time exceeds time_to_explode.
		await wait_seconds(0.4)

		# Assert: Confirm the car explodes, fire VFX/SFX stop, and explosion SFX plays.
		assert_true(car_instance.has_exploded, "Car should explode after burning for too long (exceeding time_to_explode).")
		if car_instance.fire:
			assert_false(car_instance.fire.emitting, "Fire VFX should stop emitting after explosion.")
		if car_instance.fire_sfx:
			assert_false(car_instance.fire_sfx.playing, "Fire SFX should stop playing after explosion.")
		if car_instance.explosion_sfx:
			assert_true(car_instance.explosion_sfx.playing, "Explosion SFX should be playing after explosion.")

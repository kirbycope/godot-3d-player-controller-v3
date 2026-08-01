extends GutTest

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

		player_instance.controls.current_input_type = 0
		player_instance.is_driving_in = car_instance
		car_instance.player = player_instance
		player_instance.state_machine.travel(player_instance.current_state, NodeStateMachine.States.DRIVING)
		player_instance.is_entering_vehicle = false

	## Helper getter to access the Driving state node on the player instance.
	var driving_state: Driving:
		get:
			return player_instance.state_machine.get_node("Driving") as Driving if player_instance and player_instance.state_machine else null


## Tests related to the function performed by an action.
class TestCarActions:
	extends CarTestBase

	## Test Case: Testing the car being driven forward.
	func test_car_driven_forward():
		# Arrange: Setup player driving and confirm initial engine force is 0.0.
		setup_player_driving()
		assert_eq(car_instance.engine_force, 0.0, "Car engine force should be 0.0 initially.")

		# Act: Press the accelerate action.
		var action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		# Assert: Confirm engine force is positive when accelerating.
		assert_gt(car_instance.engine_force, 0.0, "Car engine force should be positive when accelerating forward.")
		sender.action_up(action)

	## Test Case: Testing the car reversing.
	func test_car_reversing():
		# Arrange: Setup player driving while stopped and confirm initial engine force is 0.0.
		setup_player_driving()
		car_instance.linear_velocity = Vector3.ZERO
		car_instance.angular_velocity = Vector3.ZERO
		assert_eq(car_instance.engine_force, 0.0, "Car engine force should be 0.0 initially.")

		# Act: Press the brake/reverse action.
		var action: StringName = driving_state.keyboard_brake_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		# Assert: Confirm engine force is negative when reversing while stopped.
		assert_lt(car_instance.engine_force, 0.0, "Car engine force should be negative when reversing.")
		sender.action_up(action)

	## Test Case: Testing the car braking.
	func test_car_braking():
		# Arrange: Setup player driving with forward linear velocity (+Z) and confirm initial brake is 0.0.
		setup_player_driving()
		car_instance.linear_velocity = Vector3(0.0, 0.0, 5.0)
		assert_eq(car_instance.brake, 0.0, "Car brake should be 0.0 initially.")

		# Act: Press the brake action while moving forward.
		var action: StringName = driving_state.keyboard_brake_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		# Assert: Confirm brake force is positive when braking.
		assert_gt(car_instance.brake, 0.0, "Car brake force should be positive when braking.")
		sender.action_up(action)

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

	## Test Case: Testing the car acceleration SFX with keyboard input.
	func test_car_accelerate_sfx_keyboard():
		# Arrange: Setup player driving using keyboard/mouse (input_type = 0).
		setup_player_driving()
		player_instance.controls.current_input_type = 0

		# Act: Press the keyboard accelerate action.
		var action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		# Assert: Acceleration engine SFX should be playing.
		var is_accel_sfx_playing: bool = car_instance.sfx_engine_speed_up_outside.playing or car_instance.sfx_engine_speed_up_inside.playing
		assert_true(is_accel_sfx_playing, "Acceleration engine SFX should play when holding keyboard accelerate action.")
		sender.action_up(action)

	## Test Case: Testing the car acceleration SFX with pad input.
	func test_car_accelerate_sfx_pad():
		# Arrange: Setup player driving using pad (input_type = 1).
		setup_player_driving()
		player_instance.controls.current_input_type = 1

		# Act: Press the pad accelerate action.
		var action: StringName = driving_state.pad_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(action)
		await wait_physics_frames(5)

		# Assert: Acceleration engine SFX should be playing.
		var is_accel_sfx_playing: bool = car_instance.sfx_engine_speed_up_outside.playing or car_instance.sfx_engine_speed_up_inside.playing
		assert_true(is_accel_sfx_playing, "Acceleration engine SFX should play when holding pad accelerate action.")
		sender.action_up(action)

	## Test Case: Testing that rev SFX plays once per acceleration press while holding brake.
	func test_car_rev_sfx_once_per_accel_press():
		# Arrange: Setup player driving while stopped.
		setup_player_driving()
		car_instance.linear_velocity = Vector3.ZERO

		# Act: Hold brake action and press accelerate action.
		var brake_action: StringName = driving_state.keyboard_brake_action
		var accel_action: StringName = driving_state.keyboard_accelerate_action
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down(brake_action)
		sender.action_down(accel_action)
		await wait_physics_frames(5)

		# Assert: Rev SFX is registered for current acceleration press.
		assert_true(car_instance._revved_current_accel, "Car should register rev state for current acceleration press.")

		# Act: Simulate rev SFX finishing while continuing to hold brake and accelerate.
		if car_instance.sfx_engine_rev and car_instance.sfx_engine_rev.playing:
			car_instance.sfx_engine_rev.stop()
		await wait_physics_frames(5)

		# Assert: Rev SFX should NOT re-trigger; engine should revert to running SFX.
		assert_false(car_instance.sfx_engine_rev.playing, "Rev SFX should not re-trigger after finishing.")
		assert_true(car_instance.sfx_engine_running_outside.playing or car_instance.sfx_engine_running_inside.playing, "Engine should revert to running SFX after rev finishes.")

		# Clean up inputs
		sender.action_up(accel_action)
		sender.action_up(brake_action)
 

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

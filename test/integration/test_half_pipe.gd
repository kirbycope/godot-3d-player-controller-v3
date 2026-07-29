extends GutTest

## Purpose: To test half-pipe area detection and surface-relative skateboarding physics.


class TestHalfPipePhysics:
	extends IntegrationTestBase

	var MainScene = load("res://scenes/main.tscn")
	var main_instance = null
	var player = null
	var half_pipe = null

	func before_each() -> void:
		main_instance = MainScene.instantiate()
		add_child_autofree(main_instance)
		player = main_instance.get_node("Player") as Player
		half_pipe = main_instance.get_node("NavigationRegion3D/HalfPipe")

	func after_each() -> void:
		if is_instance_valid(main_instance):
			main_instance.free()
			main_instance = null
			player = null
			half_pipe = null

	func test_player_detection_sets_half_pipe_flag() -> void:
		assert_false(player.is_on_half_pipe, "Player should not be on half-pipe by default.")
		
		# Simulate body entering half pipe player detection
		half_pipe._on_player_detection_body_entered(player)
		assert_true(player.is_on_half_pipe, "Player should be flagged on half-pipe after body entered.")

		# Simulate body exiting half pipe player detection
		half_pipe._on_player_detection_body_exited(player)
		assert_false(player.is_on_half_pipe, "Player should not be flagged on half-pipe after body exited.")

	func test_skateboarding_up_direction_aligns_to_surface_on_half_pipe() -> void:
		player.is_skateboarding = true
		player.set_on_half_pipe(true)
		assert_eq(player.up_direction, Vector3.UP)

		# Run a physics frame
		player.state_machine.get_node("Skateboarding")._physics_process(0.016)
		# Player up_direction should remain defined
		assert_true(player.up_direction.is_normalized(), "Up direction should remain normalized.")

	func test_up_direction_resets_to_world_up_when_leaving_half_pipe() -> void:
		player.up_direction = Vector3(0.707, 0.707, 0.0).normalized()
		player.is_skateboarding = true
		player.set_on_half_pipe(false)

		var skateboarding_node = player.state_machine.get_node("Skateboarding")
		for i in range(30):
			skateboarding_node._physics_process(0.016)

		assert_true(
			player.up_direction.is_equal_approx(Vector3.UP),
			"Up direction should slerp back to Vector3.UP when leaving half-pipe while skateboarding."
		)

	func test_up_direction_resets_when_stopping_skateboarding() -> void:
		player.up_direction = Vector3(0.707, 0.707, 0.0).normalized()
		player.is_skateboarding = false
		player.set_on_half_pipe(false)

		for i in range(30):
			player._physics_process(0.016)

		assert_true(
			player.up_direction.is_equal_approx(Vector3.UP),
			"Up direction should slerp back to Vector3.UP when not skateboarding."
		)

	func test_apex_180_turn_when_momentum_reverses() -> void:
		player.is_skateboarding = true
		player.set_on_half_pipe(true)
		var skateboarding_node = player.state_machine.get_node("Skateboarding")

		# Set initial orientation and negative forward velocity (moving backward relative to model orientation)
		var initial_forward = player.orientation.basis.z.normalized()
		player.velocity = -initial_forward * 1.0

		# Process physics frame
		skateboarding_node._physics_process(0.016)

		# Forward basis should turn 180 degrees
		var new_forward = player.orientation.basis.z.normalized()
		assert_true(
			new_forward.dot(initial_forward) < -0.9,
			"Orientation should rotate 180 degrees at apex when momentum reverses."
		)

extends GutTest

## Purpose: To test stamina drain and regen behavior.

class StaminaTestBase:
	extends IntegrationTestBase

	var PlayerScene = load("res://addons/3d_player_controller/player.tscn")
	var root: Node3D
	var player: Player
	var stamina: TextureProgressBar
	var floor: StaticBody3D

	func before_each() -> void:
		root = Node3D.new()
		add_child_autofree(root)

		# Create floor
		floor = StaticBody3D.new()
		var floor_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(100, 1, 100)
		floor_shape.shape = box
		floor.add_child(floor_shape)
		floor.position = Vector3(0, -0.5, 0)
		root.add_child(floor)

		# Instantiate Player
		player = PlayerScene.instantiate()
		root.add_child(player)
		player.position = Vector3(0, 0.1, 0) # Slightly above floor to snap down
		player.enable_stamina = true
		stamina = player.get_node("Stamina")

		# Await physics frames so state machine can boot
		await wait_physics_frames(2)

	func after_each() -> void:
		Input.action_release("sprint")
		Input.action_release("move_up")
		if is_instance_valid(root):
			root.free()
			root = null
			player = null
			stamina = null


class TestStaminaEnableSetting:
	extends StaminaTestBase

	func test_disabled_stamina_resets_and_clears_exhaustion():
		stamina.stamina = 50.0
		player.is_exhausted = true
		player.enable_stamina = false
		await wait_physics_frames(2)

		assert_eq(stamina.stamina, stamina.max_value)
		assert_false(player.is_exhausted)
		assert_false(stamina.visible)


class TestStaminaDrain:
	extends StaminaTestBase

	func test_no_drain_when_standing_idle():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")

		var before: float = stamina.stamina
		await wait_physics_frames(30)

		assert_eq(stamina.stamina, before, "Stamina should not drain while standing idle.")

	func test_no_drain_when_sprint_held_but_not_moving():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")

		# Enter SPRINTING with movement input
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(5)

		assert_eq(player.current_state, NodeStateMachine.States.SPRINTING, "Player should be SPRINTING while moving with sprint held.")
		var while_moving: float = stamina.stamina
		assert_lt(while_moving, 100.0, "Stamina should drain while sprinting and moving.")

		# Release movement but keep sprint held — player is stationary
		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO
		await wait_physics_frames(5)

		var before: float = stamina.stamina
		await wait_physics_frames(30)

		assert_between(stamina.stamina, before, 100.0, "Stamina should not drain while stationary, even with sprint held.")

		sender.action_up("sprint")

	func test_drains_while_sprinting_and_moving():
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(2)

		var before: float = stamina.stamina
		await wait_physics_frames(30)

		assert_lt(stamina.stamina, before, "Stamina should drain while sprinting and moving.")

		sender.action_up("sprint")
		sender.action_up("move_up")


class TestStaminaRegen:
	extends StaminaTestBase

	func test_no_regen_while_climbing_idle():
		stamina.stamina = 50.0
		player.is_climbing = true
		await wait_physics_frames(30)

		assert_eq(stamina.stamina, 50.0, "Stamina should hold (not regen) while climbing and not moving.")

		player.is_climbing = false

	func test_regen_while_hanging():
		stamina.stamina = 50.0
		player.is_hanging_braced = true
		await wait_physics_frames(30)

		assert_gt(stamina.stamina, 50.0, "Stamina should regenerate while hanging.")

		player.is_hanging_braced = false

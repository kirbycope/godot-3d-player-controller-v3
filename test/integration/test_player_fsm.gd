extends GutTest

## Purpose: To test the state transitions of the Player FSM.

class FsmTestBase:
	extends IntegrationTestBase

	var PlayerScene = load("res://addons/3d_player_controller/player.tscn")
	var root: Node3D
	var player: Player
	var floor: StaticBody3D
	var wall: StaticBody3D
	
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
		
		# Create walls for climbing (surrounding player closely so 1m raycast hits)
		for dir in [Vector3(0, 0, -1.2), Vector3(0, 0, 1.2), Vector3(-1.2, 0, 0), Vector3(1.2, 0, 0)]:
			var w = StaticBody3D.new()
			var w_shape = CollisionShape3D.new()
			var w_box = BoxShape3D.new()
			if dir.z != 0:
				w_box.size = Vector3(10, 10, 1)
			else:
				w_box.size = Vector3(1, 10, 10)
			w_shape.shape = w_box
			w.add_child(w_shape)
			w.position = dir + Vector3(0, 5, 0)
			root.add_child(w)
		
		# Instantiate Player
		player = PlayerScene.instantiate()
		root.add_child(player)
		player.position = Vector3(0, 0.1, 0) # Slightly above floor to snap down
		
		# Await physics frames so state machine can boot
		await wait_physics_frames(2)

	func after_each() -> void:
		Input.action_release("jump")
		Input.action_release("sprint")
		Input.action_release("crouch")
		Input.action_release("attack")
		Input.action_release("move_up")
		if is_instance_valid(root):
			root.free()
			root = null
			player = null

class TestStandingTransitions:
	extends FsmTestBase
	
	func test_standing_to_jumping():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.JUMPING, "Player should transition to JUMPING state after jump action.")

	func test_exhausted_player_can_jump():
		player.enable_stamina = true
		var stamina: Node = player.get_node("Stamina")
		stamina.set("stamina", 0.0)
		player.is_exhausted = true
		await wait_physics_frames(15)
		assert_eq(player.current_locomotion_node, "HeavyBreathing")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(45)

		assert_ne(player.current_locomotion_node, "HeavyBreathing")
		assert_false(
				player.is_jump_queued,
				"Jump queue should execute from %s." % player.current_locomotion_node,
		)
		assert_false(
				player.is_on_floor(),
				"Player should leave floor from %s." % player.current_locomotion_node,
		)
		
	func test_standing_to_sprinting():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SPRINTING, "Player should transition to SPRINTING state while holding sprint.")
		
		sender.action_up("sprint")
		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition back to STANDING after releasing sprint.")
		
	func test_standing_to_crouching():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.CROUCHING, "Player should transition to CROUCHING state while holding crouch.")
		
		sender.action_up("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition back to STANDING after releasing crouch.")
		
	func test_standing_to_attacking():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("attack")
		await wait_physics_frames(2)
		sender.action_up("attack")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.ATTACKING, "Player should transition to ATTACKING state after attack action.")

class TestSprintingTransitions:
	extends FsmTestBase
	
	func test_sprinting_to_sliding():
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SPRINTING, "Player should be in SPRINTING state.")
		
		sender.action_down("crouch")
		await wait_physics_frames(2)
		sender.action_up("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SLIDING, "Player should transition to SLIDING from sprint when crouch is pressed.")
		
		sender.action_up("sprint")
		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO

class TestAirborneTransitions:
	extends FsmTestBase
	
	func test_falling_to_standing_on_floor():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.FALLING)
		await wait_physics_frames(2)
		
		# Position player slightly above ground so they quickly land
		player.global_position = Vector3(0, 0.2, 0)
		await wait_physics_frames(10)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition to STANDING after landing on floor.")

	func test_jumping_to_climbing():
		# Start on floor
		player.global_position = Vector3(0, 0.1, 0)
		await wait_physics_frames(2)
		
		# Jump 1: STANDING -> JUMPING
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.JUMPING, "Player should be jumping.")
		
		# Teleport player into air near walls while in JUMPING state
		player.global_position = Vector3(0, 2.0, 0)
		player.ledge_detection_horizontal.force_raycast_update()
		await wait_physics_frames(2)
		
		# Jump 2: JUMPING -> CLIMBING
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.CLIMBING, "Player should transition to CLIMBING when jumping near wall while in air.")

class TestAttackingTransitions:
	extends FsmTestBase
	
	func test_attacking_timeout():
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("attack")
		await wait_physics_frames(2)
		sender.action_up("attack")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.ATTACKING, "Player should be in ATTACKING state.")
		
		var attacking_state = player.state_machine.get_node("Attacking")
		attacking_state.boxing_inactivity_delay_remaining = 0.1
		
		await wait_seconds(0.2)
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should return to STANDING after attack timeout.")

class TestEquipmentInteractionTransitions:
	extends FsmTestBase

	func test_greatsword_logging_animation():
		var greatsword: Equipment = Equipment.new()
		greatsword.equipment_type = Equipment.EquipmentType.SWORD_2H
		greatsword.can_log = true
		root.add_child(greatsword)
		player.inventory.add_equipment(greatsword)

		player.locomotion_state.start("GreatSword")
		var greatsword_playback: AnimationNodeStateMachinePlayback = player.animation_tree.get(
				"parameters/LocomotionStateMachine/GreatSword/playback",
		)
		greatsword_playback.start("GreatSwordLocomotion")
		player.travel_locomotion("GreatSword/Logging")
		await wait_physics_frames(2)

		assert_true(player.is_logging, "GreatSword logging animation should become active.")

class TestEnableSettings:
	extends FsmTestBase

	func test_disabled_special_states_block_entry():
		var special_states: Array[NodeStateMachine.States] = [
			NodeStateMachine.States.FLYING,
			NodeStateMachine.States.PARAGLIDING,
			NodeStateMachine.States.RAGDOLLING,
		]
		for state: NodeStateMachine.States in special_states:
			player.state_machine.travel(player.current_state, state)
			assert_eq(
					player.current_state,
					NodeStateMachine.States.STANDING,
					"Disabled special state should not be entered.",
			)

	func test_enabled_flying_allows_entry():
		player.enable_flying = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.FLYING)
		assert_eq(player.current_state, NodeStateMachine.States.FLYING)

	func test_enabled_paraglider_allows_entry():
		player.enable_paraglider = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.PARAGLIDING)
		assert_eq(player.current_state, NodeStateMachine.States.PARAGLIDING)

	func test_enabled_ragdoll_allows_entry():
		player.enable_ragdoll = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.RAGDOLLING)
		assert_eq(player.current_state, NodeStateMachine.States.RAGDOLLING)

class TestPauseTransitions:
	extends FsmTestBase
	
	func test_no_ragdoll_when_pause_visible():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		player.enable_ragdoll = true
		player.pause.show_menu()
		assert_true(player.is_paused, "Player should be paused.")
		assert_true(player.pause.visible, "Pause CanvasLayer should be visible.")
		
		player.state_machine.travel(player.current_state, NodeStateMachine.States.RAGDOLLING)
		await wait_physics_frames(2)
		
		assert_ne(player.current_state, NodeStateMachine.States.RAGDOLLING, "Player should not transition to RAGDOLLING when Pause CanvasLayer is visible.")


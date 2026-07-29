extends GutTest

## Purpose: To test the actions and keybindings in `res://addons/3d_player_controller/controls.gd`.


## Shared base setup/teardown for test classes that inherit from _this_ one.
class ControlsTestBase:
	extends IntegrationTestBase

	var MainScene = load("res://scenes/main.tscn")
	var main_instance = null
	var player_debug = null

	## Runs before each test is executed.
	func before_each() -> void:
		main_instance = MainScene.instantiate()
		add_child_autofree(main_instance)
		player_debug = main_instance.get_node("Player/Debug")

	## Runs after each test is executed.
	func after_each() -> void:
		if is_instance_valid(main_instance):
			main_instance.free()
			main_instance = null
			player_debug = null


## Tests related to the function performed by an action.
class TestDebugAction:
	extends ControlsTestBase

	func test_pressing_debug_action_toggles_debug_node_visibility():
		# Arrange: Ensure the "debug" node is hidden before performing the action.
		assert_false(player_debug.visible, "Debug node should be hidden by default.")

		# Act: Perform the "debug" action.
		var sender = InputSender.new(player_debug)
		sender.action_down("debug").wait(0.1).action_up("debug")
		await sender.idle

		# Assert: Ensure that the "debug" node is now visible.
		assert_true(
			player_debug.visible,
			"Debug node should be visible after pressing the debug action.",
		)


## Tests related to the keybinding for an action.
class TestDebugKeybind:
	extends ControlsTestBase

	func test_pressing_f3_key_toggles_debug_node_visibility():
		# Arrange: Ensure the "debug" node is hidden before sending key events.
		assert_false(player_debug.visible, "Debug node should be hidden by default.")

		# Act: Perform the key press for [F3] to trigger the "debug" action.
		await send_key(Key.KEY_F3)

		# Assert: Ensure that the "debug" node is now visible.
		assert_true(player_debug.visible, "Debug node should be visible after pressing F3.")


## Tests related to Flying controls and contextual UI labels.
class TestFlyingControls:
	extends ControlsTestBase

	func test_flying_contextual_controls_keyboard():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.FLYING)

		assert_eq(player.controls.joypad_button_3_label.text, "Fly Up")
		assert_eq(player.controls.joypad_button_7_label.text, "Fly Down")
		assert_eq(player.controls.left_joystick_label.text, "Fly")

	func test_flying_contextual_controls_controller():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 1 # MICROSOFT controller
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.FLYING)

		assert_eq(player.controls.joypad_button_3_label.text, "Fly Up")
		assert_eq(player.controls.joypad_button_0_label.text, "Fly Down")
		assert_eq(player.controls.left_joystick_label.text, "Fly")


## Tests related to Paragliding controls and contextual UI labels.
class TestParaglidingControls:
	extends ControlsTestBase

	func test_paragliding_contextual_controls_keyboard():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.PARAGLIDING)

		assert_eq(player.controls.joypad_button_7_label.text, "Cancel")
		assert_eq(player.controls.left_joystick_label.text, "Steer")

	func test_paragliding_contextual_controls_controller():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 1 # MICROSOFT controller
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.PARAGLIDING)

		assert_eq(player.controls.joypad_button_0_label.text, "Cancel")
		assert_eq(player.controls.left_joystick_label.text, "Steer")


## Tests related to Climbing controls and contextual UI labels.
class TestClimbingControls:
	extends ControlsTestBase

	func test_climbing_contextual_controls_keyboard():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.CLIMBING)

		assert_eq(player.controls.joypad_button_3_label.text, "Hop")
		assert_eq(player.controls.joypad_button_1_label.text, "Fast Climb")
		assert_eq(player.controls.joypad_button_7_label.text, "Drop")
		assert_eq(player.controls.left_joystick_label.text, "Climb")

	func test_climbing_contextual_controls_controller():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 1 # MICROSOFT controller
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.CLIMBING)

		assert_eq(player.controls.joypad_button_3_label.text, "Hop")
		assert_eq(player.controls.joypad_button_1_label.text, "Fast Climb")
		assert_eq(player.controls.joypad_button_7_label.text, "Drop")
		assert_eq(player.controls.left_joystick_label.text, "Climb")


## Tests related to Hanging controls and contextual UI labels.
class TestHangingControls:
	extends ControlsTestBase

	func test_hanging_contextual_controls_keyboard():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.HANGING)

		assert_eq(player.controls.joypad_button_3_label.text, "Climb Up")
		assert_eq(player.controls.joypad_button_7_label.text, "Drop")
		assert_eq(player.controls.left_joystick_label.text, "Shimmy")

	func test_hanging_contextual_controls_controller():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 1 # MICROSOFT controller
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.HANGING)

		assert_eq(player.controls.joypad_button_3_label.text, "Climb Up")
		assert_eq(player.controls.joypad_button_7_label.text, "Drop")
		assert_eq(player.controls.left_joystick_label.text, "Shimmy")


## Tests related to Swimming controls and contextual UI labels.
class TestSwimmingControls:
	extends ControlsTestBase

	func test_swimming_contextual_controls_keyboard():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.SWIMMING)

		assert_eq(player.controls.joypad_button_3_label.text, "Climb Out")
		assert_eq(player.controls.joypad_button_1_label.text, "Fast Swim")
		assert_eq(player.controls.left_joystick_label.text, "Swim")

	func test_swimming_contextual_controls_controller():
		var player = main_instance.get_node("Player") as Player
		player.controls.current_input_type = 1 # MICROSOFT controller
		player.state_machine.travel(NodeStateMachine.States.STANDING, NodeStateMachine.States.SWIMMING)

		assert_eq(player.controls.joypad_button_3_label.text, "Climb Out")
		assert_eq(player.controls.joypad_button_1_label.text, "Fast Swim")
		assert_eq(player.controls.left_joystick_label.text, "Swim")

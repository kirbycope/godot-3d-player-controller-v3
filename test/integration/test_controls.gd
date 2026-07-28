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

extends GutTest

## Purpose: To test the actions and keybindings in `res://addons/3d_player_controller/controls.gd`.
## Tests are atomic and focus on individual actions and keybindings.
## As such, the scene is reset each test to ensure isolation.


## Shared base setup/teardown for test classes that inherit from _this_ one.
class ControlsTestBase:
	extends GutTest

	var MainScene = load("res://test/integration/test_controls.tscn")
	var main_instance = null

	func after_each():
		_cleanup_main_instance()

	func _cleanup_main_instance() -> void:
		if is_instance_valid(main_instance):
			main_instance.free()

	func _spawn_main_and_get_debug_node() -> CanvasLayer:
		main_instance = MainScene.instantiate()
		add_child_autofree(main_instance)
		return main_instance.get_node("Player/Debug")


## Tests related to the function performed by action.
class TestDebugAction:
	extends ControlsTestBase

	func test_pressing_debug_action_toggles_debug_node_visibility():
		var debug_node := _spawn_main_and_get_debug_node()
		assert_false(debug_node.visible, "Debug node should be hidden by default.")

		# Send action events directly to the Debug node's _input handler.
		var sender = InputSender.new(debug_node)
		sender.action_down("debug").wait(0.1).action_up("debug")
		await sender.idle

		assert_true(
			debug_node.visible,
			"Debug node should be visible after pressing the debug action.",
		)


class TestDebugKeybind:
	extends ControlsTestBase

	func test_pressing_f3_key_toggles_debug_node_visibility():
		var debug_node := _spawn_main_and_get_debug_node()
		assert_false(debug_node.visible, "Debug node should be hidden by default.")

		# Send physical-key events through global Input for InputMap key binding coverage.
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)

		var key_down_event := InputEventKey.new()
		key_down_event.physical_keycode = KEY_F3
		key_down_event.pressed = true

		var key_up_event := InputEventKey.new()
		key_up_event.physical_keycode = KEY_F3
		key_up_event.pressed = false

		sender.send_event(key_down_event).wait(0.1).send_event(key_up_event)
		await sender.idle

		assert_true(debug_node.visible, "Debug node should be visible after pressing F3.")

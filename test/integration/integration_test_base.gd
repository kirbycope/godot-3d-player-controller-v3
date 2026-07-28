class_name IntegrationTestBase
extends GutTest

## Purpose: Shared base class providing common input helper functions for GUT integration tests.


## Waits for physics frames. Multiplies the frame count when running interactively in GUI/Editor mode (non-headless) to allow visual observation.
func wait_physics_frames(frames: int = 1, msg: String = "") -> void:
	var multiplier: int = 20 if DisplayServer.get_name() != "headless" else 1
	await super.wait_physics_frames(frames * multiplier, msg)


## Performs a "down" and "up" sequence for the specified action.
func perform_action(action_name: String) -> void:
	var sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	sender.action_down(action_name).wait(0.1).action_up(action_name)
	await sender.idle


## Sends a key "press" and "release" sequence for the specified keycode.
func send_key(keycode: Key) -> void:
	var sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)

	var key_down_event := InputEventKey.new()
	key_down_event.physical_keycode = keycode
	key_down_event.pressed = true

	var key_up_event := InputEventKey.new()
	key_up_event.physical_keycode = keycode
	key_up_event.pressed = false

	sender.send_event(key_down_event).wait(0.1).send_event(key_up_event)
	await sender.idle

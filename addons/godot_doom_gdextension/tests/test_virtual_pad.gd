extends GutTest

## Purpose: The on-screen pad fills itself from the controls addon, names every button after what DOOM does
## with it, and turns a tap back into the joypad event the engine reads.

var pad: PureDoomVirtualPad


func before_each() -> void:
	pad = PureDoomVirtualPad.new()
	pad.name = "VirtualPad"
	add_child_autofree(pad)


func after_each() -> void:
	for slot: String in PureDoomVirtualPad.SLOTS:
		Input.action_release(PureDoomVirtualPad.SLOTS[slot]["action"])


func test_the_addon_is_installed_in_the_demo_project() -> void:
	assert_true(ResourceLoader.exists(PureDoomVirtualPad.CONTROLS_SCENE), "demo/addons/controls is a submodule")
	assert_not_null(pad.controls, "The HUD is filled in when the addon is there")


func test_every_slot_carries_its_action() -> void:
	for slot: String in PureDoomVirtualPad.SLOTS:
		var action: StringName = PureDoomVirtualPad.SLOTS[slot]["action"]
		assert_eq(pad.controls.get("action_" + slot), action, "Slot %s is mapped" % slot)
		assert_true(InputMap.has_action(action), "%s is registered for the project" % action)


func test_a_slot_is_either_a_button_or_an_axis() -> void:
	for slot: String in PureDoomVirtualPad.SLOTS:
		var binding: Dictionary = PureDoomVirtualPad.SLOTS[slot]
		assert_eq(binding.has("button"), not binding.has("axis"), "Slot %s reads one way only" % slot)
		if binding.has("axis"):
			assert_true(binding["axis"] in PureDoomVirtualPad.AXES, "The axis of %s is polled" % slot)
			assert_ne(binding["value"], 0.0, "Slot %s pushes its axis somewhere" % slot)


func test_every_button_has_a_label_and_every_label_a_button() -> void:
	assert_eq(PureDoomVirtualPad.LABELS.keys(), PureDoomVirtualPad.LABEL_PROPERTIES.keys())
	for slot: String in PureDoomVirtualPad.LABEL_PROPERTIES:
		var label: Label = pad.controls.get(PureDoomVirtualPad.LABEL_PROPERTIES[slot]) as Label
		assert_not_null(label, "The HUD has %s" % PureDoomVirtualPad.LABEL_PROPERTIES[slot])
		assert_eq(label.text, PureDoomVirtualPad.LABELS[slot], "%s says what DOOM does with it" % slot)


func test_a_stick_reads_both_of_its_directions_at_once() -> void:
	assert_eq(pad.axis_value(JOY_AXIS_LEFT_Y), 0.0, "Centred to begin with")
	Input.action_press(&"doom_move_up")
	assert_eq(pad.axis_value(JOY_AXIS_LEFT_Y), -1.0, "Forward")
	Input.action_press(&"doom_move_down")
	assert_eq(pad.axis_value(JOY_AXIS_LEFT_Y), 0.0, "Both at once cancel out")
	Input.action_release(&"doom_move_up")
	assert_eq(pad.axis_value(JOY_AXIS_LEFT_Y), 1.0, "Letting go of one leaves the other pushed")


func test_a_tap_reaches_the_engine_as_the_joypad_button_it_stands_for() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"doom_use"
	press.pressed = true
	pad._input(press)
	# Headless, the input queue takes several frames to hand a joypad event on. This is generous on purpose.
	await wait_frames(12)
	# doom_use is the addon's own binding for the bottom face button, so the engine seeing that button held is
	# the whole round trip: tap, action, joypad event, InputMap.
	assert_true(Input.is_joy_button_pressed(0, JOY_BUTTON_A), "The bottom face button the tap stands for")
	assert_true(Input.is_action_pressed(&"doom_use"), "And the action the addon bound to it")

	var release: InputEventAction = InputEventAction.new()
	release.action = &"doom_use"
	release.pressed = false
	pad._input(release)
	await wait_frames(12)
	assert_false(Input.is_joy_button_pressed(0, JOY_BUTTON_A), "And lets go of it")


func test_a_real_key_is_left_alone() -> void:
	# Only a TouchScreenButton sends an InputEventAction. A key reaches PureDoom by itself and would otherwise
	# be pressed twice.
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	pad._input(key)
	assert_eq(pad.axis_value(JOY_AXIS_LEFT_Y), 0.0, "Nothing was forwarded")


func test_the_pad_is_only_up_for_touch() -> void:
	# The device is settled first: the HUD's setter only fires on a change, and where the pad was built decides
	# what it started on.
	pad.controls.set("current_input_type", PureDoomVirtualPad.KEYBOARD_MOUSE)
	watch_signals(pad)

	pad.controls.set("current_input_type", PureDoomVirtualPad.TOUCH)
	assert_true(pad.controls.visible)
	assert_true(pad.is_processing(), "The sticks are read while the pad is up")
	assert_signal_emitted_with_parameters(pad, "device_changed", ["touch"])
	assert_eq(pad.card_input_type(), "touch", "And the card is told the same")

	pad.controls.set("current_input_type", PureDoomVirtualPad.KEYBOARD_MOUSE)
	assert_false(pad.controls.visible, "A keyboard has its own buttons")
	assert_false(pad.is_processing(), "And the sticks are not read")
	assert_signal_emitted_with_parameters(pad, "device_changed", ["keyboard"])
	assert_eq(pad.card_input_type(), "keyboard")

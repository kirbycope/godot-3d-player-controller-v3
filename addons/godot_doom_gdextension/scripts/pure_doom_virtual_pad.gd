class_name PureDoomVirtualPad
extends Node
## The on-screen pad for the DOOM screen, so the web demo is playable with no keyboard. It fills itself with
## the controls addon's HUD ([url]https://github.com/kirbycope/godot-controls[/url]) when that addon is in the
## project, maps every slot it uses to an action of its own, and turns the taps back into the joypad events
## [PureDoom] already understands: the engine has a full pad mapping in C++, so a virtual pad needs no new
## engine code.
##
## The addon is optional the same way Godot MIDI Player is. Without it this node does nothing and the demo
## still runs, which is why the HUD is loaded here rather than instanced in [code]demo.tscn[/code].

signal device_changed(card_input_type: String) ## The device in hand changed; carries [PureDoomControlsOverlay] wording.

const CONTROLS_SCENE: String = "res://addons/controls/controls.tscn" ## Optional: no pad without it.

## The addon's own InputType values and the [PureDoomControlsOverlay] wording for each, in its enum's order.
## Repeated here rather than named through the addon, which a project taking DOOM alone will not have.
const KEYBOARD_MOUSE: int = 0
const TOUCH: int = 4
const CARD_INPUT_TYPES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]

## The joypad axes this pad fills, so [method _process] asks about no others.
const AXES: Array[int] = [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]

## Each slot this pad uses, as the controls addon names it, with the action to put on it and the joypad event
## [PureDoom] reads that action as. A slot missing from here is left blank, and the addon hides a blank slot:
## the shoulders, the triggers and the Start button, none of which DOOM does anything with. The Back button is
## left out too, even though the engine reads it: the d-pad's down arm already opens DOOM's menu, and one menu
## button is enough. The share button is left to the addon, which puts its own screenshot on it.
const SLOTS: Dictionary = {
	"button_0": {"action": &"doom_use", "button": JOY_BUTTON_A},
	"button_1": {"action": &"doom_confirm", "button": JOY_BUTTON_B},
	"button_2": {"action": &"doom_fire", "button": JOY_BUTTON_X},
	"button_3": {"action": &"doom_run", "button": JOY_BUTTON_Y},
	"button_11": {"action": &"doom_dpad_up", "button": JOY_BUTTON_DPAD_UP},
	"button_12": {"action": &"doom_dpad_down", "button": JOY_BUTTON_DPAD_DOWN},
	"button_13": {"action": &"doom_dpad_left", "button": JOY_BUTTON_DPAD_LEFT},
	"button_14": {"action": &"doom_dpad_right", "button": JOY_BUTTON_DPAD_RIGHT},
	"move_up": {"action": &"doom_move_up", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
	"move_down": {"action": &"doom_move_down", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
	"move_left": {"action": &"doom_move_left", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
	"move_right": {"action": &"doom_move_right", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
	"look_left": {"action": &"doom_look_left", "axis": JOY_AXIS_RIGHT_X, "value": -1.0},
	"look_right": {"action": &"doom_look_right", "axis": JOY_AXIS_RIGHT_X, "value": 1.0},
	# DOOM has no free look, so the engine ignores this axis. The slots are filled anyway: the addon hides a
	# stick whose vertical pair is blank, and the right stick is how the player turns.
	"look_up": {"action": &"doom_look_up", "axis": JOY_AXIS_RIGHT_Y, "value": -1.0},
	"look_down": {"action": &"doom_look_down", "axis": JOY_AXIS_RIGHT_Y, "value": 1.0},
}

## What each button does, by the slot it sits on. The d-pad is read two ways by the engine - the automap, the
## menu and the weapons while playing, plain arrows once the menu is up - and these name the playing half.
const LABELS: Dictionary = {
	"button_0": "Use",
	"button_1": "Pick",
	"button_2": "Fire",
	"button_3": "Run",
	# Not a slot this pad fills: the addon puts its own screenshot on the share button, and set_labels clears
	# every label it is not given, so the word has to be repeated here to survive.
	"button_15": "Screenshot",
	"button_11": "Automap",
	"button_12": "Menu",
	"button_13": "Prev",
	"button_14": "Next",
	"left_joystick": "Move",
	"right_joystick": "Turn",
}

## The label property on the addon's HUD for each slot in [constant LABELS].
const LABEL_PROPERTIES: Dictionary = {
	"button_0": "joypad_button_0_label",
	"button_1": "joypad_button_1_label",
	"button_2": "joypad_button_2_label",
	"button_3": "joypad_button_3_label",
	"button_15": "joypad_button_15_label",
	"button_11": "joypad_button_11_label",
	"button_12": "joypad_button_12_label",
	"button_13": "joypad_button_13_label",
	"button_14": "joypad_button_14_label",
	"left_joystick": "left_joystick_label",
	"right_joystick": "right_joystick_label",
}

var controls: CanvasLayer ## The addon's HUD, null where the addon is not installed.

var _sent: Dictionary[int, float] = {} ## The last value handed to the engine per axis, so it hears only changes.


func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(CONTROLS_SCENE):
		return
	controls = (load(CONTROLS_SCENE) as PackedScene).instantiate() as CanvasLayer
	# Slot names are written before the HUD enters the tree: it registers the InputMap actions in its own
	# _ready, from whatever the exports say at that moment.
	for slot: String in SLOTS:
		controls.set(&"action_" + slot, SLOTS[slot]["action"])
	add_child(controls)
	_apply_labels()
	controls.connect(&"input_type_changed", _on_input_type_changed)
	# Swapping device redraws the HUD from the scene's own text, so the DOOM wording goes back on afterwards.
	controls.connect(&"contextual_labels_requested", _apply_labels)
	# The HUD starts on touch and waits for an event to say otherwise, which on a desktop browser means it
	# flashes up before the first keypress. A machine with no touchscreen can say so straight away.
	if not DisplayServer.is_touchscreen_available():
		controls.set(&"current_input_type", KEYBOARD_MOUSE)
	else:
		_on_input_type_changed(TOUCH)


## The pad is for the one device with no buttons of its own. A keyboard or a real controller has them, and the
## card beside the monitor already names every one, so the two never share the screen and never overlap.
func _on_input_type_changed(input_type: int) -> void:
	controls.visible = input_type == TOUCH
	set_process(controls.visible)
	_apply_labels()
	device_changed.emit(CARD_INPUT_TYPES[input_type])


## The [PureDoomControlsOverlay] wording for the device in hand, for a caller that missed [signal device_changed].
func card_input_type() -> String:
	if controls == null:
		return CARD_INPUT_TYPES[KEYBOARD_MOUSE]
	return CARD_INPUT_TYPES[controls.get(&"current_input_type")]


## Names every button after what DOOM does with it. [code]set_labels[/code] clears the ones not named, which is
## how the slots this pad leaves blank stay wordless.
func _apply_labels() -> void:
	var texts: Dictionary = {}
	for slot: String in LABELS:
		texts[controls.get(LABEL_PROPERTIES[slot])] = LABELS[slot]
	controls.call(&"set_labels", texts)


## The buttons. A [TouchScreenButton] sends an [InputEventAction], and nothing else does: a real key or pad
## reaches [PureDoom] on its own and must not be sent twice.
func _input(event: InputEvent) -> void:
	var action_event: InputEventAction = event as InputEventAction
	if action_event == null:
		return
	for slot: String in SLOTS:
		var slot_binding: Dictionary = SLOTS[slot]
		if not slot_binding.has("button") or slot_binding["action"] != action_event.action:
			continue
		var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
		button_event.button_index = slot_binding["button"]
		button_event.pressed = action_event.pressed
		Input.parse_input_event(button_event)
		return


## The sticks and the trigger. Godot's [VirtualJoystick] presses its actions straight into the input state
## rather than sending an event, so these are the one thing here that has to be read rather than listened for.
## Reading only happens while the pad is on screen, which is only on touch, so a keyboard's W is never counted
## on top of the key press [PureDoom] already had.
func _process(_delta: float) -> void:
	for axis: int in AXES:
		var value: float = axis_value(axis)
		if is_equal_approx(value, _sent.get(axis, 0.0)):
			continue
		_sent[axis] = value
		var motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion_event.axis = axis
		motion_event.axis_value = value
		Input.parse_input_event(motion_event)


## How far an axis is pushed, from both of its directions at once, so letting go of one while the other is held
## leaves the stick pushed the other way rather than centred.
func axis_value(axis: int) -> float:
	var value: float = 0.0
	for slot: String in SLOTS:
		var slot_binding: Dictionary = SLOTS[slot]
		if slot_binding.get("axis", -1) == axis:
			value += slot_binding["value"] * Input.get_action_strength(slot_binding["action"])
	return clampf(value, -1.0, 1.0)

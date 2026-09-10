extends GutTest
## The world prompt: it shows the sub-prompt for the device in hand and can name the HUD's bottom-action
## button after what it does while it is up.

const CONTROLS_SCENE: PackedScene = preload("res://addons/controls/controls.tscn")
const PROMPT_SCENE: PackedScene = preload("res://addons/controls/action_prompt.tscn")

var _controls: Controls
var _prompt: ActionPrompt


func before_each() -> void:
	_controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(_controls)
	_prompt = PROMPT_SCENE.instantiate()
	add_child_autofree(_prompt)


func test_hidden_until_shown() -> void:
	assert_false(_prompt.visible, "A prompt out of range is down")


func test_shows_the_sub_prompt_for_the_device_in_hand() -> void:
	_controls.current_input_type = Controls.InputType.SONY
	_prompt.show_for(_controls)
	assert_true(_prompt.visible)
	assert_true(_prompt.get_node("Sony").visible, "The PlayStation art is up")
	assert_false(_prompt.get_node("Microsoft").visible, "and no other")

	_controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	_prompt.show_for(_controls)
	assert_true(_prompt.get_node("KeyboardMouse").visible, "Switching device switches the art")
	assert_false(_prompt.get_node("Sony").visible)


func test_message_reads_press_something_to_do_something() -> void:
	_prompt.message_end = "to open"
	assert_eq(_prompt.label_3d_1.text, "Press")
	assert_eq(_prompt.label_3d_2_1.text, "to open", "Every device's second label follows the message")
	assert_eq(_prompt.label_3d_2_4.text, "to open")


func test_showing_with_a_label_names_the_action_button() -> void:
	_prompt.show_for(_controls, "Open")
	assert_eq(_controls.prompt_action_label, "Open")
	assert_eq(_controls.joypad_button_0_label.text, "Open")


func test_hiding_gives_the_label_back() -> void:
	_prompt.show_for(_controls, "Open")
	_prompt.hide_for(_controls)
	assert_false(_prompt.visible)
	assert_eq(_controls.prompt_action_label, "", "The button is the state's again")


## Leaving a crate while sitting in a car has to leave the car's label alone.
func test_hiding_one_prompt_leaves_anothers_label() -> void:
	var other: ActionPrompt = PROMPT_SCENE.instantiate()
	add_child_autofree(other)

	_prompt.show_for(_controls, "Open")
	other.show_for(_controls, "Get In")
	_prompt.hide_for(_controls)

	assert_eq(_controls.prompt_action_label, "Get In", "The prompt still in range keeps the button")


func test_hide_all_takes_every_sub_prompt_down() -> void:
	_prompt.show_for(_controls)
	_prompt.hide_all()
	assert_false(_prompt.visible)
	for child: Node3D in _prompt.get_children():
		assert_false(child.visible, "%s is down too" % child.name)


## A project with no HUD in the scene, or one asking before the HUD is ready, hands over null rather than a
## node; the prompt has to cope instead of erroring.
func test_no_controls_node_is_survivable() -> void:
	_prompt.show_for(null, "Open")
	assert_false(_prompt.visible, "Nothing to read the device off, so the prompt stays down")
	_prompt.show_for(_controls)
	_prompt.hide_for(null)
	assert_false(_prompt.visible, "Hiding still works")

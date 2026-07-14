extends VehicleBody3D

var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		if event.is_action_pressed("action"):
			if menu_displayed \
			and not player.is_driving:
				player.is_driving_in = self
				player.state_machine.travel(player.current_state, NodeStateMachine.States.DRIVING)


func display_menu(_player: Player) -> void:
	player = _player
	if action_prompt:
		action_prompt.show()
		action_prompt.update_text()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
	menu_displayed = true


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	if player:
		player.is_driving_in = null
		player = null
	menu_displayed = false

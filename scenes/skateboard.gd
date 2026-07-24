extends Node3D

var _this_state = NodeStateMachine.States.SKATEBOARDING
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Unequip skateboard
	if player \
	and event.is_action_pressed("unequip") \
	and not event.is_echo():
		# Stop skateboarding and start standing
		player.state_machine.travel(player.current_state, _this_state)
		return


func display_menu(_player) -> void:
	player = _player
	if not player:
		push_warning("Player is not defined.")
		return
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
	else:
		push_warning("Action prompt is not defined.")


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
		menu_displayed = false
	else:
		push_warning("Action prompt is not defined.")

func equip(_player) -> void:
	player = _player
	if not player:
		push_warning("Player is not defined.")
		return
	player.skateboard.show()
	player.state_machine.travel(player.current_state, _this_state)
	return


func unequip(_player) -> void:
	player = _player
	if not player:
		push_warning("Player is not defined.")
		return
	player.skateboard.hide()
	player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
	return

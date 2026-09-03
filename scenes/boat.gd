extends StaticBody3D

var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt
@onready var seat_01: Marker3D = $Seat01


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return

	if player:
		if event.is_action_pressed("action"):
			if menu_displayed and not player.is_sitting:
				_sit_player()


func display_menu(_player: Player) -> void:
	if _player and _player.is_sitting:
		hide_menu()
		return
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
	menu_displayed = false
	if player and player.is_sitting:
		return
	player = null


func _sit_player() -> void:
	if not player or not seat_01: return
	_update_player_seat_transform()
	if player.state_machine:
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SITTING)
	hide_menu()


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return

	var is_sitting_in_this_boat: bool = player != null and player.is_sitting

	var y_bot = seat_01.get_node_or_null("y_bot_root") if seat_01 else null
	if y_bot:
		y_bot.visible = not is_sitting_in_this_boat

	if is_sitting_in_this_boat:
		_update_player_seat_transform()
	elif not menu_displayed and player != null and not player.is_sitting:
		player = null


func _update_player_seat_transform() -> void:
	player.global_position = seat_01.global_position
	player.orientation = seat_01.global_transform
	player.orientation.origin = Vector3.ZERO
	player.player_model.global_transform = seat_01.global_transform
	player.velocity = Vector3.ZERO

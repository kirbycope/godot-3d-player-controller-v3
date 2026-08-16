extends Node3D

var _this_state = NodeStateMachine.States.SKATEBOARDING
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt
@onready var sfx_roll_on_cobblestone: AudioStreamPlayer3D = $SFX_Roll_on_Cobblestone
@onready var sfx_roll_on_concrete: AudioStreamPlayer3D = $SFX_Roll_on_Concrete
@onready var sfx_roll_on_wood: AudioStreamPlayer3D = $SFX_Roll_on_Wood
@onready var sfx_ollie: AudioStreamPlayer3D = $SFX_Ollie
@onready var sfx_land: AudioStreamPlayer3D = $SFX_Land


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


var _was_skateboarding: bool = false
var _was_on_floor: bool = false
var _was_jumping: bool = false
var _was_falling: bool = false


## Called every physics frame.
func _physics_process(_delta: float) -> void:
	if not player or not player.is_skateboarding:
		if _was_skateboarding:
			stop_all_roll_sounds()
			_was_skateboarding = false
			_was_on_floor = false
			_was_jumping = false
			_was_falling = false
		return

	var is_on_floor: bool = player.is_on_floor()
	var is_jumping: bool = player.is_jumping
	var is_falling: bool = player.is_falling
	var target_roll_sfx: AudioStreamPlayer3D = _get_target_roll_sfx()

	# Jump / Ollie SFX
	if is_jumping and not _was_jumping:
		stop_all_roll_sounds()
		if target_roll_sfx and sfx_ollie and not sfx_ollie.playing:
			sfx_ollie.play()

	# Landing SFX
	if is_on_floor and _was_skateboarding and (not _was_on_floor or _was_jumping or _was_falling):
		if target_roll_sfx and sfx_land and not sfx_land.playing:
			sfx_land.play()

	# Roll On SFX playing according to ground group seen by Raycast
	if is_on_floor:
		var h_speed: float = player.velocity.slide(player.up_direction).length()
		if h_speed > 0.1:
			_play_roll_sfx(target_roll_sfx)
		else:
			stop_all_roll_sounds()
	else:
		stop_all_roll_sounds()

	_was_skateboarding = true
	_was_on_floor = is_on_floor
	_was_jumping = is_jumping
	_was_falling = is_falling


func _get_target_roll_sfx() -> AudioStreamPlayer3D:
	if player and player.paraglider_raycast and player.paraglider_raycast.is_colliding():
		var collider := player.paraglider_raycast.get_collider() as Node3D
		if collider:
			if collider.is_in_group("WOOD"):
				return sfx_roll_on_wood
			elif collider.is_in_group("STONE") or collider.is_in_group("COBBLESTONE"):
				return sfx_roll_on_cobblestone
			elif collider.is_in_group("CONCRETE"):
				return sfx_roll_on_concrete
	return null


func _play_roll_sfx(target_sfx: AudioStreamPlayer3D) -> void:
	if not target_sfx:
		stop_all_roll_sounds()
		return

	# Don't play roll sound while Ollie or Land SFX is actively playing
	if (sfx_ollie and sfx_ollie.playing) or (sfx_land and sfx_land.playing):
		stop_all_roll_sounds()
		return

	# If the appropriate roll SFX is already playing, do nothing
	if target_sfx.playing:
		return

	# Stop any other roll SFX that is currently playing
	if sfx_roll_on_cobblestone and sfx_roll_on_cobblestone != target_sfx and sfx_roll_on_cobblestone.playing:
		sfx_roll_on_cobblestone.stop()
	if sfx_roll_on_concrete and sfx_roll_on_concrete != target_sfx and sfx_roll_on_concrete.playing:
		sfx_roll_on_concrete.stop()
	if sfx_roll_on_wood and sfx_roll_on_wood != target_sfx and sfx_roll_on_wood.playing:
		sfx_roll_on_wood.stop()

	target_sfx.play()


func stop_all_roll_sounds() -> void:
	if sfx_roll_on_cobblestone and sfx_roll_on_cobblestone.playing:
		sfx_roll_on_cobblestone.stop()
	if sfx_roll_on_concrete and sfx_roll_on_concrete.playing:
		sfx_roll_on_concrete.stop()
	if sfx_roll_on_wood and sfx_roll_on_wood.playing:
		sfx_roll_on_wood.stop()


func unequip(_player) -> void:
	stop_all_roll_sounds()
	player = _player
	if not player:
		push_warning("Player is not defined.")
		return
	player.skateboard.hide()
	player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
	return

extends Node3D
## A skateboard the Player picks up with "action"; plays roll, ollie and landing sounds while skateboarding.

const THIS_STATE: NodeStateMachine.States = NodeStateMachine.States.SKATEBOARDING

var player: Player: ## The Player using (or looking at) this skateboard.
	set(value):
		if player:
			player.state_changed.disconnect(_on_player_state_changed)
		player = value
		if player:
			player.state_changed.connect(_on_player_state_changed)
var _was_on_floor: bool = false
var _was_jumping: bool = false
var _was_falling: bool = false

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var sfx_roll_on_cobblestone: AudioStreamPlayer3D = $SFX_Roll_on_Cobblestone
@onready var sfx_roll_on_concrete: AudioStreamPlayer3D = $SFX_Roll_on_Concrete
@onready var sfx_roll_on_wood: AudioStreamPlayer3D = $SFX_Roll_on_Wood
@onready var sfx_ollie: AudioStreamPlayer3D = $SFX_Ollie
@onready var sfx_land: AudioStreamPlayer3D = $SFX_Land


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(false)


## Called by [Camera] while the player looks at the skateboard.
func display_menu(_player: Player) -> void:
	player = _player
	action_prompt.show_for(player)


## Called by [Camera] when the player looks away from the skateboard.
func hide_menu() -> void:
	action_prompt.hide()


## Called by [Camera] when the player looks at the skateboard and presses "action".
func equip(_player: Player) -> void:
	player = _player
	player.skateboard.show()
	player.state_machine.travel(player.current_state, THIS_STATE)


func unequip(_player: Player) -> void:
	stop_all_roll_sounds()
	player = _player
	player.skateboard.hide()
	player.state_machine.travel(THIS_STATE, NodeStateMachine.States.STANDING)


## Plays surface sounds only while the Player is skateboarding.
func _on_player_state_changed(from_state: int, to_state: int) -> void:
	if to_state == THIS_STATE:
		_was_on_floor = false
		_was_jumping = false
		_was_falling = false
		set_physics_process(true)
	elif from_state == THIS_STATE:
		set_physics_process(false)
		stop_all_roll_sounds()


## Called every physics frame while skateboarding.
func _physics_process(_delta: float) -> void:
	var is_on_floor: bool = player.is_on_floor()
	var is_jumping: bool = player.is_jumping
	var is_falling: bool = player.is_falling
	var target_roll_sfx: AudioStreamPlayer3D = _get_target_roll_sfx()

	# Jump / Ollie SFX
	if is_jumping and not _was_jumping:
		stop_all_roll_sounds()
		if target_roll_sfx and not sfx_ollie.playing:
			sfx_ollie.play()

	# Landing SFX
	if is_on_floor and (not _was_on_floor or _was_jumping or _was_falling):
		if target_roll_sfx and not sfx_land.playing:
			sfx_land.play()

	# Roll On SFX playing according to ground group seen by Raycast
	var h_speed: float = player.velocity.slide(player.up_direction).length()
	if is_on_floor and h_speed > 0.1:
		_play_roll_sfx(target_roll_sfx)
	else:
		stop_all_roll_sounds()

	_was_on_floor = is_on_floor
	_was_jumping = is_jumping
	_was_falling = is_falling


func _get_target_roll_sfx() -> AudioStreamPlayer3D:
	if player.paraglider_raycast.is_colliding():
		var collider: Node3D = player.paraglider_raycast.get_collider() as Node3D
		if collider:
			if collider.is_in_group("WOOD"):
				return sfx_roll_on_wood
			elif collider.is_in_group("STONE") or collider.is_in_group("COBBLESTONE"):
				return sfx_roll_on_cobblestone
			elif collider.is_in_group("CONCRETE"):
				return sfx_roll_on_concrete
	return null


func _play_roll_sfx(target_sfx: AudioStreamPlayer3D) -> void:
	# Don't play roll sound while Ollie or Land SFX is actively playing
	if not target_sfx or sfx_ollie.playing or sfx_land.playing:
		stop_all_roll_sounds()
		return

	# If the appropriate roll SFX is already playing, do nothing
	if target_sfx.playing:
		return

	stop_all_roll_sounds()
	target_sfx.play()


func stop_all_roll_sounds() -> void:
	sfx_roll_on_cobblestone.stop()
	sfx_roll_on_concrete.stop()
	sfx_roll_on_wood.stop()

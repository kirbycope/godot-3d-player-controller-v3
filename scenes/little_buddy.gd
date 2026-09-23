extends FollowerNpc
## A small companion that follows the Player and can be picked up, carried and thrown. Picking it up hands it to the
## carrier's peer, as mounting a horse does, and puts every peer's copy on that Player's spring arm; a drop hands it
## back to the server, a throw once it lands. The server arbitrates every hand-off: a pick-up only counts once the
## server has put the buddy on that Player's arm, so of two Players reaching for it only one ever holds it, and a
## carrier or thrower who drops out leaves it back in the scene, the server's again. The walk and run blend
## replicates so the puppets' legs move too.

const LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/LocomotionBlendSpace/blend_position"
const LOCOMOTION_STATE_MACHINE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const SERVER_PEER: int = 1

@export var throw_force_horizontal: float = 16.0
@export var throw_force_vertical: float = 3.5

var is_held: bool = false ## On this peer's own Player's arm; set when the server puts it there.
var is_thrown: bool = false ## In the air from this peer's throw, until it lands.
var carried_by: int = 0 ## The peer whose Player has the buddy on its arm, 0 when it is in the scene; the same on every peer.
var locomotion_blend: float = 0.0: ## Replicated: 0 idle, 0.5 walk, 1 run; the setter feeds the blend space on every peer.
	set(value):
		locomotion_blend = value
		if animation_tree:
			animation_tree.set(LOCOMOTION_BLEND_POSITION_PATH, value)

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var animation_tree: AnimationTree = $y_bot_root/AnimationTree
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _home: Node = get_parent() ## Where the buddy stood before anyone picked it up; where a drop puts it back on every peer.


func _ready() -> void:
	super()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_held or carried_by != 0:
		return # in somebody's hands, or thrown and not yet off the arm
	super(delta)


## Lets a throw carry the buddy until it lands, then hands it back to the server, which resumes following.
func _follow_player(delta: float) -> void:
	if is_thrown:
		move_and_slide()
		is_thrown = not is_on_floor()
		if not is_thrown:
			_hand_to(SERVER_PEER, -1)
		return
	super(delta)


func _move_with_control(control_velocity: Vector3) -> void:
	super(control_velocity)
	# Blend: 0.0 = Idle, 0.5 = Walk (at walk_speed), 1.0 = Run (at move_speed)
	var actual_h_speed: float = velocity.slide(up_direction).length()
	var target_blend: float = 0.0
	if actual_h_speed > 0.05 and control_velocity.slide(up_direction).length() > 0.05:
		if actual_h_speed <= walk_speed:
			target_blend = (actual_h_speed / maxf(walk_speed, 0.001)) * 0.5
		else:
			target_blend = 0.5 + clampf((actual_h_speed - walk_speed) / maxf(move_speed - walk_speed, 0.001), 0.0, 1.0) * 0.5
	var blend_speed: float = 8.0 if target_blend < locomotion_blend else 6.0
	locomotion_blend = move_toward(locomotion_blend, target_blend, blend_speed * get_physics_process_delta_time())


## Applies the avoidance-adjusted velocity requested in [method _follow_player].
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_thrown or is_held:
		return
	_move_with_control(safe_velocity)


func _on_swimming_changed(is_now_swimming: bool) -> void:
	animation_tree.get(LOCOMOTION_STATE_MACHINE_PLAYBACK_PATH).travel("Swimming" if is_now_swimming else "LocomotionBlendSpace")


func sfx_footsteps_play() -> void:
	pass


## Called by [Camera] while the player looks at the buddy.
func display_menu(_player: Player) -> void:
	if is_held:
		return
	player = _player
	action_prompt.show_for(player.controls)


## Called by [Camera] when the player looks away from the buddy.
func hide_menu() -> void:
	action_prompt.hide()


func _input(event: InputEvent) -> void:
	if player and (player.is_typing or player.is_paused):
		return
	if is_held:
		if event.is_action_pressed("action") and not event.is_echo():
			drop()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("shoot") and not event.is_echo():
			if player:
				player.start_charging_throw()
			else:
				throw_with_direction(Vector3.ZERO, 0.25)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("shoot") and not event.is_echo():
			if player:
				player.release_charging_throw()
			get_viewport().set_input_as_handled()
		return

	if action_prompt.visible and event.is_action_pressed("action") and not event.is_echo():
		pick_up()
		get_viewport().set_input_as_handled()


## Asks the server for the buddy; it is in the hands once the server has put it on this Player's arm. One already on
## somebody's arm stays theirs.
func pick_up() -> void:
	if not player or not player.item_spring_arm or get_parent() is SpringArm3D:
		return
	hide_menu()

	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	locomotion_blend = 0.0

	_hand_to(player.get_multiplayer_authority(), player.get_multiplayer_authority())


func drop() -> void:
	is_held = false
	is_thrown = false
	_hand_to(SERVER_PEER, 0)
	velocity = Vector3.ZERO


## The thrower keeps the authority until the buddy lands, so the flight is theirs to move.
func throw_with_direction(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	is_held = false
	is_thrown = true
	_hand_to(get_multiplayer_authority(), 0)

	if throw_dir.length_squared() < 0.001:
		if player and player.camera:
			throw_dir = -player.camera.global_transform.basis.z.normalized()
		elif player:
			throw_dir = player.get_facing_direction()
		if throw_dir.length_squared() < 0.001:
			throw_dir = Vector3.FORWARD

	var throw_up: Vector3 = player.up_direction if player else up_direction
	velocity = (throw_dir * throw_force_horizontal + throw_up * throw_force_vertical) * throw_power
	knockback_velocity = Vector3.ZERO


## Puts this copy on the spring arm of [param peer_id]'s Player (the copy in this branch of the tree, since a test can
## run two), or back into the scene for 0; sent by the server to every peer so the buddy shows in the carrier's hands
## everywhere, and refused from anyone else.
@rpc("any_peer", "call_local", "reliable")
func _carry_by(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() > SERVER_PEER:
		return
	carried_by = peer_id
	is_held = peer_id != 0 and peer_id == multiplayer.get_unique_id()
	collision_shape.disabled = peer_id != 0
	if peer_id == 0:
		_return_to_scene()
		return
	for node: Node in get_tree().get_nodes_in_group("Player"):
		if node is Player and node.get_multiplayer_authority() == peer_id and node.multiplayer == multiplayer:
			reparent((node as Player).item_spring_arm, false)
			transform = Transform3D()
			return


## Moves the buddy to [param peer_id] on every peer, the server first, and onto [param carrier]'s spring arm (0 the
## world, -1 leave it where it is). A client only asks: the server puts the buddy where it goes everywhere and then
## switches the authority, both on one reliable stream, so the old authority has stopped sending before the new
## one starts and no peer is left rejecting a stale packet as a non-authority's. Giving it back, this side goes
## quiet first, so the server's first packets find no rival. Offline there is nobody to ask.
func _hand_to(peer_id: int, carrier: int) -> void:
	if multiplayer.get_peers().is_empty():
		if carrier >= 0:
			_carry_by(carrier)
		set_multiplayer_authority(peer_id)
	elif multiplayer.is_server():
		_grant(peer_id, carrier)
	else:
		if peer_id == SERVER_PEER:
			set_multiplayer_authority(SERVER_PEER)
		_grant.rpc_id(SERVER_PEER, peer_id, carrier)


## The server's half of [method _hand_to]: where the buddy goes, then whose it is, in that order everywhere. The
## server arbitrates: a peer only picks it up for itself and only while nobody else has it (on an arm, or in the air
## from their throw), and only whoever has it lets go of it. A refused pick-up needs no answer: the buddy was never
## in the sender's hands, since only the server's [method _carry_by] puts it there.
@rpc("any_peer", "reliable")
func _grant(peer_id: int, carrier: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = SERVER_PEER # the server's own call
	var holder: int = carried_by
	if holder == 0 and (get_multiplayer_authority() != SERVER_PEER or is_thrown):
		holder = get_multiplayer_authority() # a throw is the thrower's until it lands
	if carrier > 0:
		if carrier != sender or peer_id != sender or (holder != 0 and holder != sender):
			return
	elif holder != sender or (peer_id != SERVER_PEER and peer_id != sender):
		return
	if carrier >= 0:
		_carry_by.rpc(carrier)
	_set_authority.rpc(peer_id)


## From the server only (or this peer's own call): the buddy is [param peer_id]'s.
@rpc("any_peer", "call_local", "reliable")
func _set_authority(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() <= SERVER_PEER:
		set_multiplayer_authority(peer_id)


## A carrier or thrower who drops out takes the authority with them, and a carried buddy would go with their Player:
## every peer puts it back into the scene, lets go of it and hands it to the server, as the horse does.
func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id != get_multiplayer_authority() and peer_id != carried_by:
		return
	carried_by = 0
	collision_shape.disabled = false
	_return_to_scene()
	set_multiplayer_authority(SERVER_PEER)
	is_held = false
	is_thrown = false
	velocity = Vector3.ZERO


## Moves the buddy from the player's spring arm back to where it lived before, keeping its world position. The
## same parent on every peer, or the copies end up under different paths and the synchronizer's data lands on
## a node the other side cannot find. One already there stays put.
func _return_to_scene() -> void:
	var home: Node = _home if is_instance_valid(_home) else get_tree().root
	if get_parent() != home:
		reparent(home)

extends AnimatableBody3D
## A boat the Player sits in with the "action" interaction while looking at it; it rides the pool's waves.
##
## One seat, the server's to give: Action asks the server for it, the first Player to ask gets it and their own peer
## sits them down, and anyone asking while it is taken is refused. The server keeps who sits there in
## [member occupant_peer], which the SeatSynchronizer replicates, so every peer hides the dummy passenger while a real
## Player is in the seat, a peer joining later included. Standing up, or leaving the game, frees the seat.

const SERVER_PEER: int = 1

@export var water: Buoyancy ## The water the boat floats on; without it the boat sits still.
@export var hull_length: float = 2.0 ## Bow-to-stern distance (m) the waves are sampled over for pitch.
@export var hull_width: float = 1.0 ## Port-to-starboard distance (m) sampled for roll.
@export var rock_multiplier: float = 1.0 ## Exaggerates the tilt.
@export var response_time: float = 1.0 ## Seconds the hull takes to settle onto a wave; the heft of the boat. Longer shrugs off more of the chop.

var player: Player ## The Player looking at the boat or seated in it.
var occupant_peer: int = 0: ## The peer whose Player sits in the seat, 0 when it is free. The server's, replicated; the dummy passenger shows only while it is 0.
	set(value):
		occupant_peer = value
		if is_node_ready():
			seat_01_dummy.visible = value == 0
var _seated: bool = false
var _mooring: Transform3D ## Placement in the scene; the wave motion is applied on top each frame.
var _heave: float = 0.0 ## Current lift above the mooring (m).
var _heave_velocity: float = 0.0
var _tilt: Vector2 = Vector2.ZERO ## Current pitch and roll (rad).
var _tilt_velocity: Vector2 = Vector2.ZERO

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var seat_01: Marker3D = $Seat01
@onready var seat_01_dummy: Node3D = $Seat01/y_bot_root ## Placeholder passenger hidden while a Player is seated.


func _ready() -> void:
	_mooring = global_transform
	seat_01_dummy.visible = occupant_peer == 0
	set_physics_process(water != null)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Called when there is an input event. The gate is the looking Player's authority, not the boat's (the server
## owns the boat), so a client can ask for the seat too.
func _input(event: InputEvent) -> void:
	if player and player.is_multiplayer_authority() and action_prompt.visible and not player.is_sitting \
			and not player.is_typing and not player.is_paused and event.is_action_pressed("action"):
		_request_seat.rpc_id(SERVER_PEER, get_path_to(player))
		hide_menu()


## Called by [Camera] while the player looks at the boat.
func display_menu(_player: Player) -> void:
	if _player.is_sitting:
		return
	player = _player
	action_prompt.show_for(player.controls)


## Called by [Camera] when the player looks away from the boat.
func hide_menu() -> void:
	action_prompt.hide()
	if player and not player.is_sitting:
		player = null


## The server's half of sitting down: the seat goes to the Player at [param player_path] (relative to the boat, so it
## resolves on every peer) when it is free and that Player is the sender's own; that peer then sits them down.
@rpc("any_peer", "call_local", "reliable")
func _request_seat(player_path: NodePath) -> void:
	var sitter: Player = get_node_or_null(player_path) as Player
	if not multiplayer.is_server() or occupant_peer != 0 or sitter == null \
			or sitter.get_multiplayer_authority() != multiplayer.get_remote_sender_id():
		return
	occupant_peer = sitter.get_multiplayer_authority()
	_sit.rpc_id(occupant_peer, player_path)


## The server gave this peer the seat: its Player at [param player_path] sits down and is pinned there.
@rpc("authority", "call_local", "reliable")
func _sit(player_path: NodePath) -> void:
	var sitter: Player = get_node_or_null(player_path) as Player
	if sitter == null or not sitter.is_multiplayer_authority() or sitter.is_sitting:
		return
	player = sitter
	player.state_changed.connect(_on_player_state_changed)
	player.state_machine.travel(player.current_state, NodeStateMachine.States.SITTING)


## The seated Player stood up: the server frees the seat, for the sender's own Player only.
@rpc("any_peer", "call_local", "reliable")
func _leave_seat() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == occupant_peer:
		occupant_peer = 0


## A seated Player who leaves the game leaves the seat free.
func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id == occupant_peer:
		occupant_peer = 0


## Pins the Player to the seat while sitting and gives the seat back once they stand up.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.NONE:
		return # travel() passes through NONE on its way to the next state
	_seated = to_state == NodeStateMachine.States.SITTING
	set_physics_process(_seated or water != null)
	if not _seated:
		player.state_changed.disconnect(_on_player_state_changed)
		player = null
		_leave_seat.rpc_id(SERVER_PEER)


## Rides the waves (they have no signal) and keeps a seated Player on the seat.
func _physics_process(delta: float) -> void:
	if water:
		_ride_waves(delta)
	if not _seated:
		return
	player.global_position = seat_01.global_position
	player.orientation = seat_01.global_transform
	player.orientation.origin = Vector3.ZERO
	player.player_model.global_transform = seat_01.global_transform
	player.velocity = Vector3.ZERO


## Eases toward the mean wave height under the hull and the tilt toward the higher end and side.
## The hull is a critically damped spring on each axis, so it has the heft to ignore ripples shorter
## than its own swing and never overshoots the swell it follows. The waves are read once for the four samples.
func _ride_waves(delta: float) -> void:
	var origin: Vector3 = _mooring.origin
	var waves: Buoyancy.Waves = water.read_waves()
	var bow: float = water.get_wave_offset(origin + _mooring.basis.z * hull_length * 0.5, waves)
	var stern: float = water.get_wave_offset(origin - _mooring.basis.z * hull_length * 0.5, waves)
	var starboard: float = water.get_wave_offset(origin + _mooring.basis.x * hull_width * 0.5, waves)
	var port: float = water.get_wave_offset(origin - _mooring.basis.x * hull_width * 0.5, waves)
	var target_heave: float = (bow + stern + starboard + port) * 0.25
	var target_tilt: Vector2 = Vector2(-atan2(bow - stern, hull_length), atan2(starboard - port, hull_width)) * rock_multiplier
	var stiffness: float = pow(TAU / maxf(response_time, 0.01), 2.0)
	var damping: float = 2.0 * sqrt(stiffness)
	_heave_velocity += ((target_heave - _heave) * stiffness - _heave_velocity * damping) * delta
	_heave += _heave_velocity * delta
	_tilt_velocity += ((target_tilt - _tilt) * stiffness - _tilt_velocity * damping) * delta
	_tilt += _tilt_velocity * delta
	global_transform = Transform3D(_mooring.basis * Basis.from_euler(Vector3(_tilt.x, 0.0, _tilt.y)), origin + Vector3.UP * _heave)

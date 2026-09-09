extends AnimatableBody3D
## A boat the Player sits in with the "action" interaction while looking at it; it rides the pool's waves.

@export var water: Buoyancy ## The water the boat floats on; without it the boat sits still.
@export var hull_length: float = 2.0 ## Bow-to-stern distance (m) the waves are sampled over for pitch.
@export var hull_width: float = 1.0 ## Port-to-starboard distance (m) sampled for roll.
@export var rock_multiplier: float = 1.0 ## Exaggerates the tilt.
@export var response_time: float = 1.0 ## Seconds the hull takes to settle onto a wave; the heft of the boat. Longer shrugs off more of the chop.

var player: Player ## The Player looking at the boat or seated in it.
var _seated: bool = false
var _mooring: Transform3D ## Placement in the scene; the wave motion is applied on top each frame.
var _heave: float = 0.0 ## Current lift above the mooring (m).
var _heave_velocity: float = 0.0
var _tilt: Vector2 = Vector2.ZERO ## Current pitch and roll (rad).
var _tilt_velocity: Vector2 = Vector2.ZERO

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var seat_01: Marker3D = $Seat01
@onready var seat_01_dummy: Node3D = $Seat01/y_bot_root ## Placeholder passenger hidden while the Player is seated.


func _ready() -> void:
	_mooring = global_transform
	set_physics_process(water != null)


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return

	if player and action_prompt.visible and not player.is_sitting and event.is_action_pressed("action"):
		player.state_changed.connect(_on_player_state_changed)
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SITTING)
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


## Pins the Player to the seat while sitting and releases the boat once they stand up.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.NONE:
		return # travel() passes through NONE on its way to the next state
	_seated = to_state == NodeStateMachine.States.SITTING
	seat_01_dummy.visible = not _seated
	set_physics_process(_seated or water != null)
	if not _seated:
		player.state_changed.disconnect(_on_player_state_changed)
		player = null


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
## than its own swing and never overshoots the swell it follows.
func _ride_waves(delta: float) -> void:
	var origin: Vector3 = _mooring.origin
	var bow: float = water.get_wave_offset(origin + _mooring.basis.z * hull_length * 0.5)
	var stern: float = water.get_wave_offset(origin - _mooring.basis.z * hull_length * 0.5)
	var starboard: float = water.get_wave_offset(origin + _mooring.basis.x * hull_width * 0.5)
	var port: float = water.get_wave_offset(origin - _mooring.basis.x * hull_width * 0.5)
	var target_heave: float = (bow + stern + starboard + port) * 0.25
	var target_tilt: Vector2 = Vector2(-atan2(bow - stern, hull_length), atan2(starboard - port, hull_width)) * rock_multiplier
	var stiffness: float = pow(TAU / maxf(response_time, 0.01), 2.0)
	var damping: float = 2.0 * sqrt(stiffness)
	_heave_velocity += ((target_heave - _heave) * stiffness - _heave_velocity * damping) * delta
	_heave += _heave_velocity * delta
	_tilt_velocity += ((target_tilt - _tilt) * stiffness - _tilt_velocity * damping) * delta
	_tilt += _tilt_velocity * delta
	global_transform = Transform3D(_mooring.basis * Basis.from_euler(Vector3(_tilt.x, 0.0, _tilt.y)), origin + Vector3.UP * _heave)

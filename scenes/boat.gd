extends AnimatableBody3D
## A boat the Player sits in with the "action" interaction while looking at it; it rides the pool's waves.

@export var water: Buoyancy ## The water the boat floats on; without it the boat sits still.
@export var hull_length: float = 2.0 ## Bow-to-stern distance (m) the waves are sampled over for pitch.
@export var hull_width: float = 1.0 ## Port-to-starboard distance (m) sampled for roll.
@export var rock_multiplier: float = 3.0 ## Exaggerates the tilt so pool-sized waves still read as rocking.

var player: Player ## The Player looking at the boat or seated in it.
var _seated: bool = false
var _mooring: Transform3D ## Placement in the scene; the wave motion is applied on top each frame.

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
	action_prompt.show_for(player)


## Called by [Camera] when the player looks away from the boat.
func hide_menu() -> void:
	action_prompt.hide()
	if player and not player.is_sitting:
		player = null


## Pins the Player to the seat while sitting and releases the boat once they stand up.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	_seated = to_state == NodeStateMachine.States.SITTING
	seat_01_dummy.visible = not _seated
	set_physics_process(_seated or water != null)
	if not _seated:
		player.state_changed.disconnect(_on_player_state_changed)
		player = null


## Rides the waves (they have no signal) and keeps a seated Player on the seat.
func _physics_process(_delta: float) -> void:
	if water:
		_ride_waves()
	if not _seated:
		return
	player.global_position = seat_01.global_position
	player.orientation = seat_01.global_transform
	player.orientation.origin = Vector3.ZERO
	player.player_model.global_transform = seat_01.global_transform
	player.velocity = Vector3.ZERO


## Bobs on the mean wave height under the hull and tilts toward the higher end and side.
func _ride_waves() -> void:
	var origin: Vector3 = _mooring.origin
	var bow: float = water.get_wave_offset(origin + _mooring.basis.z * hull_length * 0.5)
	var stern: float = water.get_wave_offset(origin - _mooring.basis.z * hull_length * 0.5)
	var starboard: float = water.get_wave_offset(origin + _mooring.basis.x * hull_width * 0.5)
	var port: float = water.get_wave_offset(origin - _mooring.basis.x * hull_width * 0.5)
	var pitch: float = -atan2(bow - stern, hull_length) * rock_multiplier
	var roll: float = atan2(starboard - port, hull_width) * rock_multiplier
	global_transform = Transform3D(_mooring.basis * Basis.from_euler(Vector3(pitch, 0.0, roll)), origin + Vector3.UP * (bow + stern + starboard + port) * 0.25)

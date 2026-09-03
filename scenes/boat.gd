extends StaticBody3D
## A boat the Player sits in with the "action" interaction while looking at it.

var player: Player ## The Player looking at the boat or seated in it.

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var seat_01: Marker3D = $Seat01
@onready var seat_01_dummy: Node3D = $Seat01/y_bot_root ## Placeholder passenger hidden while the Player is seated.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(false)


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
	var is_seated: bool = to_state == NodeStateMachine.States.SITTING
	seat_01_dummy.visible = not is_seated
	set_physics_process(is_seated)
	if not is_seated:
		player.state_changed.disconnect(_on_player_state_changed)
		player = null


## Called every physics frame while the Player is seated.
func _physics_process(_delta: float) -> void:
	player.global_position = seat_01.global_position
	player.orientation = seat_01.global_transform
	player.orientation.origin = Vector3.ZERO
	player.player_model.global_transform = seat_01.global_transform
	player.velocity = Vector3.ZERO

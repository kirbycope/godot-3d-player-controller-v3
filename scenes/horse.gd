class_name Horse
extends CharacterBody3D
## A rideable horse on the Player's [Riding] contract: walk up, Action mounts, the horse walks and runs on the
## move input and turns with left and right, Action gets off. The N-Hance model from aethereal is the body; its
## clips are in place, not root motion (no position track moves over a cycle), so the body is driven here and the
## [AnimationTree] in the scene only follows: a Locomotion blend space (turn across, pace up: idle, walk, run and
## the left, right and backwards cycles) and a JumpStart, JumpLoop, JumpEnd chain that [member is_jumping] and
## [method is_on_floor] advance through their transitions' expressions. The Riding state pins the rider to
## [member seat] (the seat contract property) after every ride, so they turn and move with the horse in the same
## frame and their own camera comes along; they play [member rider_animation] while up there.

signal locomotion_requested(state_path: String, immediate: bool) ## Asks the rider to play an animation node.

const BLEND_PATH: String = "parameters/Locomotion/blend_position"
const JUMP_STATES: Array[StringName] = [&"JumpStart", &"JumpLoop", &"JumpEnd"]

@export_category("Riding Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_sprint_action: StringName = &"sprint"
@export var keyboard_jump_action: StringName = &"jump"
@export var keyboard_dismount_action: StringName = &"action"
@export_group("Controller/Touch Actions")
@export var pad_sprint_action: StringName = &"sprint"
@export var pad_jump_action: StringName = &"jump"
@export var pad_dismount_action: StringName = &"action"
@export_group("")

@export var walk_speed: float = 3.5 ## Metres per second on the move input.
@export var run_speed: float = 11.0 ## Metres per second with sprint held: a gallop, three times the walk.
@export var acceleration: float = 8.0 ## Metres per second squared toward the wanted speed.
@export var turn_speed: float = 2.0 ## Radians per second on the left and right input.
@export var jump_speed: float = 5.0
@export var blend_speed: float = 6.0 ## Per-second rate the blend space position follows the pace and the turn.
@export var rider_animation: String = "Driving" ## The Player's locomotion node while mounted (the seated driving pose, which the tree holds while riding); a riding clip goes here once there is one.

var player: Player ## The rider, or the Player standing by the horse.
var menu_displayed: bool = false
var blocks_hands: bool = true ## Both hands on the reins (rideable contract).
var disables_collision: bool = true ## The rider sits inside the horse's body (rideable contract).
var input_type: int = Controls.InputType.KEYBOARD_MOUSE ## Kept equal to the Player's input device by the Riding state.
var speed: float = 0.0 ## Current forward speed along the facing.
var is_jumping: bool = false ## Read by the tree: takes Locomotion into JumpStart; off again on landing.
var _turn: float = 0.0 ## The current left/right input, for the blend space.
var _air_time: float = 0.0 ## Seconds off the ground; a drop longer than a spawn settle or a bump counts as a jump too.

@onready var model: Node3D = $Horse
@onready var animation_player: AnimationPlayer = $Horse/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var seat: Marker3D = $Seat ## Where the rider sits; the Riding state pins them here (rideable contract).
@onready var dismount_point: Marker3D = $DismountPoint ## Where the rider lands on getting off.
@onready var action_prompt: ActionPrompt = $ActionPrompt


func _ready() -> void:
	add_to_group("horses")


func _input(event: InputEvent) -> void:
	if player == null or player.is_riding or not menu_displayed:
		return
	if event.is_action_pressed("action"):
		player.mount(self)
		get_viewport().set_input_as_handled()


## Gravity and the last wanted speed keep applying whether or not somebody is on; a riderless horse just stands.
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	if is_on_floor() and velocity.y <= 0.0:
		is_jumping = false # landed (a jump just pressed still has the floor under it this frame)
	elif _air_time > 0.35:
		is_jumping = true # a real drop, not a spawn settle or a bump
	if player == null or not player.is_riding:
		speed = move_toward(speed, 0.0, acceleration * delta)
		_turn = move_toward(_turn, 0.0, blend_speed * delta)
		velocity = _forward() * speed + Vector3.UP * velocity.y
		move_and_slide()
		_animate(delta)


## Facing along +Z of the body; the model's head is on +Z as imported, so it needs no turn.
func _forward() -> Vector3:
	return global_basis.z


# --- Rideable contract --------------------------------------------------------------------------------------------

## The Riding state hands the Player over, already pinned to the seat; they play [member rider_animation].
func mount(_player: Player) -> void:
	player = _player
	_hide_prompt()
	locomotion_requested.emit(rider_animation, true)


## The Player gets off beside the horse.
func dismount(_player: Player) -> void:
	_player.global_position = dismount_point.global_position
	_player.velocity = Vector3.ZERO
	speed = 0.0
	_turn = 0.0
	player = null


## Every physics frame with a rider: the move input drives the horse; the Riding state pins the rider to the seat after.
func ride(_player: Player, delta: float) -> void:
	var motion: Vector2 = _player.player_input.motion
	if _player.is_paused or _player.is_ragdolling:
		motion = Vector2.ZERO
	if not is_zero_approx(motion.x):
		rotate_y(-motion.x * turn_speed * delta)
	_turn = move_toward(_turn, motion.x, blend_speed * delta)
	var wanted: float = 0.0
	if motion.y > 0.0:
		wanted = (run_speed if Input.is_action_pressed(_action(keyboard_sprint_action, pad_sprint_action)) else walk_speed) * motion.y
	elif motion.y < 0.0:
		wanted = walk_speed * 0.5 * motion.y # backing up, slowly
	speed = move_toward(speed, wanted, acceleration * delta)
	velocity = _forward() * speed + Vector3.UP * velocity.y
	move_and_slide()
	_animate(delta)


## Action gets off; jump hops the horse.
func ride_input(_player: Player, event: InputEvent) -> void:
	if event.is_action_pressed(_action(keyboard_dismount_action, pad_dismount_action)):
		_player.dismount()
	elif event.is_action_pressed(_action(keyboard_jump_action, pad_jump_action)) and is_on_floor():
		velocity.y = jump_speed
		is_jumping = true


func get_contextual_controls(_input_type: int) -> Dictionary:
	return {
		"left_joystick": "Ride",
		"right_joystick": "Camera",
		"joypad_button_3": "Jump",
		"joypad_button_1": "Gallop",
		"joypad_button_0": "Dismount",
	}


# --- Helpers -----------------------------------------------------------------------------------------------------

## The blend space position for the pace and the turn: walk is half way up, a gallop the top, backing up below.
func pace_blend() -> Vector2:
	var pace: float = 0.0
	if speed > walk_speed:
		pace = 0.5 + 0.5 * clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	elif speed > 0.0:
		pace = 0.5 * clampf(speed / walk_speed, 0.0, 1.0)
	elif speed < 0.0:
		pace = -0.5 * clampf(-speed / (walk_speed * 0.5), 0.0, 1.0)
	return Vector2(_turn, pace)


## Eases the blend space toward the pace; the jump chain runs on the tree's own transitions.
func _animate(delta: float) -> void:
	var current: Vector2 = animation_tree.get(BLEND_PATH)
	animation_tree.set(BLEND_PATH, current.lerp(pace_blend(), clampf(blend_speed * delta, 0.0, 1.0)))


## The action for the rider's current input device.
func _action(keyboard_action: StringName, pad_action: StringName) -> StringName:
	return keyboard_action if input_type == Controls.InputType.KEYBOARD_MOUSE else pad_action


## Wired to PlayerDetection.body_entered: the Player who walked up gets the prompt.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not (body as Player).is_riding:
		player = body
		action_prompt.update_text()
		action_prompt.show_for(player, "Mount")
		menu_displayed = true


## Wired to PlayerDetection.body_exited: walking away takes the prompt with it.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == player and not player.is_riding:
		_hide_prompt()
		player = null


func _hide_prompt() -> void:
	menu_displayed = false
	if action_prompt.visible and player and player.riding != self:
		action_prompt.hide_for(player)
	else:
		action_prompt.hide()

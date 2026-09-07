class_name Horse
extends CharacterBody3D
## A rideable horse on the Player's [Riding] contract: walk up, Action mounts, the horse steers like the Player on
## foot (the move input points somewhere relative to the camera, the horse turns to face it and walks or runs that
## way), Action gets off. The N-Hance model from aethereal is the body; its
## clips are in place, not root motion (no position track moves over a cycle), so the body is driven here and the
## [AnimationTree] in the scene only follows: a Locomotion blend space read up its middle for the pace (idle, walk,
## run; the body turns to face the way it goes, like the Player model, so the turning cycles at the sides are not
## used) and a JumpStart, JumpLoop, JumpEnd chain that [member is_jumping] and
## [method is_on_floor] advance through their transitions' expressions. The Riding state pins the rider to
## [member seat] (the seat contract property) after every ride, so they turn and move with the horse in the same
## frame while their own camera keeps its view; they play [member rider_animation] while up there.

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
@export var turn_speed: float = 10.0 ## Per-second rate the body turns to face where the move input points, the Player model's rotation_interpolate_speed.
@export var jump_speed: float = 5.0
@export var blend_speed: float = 6.0 ## Per-second rate the blend space position follows the pace.
@export var rider_animation: String = "Driving" ## The Player's locomotion node while mounted (the seated driving pose, which the tree holds while riding); a riding clip goes here once there is one.

@export var swim_speed: float = 1.5 ## Top speed in the water, ridden or heading home on its own.
@export var swim_depth: float = 0.85 ## How far below the surface the feet settle while swimming: half the body, like a floating ball.

var player: Player ## The rider, or the Player standing by the horse.
var menu_displayed: bool = false
var in_water_area: Buoyancy = null ## The water the horse is in; set by the world from the water's body signals.
var last_land_position: Vector3 = Vector3.ZERO ## Where it last stood on the ground; a riderless horse swims back here.
var blocks_hands: bool = true ## Both hands on the reins (rideable contract).
var disables_collision: bool = true ## The rider sits inside the horse's body (rideable contract).
var input_type: int = Controls.InputType.KEYBOARD_MOUSE ## Kept equal to the Player's input device by the Riding state.
var speed: float = 0.0 ## Current forward speed along the facing.
var is_jumping: bool = false ## Read by the tree: takes Locomotion into JumpStart; off again on landing.
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


## Gravity and the last wanted speed keep applying whether or not somebody is on; a riderless horse just stands,
## or, in the water, swims back to the last ground it stood on.
func _physics_process(delta: float) -> void:
	if in_water_area:
		_float(delta)
	elif not is_on_floor():
		velocity += get_gravity() * delta
	if is_on_floor() and in_water_area == null:
		last_land_position = global_position
	_air_time = 0.0 if is_on_floor() or in_water_area else _air_time + delta
	if (is_on_floor() and velocity.y <= 0.0) or in_water_area:
		is_jumping = false # landed (a jump just pressed still has the floor under it this frame)
	elif _air_time > 0.35:
		is_jumping = true # a real drop, not a spawn settle or a bump
	if player == null or not player.is_riding:
		if in_water_area:
			_swim_home(delta)
		else:
			speed = move_toward(speed, 0.0, acceleration * delta)
		velocity = _forward() * speed + Vector3.UP * velocity.y
		move_and_slide()
		_animate(delta)


## Buoyant: the body eases to [member swim_depth] under the surface instead of sinking.
func _float(_delta: float) -> void:
	var target_y: float = in_water_area.get_surface_height(global_position) - swim_depth
	velocity.y = clampf((target_y - global_position.y) * 4.0, -3.0, 3.0)


## Turns toward [member last_land_position] and paddles there; it eases to a stop once it is close.
func _swim_home(delta: float) -> void:
	var to_land: Vector3 = last_land_position - global_position
	to_land.y = 0.0
	if to_land.length() < 0.6:
		speed = move_toward(speed, 0.0, acceleration * delta)
		return
	var wanted_yaw: float = atan2(to_land.x, to_land.z) # +Z is the facing
	rotation.y = lerp_angle(rotation.y, wanted_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	speed = move_toward(speed, swim_speed, acceleration * delta)


## Facing along +Z of the body; the model's head is on +Z as imported, so it needs no turn.
func _forward() -> Vector3:
	return global_basis.z


## Standing on the ground or held up by the water: what ends the jump chain in the animation tree, so a horse
## that jumps into the pool comes down into the walk instead of hanging in the air.
func is_grounded() -> bool:
	return is_on_floor() or in_water_area != null


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
	player = null


## Every physics frame with a rider: the move input drives the horse the way it drives the Player on foot, relative
## to the camera: it turns toward where the input points and walks or gallops that way. The Riding state pins the
## rider to the seat after.
func ride(_player: Player, delta: float) -> void:
	var motion: Vector2 = _player.player_input.motion
	if _player.is_paused or _player.is_ragdolling:
		motion = Vector2.ZERO
	var wish: Vector3 = (_player.camera.global_basis * Vector3(motion.x, 0.0, -motion.y)).slide(Vector3.UP)
	var wanted: float = 0.0
	if wish.length() > 0.05:
		# Face the way it goes, as fast as the Player model turns; no turning cycles, the body just points there
		rotation.y = lerp_angle(rotation.y, atan2(wish.x, wish.z), clampf(turn_speed * delta, 0.0, 1.0)) # +Z is the facing
		var pace: float = run_speed if Input.is_action_pressed(_action(keyboard_sprint_action, pad_sprint_action)) else walk_speed
		wanted = pace * minf(wish.length(), 1.0)
	if in_water_area:
		wanted = minf(wanted, swim_speed) # no galloping through water
	speed = move_toward(speed, wanted, acceleration * delta)
	velocity = _forward() * speed + Vector3.UP * velocity.y
	move_and_slide()
	_animate(delta)


## Action gets off; jump hops the horse.
func ride_input(_player: Player, event: InputEvent) -> void:
	if event.is_action_pressed(_action(keyboard_dismount_action, pad_dismount_action)):
		_player.dismount()
	elif event.is_action_pressed(_action(keyboard_jump_action, pad_jump_action)) and is_on_floor() and in_water_area == null:
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

## The blend space position for the pace, up the middle: walk is half way up, a gallop the top; the turn axis stays
## at zero because the body itself turns.
func pace_blend() -> Vector2:
	var pace: float = 0.0
	if speed > walk_speed:
		pace = 0.5 + 0.5 * clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	elif speed > 0.0:
		pace = 0.5 * clampf(speed / walk_speed, 0.0, 1.0)
	elif speed < 0.0:
		pace = -0.5 * clampf(-speed / (walk_speed * 0.5), 0.0, 1.0)
	return Vector2(0.0, pace)


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

extends FollowerNpc
## A small companion that follows the Player and can be picked up, carried and thrown.

const LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/LocomotionBlendSpace/blend_position"
const LOCOMOTION_STATE_MACHINE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"

@export var throw_force_horizontal: float = 16.0
@export var throw_force_vertical: float = 3.5

var is_held: bool = false
var is_thrown: bool = false

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var animation_tree: AnimationTree = $y_bot_root/AnimationTree
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _physics_process(delta: float) -> void:
	if is_held:
		return
	super(delta)


## Lets a throw carry the buddy until it lands, then resumes following.
func _follow_player(delta: float) -> void:
	if is_thrown:
		move_and_slide()
		is_thrown = not is_on_floor()
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
	var current_blend: float = animation_tree.get(LOCOMOTION_BLEND_POSITION_PATH)
	var blend_speed: float = 8.0 if target_blend < current_blend else 6.0
	animation_tree.set(LOCOMOTION_BLEND_POSITION_PATH, move_toward(current_blend, target_blend, blend_speed * get_physics_process_delta_time()))


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
	action_prompt.show_for(player)


## Called by [Camera] when the player looks away from the buddy.
func hide_menu() -> void:
	action_prompt.hide()


func _input(event: InputEvent) -> void:
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


func pick_up() -> void:
	if not player or not player.item_spring_arm:
		return
	is_held = true
	hide_menu()

	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	collision_shape.disabled = true
	animation_tree.set(LOCOMOTION_BLEND_POSITION_PATH, 0.0)

	reparent(player.item_spring_arm, false)
	transform = Transform3D()


func drop() -> void:
	is_held = false
	is_thrown = false
	collision_shape.disabled = false
	_return_to_scene()
	velocity = Vector3.ZERO


func throw_with_direction(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	is_held = false
	is_thrown = true
	collision_shape.disabled = false
	_return_to_scene()

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


## Moves the buddy from the player's spring arm back into the current scene, keeping its world position.
func _return_to_scene() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = player.get_parent() if player and player.get_parent() else get_tree().root
	reparent(scene_root)

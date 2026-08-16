extends CharacterBody3D

const GIANT_QUACK_BUS: StringName = &"GiantDuck"
const GIANT_QUACK_BUS_LAYOUT: AudioBusLayout = preload("res://default_bus_layout.tres")
const WALK_ANIMATION: StringName = &"FBXExportClip_0_001"

@export var move_speed: float = 2.0 ## Speed at which the duck moves
@export var turn_speed: float = 10.0 ## Speed at which the duck turns
@export var follow_distance: float = 2.0 ## Distance to maintain from the player
@export var max_follow_distance: float = 10.0 ## Maximum distance before the duck stops following
@export var min_impact_speed: float = 2.0 ## Minimum collider speed that counts as an impact
@export var impact_upward_boost: float = 2.0 ## Extra upward speed added on impact
@export var knockback_damping: float = 6.0 ## How quickly knockback velocity decays
@export var respawn_height: float = -40.0
@export var giant_scale: float = 10.0
@export var giant_move_speed_multiplier: float = 2.0
@export var giant_follow_distance: float = 4.0
@export var giant_quack_pitch: float = 0.5
@export var collision_quack_speed: float = 1.0
@export var collision_quack_cooldown: float = 0.5

var knockback_velocity: Vector3 = Vector3.ZERO
var nav_ready: bool = false
var player: Player
var _collision_exception_added: bool = false
var _collision_quack_time: float = 0.0
var _is_giant: bool = false
var _player_range_initialized: bool = false
var _player_was_in_range: bool = false
var _spawn_transform: Transform3D

@onready var animation_player: AnimationPlayer = $WALK2/AnimationPlayer
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var bone_attachment_3d: BoneAttachment3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D
@onready var knife: Node3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D/Knife
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var walk_model: Node3D = $WALK2


func _ready() -> void:
	_ensure_giant_quack_bus()
	_spawn_transform = global_transform
	navigation_agent_3d.path_desired_distance = 0.5
	navigation_agent_3d.target_desired_distance = follow_distance
	call_deferred("_setup_navigation")


func _physics_process(delta: float) -> void:
	_collision_quack_time = maxf(_collision_quack_time - delta, 0.0)
	if global_position.y < respawn_height:
		_respawn_as_giant()
	if not is_on_floor():
		velocity += get_gravity() * delta
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_damping * delta)
	if not nav_ready:
		_move_with_control(Vector3.ZERO)
		return
	if not player:
		_find_player()
		if not player:
			_move_with_control(Vector3.ZERO)
			return
	if player.is_driving and not _is_giant:
		_stop_moving()
		return
	up_direction = player.up_direction
	var distance_to_player: float = global_position.distance_to(player.global_position)
	_update_player_range(distance_to_player)

	# Only follow if within range and beyond the follow distance
	if distance_to_player > max_follow_distance or distance_to_player <= follow_distance:
		_stop_moving()
		return
	navigation_agent_3d.target_position = player.global_position
	if navigation_agent_3d.is_navigation_finished():
		_stop_moving()
		return
	var next_path_position: Vector3 = navigation_agent_3d.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(next_path_position)
	direction = direction.slide(up_direction)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()

		# Rotate the duck to face the direction of movement
		var look_target: Vector3 = global_position + direction
		var target_transform: Transform3D = global_transform.looking_at(look_target, up_direction)
		global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
		_move_with_control(direction * move_speed)
		_play_walk_animation()
	else:
		_stop_moving()


## Adds an instantaneous velocity change, e.g. when hit by a vehicle.
func apply_impulse(impulse: Vector3, _position: Vector3 = Vector3.ZERO) -> void:
	knockback_velocity += impulse.slide(up_direction)
	velocity += impulse.project(up_direction)
	if impulse.length() >= collision_quack_speed:
		_play_quack()


## Responds to physics props, such as the beach ball, registering a hit.
func register_hit(_hit_node: Node = null) -> void:
	_play_quack()


func _setup_navigation() -> void:
	# Wait for the first physics frame so the NavigationServer can sync
	await get_tree().physics_frame
	nav_ready = true


func _find_player() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		player = current_scene.find_child("Player", true, false) as Player
	if player and not _collision_exception_added:
		add_collision_exception_with(player)
		_collision_exception_added = true


func _move_with_control(control_velocity: Vector3) -> void:
	var vertical_velocity: Vector3 = velocity.project(up_direction)
	velocity = control_velocity.slide(up_direction) + knockback_velocity + vertical_velocity
	var movement_velocity: Vector3 = velocity
	move_and_slide()
	_check_impacts(movement_velocity)


func _check_impacts(movement_velocity: Vector3) -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		var impact_speed: float = -movement_velocity.dot(collision.get_normal())
		if collider is RigidBody3D:
			var body: RigidBody3D = collider
			var impact_velocity: Vector3 = body.linear_velocity
			impact_speed = maxf(impact_speed, impact_velocity.dot(collision.get_normal()))
			if impact_velocity.length() >= min_impact_speed \
					and knockback_velocity.length() < min_impact_speed:
				apply_impulse(impact_velocity + up_direction * impact_upward_boost)
		if impact_speed >= collision_quack_speed \
				and _collision_quack_time <= 0.0:
			_play_quack()


func _respawn_as_giant() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	if not _is_giant:
		_is_giant = true
		walk_model.scale *= giant_scale
		move_speed *= giant_move_speed_multiplier
		follow_distance = giant_follow_distance
		max_follow_distance *= giant_scale
		navigation_agent_3d.target_desired_distance = follow_distance
		knife.visible = true
		audio_stream_player_3d.pitch_scale = giant_quack_pitch
		audio_stream_player_3d.unit_size *= giant_scale
		audio_stream_player_3d.bus = GIANT_QUACK_BUS
	audio_stream_player_3d.play()


func _play_quack() -> void:
	if _collision_quack_time > 0.0:
		return
	audio_stream_player_3d.play()
	_collision_quack_time = collision_quack_cooldown


func _play_walk_animation() -> void:
	animation_player.play(WALK_ANIMATION)


func _ensure_giant_quack_bus() -> void:
	if AudioServer.get_bus_index(GIANT_QUACK_BUS) < 0:
		AudioServer.set_bus_layout(GIANT_QUACK_BUS_LAYOUT)


func _update_player_range(distance_to_player: float) -> void:
	var is_in_range: bool = distance_to_player <= max_follow_distance
	if not _player_range_initialized:
		_player_range_initialized = true
		_player_was_in_range = is_in_range
		return
	if is_in_range == _player_was_in_range:
		return
	_player_was_in_range = is_in_range
	audio_stream_player_3d.play()


func _stop_moving() -> void:
	_move_with_control(Vector3.ZERO)
	if animation_player.is_playing():
		animation_player.pause()

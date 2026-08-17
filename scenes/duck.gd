extends CharacterBody3D

const GIANT_QUACK_BUS: StringName = &"GiantDuck"
const GIANT_QUACK_BUS_LAYOUT: AudioBusLayout = preload("res://default_bus_layout.tres")
const ANIMATION_NAME: StringName = &"FBXExportClip_0_001"

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
@export var attack_quack_cooldown: float = 1.2
@export var swimming_depth_offset: float = -0.2 ## Depth to submerge when swimming

var is_swimming: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var nav_ready: bool = false
var player: Player
var _attack_quack_time: float = 0.0
var _collision_exception_added: bool = false
var _collision_quack_time: float = 0.0
var _is_giant: bool = false
var _player_range_initialized: bool = false
var _player_was_in_range: bool = false
var _spawn_transform: Transform3D

@onready var animation_player_eat: AnimationPlayer = $EAT2/AnimationPlayer
@onready var eat_model: Node3D = $EAT2
@onready var animation_player_idle: AnimationPlayer = $IDLE2/AnimationPlayer
@onready var idle_model: Node3D = $IDLE2
@onready var animation_player_walk: AnimationPlayer = $WALK2/AnimationPlayer
@onready var walk_model: Node3D = $WALK2
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var bone_attachment_3d: BoneAttachment3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D
@onready var knife: Node3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_idle: Node3D = $IDLE2/IDLE/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_walk: Node3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_eat: Node3D = $EAT2/EAT/Skeleton3D/BoneAttachment3D/Knife
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_ensure_giant_quack_bus()
	_spawn_transform = global_transform
	navigation_agent_3d.path_desired_distance = 0.5
	navigation_agent_3d.target_desired_distance = follow_distance
	knife.visible = _is_giant
	knife_idle.visible = _is_giant
	knife_walk.visible = _is_giant
	knife_eat.visible = _is_giant
	_stop_moving()
	call_deferred("_setup_navigation")


func _physics_process(delta: float) -> void:
	_collision_quack_time = maxf(_collision_quack_time - delta, 0.0)
	_attack_quack_time = maxf(_attack_quack_time - delta, 0.0)
	if global_position.y < respawn_height:
		_respawn_as_giant()
		
	var water_surface_along_up: float = _get_water_surface_along_up()
	if not is_nan(water_surface_along_up):
		var current_position_along_up := up_direction.dot(global_position)
		if water_surface_along_up > current_position_along_up:
			is_swimming = true
		else:
			is_swimming = false
	else:
		is_swimming = false

	if is_swimming:
		var current_swimming_offset: float = swimming_depth_offset
		if _is_giant:
			current_swimming_offset *= giant_scale
			
		var target_y = water_surface_along_up + current_swimming_offset
		var current_y = up_direction.dot(global_position)
		var vertical_correction = (target_y - current_y) * 5.0
		if vertical_correction < 0.0 and is_on_floor():
			vertical_correction = 0.0
		
		var current_up_vel = velocity.project(up_direction).length() * sign(up_direction.dot(velocity))
		if current_up_vel > 1.0:
			velocity += get_gravity() * delta
		else:
			velocity -= velocity.project(up_direction)
			velocity += up_direction * vertical_correction
	elif not is_on_floor():
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
	if distance_to_player > max_follow_distance:
		_stop_moving()
		return

	# If giant is already in an attack animation, commit to it unless player moves far away or we need to climb out of water
	if _is_giant and animation_player_eat.is_playing() and distance_to_player <= follow_distance * 1.5:
		if not (is_swimming and not player.is_swimming):
			var direction_to_player: Vector3 = global_position.direction_to(player.global_position).slide(up_direction)
			if direction_to_player.length_squared() > 0.0001:
				var look_target: Vector3 = global_position + direction_to_player.normalized()
				var target_transform: Transform3D = global_transform.looking_at(look_target, up_direction)
				global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
			_move_with_control(Vector3.ZERO)
			_play_eating_animation()
			return

	var vertical_distance: float = abs(up_direction.dot(global_position) - up_direction.dot(player.global_position))
	var is_close_enough: bool = distance_to_player <= follow_distance and vertical_distance < 1.5
	if _is_giant:
		is_close_enough = distance_to_player <= follow_distance and vertical_distance < 2.5
	# If duck is swimming and player is on land, duck is never "close enough" until it exits water
	if is_swimming and not player.is_swimming:
		is_close_enough = false

	if is_close_enough:
		if _is_giant:
			var direction_to_player: Vector3 = global_position.direction_to(player.global_position).slide(up_direction)
			if direction_to_player.length_squared() > 0.0001:
				var look_target: Vector3 = global_position + direction_to_player.normalized()
				var target_transform: Transform3D = global_transform.looking_at(look_target, up_direction)
				global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
			_move_with_control(Vector3.ZERO)
			_play_eating_animation()
		else:
			_stop_moving()
		return
	navigation_agent_3d.target_position = player.global_position
	var next_path_position: Vector3
	if is_swimming or navigation_agent_3d.is_navigation_finished() or not navigation_agent_3d.is_target_reachable():
		next_path_position = player.global_position
	else:
		next_path_position = navigation_agent_3d.get_next_path_position()
		
	var direction: Vector3 = global_position.direction_to(next_path_position)
	direction = direction.slide(up_direction)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()

		# Rotate the duck to face the direction of movement
		var look_target: Vector3 = global_position + direction
		var target_transform: Transform3D = global_transform.looking_at(look_target, up_direction)
		global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
		
		var current_speed: float = move_speed
		if is_swimming:
			current_speed *= 0.5
			if is_on_wall():
				velocity -= velocity.project(up_direction)
				var climb_vel: float = 2.5
				if _is_giant:
					climb_vel = 4.5
				velocity += up_direction * climb_vel
				
		_move_with_control(direction * current_speed)
		_play_walk_animation()
	else:
		if _is_giant and distance_to_player <= follow_distance:
			_play_eating_animation()
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
		var impact_speed: float = - movement_velocity.dot(collision.get_normal())
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
		idle_model.scale *= giant_scale
		walk_model.scale *= giant_scale
		eat_model.scale *= giant_scale
		move_speed *= giant_move_speed_multiplier
		follow_distance = giant_follow_distance
		max_follow_distance *= giant_scale
		navigation_agent_3d.target_desired_distance = follow_distance
		knife.visible = true
		knife_idle.visible = true
		knife_walk.visible = true
		knife_eat.visible = true
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
	idle_model.visible = false
	walk_model.visible = true
	eat_model.visible = false
	if not animation_player_walk.is_playing():
		animation_player_walk.play(ANIMATION_NAME)
	if animation_player_idle.is_playing():
		animation_player_idle.stop()
	if animation_player_eat.is_playing():
		animation_player_eat.stop()


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
	idle_model.visible = true
	walk_model.visible = false
	eat_model.visible = false
	if animation_player_walk.is_playing():
		animation_player_walk.pause()
	if animation_player_eat.is_playing():
		animation_player_eat.stop()
	if not animation_player_idle.is_playing():
		animation_player_idle.play(ANIMATION_NAME)


func _play_eating_animation() -> void:
	idle_model.visible = false
	walk_model.visible = false
	eat_model.visible = true
	var was_playing: bool = animation_player_eat.is_playing()
	if not was_playing:
		animation_player_eat.play(ANIMATION_NAME)
	if not was_playing and _attack_quack_time <= 0.0:
		audio_stream_player_3d.play()
		_attack_quack_time = attack_quack_cooldown
	if animation_player_idle.is_playing():
		animation_player_idle.stop()
	if animation_player_walk.is_playing():
		animation_player_walk.pause()


func _get_water_surface_along_up() -> float:
	if not is_inside_tree():
		return NAN
	var tree := get_tree()
	if not tree:
		return NAN

	var has_surface := false
	var highest_surface_along_up := 0.0
	
	var water_nodes := tree.get_nodes_in_group("WATER")
	for node in water_nodes:
		var water_area := node as Area3D
		if not water_area:
			continue
		
		var overlapping := water_area.overlaps_body(self)
		if not overlapping:
			continue

		var collision_shape := water_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not collision_shape:
			continue

		var box_shape := collision_shape.shape as BoxShape3D
		if not box_shape:
			continue

		var up_in_local: Vector3 = collision_shape.global_basis.inverse() * up_direction
		var half_size: Vector3 = box_shape.size * 0.5
		var half_extent_along_up: float = abs(up_in_local.x) * half_size.x \
			+ abs(up_in_local.y) * half_size.y \
			+ abs(up_in_local.z) * half_size.z

		var local_surface: Vector3 = up_in_local.normalized() * half_extent_along_up
		var world_surface: Vector3 = collision_shape.to_global(local_surface)
		var surface_along_up: float = up_direction.dot(world_surface)

		if not has_surface or surface_along_up > highest_surface_along_up:
			has_surface = true
			highest_surface_along_up = surface_along_up

	if not has_surface:
		return NAN
	return highest_surface_along_up

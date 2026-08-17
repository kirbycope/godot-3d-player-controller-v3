extends CharacterBody3D

@export var move_speed: float = 3.0
@export var turn_speed: float = 10.0
@export var stopping_distance: float = 2.0
@export var throw_force_horizontal: float = 16.0
@export var throw_force_vertical: float = 3.5
@export var apply_gravity: bool = true
@export var min_impact_speed: float = 2.0 ## Minimum collider speed that counts as an impact
@export var impact_upward_boost: float = 2.0 ## Extra upward speed added on impact
@export var knockback_damping: float = 6.0 ## How quickly knockback velocity decays
@export var swimming_depth_offset: float = -0.3 ## Depth to submerge when swimming

var is_swimming: bool = false
var is_held: bool = false
var is_thrown: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var menu_displayed: bool = false
var nav_ready: bool = false
var player: Player
var _collision_exception_added: bool = false

@onready var action_prompt: Node3D = $ActionPrompt
@onready var animation_tree: AnimationTree = $y_bot_root/AnimationTree
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	if animation_tree:
		animation_tree.active = true
		
	if navigation_agent_3d:
		navigation_agent_3d.target_desired_distance = stopping_distance
		# We must connect the avoidance signal to apply the safe velocity
		navigation_agent_3d.velocity_computed.connect(_on_velocity_computed)

	# Wait for the first physics frame so the NavigationServer can sync.
	call_deferred("_nav_setup")

func _nav_setup() -> void:
	nav_ready = true

func _physics_process(delta: float) -> void:
	if is_held:
		return
		
	var water_surface_along_up: float = _get_water_surface_along_up()
	var new_is_swimming: bool = false
	if not is_nan(water_surface_along_up):
		var current_position_along_up := up_direction.dot(global_position)
		if water_surface_along_up > current_position_along_up:
			new_is_swimming = true
			
	if new_is_swimming != is_swimming:
		is_swimming = new_is_swimming
		if is_swimming and animation_tree:
			animation_tree.get("parameters/LocomotionStateMachine/playback").travel("Swimming")
		elif not is_swimming and animation_tree:
			animation_tree.get("parameters/LocomotionStateMachine/playback").travel("LocomotionBlendSpace")
		
	if is_swimming:
		var target_y = water_surface_along_up + swimming_depth_offset
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
	elif apply_gravity and not is_on_floor():
		velocity += get_gravity() * delta
		
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_damping * delta)
		
	if is_thrown:
		# Let the throw velocity and gravity carry the NPC until it lands
		move_and_slide()
		if is_on_floor():
			is_thrown = false
		return
		
	if not nav_ready:
		_move_with_control(Vector3.ZERO)
		return
		
	if not player:
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			player = current_scene.find_child("Player", true, false) as Player
		if not player:
			_move_with_control(Vector3.ZERO)
			return
			
	if player and not _collision_exception_added:
		add_collision_exception_with(player)
		_collision_exception_added = true
	if player.is_driving:
		_stop_moving()
		return
	up_direction = player.up_direction
		
	# Update the target position (staggered to avoid massive CPU spikes with many agents)
	if navigation_agent_3d:
		if Engine.get_physics_frames() % 20 == get_instance_id() % 20:
			if navigation_agent_3d.target_position.distance_squared_to(player.global_position) > 0.5:
				navigation_agent_3d.target_position = player.global_position
	
	# Explicit distance check (prevents getting stuck spinning near target)
	var dist_sq_to_player: float = global_position.distance_squared_to(player.global_position)
	var vertical_distance: float = abs(up_direction.dot(global_position) - up_direction.dot(player.global_position))
	var is_close_enough: bool = dist_sq_to_player <= stopping_distance * stopping_distance and vertical_distance < 1.5
	if is_swimming and not player.is_swimming:
		is_close_enough = false
	if is_close_enough:
		_stop_moving()
		return

	var current_agent_position: Vector3 = global_position
	var target_pos: Vector3
	
	# If nav agent can't find a path or we are swimming,
	# fallback to moving directly towards the player.
	if not is_swimming and navigation_agent_3d and navigation_agent_3d.is_target_reachable():
		target_pos = navigation_agent_3d.get_next_path_position()
		# If the next path position is exactly above/below us (like stuck snapping), fallback
		var horizontal_offset: Vector3 = (target_pos - current_agent_position).slide(up_direction)
		if horizontal_offset.length() < 0.1:
			target_pos = player.global_position
	else:
		target_pos = player.global_position
		
	var direction: Vector3 = current_agent_position.direction_to(target_pos)
	direction = direction.slide(up_direction) # Ignore difference along up_direction for heading

	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		
		# Look at the next path position
		var look_target: Vector3 = global_position + direction
		var current_transform: Transform3D = global_transform
		var target_transform: Transform3D = current_transform.looking_at(look_target, up_direction)
		global_transform = current_transform.interpolate_with(target_transform, turn_speed * delta)
		
		var current_speed: float = move_speed
		if is_swimming:
			current_speed *= 0.5
			if is_on_wall():
				velocity -= velocity.project(up_direction)
				velocity += up_direction * 2.5
				
		var target_velocity: Vector3 = direction * current_speed
		animation_tree.set("parameters/LocomotionStateMachine/LocomotionBlendSpace/blend_position", 1.0)
		
		if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
			# With avoidance, movement happens in _on_velocity_computed
			navigation_agent_3d.set_velocity(target_velocity)
		else:
			_move_with_control(target_velocity)
	else:
		_stop_moving()


## Adds an instantaneous velocity change, e.g. when hit by a vehicle.
func apply_impulse(impulse: Vector3, _position: Vector3 = Vector3.ZERO) -> void:
	knockback_velocity += impulse.slide(up_direction)
	velocity += impulse.project(up_direction)


func _move_with_control(control_velocity: Vector3) -> void:
	var vertical_velocity: Vector3 = velocity.project(up_direction)
	velocity = control_velocity.slide(up_direction) + knockback_velocity + vertical_velocity
	move_and_slide()
	_check_impacts()


func _check_impacts() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is RigidBody3D:
			var body: RigidBody3D = collider
			var impact_velocity: Vector3 = body.linear_velocity
			if impact_velocity.length() >= min_impact_speed \
					and knockback_velocity.length() < min_impact_speed:
				apply_impulse(impact_velocity + up_direction * impact_upward_boost)


func _stop_moving() -> void:
	animation_tree.set("parameters/Locomotion/blend_position", 0.0)
	if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
		navigation_agent_3d.set_velocity(Vector3.ZERO)
	else:
		_move_with_control(Vector3.ZERO)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# This signal is triggered by set_velocity() in _physics_process
	# We use it to apply the avoidance-adjusted velocity.
	if is_thrown or is_held:
		return
		
	_move_with_control(safe_velocity)


func sfx_footsteps_play() -> void:
	pass

func display_menu(_player: Player) -> void:
	if is_held:
		return
	player = _player
	if not player:
		push_warning("Player is not defined.")
		return
	if action_prompt:
		action_prompt.message_end = "to pick up"
		action_prompt.show()
		action_prompt.update_text()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
		menu_displayed = true
	else:
		push_warning("Action prompt is not defined.")

func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
		menu_displayed = false

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
	
	if menu_displayed and not is_held:
		if event.is_action_pressed("action") and not event.is_echo():
			pick_up()
			get_viewport().set_input_as_handled()

func pick_up() -> void:
	if not player or not player.item_spring_arm:
		return
	is_held = true
	hide_menu()
	
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	if collision_shape:
		collision_shape.disabled = true
	if animation_tree:
		animation_tree.set("parameters/Locomotion/blend_position", 0.0)
	
	if get_parent():
		get_parent().remove_child(self)
	player.item_spring_arm.add_child(self)
	
	transform = Transform3D()
	position = Vector3.ZERO

func drop() -> void:
	is_held = false
	is_thrown = false
	
	if collision_shape:
		collision_shape.disabled = false
		
	var current_scene = get_tree().current_scene
	var drop_pos = global_position
	if get_parent():
		get_parent().remove_child(self)
	current_scene.add_child(self)
	global_position = drop_pos
	_collision_exception_added = false
	velocity = Vector3.ZERO

func throw(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	throw_with_direction(throw_dir, throw_power)

func throw_with_direction(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	is_held = false
	is_thrown = true
	
	if collision_shape:
		collision_shape.disabled = false
		
	var current_scene = get_tree().current_scene
	var throw_pos = global_position
	if get_parent():
		get_parent().remove_child(self)
	current_scene.add_child(self)
	global_position = throw_pos
	_collision_exception_added = false
	
	if throw_dir.length_squared() < 0.001:
		if player and player.camera:
			throw_dir = -player.camera.global_transform.basis.z.normalized()
		elif player:
			throw_dir = player.get_facing_direction()
		if throw_dir.length_squared() < 0.001:
			throw_dir = Vector3.FORWARD
			
	var throw_up: Vector3 = player.up_direction if player else up_direction
	var impulse: Vector3 = (throw_dir * throw_force_horizontal + throw_up * throw_force_vertical) * throw_power
	velocity = impulse
	knockback_velocity = Vector3.ZERO


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

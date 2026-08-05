extends RigidBody3D

@export var move_speed: float = 3.0
var up_direction := Vector3.UP
@export var turn_speed: float = 10.0
@export var stopping_distance: float = 2.0
@export var throw_force_horizontal: float = 16.0
@export var throw_force_vertical: float = 3.5
@export var apply_gravity: bool = true

@onready var animation_tree: AnimationTree = $y_bot_root/AnimationTree
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

var player: Player
var nav_ready := false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_held: bool = false
var is_thrown: bool = false
var menu_displayed: bool = false
var _collision_exception_added: bool = false
@onready var action_prompt: Node3D = $ActionPrompt
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	axis_lock_angular_y = true # Prevent physics engine from spinning the NPC
	
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
		
	if not apply_gravity:
		gravity_scale = 0.0
	else:
		gravity_scale = 1.0
		
	if is_thrown:
		# Check if we hit the floor to stop being "thrown" (RigidBody handles movement naturally)
		var bodies = get_colliding_bodies()
		if bodies.size() > 0:
			is_thrown = false
		return
		
	if not nav_ready:
		return
		
	if not player:
		var current_scene = get_tree().current_scene
		if current_scene:
			player = current_scene.find_child("Player", true, false) as Player
		if not player:
			return
			
	if player and not _collision_exception_added:
		add_collision_exception_with(player)
		_collision_exception_added = true
		
	# Update the target position (staggered to avoid massive CPU spikes with many agents)
	if navigation_agent_3d:
		if Engine.get_physics_frames() % 20 == get_instance_id() % 20:
			if navigation_agent_3d.target_position.distance_squared_to(player.global_position) > 0.5:
				navigation_agent_3d.target_position = player.global_position
	
	# Explicit distance check (prevents getting stuck spinning near target)
	var dist_sq_to_player = global_position.distance_squared_to(player.global_position)
	if dist_sq_to_player <= stopping_distance * stopping_distance:
		animation_tree.set("parameters/Locomotion/blend_position", 0.0)
		_stop_moving()
		return

	# Stop if nav agent is perfectly finished
	if navigation_agent_3d and navigation_agent_3d.is_navigation_finished():
		animation_tree.set("parameters/Locomotion/blend_position", 0.0)
		_stop_moving()
		return

	var current_agent_position: Vector3 = global_position
	var target_pos: Vector3
	
	# If nav agent can't find a path (e.g. Player jumped off nav mesh or no nav mesh baked), 
	# fallback to moving directly towards the player.
	if navigation_agent_3d and navigation_agent_3d.is_target_reachable():
		target_pos = navigation_agent_3d.get_next_path_position()
		# If the next path position is exactly above/below us (like stuck snapping), fallback
		var horizontal_dist = Vector2(current_agent_position.x - target_pos.x, current_agent_position.z - target_pos.z).length()
		if horizontal_dist < 0.1:
			target_pos = player.global_position
	else:
		target_pos = player.global_position
		
	var direction: Vector3 = current_agent_position.direction_to(target_pos)
	direction = direction.slide(up_direction) # Ignore difference along up_direction for heading

	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		
		# Look at the next path position
		var look_target = global_position + direction
		var current_transform = global_transform
		var target_transform = current_transform.looking_at(look_target, up_direction)
		global_transform = current_transform.interpolate_with(target_transform, turn_speed * delta)
		
		# Compute horizontal velocity
		var target_velocity = direction * move_speed
		
		if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
			# If using avoidance, pass it to the agent so it can compute safe_velocity
			navigation_agent_3d.set_velocity(target_velocity)
		else:
			# Otherwise apply forces to reach the target velocity
			var current_h_vel = linear_velocity
			current_h_vel.y = 0
			var velocity_diff = target_velocity - current_h_vel
			apply_central_force(velocity_diff * mass * 10.0)
		
		animation_tree.set("parameters/Locomotion/blend_position", 1.0)
	else:
		animation_tree.set("parameters/Locomotion/blend_position", 0.0)
		_stop_moving()


func _stop_moving() -> void:
	if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
		navigation_agent_3d.set_velocity(Vector3.ZERO)
	else:
		var current_h_vel = linear_velocity
		current_h_vel.y = 0
		apply_central_force(-current_h_vel * mass * 10.0)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# This signal is triggered by set_velocity() in _physics_process
	# We use it to apply the avoidance-adjusted velocity.
	if is_thrown or is_held:
		return
		
	var target_h_vel = safe_velocity.slide(up_direction)
	var current_h_vel = linear_velocity
	current_h_vel.y = 0
	var velocity_diff = target_h_vel - current_h_vel
	apply_central_force(velocity_diff * mass * 10.0)


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
	
	freeze = true
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
	freeze = false
	
	if collision_shape:
		collision_shape.disabled = false
		
	var current_scene = get_tree().current_scene
	var drop_pos = global_position
	if get_parent():
		get_parent().remove_child(self)
	current_scene.add_child(self)
	global_position = drop_pos
	_collision_exception_added = false
	linear_velocity = Vector3.ZERO

func throw(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	throw_with_direction(throw_dir, throw_power)

func throw_with_direction(throw_dir: Vector3 = Vector3.ZERO, throw_power: float = 1.0) -> void:
	is_held = false
	is_thrown = true
	freeze = false
	
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
			
	var impulse = (throw_dir * throw_force_horizontal + Vector3(0, throw_force_vertical, 0)) * throw_power
	apply_central_impulse(impulse * mass)

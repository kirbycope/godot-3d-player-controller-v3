extends CharacterBody3D

@export var move_speed: float = 3.0
@export var turn_speed: float = 10.0
@export var stopping_distance: float = 2.0
@export var apply_gravity: bool = true

@onready var animation_tree: AnimationTree = $y_bot_root/AnimationTree
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

var player: Player
var nav_ready := false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

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
	# Apply gravity if enabled and not on floor
	if apply_gravity and not is_on_floor():
		velocity.y -= gravity * delta
	elif not apply_gravity:
		velocity.y = 0 # Prevent falling if gravity is disabled
		
	if not nav_ready:
		move_and_slide()
		return
		
	if not player:
		var current_scene = get_tree().current_scene
		if current_scene:
			player = current_scene.find_child("Player", true, false) as Player
			if player:
				# Add a collision exception so they don't block the player
				add_collision_exception_with(player)
		if not player:
			move_and_slide()
			return
		
	# Update the target position
	if navigation_agent_3d:
		navigation_agent_3d.target_position = player.global_position
	
	# Explicit distance check (prevents getting stuck spinning near target)
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= stopping_distance:
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
	direction.y = 0.0 # Ignore vertical difference for heading

	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		
		# Look at the next path position
		var look_target = global_position + direction
		var current_transform = global_transform
		var target_transform = current_transform.looking_at(look_target, Vector3.UP)
		global_transform = current_transform.interpolate_with(target_transform, turn_speed * delta)
		
		# Compute horizontal velocity
		var new_velocity = direction * move_speed
		
		if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
			# If using avoidance, pass it to the agent so it can compute safe_velocity
			navigation_agent_3d.set_velocity(new_velocity)
		else:
			# Otherwise just move immediately
			velocity.x = new_velocity.x
			velocity.z = new_velocity.z
			move_and_slide()
		
		animation_tree.set("parameters/Locomotion/blend_position", 1.0)
	else:
		animation_tree.set("parameters/Locomotion/blend_position", 0.0)
		_stop_moving()

func _stop_moving() -> void:
	if navigation_agent_3d and navigation_agent_3d.avoidance_enabled:
		navigation_agent_3d.set_velocity(Vector3.ZERO)
	else:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# This signal is triggered by set_velocity() in _physics_process
	# We use it to apply the avoidance-adjusted velocity.
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()

func sfx_footsteps_play() -> void:
	pass

extends CharacterBody3D

@export var move_speed: float = 2.0 ## Speed at which the duck moves
@export var turn_speed: float = 10.0 ## Speed at which the duck turns
@export var follow_distance: float = 2.0 ## Distance to maintain from the player
@export var max_follow_distance: float = 10.0 ## Maximum distance before the duck stops following
@export var min_impact_speed: float = 2.0 ## Minimum collider speed that counts as an impact
@export var impact_upward_boost: float = 2.0 ## Extra upward speed added on impact
@export var knockback_damping: float = 6.0 ## How quickly knockback velocity decays

var knockback_velocity: Vector3 = Vector3.ZERO
var nav_ready: bool = false
var player: Player
var _collision_exception_added: bool = false

@onready var animation_player: AnimationPlayer = $WALK2/AnimationPlayer
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	navigation_agent_3d.path_desired_distance = 0.5
	navigation_agent_3d.target_desired_distance = follow_distance
	call_deferred("_setup_navigation")


func _physics_process(delta: float) -> void:
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
	if player.is_driving:
		_stop_moving()
		return
	up_direction = player.up_direction
	var distance_to_player: float = global_position.distance_to(player.global_position)

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
		if not animation_player.is_playing():
			animation_player.play("FBXExportClip_0_001")
	else:
		_stop_moving()


## Adds an instantaneous velocity change, e.g. when hit by a vehicle.
func apply_impulse(impulse: Vector3) -> void:
	knockback_velocity += impulse.slide(up_direction)
	velocity += impulse.project(up_direction)


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
	_move_with_control(Vector3.ZERO)
	if animation_player.is_playing():
		animation_player.pause()

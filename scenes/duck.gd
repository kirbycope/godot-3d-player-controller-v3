extends FollowerNpc
## A duck that follows the Player, quacks on impacts, and respawns as a knife-wielding giant if it falls out of the world.

const GIANT_QUACK_BUS: StringName = &"GiantDuck"
const GIANT_QUACK_BUS_LAYOUT: AudioBusLayout = preload("res://default_bus_layout.tres")
const ANIMATION_NAME: StringName = &"FBXExportClip_0_001"

@export var respawn_height: float = -40.0
@export var giant_scale: float = 10.0
@export var giant_move_speed_multiplier: float = 2.0
@export var giant_follow_distance: float = 4.0
@export var giant_quack_pitch: float = 0.5
@export var collision_quack_speed: float = 1.0 ## Minimum impact speed that triggers a quack.

var _is_giant: bool = false
var _model_collision_shapes: Array[CollisionShape3D] = [] ## Per-model shapes toggled with the visible model while giant.
var _player_range_initialized: bool = false
var _player_was_in_range: bool = false
var _spawn_transform: Transform3D

@onready var animation_player_eat: AnimationPlayer = $EAT2/AnimationPlayer
@onready var eat_model: Node3D = $EAT2
@onready var animation_player_idle: AnimationPlayer = $IDLE2/AnimationPlayer
@onready var idle_model: Node3D = $IDLE2
@onready var animation_player_walk: AnimationPlayer = $WALK2/AnimationPlayer
@onready var walk_model: Node3D = $WALK2
@onready var attack_quack_cooldown: Timer = $AttackQuackCooldown
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var collision_quack_cooldown: Timer = $CollisionQuackCooldown
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var knife: Node3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_idle: Node3D = $IDLE2/IDLE/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_walk: Node3D = $WALK2/WALK/Skeleton3D/BoneAttachment3D/Knife
@onready var knife_eat: Node3D = $EAT2/EAT/Skeleton3D/BoneAttachment3D/Knife


func _ready() -> void:
	super()
	if AudioServer.get_bus_index(GIANT_QUACK_BUS) < 0:
		AudioServer.set_bus_layout(GIANT_QUACK_BUS_LAYOUT)
	_spawn_transform = global_transform
	navigation_agent_3d.path_desired_distance = 0.5
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		if shape != collision_shape:
			_model_collision_shapes.append(shape as CollisionShape3D)
	knife.visible = _is_giant
	knife_idle.visible = _is_giant
	knife_walk.visible = _is_giant
	knife_eat.visible = _is_giant
	_update_collision_shapes()
	_stop_moving()


func _physics_process(delta: float) -> void:
	if global_position.y < respawn_height and not _is_giant:
		_respawn_as_giant()
	if player:
		_update_player_range(global_position.distance_to(player.global_position))
	super(delta)


## A giant mid-attack commits to it while the player stays near.
func _follow_player(delta: float) -> void:
	if _is_giant and animation_player_eat.is_playing() \
	and global_position.distance_to(player.global_position) <= follow_distance * 1.5 \
	and not (is_swimming and not player.is_swimming):
		_face_player(delta)
		_stop_moving()
		return
	super(delta)


## Adds an instantaneous velocity change, e.g. when hit by a vehicle.
func apply_impulse(impulse: Vector3, _position: Vector3 = Vector3.ZERO) -> void:
	super(impulse, _position)
	if impulse.length() >= collision_quack_speed:
		_play_quack()


## Responds to physics props, such as the beach ball, registering a hit.
func register_hit(_hit_node: Node = null) -> void:
	_play_quack()


func _on_collided(impact_speed: float) -> void:
	if impact_speed >= collision_quack_speed:
		_play_quack()


func _move_with_control(control_velocity: Vector3) -> void:
	super(control_velocity)
	if control_velocity != Vector3.ZERO:
		_play_walk_animation()


func _stop_moving() -> void:
	super()
	if _is_giant and player and global_position.distance_to(player.global_position) <= follow_distance * 1.5:
		_play_eating_animation()
	else:
		_play_idle_animation()


func _respawn_as_giant() -> void:
	_is_giant = true
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	idle_model.scale *= giant_scale
	walk_model.scale *= giant_scale
	eat_model.scale *= giant_scale
	move_speed *= giant_move_speed_multiplier
	follow_distance = giant_follow_distance
	follow_height_tolerance = 2.5
	follow_while_driving = true
	max_follow_distance *= giant_scale
	mass *= giant_scale * 10.0
	swim_climb_speed = 4.5
	swimming_depth_offset *= giant_scale
	navigation_agent_3d.target_desired_distance = follow_distance
	knife.visible = true
	knife_idle.visible = true
	knife_walk.visible = true
	knife_eat.visible = true
	audio_stream_player_3d.pitch_scale = giant_quack_pitch
	audio_stream_player_3d.unit_size *= giant_scale
	audio_stream_player_3d.bus = GIANT_QUACK_BUS
	_update_collision_shapes()
	audio_stream_player_3d.play()


func _play_quack() -> void:
	if not collision_quack_cooldown.is_stopped():
		return
	audio_stream_player_3d.play()
	collision_quack_cooldown.start()


## Quacks when the player crosses the follow range in either direction.
func _update_player_range(distance_to_player: float) -> void:
	var exit_threshold: float = max_follow_distance + 0.5
	var is_in_range: bool = distance_to_player <= max_follow_distance if not _player_was_in_range else distance_to_player <= exit_threshold
	if not _player_range_initialized:
		_player_range_initialized = true
		_player_was_in_range = distance_to_player <= max_follow_distance
		return
	if is_in_range == _player_was_in_range:
		return
	_player_was_in_range = is_in_range
	audio_stream_player_3d.play()


func _play_walk_animation() -> void:
	idle_model.visible = false
	walk_model.visible = true
	eat_model.visible = false
	if _is_giant:
		_update_collision_shapes()
	if not animation_player_walk.is_playing():
		animation_player_walk.play(ANIMATION_NAME)
	animation_player_idle.stop()
	animation_player_eat.stop()


func _play_idle_animation() -> void:
	idle_model.visible = true
	walk_model.visible = false
	eat_model.visible = false
	if _is_giant:
		_update_collision_shapes()
	animation_player_walk.pause()
	animation_player_eat.stop()
	if not animation_player_idle.is_playing():
		animation_player_idle.play(ANIMATION_NAME)


func _play_eating_animation() -> void:
	idle_model.visible = false
	walk_model.visible = false
	eat_model.visible = true
	if _is_giant:
		_update_collision_shapes()
	if not animation_player_eat.is_playing():
		animation_player_eat.play(ANIMATION_NAME)
		if attack_quack_cooldown.is_stopped():
			audio_stream_player_3d.play()
			attack_quack_cooldown.start()
	animation_player_idle.stop()
	animation_player_walk.pause()


## The giant uses the visible model's shapes instead of the small root shape.
func _update_collision_shapes() -> void:
	collision_shape.disabled = _is_giant
	for shape: CollisionShape3D in _model_collision_shapes:
		var is_vis: bool = shape.is_visible_in_tree() if shape.is_inside_tree() else shape.visible
		shape.disabled = not (_is_giant and is_vis)

extends FollowerNpc
## A duck that follows the Player and quacks on impacts. Killing it, or letting it fall out of the world, brings it
## back as a knife-wielding giant boss that hunts the Player; killing the giant returns the duckling. The size, the
## animation and the health replicate from the server, so the puppets grow, walk and eat with it; hits relay, and
## every quack is the server's, sent to every peer. The giant's bite runs on AttackQuackCooldown's timeout.

const GIANT_QUACK_BUS: StringName = &"GiantDuck" ## A bus of the project's default_bus_layout.tres, with the giant's reverb and delay.
const ANIMATION_NAME: StringName = &"FBXExportClip_0_001"

@export var respawn_height: float = -40.0
@export var giant_scale: float = 10.0
@export var giant_move_speed_multiplier: float = 2.0
@export var giant_follow_distance: float = 4.0
@export var leash_distance: float = 20.0 ## The giant gives up on a dead Player, or one further than this from its spawn, and walks home to heal; the Player's spawn point lies outside it.
@export var giant_quack_pitch: float = 0.5
@export var collision_quack_speed: float = 1.0 ## Minimum impact speed that triggers a quack.
@export var giant_health: float = 400.0
@export var giant_damage: float = 25.0 ## Health the giant's knife takes when it actually touches the Player.
@export var melee_hit_damage: float = 25.0 ## Damage taken from one of the Player's melee swings.

var is_giant: bool = false: ## Replicated; the setter sizes the models, shows the knife and deepens the quack on every peer.
	set(value):
		if value == is_giant:
			return
		is_giant = value
		if is_node_ready():
			_apply_giant()
var anim_state: StringName = &"idle": ## Replicated: which of the three models shows and plays (idle, walk or eat); only a change switches them.
	set(value):
		if value == anim_state:
			return
		anim_state = value
		if is_node_ready():
			_apply_anim_state()
var _model_collision_shapes: Array[CollisionShape3D] = [] ## Per-model shapes toggled with the visible model while giant.
var _player_range_initialized: bool = false
var _player_was_in_range: bool = false
var _spawn_transform: Transform3D
var _leashed: bool = false ## The giant is walking home with nobody to hunt.
var _duckling: Dictionary = {} ## The small duck's tunables, restored when the giant falls.

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
@onready var health: Health = $Health
@onready var boss: Boss = $Boss
@onready var status_bars: StatusBars3D = $StatusBars3D
@onready var knife_hitbox: MeleeHitbox = $EAT2/EAT/Skeleton3D/BoneAttachment3D/KnifeHitbox ## On the beak; live for each bite of the giant's eating cadence.


func _ready() -> void:
	super()
	_spawn_transform = global_transform
	_duckling = {"follow_distance": follow_distance, "follow_height_tolerance": follow_height_tolerance, "swim_climb_speed": swim_climb_speed, "max_health": health.max_health, "bus": audio_stream_player_3d.bus, "unit_size": audio_stream_player_3d.unit_size, "bars_y": status_bars.position.y}
	navigation_agent_3d.path_desired_distance = 0.5
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		if shape != collision_shape and not shape.get_parent() is Area3D:
			_model_collision_shapes.append(shape as CollisionShape3D)
	if is_giant:
		_apply_giant()
	_update_collision_shapes()
	_stop_moving()
	_apply_anim_state()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if global_position.y < respawn_height and not is_giant:
		_respawn_as_giant()
	if player:
		_update_player_range(global_position.distance_to(player.global_position))
		if is_giant and (not player.health.is_alive() or player.global_position.distance_to(_spawn_transform.origin) > leash_distance):
			# Nobody to hunt: give up, walk home and heal, like a leashed boss
			if not _leashed:
				_leashed = true
				boss.disengage()
				player.hunted_by(get_path(), false)
			_return_home(delta)
			return
		_leashed = false
		if is_giant and boss.target_peer == 0:
			boss.engage(player.get_multiplayer_authority())
			player.hunted_by(get_path(), true)
	super(delta)


## Walks the navigation mesh back to the spawn point; once there it idles and heals to full.
func _return_home(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var home: Vector3 = _spawn_transform.origin
	if (home - global_position).slide(up_direction).length() > 0.6:
		navigation_agent_3d.target_position = home
		var next: Vector3 = navigation_agent_3d.get_next_path_position() if navigation_agent_3d.is_target_reachable() else home
		var direction: Vector3 = global_position.direction_to(next).slide(up_direction).normalized()
		global_transform = global_transform.interpolate_with(global_transform.looking_at(global_position + direction, up_direction), turn_speed * delta)
		_move_with_control(direction * move_speed)
		return
	_stop_moving()
	health.health = health.max_health


## A giant mid-attack commits to it while the player stays near.
func _follow_player(delta: float) -> void:
	if is_giant and animation_player_eat.is_playing() \
	and global_position.distance_to(player.global_position) <= follow_distance * 1.5 \
	and not (is_swimming and not player.is_swimming):
		_face_player(delta)
		_stop_moving()
		return
	super(delta)


## Adds an instantaneous velocity change, e.g. when hit by a vehicle.
func apply_impulse(impulse: Vector3, _position: Vector3 = Vector3.ZERO) -> void:
	super(impulse, _position)
	if impulse.length() >= collision_quack_speed and is_multiplayer_authority():
		_play_quack.rpc()


## Responds to physics props, such as the beach ball, registering a hit.
func register_hit(_hit_node: Node = null) -> void:
	if is_multiplayer_authority():
		_play_quack.rpc()


## Called by [HitDetection] on the swinging Player's peer; unarmed swings pass the Player itself as the equipment,
## and the swinging Player is named as the hit's source.
func register_weapon_hit(equipment: Node = null, _hit_node: Node = null) -> void:
	var attacker: Node3D = (equipment as Equipment).player if equipment is Equipment else equipment as Node3D
	if is_instance_valid(attacker) and attacker.is_inside_tree():
		take_hit(melee_hit_damage, attacker.global_position, attacker.get_path())
	else:
		take_hit(melee_hit_damage, global_position)


## Called by a landing [Projectile], on the server's copy of the round alone; the shooter is named as the source.
func register_projectile_hit(projectile: Projectile, point: Vector3, _normal: Vector3) -> void:
	take_hit(projectile.damage, point, projectile.shooter.get_path() if is_instance_valid(projectile.shooter) else ^"")


## Damage counts on the server; a client relays its own, which the server takes only from the peer that owns the
## attacker [param source_path] names ([method FollowerNpc._may_affect]). A negative amount does nothing.
func take_hit(damage: float, from: Vector3, source_path: NodePath = ^"") -> void:
	if not multiplayer.is_server():
		_request_hit.rpc_id(1, damage, from, source_path)
		return
	_play_quack.rpc()
	health.damage(maxf(damage, 0.0), from)


@rpc("any_peer", "call_remote", "reliable")
func _request_hit(damage: float, from: Vector3, source_path: NodePath) -> void:
	if multiplayer.is_server() and _may_affect(source_path):
		take_hit(damage, from, source_path)


## Wired to Health.died: a dead duckling comes back as the giant, a dead giant as the duckling.
func _on_health_died() -> void:
	if not is_multiplayer_authority():
		return
	if is_giant:
		_become_duckling()
	else:
		_respawn_as_giant()


func _on_knife_hitbox_hit(_body: Node3D) -> void:
	_play_quack.rpc()


func _on_collided(impact_speed: float) -> void:
	if impact_speed >= collision_quack_speed:
		_play_quack.rpc()


func _move_with_control(control_velocity: Vector3) -> void:
	super(control_velocity)
	if control_velocity != Vector3.ZERO:
		anim_state = &"walk"


func _stop_moving() -> void:
	super()
	if is_giant and not _leashed and player and global_position.distance_to(player.global_position) <= follow_distance * 1.5:
		anim_state = &"eat"
	else:
		anim_state = &"idle"


## The giant's looks (size, knife, quack, collision, bars) for every peer through [member is_giant]; the rest of
## the giant is the authority's own (how it moves, hunts and hurts) and stays in [method _respawn_as_giant].
func _apply_giant() -> void:
	var factor: float = giant_scale if is_giant else 1.0 / giant_scale
	idle_model.scale *= factor
	walk_model.scale *= factor
	eat_model.scale *= factor
	knife.visible = is_giant
	knife_idle.visible = is_giant
	knife_walk.visible = is_giant
	knife_eat.visible = is_giant
	audio_stream_player_3d.pitch_scale = giant_quack_pitch if is_giant else 1.0
	audio_stream_player_3d.unit_size = _duckling["unit_size"] * (giant_scale if is_giant else 1.0)
	audio_stream_player_3d.bus = GIANT_QUACK_BUS if is_giant else _duckling["bus"]
	_update_collision_shapes()
	status_bars.position.y = _duckling["bars_y"] * (giant_scale if is_giant else 1.0)


func _respawn_as_giant() -> void:
	is_giant = true
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	move_speed *= giant_move_speed_multiplier
	follow_distance = giant_follow_distance
	follow_height_tolerance = 2.5
	follow_while_driving = true
	max_follow_distance *= giant_scale
	mass *= giant_scale * 10.0
	swim_climb_speed = 4.5
	swimming_depth_offset *= giant_scale
	navigation_agent_3d.target_desired_distance = follow_distance
	knife_hitbox.damage = giant_damage
	health.max_health = giant_health
	health.health = giant_health
	if player:
		boss.engage(player.get_multiplayer_authority())
		player.hunted_by(get_path(), true)
	_play_quack.rpc()


## Undoes [method _respawn_as_giant]: the duckling is back at its spawn with its own health.
func _become_duckling() -> void:
	is_giant = false
	_leashed = false
	boss.disengage()
	if player:
		player.hunted_by(get_path(), false)
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	move_speed /= giant_move_speed_multiplier
	follow_distance = _duckling["follow_distance"]
	follow_height_tolerance = _duckling["follow_height_tolerance"]
	follow_while_driving = false
	max_follow_distance /= giant_scale
	mass /= giant_scale * 10.0
	swim_climb_speed = _duckling["swim_climb_speed"]
	swimming_depth_offset /= giant_scale
	navigation_agent_3d.target_desired_distance = follow_distance
	health.max_health = _duckling["max_health"]
	health.health = health.max_health


## A quack on every peer, sent by the server; CollisionQuackCooldown keeps a run of bumps to one.
@rpc("authority", "call_local")
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
	_play_quack.rpc()


## Shows and plays the model for [member anim_state].
func _apply_anim_state() -> void:
	match anim_state:
		&"walk":
			_play_walk_animation()
		&"eat":
			_play_eating_animation()
		_:
			_play_idle_animation()


func _play_walk_animation() -> void:
	idle_model.visible = false
	walk_model.visible = true
	eat_model.visible = false
	if is_giant:
		_update_collision_shapes()
	if not animation_player_walk.is_playing():
		animation_player_walk.play(ANIMATION_NAME)
	animation_player_idle.stop()
	animation_player_eat.stop()


func _play_idle_animation() -> void:
	idle_model.visible = true
	walk_model.visible = false
	eat_model.visible = false
	if is_giant:
		_update_collision_shapes()
	animation_player_walk.pause()
	animation_player_eat.stop()
	if not animation_player_idle.is_playing():
		animation_player_idle.play(ANIMATION_NAME)


func _play_eating_animation() -> void:
	idle_model.visible = false
	walk_model.visible = false
	eat_model.visible = true
	if is_giant:
		_update_collision_shapes()
	if not animation_player_eat.is_playing():
		animation_player_eat.play(ANIMATION_NAME)
	# The first bite lands as the eating starts; AttackQuackCooldown times the rest
	if is_multiplayer_authority() and attack_quack_cooldown.is_stopped():
		_bite()
	animation_player_idle.stop()
	animation_player_walk.pause()


## One bite of the eating cadence, on the server: a quack every peer hears, and the giant's beak live for the swing so
## it hurts whatever it slams into.
func _bite() -> void:
	_play_quack.rpc()
	attack_quack_cooldown.start()
	if is_giant:
		knife_hitbox.swing()


## Wired to AttackQuackCooldown.timeout: the server bites again for as long as the duck is still eating.
func _on_attack_quack_cooldown_timeout() -> void:
	if is_multiplayer_authority() and anim_state == &"eat":
		_bite()


## The giant uses the visible model's shapes instead of the small root shape.
func _update_collision_shapes() -> void:
	collision_shape.disabled = is_giant
	for shape: CollisionShape3D in _model_collision_shapes:
		var is_vis: bool = shape.is_visible_in_tree() if shape.is_inside_tree() else shape.visible
		shape.disabled = not (is_giant and is_vis)

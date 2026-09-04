class_name EnemyNpc
extends FollowerNpc
## A hostile NPC: idles until the Player attacks it or steps within its aggro area, then chases over the
## navigation mesh and attacks in reach with a melee swing whose weapon hitbox must touch you, a projectile
## weapon, or abilities cast in range with line of sight. When the hunted Player dies, or strays further than
## [member leash_distance] from the post (a respawn far away counts), it turns on any other living Player still
## inside its aggro area or walks back to where it started, stands as it stood and heals to full.
## Health, death and the animation state replicate from the server; hits from clients relay.

signal aggroed(target: Node3D)
signal attacked(target: Node3D) ## A melee swing or a shot was started.
signal struck(body: Node3D) ## The weapon hitbox connected.
signal died
signal returned_home ## Back at the spawn point after the hunted Player died.

const LOCOMOTION_STATES: Array[String] = ["Idle", "Walking", "Running"]

@export var is_boss: bool = false ## Puts the name and health on the hunted player's HUD boss bar.
@export var attack_range: float = 1.6 ## Distance the attack lands from: melee reach, or firing range for projectiles.
@export var attack_damage: float = 15.0 ## Melee damage dealt by the weapon hitbox; projectiles carry their own.
@export var attack_interval: float = 1.5 ## Seconds between attacks or ability casts.
@export var attack_animation: String = "SwordAttack" ## AnimationTree state played for each attack.
@export var strike_delay: float = 0.45 ## Seconds into the attack animation when the hit or shot happens.
@export var projectile_scene: PackedScene ## Archers and riflemen fire this; empty means melee.
@export var projectile_speed: float = 30.0
@export var melee_hit_damage: float = 25.0 ## Damage taken from one of the Player's melee swings.
@export var leash_distance: float = 30.0 ## A target further than this from the post is given up on; the enemy resets.
@export var footstep_sfx: AudioStream ## Played by the walk and run animations' method tracks.

var target: Node3D ## The Player being hunted; abilities read it through [method Ability.get_target].
var is_returning_home: bool = false ## Walking back to the spawn point with nobody to hunt.
var _spawn_transform: Transform3D
var is_dead: bool = false: ## Replicated; the setter drops the body into the ragdoll on every peer.
	set(value):
		if value == is_dead:
			return
		is_dead = value
		if value and is_node_ready():
			_apply_death()
var anim_state: String = "Idle": ## Replicated AnimationTree state.
	set(value):
		anim_state = value
		if playback and String(playback.get_current_node()) != value:
			playback.start(value)

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var attack_timer: Timer = $AttackTimer ## Cooldown between attacks.
@onready var strike_timer: Timer = $StrikeTimer ## Delay from the swing's start to its hit or shot.
@onready var muzzle: Marker3D = $Muzzle ## Where projectiles leave.
@onready var weapon_hitbox: MeleeHitbox = $Mannequin_M/Armature/GeneralSkeleton/WeaponAttachment/WeaponHitbox ## Live during the swing's strike frames.
@onready var caster: NpcCaster = $NpcCaster
@onready var health: Health = $Health
@onready var boss: Boss = $Boss
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var aggro_area: Area3D = $AggroArea
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Mannequin_M/Armature/GeneralSkeleton/PhysicalBoneSimulator3D


func _ready() -> void:
	super()
	_spawn_transform = global_transform
	animation_tree.active = true
	attack_timer.wait_time = attack_interval
	strike_timer.wait_time = strike_delay
	if is_dead:
		_apply_death()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if caster.casting:
		# Stand and face the target through the cast
		if player:
			_face_player(delta)
		_stop_moving()
		return
	if is_returning_home:
		_return_home(delta)
		_update_locomotion()
		return
	if target and target.global_position.distance_to(_spawn_transform.origin) > leash_distance:
		# Off the leash (a respawn at the far spawn point, or a chase that went too far): reset
		_drop_target()
		is_returning_home = true
		_return_home(delta)
		_update_locomotion()
		return
	super(delta)
	_update_locomotion()
	if target == null or target.get("is_stealthed") or not attack_timer.is_stopped():
		return
	if not caster.abilities.is_empty() and caster.try_cast(target):
		attack_timer.start()
		return
	if global_position.distance_to(target.global_position) <= attack_range and (projectile_scene == null or caster.has_line_of_sight(target)):
		_attack()


## Hunts [param who]; only living Players are worth chasing.
func aggro(who: Node) -> void:
	if is_dead or not who is Player or target == who or not (who as Player).health.is_alive():
		return
	if is_instance_valid(target):
		target.health.died.disconnect(_on_target_died)
		target.hunted_by(get_path(), false)
	target = who
	player = who
	is_returning_home = false
	target.health.died.connect(_on_target_died)
	target.hunted_by(get_path(), true)
	if is_boss:
		boss.engage(who.get_multiplayer_authority())
	aggroed.emit(target)


## Gives up the hunt: the target died or went past the leash.
func _drop_target() -> void:
	if is_instance_valid(target):
		target.health.died.disconnect(_on_target_died)
		target.hunted_by(get_path(), false)
	target = null
	player = null
	caster.interrupt()
	boss.disengage()


## The hunted Player died: turn on another living Player still inside the aggro area, or head home.
func _on_target_died() -> void:
	_drop_target()
	for body: Node3D in aggro_area.get_overlapping_bodies():
		if body is Player and (body as Player).health.is_alive() and not (body as Player).is_stealthed:
			aggro(body)
			return
	is_returning_home = true


## Walks the navigation mesh back to the spawn point, then turns to stand as it stood.
func _return_home(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var home: Vector3 = _spawn_transform.origin
	if (home - global_position).slide(up_direction).length() > 0.5:
		navigation_agent_3d.target_position = home
		var next: Vector3 = navigation_agent_3d.get_next_path_position() if navigation_agent_3d.is_target_reachable() else home
		var direction: Vector3 = global_position.direction_to(next).slide(up_direction).normalized()
		global_transform = global_transform.interpolate_with(global_transform.looking_at(global_position + direction, up_direction), turn_speed * delta)
		_move_with_control(direction * move_speed)
		return
	_stop_moving()
	var facing: Transform3D = global_transform.looking_at(global_position - _spawn_transform.basis.z, up_direction)
	global_transform = global_transform.interpolate_with(facing, turn_speed * delta)
	if global_transform.basis.z.angle_to(_spawn_transform.basis.z) < 0.05:
		is_returning_home = false
		# Back at the post: a full reset, as a WoW mob heals up after a leash
		health.health = health.max_health
		health.energy = health.max_energy
		returned_home.emit()


## Wired to the AggroArea's body_entered.
func _on_aggro_area_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_stealthed:
		aggro(body)


## Called by [HitDetection]; unarmed swings pass the Player itself as the equipment.
func register_weapon_hit(equipment: Node = null, _hit_node: Node = null) -> void:
	var attacker: Node = (equipment as Equipment).player if equipment is Equipment else equipment
	var from: Vector3 = (attacker as Node3D).global_position if attacker is Node3D else global_position
	take_hit(melee_hit_damage, from)
	aggro(attacker)


## Called by a landing [Projectile].
func register_projectile_hit(projectile: Projectile, point: Vector3, _normal: Vector3) -> void:
	take_hit(projectile.damage, point)
	aggro(projectile.shooter)


## Damage counts on the server; clients relay theirs. The hit reaction faces where it came from.
func take_hit(damage: float, from: Vector3) -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		_request_hit.rpc_id(1, damage, from)
		return
	health.damage(damage, from)
	if not health.is_alive():
		return
	caster.interrupt()
	var side: float = global_transform.basis.x.dot(global_position.direction_to(from))
	anim_state = "ReactionHitOnRightSide" if side > 0.35 else ("ReactionHitOnLeftSide" if side < -0.35 else "GettingHit")


@rpc("any_peer", "call_remote", "reliable")
func _request_hit(damage: float, from: Vector3) -> void:
	if multiplayer.is_server():
		take_hit(damage, from)


func can_heal() -> bool:
	return health.can_heal()


## Restores health; false when already full, so a heal ability is not wasted.
func heal(amount: float) -> bool:
	return health.heal(amount)


## Wired to Health.died on every peer; only the authority flips the replicated flag.
func _on_health_died() -> void:
	if is_multiplayer_authority():
		is_dead = true


func _attack() -> void:
	attack_timer.start()
	anim_state = attack_animation
	strike_timer.start()
	attacked.emit(target)


## Wired to the NpcCaster: the casting pose plays for the cast.
func _on_cast_started(_ability: Ability) -> void:
	anim_state = attack_animation


## Wired to the StrikeTimer: the swing connects or the shot leaves.
func _on_strike_timer_timeout() -> void:
	if is_dead or not is_instance_valid(target):
		return
	if projectile_scene:
		_fire()
	else:
		# The blade decides: only a body it overlaps during the active frames is hurt
		weapon_hitbox.damage = attack_damage
		weapon_hitbox.swing()


func _on_weapon_hitbox_hit(body: Node3D) -> void:
	struck.emit(body)


## Fires the projectile from the muzzle at the target's focus point, through the spawner when the scene has one.
func _fire() -> void:
	var origin: Transform3D = Transform3D(Basis(), muzzle.global_position)
	var direction: Vector3 = muzzle.global_position.direction_to(Focus.get_focus_target_position(target))
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if spawner:
		spawner.fire(projectile_scene, origin, direction, projectile_speed, self)
		return
	var projectile: Projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.launch(origin, direction, projectile_speed, self)


## Called by the Mixamo walk and run animations' method tracks.
func sfx_footsteps_play() -> void:
	if footstep_sfx:
		footstep_audio.stream = footstep_sfx
		footstep_audio.play()


## Idle, walk or run to match the body's speed, never cutting off a swing or a hit reaction.
func _update_locomotion() -> void:
	if String(playback.get_current_node()) not in LOCOMOTION_STATES:
		return
	var speed: float = velocity.slide(up_direction).length()
	anim_state = "Idle" if speed < 0.2 else ("Walking" if speed < move_speed * 0.6 else "Running")


## The ragdoll takes over and the enemy stops being a threat or a target.
func _apply_death() -> void:
	caster.interrupt()
	boss.disengage()
	if is_instance_valid(target) and is_multiplayer_authority():
		target.hunted_by(get_path(), false)
	target = null
	player = null
	animation_tree.active = false
	for bone: Node in physical_bone_simulator.find_children("*", "PhysicalBone3D", true, false):
		(bone as PhysicalBone3D).set_collision_layer_value(1, true)
		(bone as PhysicalBone3D).set_collision_mask_value(1, true)
	physical_bone_simulator.physical_bones_start_simulation()
	collision_shape.disabled = true
	remove_from_group("Focusable")
	set_physics_process(false)
	died.emit()

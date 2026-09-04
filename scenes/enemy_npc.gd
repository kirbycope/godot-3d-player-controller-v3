class_name EnemyNpc
extends FollowerNpc
## A hostile NPC: idles until the Player attacks it or steps within its aggro area, then chases over the
## navigation mesh and attacks in reach with a melee swing, a projectile weapon, or abilities cast in range
## with line of sight. Health, death and the animation state replicate from the server; hits from clients relay.

signal aggroed(target: Node3D)
signal attacked(target: Node3D) ## A melee swing or a shot was started.
signal died

const LOCOMOTION_STATES: Array[String] = ["Idle", "Walking", "Running"]

@export var max_health: float = 100.0
@export var attack_range: float = 1.6 ## Distance the attack lands from: melee reach, or firing range for projectiles.
@export var attack_damage: float = 15.0 ## Melee damage; projectiles carry their own.
@export var attack_interval: float = 1.5 ## Seconds between attacks or ability casts.
@export var attack_animation: String = "SwordAttack" ## AnimationTree state played for each attack.
@export var strike_delay: float = 0.45 ## Seconds into the attack animation when the hit or shot happens.
@export var projectile_scene: PackedScene ## Archers and riflemen fire this; empty means melee.
@export var projectile_speed: float = 30.0
@export var melee_hit_damage: float = 25.0 ## Damage taken from one of the Player's melee swings.
@export var footstep_sfx: AudioStream ## Played by the walk and run animations' method tracks.

var target: Node3D ## The Player being hunted; abilities read it through [method Ability.get_target].
var health: float = 100.0:
	set(value):
		health = clampf(value, 0.0, max_health)
		if health <= 0.0 and not is_dead and is_multiplayer_authority():
			is_dead = true
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
@onready var caster: NpcCaster = $NpcCaster
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Mannequin_M/Armature/GeneralSkeleton/PhysicalBoneSimulator3D


func _ready() -> void:
	super()
	animation_tree.active = true
	health = max_health
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
	super(delta)
	_update_locomotion()
	if target == null or target.get("is_stealthed") or not attack_timer.is_stopped():
		return
	if not caster.abilities.is_empty() and caster.try_cast(target):
		attack_timer.start()
		return
	if global_position.distance_to(target.global_position) <= attack_range and (projectile_scene == null or caster.has_line_of_sight(target)):
		_attack()


## Hunts [param who]; only Players are worth chasing.
func aggro(who: Node) -> void:
	if is_dead or not who is Player or target == who:
		return
	target = who
	player = who
	aggroed.emit(target)


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
	health -= damage
	if is_dead:
		return
	caster.interrupt()
	var side: float = global_transform.basis.x.dot(global_position.direction_to(from))
	anim_state = "ReactionHitOnRightSide" if side > 0.35 else ("ReactionHitOnLeftSide" if side < -0.35 else "GettingHit")


@rpc("any_peer", "call_remote", "reliable")
func _request_hit(damage: float, from: Vector3) -> void:
	if multiplayer.is_server():
		take_hit(damage, from)


## Restores health; false when already full, so a heal ability is not wasted.
func heal(amount: float) -> bool:
	if health >= max_health:
		return false
	health += amount
	return true


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
	elif global_position.distance_to(target.global_position) <= attack_range * 1.25:
		target.call("take_hit", attack_damage, global_position)


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

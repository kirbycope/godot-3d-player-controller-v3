class_name BeachBall
extends RigidBody3D
## A light ball that registers hits on whatever it bumps into; the pool's [Buoyancy] floats it. A bump is
## [code]register_hit[/code], never [code]register_weapon_hit[/code], which the enemies and the duck take for a
## sword swing; a [Harvestable] has no bump entry, so the ball never chops or mines.
##
## Shoot it and it deflates. A round ball is this [RigidBody3D]; a burst one is the [SoftBody3D] twin asleep
## beside it, which takes over on the hit. Squashing the rigid ball's mesh instead would only ever look like a
## squashed sphere, because the collider stays a sphere underneath; the twin is real cloth, so the air going
## out of it drapes and folds the way plastic does. The air is the twin's pressure: Godot's
## [member SoftBody3D.pressure_coefficient], which Jolt implements as SoftBodySharedSettings::mPressure.
##
## The twin cannot sit in the scene waiting its turn. This project runs Jolt, which says so itself: "Failed to
## set transform. Doing so without a physics space is not supported when using Jolt Physics." A disabled node
## is outside the space, so a dormant twin logs that on every touch. It is instead instantiated at the moment of the hit and added
## as a child of the ball, which is also the only way to place it: entering the tree is when the soft body is
## built, and it is built wherever it finds itself. Setting its transform by hand works at no point in its
## life, out of the space because Jolt refuses and in it because the server owns its vertices.

signal deflated ## The air has started going out; the twin has taken over.

@export var deflate_seconds: float = 1.4 ## How long the air takes to go out: the twin's pressure falling to nothing.
@export var inflated_pressure: float = 45.0 ## Enough to hold the shell round. Much above this and the pressure launches the twin: 150 threw it five metres.
@export var deflated_stiffness: float = 0.05 ## What the shell softens to as it empties.
@export var deflated_precision: int = 4 ## Solver iterations once the air is out; a loose solve for a shell with nothing left to hold.
@export var deflated_mass: float = 4.0 ## What the empty shell is made to weigh, and the one thing that actually flattens it. Emptied and softened it still settles as a bowl, because a shell already at rest has no force left to crush it; giving it weight does, and it folds into a flat ring.
@export var deflate_sound: AudioStream ## The hiss. Left empty until there is one to put here; the ball deflates silently without it.
@export var twin_scene: PackedScene = preload("res://scenes/beach_ball_deflated.tscn") ## The burst ball: a [SoftBody3D] with the same skin.

var soft_twin: SoftBody3D ## The burst ball, once there is one. Null while the ball is still round.

var is_deflated: bool = false: ## Replicated, so a peer joining later sees a burst ball rather than a round one.
	set(value):
		if is_deflated == value:
			return
		is_deflated = value
		# Arriving over the wire rather than through _deflate, which swaps before it sets this: a peer joining
		# late gets a ball that is already empty, with no deflation to watch.
		if value and is_node_ready() and soft_twin == null:
			_swap_to_twin(0.0)

var _last_velocity: Vector3 = Vector3.ZERO
var _tween: Tween

@onready var audio_player: AudioStreamPlayer3D = $SFX_Impact
@onready var deflate_player: AudioStreamPlayer3D = $SFX_Deflate
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# The scene's ShaderMaterial is a sub-resource, which every instance of this scene shares. Each ball takes
	# its own copy so one of them changing colour or deflating cannot reach the others.
	if mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()
		var material: Material = mesh_instance.mesh.surface_get_material(0)
		if material:
			mesh_instance.mesh.surface_set_material(0, material.duplicate())
	if deflate_sound:
		deflate_player.stream = deflate_sound


## A round from a firearm or an arrow. Anything that reaches here lets the air out.
func register_projectile_hit(_projectile: Projectile, _point: Vector3, _normal: Vector3) -> void:
	deflate()


## Lets the air out on every peer; a client asks the server so a hit resolved anywhere deflates it everywhere.
func deflate() -> void:
	if is_deflated or is_queued_for_deletion():
		return
	if not multiplayer.is_server():
		_request_deflate.rpc_id(1)
		return
	_deflate.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _request_deflate() -> void:
	if multiplayer.is_server() and not is_deflated and not is_queued_for_deletion():
		_deflate.rpc()


@rpc("authority", "call_local", "reliable")
func _deflate() -> void:
	if is_deflated or is_queued_for_deletion():
		return
	if deflate_player.stream:
		deflate_player.play()
	# The swap comes first, so the setter's own path finds the twin already made and leaves it alone
	_swap_to_twin(deflate_seconds)
	is_deflated = true
	deflated.emit()


## Hands the ball over to the soft-body twin: the rigid one stops simulating and hides, the twin appears round
## in its place, and its pressure falls to nothing over [param seconds], which is the air going out. At 0.0 it
## is empty from the start, for a peer who joined after the shot and has no deflation to watch.
func _swap_to_twin(seconds: float) -> void:
	if is_instance_valid(soft_twin) or twin_scene == null:
		return

	# The rigid ball gets out of the way first, and its collider goes at once rather than deferred. The twin is
	# built in the very same spot, and a soft body born inside a live sphere collider is shoved out of it and
	# creased flat in a frame or two, which is what made the deflation look instant however it was tuned.
	mesh_instance.visible = false
	collision_shape.disabled = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Added as a child of the ball with no transform of its own, so it is built exactly where the ball stands
	soft_twin = twin_scene.instantiate() as SoftBody3D
	add_child(soft_twin)
	soft_twin.pressure_coefficient = inflated_pressure if seconds > 0.0 else 0.0

	if _tween:
		_tween.kill()
		_tween = null
	if seconds > 0.0:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(soft_twin, "pressure_coefficient", 0.0, seconds)
		_tween.tween_property(soft_twin, "linear_stiffness", deflated_stiffness, seconds)
		_tween.chain().tween_callback(_go_limp)
	else:
		soft_twin.linear_stiffness = deflated_stiffness
		_go_limp()

## The last of it. Emptying the shell and softening it is not enough on its own: at rest it holds a bowl,
## because nothing is left pushing it down. Loosening the solve does nothing either, once the vertices have
## settled. Weight is what finishes it, folding the shell into a flat ring the way wet plastic lies.
func _go_limp() -> void:
	# The hiss outlasts the deflation, so it stops with the air rather than running on over a flat ball: the
	# AudioHero clips are 4.3s, 5.4s and 9.3s against a deflation of about a second and a half.
	deflate_player.stop()
	if not is_instance_valid(soft_twin):
		return
	soft_twin.simulation_precision = deflated_precision
	soft_twin.total_mass = deflated_mass


func _on_body_entered(body: Node) -> void:
	var speed_sq: float = maxf(linear_velocity.length_squared(), _last_velocity.length_squared())
	if speed_sq > 0.2:
		audio_player.play()

	# A burst ball flops rather than shoves: it stops registering hits on what it touches
	if speed_sq > 1.0 and not is_deflated:
		var node: Node = body
		while node:
			if node.has_method("register_hit") and not node is Harvestable:
				node.call("register_hit", body)
				break
			node = node.get_parent()


## Remembers the speed before a contact so the impact sound reflects it.
func _physics_process(_delta: float) -> void:
	if not is_deflated:
		_last_velocity = linear_velocity

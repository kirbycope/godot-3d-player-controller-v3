class_name RedBalloon
extends Node3D
## A balloon that pops when an arrow hits it, dropping the plush it carries.

@onready var balloon_string: MeshInstance3D = $Visuals/String
@onready var visuals: Node3D = $Visuals
@onready var hit_detection: Area3D = $Visuals/HitDetection
@onready var godot_plush: RigidBody3D = $GodotPlush
@onready var pop: AudioStreamPlayer3D = $Pop

var is_popped: bool = false: ## Replicated by PopSynchronizer, so a peer joining later finds the balloon already gone and its plush down.
	set(value):
		if is_popped == value:
			return
		is_popped = value
		if value and is_node_ready():
			_release()


## A round through the HitDetection area (the swept ray finds it; rounds sit on no collision layer, so it is never
## touched). Only the round's authority reports it, the server for every shot through the [ProjectileSpawner], a
## client's too, so this runs on the server's balloon.
func register_projectile_hit(_projectile: Projectile, _point: Vector3, _normal: Vector3) -> void:
	pop_balloon()


## Pops on every peer; the server's call, since the rounds that pop it land there.
func pop_balloon() -> void:
	if is_popped or not multiplayer.is_server():
		return
	_pop.rpc()


## The pop itself, sent once by the server. The sound plays even if the replicated flag got here first; a peer
## joining later has only the flag, and hears nothing.
@rpc("authority", "call_local", "reliable")
func _pop() -> void:
	is_popped = true
	pop.play()


## Hides the balloon and lets the plush fall. The balloon stays in the tree rather than freeing, so its
## synchronizer is still there for a late joiner, and the plush keeps the same path on every peer for its own.
func _release() -> void:
	visuals.hide()
	hit_detection.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED) # out of the physics space, so rounds fly through where it was
	godot_plush.top_level = true # the ring keeps turning; the plush stops turning with it
	godot_plush.process_mode = Node.PROCESS_MODE_INHERIT # Disabled in the scene so the plush rides inside the balloon instead of simulating
	# Only the plush's authority simulates it; on every other peer its SyncedBody keeps it frozen under the replicated transform
	if godot_plush.is_multiplayer_authority():
		godot_plush.sleeping = false
		godot_plush.freeze = false

class_name RedBalloon
extends Node3D
## A balloon that pops when an arrow hits it, dropping the plush it carries.

@onready var balloon_string: MeshInstance3D = $Visuals/String
@onready var godot_plush: RigidBody3D = $GodotPlush
@onready var pop: AudioStreamPlayer3D = $Pop


## Projectiles report through the swept-ray protocol; slower bodies still arrive through the area contact.
func register_projectile_hit(_projectile: Projectile, _point: Vector3, _normal: Vector3) -> void:
	pop_balloon()


func _on_hit_detection_body_entered(body: Node3D) -> void:
	if body is Projectile:
		pop_balloon()


## Pops on every peer; clients ask the server so a hit resolved on one peer pops everywhere.
func pop_balloon() -> void:
	if is_queued_for_deletion():
		return
	if not multiplayer.is_server():
		_request_pop.rpc_id(1)
		return
	_pop.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _request_pop() -> void:
	if multiplayer.is_server() and not is_queued_for_deletion():
		_pop.rpc()


@rpc("authority", "call_local", "reliable")
func _pop() -> void:
	if is_queued_for_deletion():
		return
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	godot_plush.reparent(scene_root)
	godot_plush.process_mode = Node.PROCESS_MODE_INHERIT # Disabled in the scene so the plush rides inside the balloon instead of simulating
	godot_plush.sleeping = false
	godot_plush.freeze = false
	pop.reparent(scene_root)
	pop.finished.connect(pop.queue_free, CONNECT_ONE_SHOT)
	pop.play()
	queue_free()

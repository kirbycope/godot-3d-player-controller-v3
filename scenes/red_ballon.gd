class_name RedBalloon
extends Node3D
## A balloon that pops when an arrow hits it, dropping the plush it carries.

@onready var balloon_string: MeshInstance3D = $Visuals/String
@onready var godot_plush: RigidBody3D = $GodotPlush
@onready var pop: AudioStreamPlayer3D = $Pop


func _on_hit_detection_body_entered(body: Node3D) -> void:
	if body.name.begins_with("Arrow") or body is Arrow:
		var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		godot_plush.reparent(scene_root)
		godot_plush.process_mode = Node.PROCESS_MODE_INHERIT # Disabled in the scene so the plush rides inside the balloon instead of simulating
		godot_plush.sleeping = false
		godot_plush.freeze = false
		pop.reparent(scene_root)
		pop.finished.connect(pop.queue_free, CONNECT_ONE_SHOT)
		pop.play()
		queue_free()

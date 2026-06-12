extends Node3D

@onready var godot_plush: RigidBody3D = $GodotPlush


func _on_hit_detection_body_entered(body: Node3D) -> void:
	if body.name.begins_with("Arrow") or body is Arrow:
		var pop := $Pop
		var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		godot_plush.reparent(scene_root)
		godot_plush.process_mode = Node.PROCESS_MODE_INHERIT
		godot_plush.sleeping = false
		godot_plush.freeze = false
		pop.reparent(scene_root)
		pop.finished.connect(pop.queue_free, CONNECT_ONE_SHOT)
		pop.play()
		queue_free()

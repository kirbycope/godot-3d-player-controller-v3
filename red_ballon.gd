extends Node3D


func _on_hit_detection_body_entered(_body: Node3D) -> void:
	var pop := $Pop
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	pop.reparent(scene_root)
	pop.finished.connect(pop.queue_free, CONNECT_ONE_SHOT)
	pop.play()
	queue_free()

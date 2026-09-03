extends StaticBody3D
## A small planetoid whose gravity well points nearby characters' up direction away from its centre.

var bodies_in_range: Array[CharacterBody3D] = []


func _physics_process(_delta: float) -> void:
	for body: CharacterBody3D in bodies_in_range:
		var dir: Vector3 = global_position.direction_to(body.global_position)
		if dir.length_squared() > 0.0001:
			body.up_direction = dir


func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not bodies_in_range.has(body):
		bodies_in_range.append(body as CharacterBody3D)


func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		bodies_in_range.erase(body)
		(body as CharacterBody3D).up_direction = Vector3.UP

extends StaticBody3D

var bodies_in_range: Array[Node3D] = []

@onready var player_detection: Area3D = $PlayerDetection


func _ready() -> void:
	for body in player_detection.get_overlapping_bodies():
		if "up_direction" in body and not bodies_in_range.has(body):
			bodies_in_range.append(body)


func _physics_process(_delta: float) -> void:
	for i: int in range(bodies_in_range.size() - 1, -1, -1):
		var body: Node3D = bodies_in_range[i]
		if is_instance_valid(body) and body.is_inside_tree() and player_detection.overlaps_body(body):
			var dir: Vector3 = global_position.direction_to(body.global_position)
			if dir.length_squared() > 0.0001:
				if body.has_method("set_up_direction"):
					body.set_up_direction(dir)
				else:
					body.up_direction = dir
		else:
			bodies_in_range.remove_at(i)


func _on_player_detection_body_entered(body: Node3D) -> void:
	if "up_direction" in body and not bodies_in_range.has(body):
		bodies_in_range.append(body)


func _on_player_detection_body_exited(body: Node3D) -> void:
	if "up_direction" in body:
		bodies_in_range.erase(body)
		if is_instance_valid(body):
			if body.has_method("set_up_direction"):
				body.set_up_direction(Vector3.UP)
			else:
				body.up_direction = Vector3.UP

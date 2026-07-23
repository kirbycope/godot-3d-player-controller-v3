extends StaticBody3D

var players_in_range: Array[Player] = []


func _physics_process(_delta: float) -> void:
	for i in range(players_in_range.size() - 1, -1, -1):
		var player := players_in_range[i]
		if is_instance_valid(player):
			player.up_direction = global_position.direction_to(player.global_position)
		else:
			players_in_range.remove_at(i)


func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and not players_in_range.has(body):
		players_in_range.append(body)


func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is Player:
		players_in_range.erase(body)
		body.up_direction = Vector3.UP

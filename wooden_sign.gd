extends Node3D

@onready var look_at_target: Node3D = $LookAtTarget

var player: Player


func _input(event: InputEvent) -> void:
	if player and event.is_action_pressed("action"):
		print("Player is interacting with: ", self.name)


func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body
		if look_at_target:
			player.look_at_modifier.target_node = look_at_target.get_path()
		else:
			player.look_at_modifier.target_node = self.get_path()


func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is Player:
		player.look_at_modifier.target_node = NodePath("")
		player = null

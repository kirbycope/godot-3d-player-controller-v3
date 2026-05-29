extends Node3D

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var look_at_target: Node3D = $LookAtTarget

var is_read: bool = false ## Has the player read this sign?
var player: Player ## Cached reference to the Player


func _input(event: InputEvent) -> void:
	# Show initial dialog
	if player \
	and event.is_action_pressed("action") \
	and not canvas_layer.visible \
	and not is_read:
		canvas_layer.show()
	# Advance dialog
	elif player \
	and event.is_action_pressed("action") \
	and canvas_layer.visible:
		canvas_layer.hide()
		is_read = true
		player.look_at_modifier.target_node = NodePath("")


func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body
		if look_at_target:
			player.look_at_modifier.target_node = look_at_target.get_path()
		else:
			player.look_at_modifier.target_node = self.get_path()


func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is Player:
		canvas_layer.hide()
		is_read = false
		player.look_at_modifier.target_node = NodePath("")
		player = null

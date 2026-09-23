extends Node3D

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var look_at_target: Node3D = $LookAtTarget

var is_read: bool = false ## Has the player read this sign?
var player: Player ## The local Player reading this sign. Other peers' Players (puppets) are ignored, so they can neither take the slot nor clear it.


## Called when there is an input event. The gate is the reading Player's authority, not the sign's (the server owns
## the sign), so a client can read it too.
func _input(event: InputEvent) -> void:
	if not is_instance_valid(player) or not player.is_multiplayer_authority(): return

	# Show initial dialog
	if event.is_action_pressed("action") \
	and not canvas_layer.visible \
	and not is_read:
		canvas_layer.show()
	# Advance dialog
	elif event.is_action_pressed("action") \
	and canvas_layer.visible:
		canvas_layer.hide()
		is_read = true
		player.look_at_modifier.target_node = NodePath("")


func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		player = body
		if look_at_target:
			player.look_at_modifier.target_node = look_at_target.get_path()
		else:
			player.look_at_modifier.target_node = self.get_path()


func _on_player_detection_body_exited(body: Node3D) -> void:
	if body != player: return
	canvas_layer.hide()
	is_read = false
	if is_instance_valid(player):
		player.look_at_modifier.target_node = NodePath("")
	player = null

extends GutTest

## Purpose: walking up to the sign turns the Player's head to it, Action opens the dialog, Action again closes it
## and marks it read, and walking away resets it. The gate is the reading Player's authority, not the sign's, so a
## client (whose copy of the sign belongs to the server) reads it too.

const SIGN_SCENE: PackedScene = preload("res://scenes/wooden_sign.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var root: Node3D
var player: Player
var wooden_sign: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	wooden_sign = SIGN_SCENE.instantiate() as Node3D
	wooden_sign.set_multiplayer_authority(2) # a client's copy: the server owns the sign
	wooden_sign.position = Vector3(0.0, 0.0, 20.0) # out of its detection area, so the test walks up itself
	root.add_child(wooden_sign)
	await wait_physics_frames(1)


func _press_action() -> void:
	var press := InputEventAction.new()
	press.action = "action"
	press.pressed = true
	wooden_sign._input(press)


func test_a_client_reads_the_sign() -> void:
	wooden_sign._on_player_detection_body_entered(player)
	assert_eq(player.look_at_modifier.target_node, wooden_sign.look_at_target.get_path(), "Walking up turns the head to the sign")
	assert_false(wooden_sign.canvas_layer.visible)
	_press_action()
	assert_true(wooden_sign.canvas_layer.visible, "Action opens the dialog on a client too")
	_press_action()
	assert_false(wooden_sign.canvas_layer.visible, "Action again closes it")
	assert_true(wooden_sign.is_read)
	assert_eq(player.look_at_modifier.target_node, NodePath(""), "and lets the head go")
	wooden_sign._on_player_detection_body_exited(player)
	assert_false(wooden_sign.is_read, "Walking away resets it")
	assert_null(wooden_sign.player)


func test_another_peers_player_neither_takes_nor_clears_the_sign() -> void:
	var puppet: Player = PLAYER_SCENE.instantiate() as Player
	puppet.name = "2" # a Player named by its peer id belongs to that peer, so on this peer it is a puppet
	puppet.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(puppet)
	await wait_physics_frames(1)
	assert_false(puppet.is_multiplayer_authority(), "the second Player is another peer's")

	wooden_sign._on_player_detection_body_entered(player)
	wooden_sign._on_player_detection_body_entered(puppet)
	assert_eq(wooden_sign.player, player, "The puppet arriving does not take the sign from the local Player")
	_press_action()
	assert_true(wooden_sign.canvas_layer.visible, "so the local Player can still read it")

	wooden_sign._on_player_detection_body_exited(puppet)
	assert_eq(wooden_sign.player, player, "The puppet leaving does not clear the local Player")
	assert_true(wooden_sign.canvas_layer.visible, "nor close the local Player's dialog")

	wooden_sign._on_player_detection_body_exited(player)
	assert_null(wooden_sign.player, "The local Player leaving after the puppet clears it without an error")
	assert_false(wooden_sign.canvas_layer.visible)

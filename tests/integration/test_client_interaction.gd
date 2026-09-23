extends GutTest

## Purpose: the world's props belong to the server, so a client's copies are never the authority; sitting in the
## boat and chopping a tree are gated on the interacting Player's authority instead, so a client can do both.

const BOAT_SCENE: PackedScene = preload("res://scenes/boat.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const EQUIPMENT_SCRIPT: Script = preload("res://addons/3d_player_controller/scripts/equipment.gd")

var root: Node3D
var player: Player


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await wait_physics_frames(2)


func _press_action(node: Node) -> void:
	var press := InputEventAction.new()
	press.action = "action"
	press.pressed = true
	node._input(press)


func test_a_client_sits_in_the_boat() -> void:
	var boat: AnimatableBody3D = BOAT_SCENE.instantiate() as AnimatableBody3D
	boat.set_multiplayer_authority(2) # a client's copy: the server owns the boat
	boat.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(boat)
	await wait_physics_frames(1)
	boat.display_menu(player)
	assert_true(boat.action_prompt.visible)
	_press_action(boat)
	await wait_physics_frames(2)
	assert_true(player.is_sitting, "Action sits the Player down on a client too")
	assert_true(boat._seated)
	assert_false(boat.action_prompt.visible)


func test_a_client_chops_a_tree() -> void:
	var tree: Choppable = TREE_SCENE.instantiate() as Choppable
	tree.set_multiplayer_authority(2) # a client's copy: the server owns the tree
	tree.position = Vector3(0.0, 0.0, -2.0)
	root.add_child(tree)
	var axe: Equipment = EQUIPMENT_SCRIPT.new()
	axe.player = player
	axe.can_log = true
	axe.equipment_type = Equipment.EquipmentType.AXE_1H
	root.add_child(axe)
	player.inventory.add_equipment(axe)
	await wait_physics_frames(1)
	tree.display_menu(player)
	assert_true(tree.action_prompt.visible)
	_press_action(tree)
	await wait_seconds(tree.hit_delay + 0.2)
	assert_eq(tree.hits, 1, "A client's swing lands on the tree")

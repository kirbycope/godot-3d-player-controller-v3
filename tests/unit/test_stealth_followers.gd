extends GutTest

## Purpose: Followers lose a stealthed Player and stand still until stealth ends.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BUDDY_SCENE: PackedScene = preload("res://scenes/little_buddy.tscn")

var player: Player
var buddy: FollowerNpc


func before_each() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(8.0, 0.0, 0.0)
	root.add_child(player)
	buddy = BUDDY_SCENE.instantiate()
	buddy.max_follow_distance = INF
	root.add_child(buddy)
	buddy.player = player
	await wait_physics_frames(5)


func test_follower_walks_toward_a_visible_player() -> void:
	await wait_physics_frames(40)
	assert_gt(buddy.global_position.x, 0.5, "The follower closes in on a visible Player")


func test_follower_ignores_a_stealthed_player() -> void:
	player.is_stealthed = true
	await wait_physics_frames(2)
	var start_x: float = buddy.global_position.x
	await wait_physics_frames(40)
	assert_almost_eq(buddy.global_position.x, start_x, 0.05, "A stealthed Player is not followed")
	player.is_stealthed = false
	await wait_physics_frames(40)
	assert_gt(buddy.global_position.x, 0.5, "Following resumes once stealth ends")

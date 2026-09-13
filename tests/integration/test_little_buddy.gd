extends GutTest

## Purpose: To test Little Buddy animation and locomotion state behavior.

const LITTLE_BUDDY_SCENE: PackedScene = preload("res://scenes/little_buddy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var root: Node3D

func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)

func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null

func test_stop_moving_resets_blend_position_to_idle():
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	root.add_child(buddy)
	await wait_physics_frames(2)

	# Simulate moving (blend_position = 1.0 for running)
	buddy.animation_tree.set(buddy.LOCOMOTION_BLEND_POSITION_PATH, 1.0)
	var moving_blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_eq(moving_blend, 1.0, "Locomotion blend position should be 1.0 while moving.")

	# Stop moving (standing next to player); the blend eases toward idle over physics frames
	for i: int in range(60):
		buddy.call("_stop_moving")
	var idle_blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_eq(idle_blend, 0.0, "Locomotion blend position should return to 0.0 (Idle) when stopped.")

func test_walking_blend_position():
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	root.add_child(buddy)
	await wait_physics_frames(2)

	# Simulate walking at walk_speed (1.5 m/s)
	for i: int in range(60):
		buddy.call("_move_with_control", Vector3(0, 0, 1.5))
	var walk_blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_almost_eq(walk_blend, 0.5, 0.05, "Locomotion blend position should be ~0.5 at walk speed.")

func test_running_blend_position():
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	root.add_child(buddy)
	await wait_physics_frames(2)

	# Simulate running at move_speed (3.0 m/s)
	for i: int in range(60):
		buddy.call("_move_with_control", Vector3(0, 0, 3.0))
	var run_blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_almost_eq(run_blend, 1.0, 0.05, "Locomotion blend position should be ~1.0 at run speed.")

func test_pickup_resets_blend_position_to_idle():
	var player: Player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	root.add_child(buddy)
	await wait_physics_frames(2)

	# Set moving
	buddy.animation_tree.set(buddy.LOCOMOTION_BLEND_POSITION_PATH, 1.0)

	buddy.player = player
	buddy.pick_up()
	var idle_blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_eq(idle_blend, 0.0, "Locomotion blend position should be 0.0 when picked up.")

func test_the_replicated_blend_feeds_the_blend_space_on_a_puppet():
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	buddy.set_multiplayer_authority(2) # a client's copy: the server owns the buddy
	root.add_child(buddy)
	await wait_physics_frames(2)

	buddy.locomotion_blend = 0.5 # what the synchronizer writes while the server's buddy walks
	var blend: float = buddy.animation_tree.get(buddy.LOCOMOTION_BLEND_POSITION_PATH)
	assert_eq(blend, 0.5, "The setter drives the blend space, so the puppet's legs move.")


## A drop puts the buddy back under the parent it stood under before, not under whatever the current scene is:
## a test runner has none, and two peers with different fallbacks would put their copies under different paths.
func test_a_drop_returns_the_buddy_to_where_it_stood() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	var home: Node3D = Node3D.new()
	home.name = "Home"
	root.add_child(home)
	var buddy: CharacterBody3D = LITTLE_BUDDY_SCENE.instantiate() as CharacterBody3D
	home.add_child(buddy)
	await wait_physics_frames(2)
	buddy.player = player
	buddy.pick_up()
	await wait_physics_frames(2)
	assert_eq(buddy.get_parent(), player.item_spring_arm, "Carried on the player's arm")
	buddy.drop()
	await wait_physics_frames(2)
	assert_eq(buddy.get_parent(), home, "and back under Home when dropped, current scene or not")

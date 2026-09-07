extends GutTest

## Purpose: The world's pool rim is flush with the water surface; a swimmer must still find the
## ledge, reach SwimmingAtEdge and mantle out onto the deck when jump is pressed.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")


func test_swimmer_climbs_out_over_a_flush_pool_rim() -> void:
	var world: Node = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var player: Player = world.get_node("Players/1")
	player.global_position = Vector3(12.0, -1.0, -24.0)
	player.camera_mount.rotation.y = -PI / 2.0 # camera forward = +X, toward the wall at x = 16
	await wait_physics_frames(40)
	assert_true(player.is_swimming, "Dropping into the pool starts swimming")

	var sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	sender.action_down("move_up")
	var at_edge: bool = false
	for i in 30:
		await wait_physics_frames(10)
		if player.current_locomotion_node == "SwimmingAtEdge":
			at_edge = true
			break
	sender.action_up("move_up")
	assert_true(at_edge, "Swimming into the wall should find the rim and reach SwimmingAtEdge")

	sender.action_down("jump")
	await wait_physics_frames(2)
	sender.action_up("jump")
	# The rim beyond this wall has no deck, so sample until the mantle lands rather than waiting a fixed time
	var stood_on_rim: bool = false
	for i in 12:
		await wait_physics_frames(10)
		if player.current_state == NodeStateMachine.States.STANDING and player.global_position.y > -0.5:
			stood_on_rim = true
			break
	assert_true(stood_on_rim, "Jump at the edge mantles out and stands on the rim")
	assert_false(player.is_swimming)

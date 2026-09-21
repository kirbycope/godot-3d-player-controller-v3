extends SteamTest
## Purpose: the client can use what the server owns. A strike on a harvestable relays to the server and the count
## comes back to both; the boat seats the client and the host sees them sitting in it; a sign is read on the
## client alone, since its dialog is the reader's own.

const SIGN_SCENE: PackedScene = preload("res://scenes/wooden_sign.tscn")
const SIGN_POSITION: Vector3 = Vector3(3.0, 0.0, 3.0)


func test_strikes_from_both_sides_count_on_the_server_and_deplete_the_tree_everywhere() -> void:
	var tree: Harvestable = world_node("Quaternius/Tree01") as Harvestable
	if is_host:
		assert_true(tree.is_multiplayer_authority(), "The server owns the tree")
		await await_step("client_struck")
		await wait_for(func() -> bool: return tree.hits_taken == 1, "The client's strike counts on the server")
		tree.register_hit()
		assert_eq(tree.hits_taken, 2, "The host's strike counts at once")
		mark("host_struck")
		await await_step("client_finished")
		await wait_for(func() -> bool: return tree.is_depleted, "The client's last strike depletes it on the server")
	else:
		assert_false(tree.is_multiplayer_authority(), "The client only mirrors the tree")
		tree.register_hit()
		await wait_for(func() -> bool: return tree.hits_taken == 1, "The client's strike comes back to the client")
		mark("client_struck")
		await await_step("host_struck")
		await wait_for(func() -> bool: return tree.hits_taken == 2, "The host's strike reaches the client")
		for hit: int in tree.hits_to_finish - 2:
			tree.register_hit()
		await wait_for(func() -> bool: return tree.is_depleted, "The client's strikes deplete it on the client")
		mark("client_finished")
	await barrier("tree_done")


func test_the_client_sits_in_the_boat_and_the_host_sees_them_there() -> void:
	var boat: Node3D = world_node("Boat") as Node3D
	var seat: Node3D = boat.get_node("Seat01") as Node3D
	if is_host:
		await await_step("client_seated")
		var them: Player = other_player()
		await wait_for(func() -> bool: return them.is_sitting, "The client is seen sitting")
		await wait_for(func() -> bool: return them.global_position.distance_to(seat.global_position) < 1.5, "in the boat's seat")
		mark("host_saw_seated")
		await await_step("client_stood")
		await wait_for(func() -> bool: return not them.is_sitting, "and standing again")
	else:
		var me: Player = own_player()
		boat.call("display_menu", me)
		boat.call("_input", action_press(&"action"))
		await wait_for(func() -> bool: return me.is_sitting, "The client sits in the boat")
		mark("client_seated")
		await await_step("host_saw_seated")
		me.state_machine.travel(NodeStateMachine.States.SITTING, NodeStateMachine.States.STANDING)
		await wait_for(func() -> bool: return not me.is_sitting, "and stands up")
		me.warp_to(Transform3D(Basis(), stand_position()))
		mark("client_stood")
	await barrier("boat_done")


func test_the_client_reads_a_sign_and_the_hosts_copy_is_untouched() -> void:
	var signpost: Node3D = SIGN_SCENE.instantiate() as Node3D
	signpost.name = "SteamTestSign"
	world.add_child(signpost)
	signpost.global_position = SIGN_POSITION
	var dialog: CanvasLayer = signpost.get_node("CanvasLayer") as CanvasLayer
	if is_host:
		await await_step("client_read")
		assert_false(signpost.get("is_read"), "Reading a sign is the reader's alone; the host's copy is unread")
		assert_false(dialog.visible, "and its dialog is down")
	else:
		var me: Player = own_player()
		signpost.call("_on_player_detection_body_entered", me)
		signpost.call("_input", action_press(&"action"))
		assert_true(dialog.visible, "The client opens the sign")
		signpost.call("_input", action_press(&"action"))
		assert_true(signpost.get("is_read"), "and reads it through")
		assert_false(dialog.visible)
		mark("client_read")
	await barrier("sign_done")
	signpost.free()

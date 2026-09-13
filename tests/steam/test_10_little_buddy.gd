extends SteamTest
## Purpose: a client carrying the buddy owns it while it is in their hands. pick_up hands the buddy and its
## synchronizer to the carrier's peer and puts every copy on that Player's spring arm, so the host's copy rides
## along instead of writing its old position back; drop hands it back to the server and puts every copy back in
## the world. The host finds its copy before the client reaches for it: the carry RPC can land here before this
## side's test body has run a line.


func test_the_client_carries_the_buddy_and_hands_it_back() -> void:
	var buddy: FollowerNpc = find_world_node("LittleBuddy") as FollowerNpc
	var synchronizer: MultiplayerSynchronizer = buddy.get_node("BodySynchronizer") as MultiplayerSynchronizer
	var shape: CollisionShape3D = buddy.get_node("CollisionShape3D") as CollisionShape3D
	if is_host:
		assert_eq(buddy.get_parent(), world, "The buddy starts in the world on the host")
		mark("host_watching")
		var client_peer: int = await await_step("client_holding")
		await wait_for(func() -> bool: return buddy.get_multiplayer_authority() == client_peer, "The carrier's peer owns the buddy on the host")
		assert_eq(synchronizer.get_multiplayer_authority(), client_peer, "synchronizer included")
		await wait_for(func() -> bool: return buddy.get_parent() == other_player().item_spring_arm, "and it rides on the host's copy of the carrier's arm")
		assert_true(shape.disabled, "bumping nothing on the host either")
		assert_lt(buddy.global_position.distance_to(other_player().global_position), 4.0, "in the carrier's hands, not where it stood")
		mark("host_saw_carry")
		await await_step("client_dropped")
		await wait_for(func() -> bool: return buddy.get_multiplayer_authority() == 1 and not buddy.get_parent() is SpringArm3D, "Dropped, the server has the buddy back and off the arm")
		assert_eq(synchronizer.get_multiplayer_authority(), 1)
		assert_false(shape.disabled)
		mark("host_saw_drop")
	else:
		var me: Player = own_player()
		await await_step("host_watching")
		buddy.player = me
		buddy.call("pick_up")
		await wait_for(func() -> bool: return buddy.get_parent() == me.item_spring_arm and buddy.get_multiplayer_authority() == multiplayer.get_unique_id(), "The buddy is on the client's arm and theirs")
		assert_true(buddy.get("is_held"))
		mark("client_holding", multiplayer.get_unique_id())
		await await_step("host_saw_carry")
		buddy.call("drop")
		await wait_for(func() -> bool: return buddy.get_multiplayer_authority() == 1 and not buddy.get_parent() is SpringArm3D, "Dropped here too")
		assert_false(buddy.get("is_held"))
		mark("client_dropped")
		await await_step("host_saw_drop")
		buddy.player = null

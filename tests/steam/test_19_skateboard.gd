extends SteamTest
## Purpose: riding the skateboard is seen on the other side. The rider's is_riding replicates with their Player,
## so the host sees the client get on and off, and the board itself follows: getting on asks the server to put it
## under the rider's model on every peer and hand it to the rider's peer, getting off puts it back in the world
## and hands it to the server. The board is found by name, wherever it is: the hand-off can land here before this
## side's test body has looked for it.


func test_the_client_riding_the_board_is_seen_on_the_host() -> void:
	var board: Skateboard = find_world_node("Skateboard") as Skateboard
	if is_host:
		await await_step("client_riding")
		await wait_for(func() -> bool: return other_player().is_riding, "The client's Player is seen riding")
		print("[steam_test] host: while the client rides, the host's board is under %s" % board.get_parent().name)
		mark("host_saw_riding")
		await await_step("client_off")
		await wait_for(func() -> bool: return not other_player().is_riding, "and on foot again")
	else:
		var me: Player = own_player()
		board.equip(me)
		await wait_for(func() -> bool: return me.is_riding and me.riding == board, "The client gets on the board")
		await wait_for(func() -> bool: return board.get_parent() == me.player_model, "which goes under their feet once the server grants it")
		mark("client_riding")
		await await_step("host_saw_riding")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding, "The client gets off")
		await wait_for(func() -> bool: return board.get_parent() == world, "and the board is back in the world")
		me.warp_to(Transform3D(Basis(), stand_position()))
		mark("client_off")
	await barrier("done")


func test_the_board_is_seen_under_the_riders_feet_on_the_other_side() -> void:
	var board: Skateboard = find_world_node("Skateboard") as Skateboard
	var synchronizer: MultiplayerSynchronizer = board.get_node("BodySynchronizer") as MultiplayerSynchronizer
	if is_host:
		await wait_for(func() -> bool: return board.get_parent() == world, "The board starts in the world on the host")
		assert_eq(board.get_multiplayer_authority(), 1, "and is the server's")
		mark("host_watching")
		var client_peer: int = await await_step("client_riding")
		await wait_for(func() -> bool: return board.get_parent() == other_player().player_model, "The host's board is under the host's copy of the client's model")
		await wait_for(func() -> bool: return board.get_multiplayer_authority() == client_peer, "and the rider's peer owns it on the host")
		assert_eq(synchronizer.get_multiplayer_authority(), client_peer, "synchronizer included")
		assert_eq(board.rider_peer, client_peer, "and it says who is on it")
		assert_lt(board.global_position.distance_to(other_player().global_position), 2.0, "under the rider's feet, not where it lay")
		mark("host_saw_riding")
		await await_step("client_off")
		await wait_for(func() -> bool: return board.get_parent() == world and board.get_multiplayer_authority() == 1, "Off, the board is back in the world under its home parent on the host, the server's again")
		assert_eq(synchronizer.get_multiplayer_authority(), 1, "synchronizer included")
		assert_eq(board.rider_peer, 0, "and free")
		assert_lt(board.global_position.distance_to(other_player().global_position), 4.0, "where the client got off, not where it lay before")
		mark("host_saw_off")
	else:
		var me: Player = own_player()
		await await_step("host_watching")
		board.equip(me)
		await wait_for(func() -> bool: return me.is_riding and me.riding == board, "The client gets on the board")
		await wait_for(func() -> bool: return board.get_parent() == me.player_model and board.get_multiplayer_authority() == multiplayer.get_unique_id(), "The server's grant puts it under their feet and in their hands")
		assert_eq(board.rider_peer, multiplayer.get_unique_id(), "and it says so")
		mark("client_riding", multiplayer.get_unique_id())
		await await_step("host_saw_riding")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding, "The client gets off")
		await wait_for(func() -> bool: return board.get_parent() == world and board.get_multiplayer_authority() == 1, "and the board is back in the world here too, the server's again")
		assert_eq(board.rider_peer, 0, "and free")
		me.warp_to(Transform3D(Basis(), stand_position()))
		mark("client_off")
		await await_step("host_saw_off")
	await barrier("done")

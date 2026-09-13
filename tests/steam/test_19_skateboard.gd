extends SteamTest
## Purpose: riding the skateboard is seen on the other side. The rider's is_riding replicates with their Player,
## so the host sees the client get on and off. The board itself is another matter: Skateboard.mount reparents it
## under the rider's model on the rider's peer alone, and nothing carries that across; the pending test records it.


func test_the_client_riding_the_board_is_seen_on_the_host() -> void:
	var board: Skateboard = world_node("Skateboard") as Skateboard
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
		assert_eq(board.get_parent(), me.player_model, "which goes under their feet")
		mark("client_riding")
		await await_step("host_saw_riding")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding, "The client gets off")
		me.warp_to(Transform3D(Basis(), stand_position()))
		mark("client_off")
	await barrier("done")


func test_the_board_is_seen_under_the_riders_feet_on_the_other_side() -> void:
	pending("The skateboard has no synchronizer and no RPC (addons/tcps/scenes/skateboard.tscn, addons/tcps/scripts/skateboard.gd): mount() reparents it under the rider's model on the rider's peer only, so the other side sees the rider ride while the board lies where it was")

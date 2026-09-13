extends SteamTest
## Purpose: the session itself. Both machines sit in one lobby owned by the host, the host is peer 1, each side's
## Player is named by its own peer id and the other side's Player belongs to the other peer and wears its Steam
## persona; and the bodies the server owns stand on the client where they stand on the host.

const SERVER_BODIES: Array[String] = ["Horse", "LittleBuddy", "Duck", "Torch", "HondaCRV"]


func test_both_sides_share_one_lobby_with_a_player_each() -> void:
	var players: int = 0
	for node: Node in get_tree().get_nodes_in_group("Player"):
		if node is Player:
			players += 1
	assert_eq(players, 2, "Two Players in the world")
	var me: Player = own_player()
	assert_not_null(me, "This side's Player spawned")
	assert_eq(String(me.name), str(multiplayer.get_unique_id()), "named by this peer's id")
	assert_true(me.is_multiplayer_authority(), "and owned here")
	if is_host:
		assert_eq(multiplayer.get_unique_id(), 1, "The host is peer 1")
		assert_true(multiplayer.is_server())
	else:
		assert_ne(multiplayer.get_unique_id(), 1, "The client is not peer 1")
		assert_false(multiplayer.is_server())
	var mine: Dictionary = {
		"peer": multiplayer.get_unique_id(),
		"lobby": int(steamworks.get("lobby_id")),
		"steam_id": int(steamworks.get("steam_id")),
		"username": str(steamworks.get("username")),
	}
	var theirs: Dictionary = await barrier("hello", mine)
	assert_eq(int(theirs["lobby"]), int(mine["lobby"]), "Both sides are in the same lobby")
	assert_ne(int(theirs["steam_id"]), int(mine["steam_id"]), "on different Steam accounts")
	var host_steam_id: int = int(mine["steam_id"]) if is_host else int(theirs["steam_id"])
	assert_eq(int(steam.call("getLobbyOwner", int(mine["lobby"]))), host_steam_id, "and the host owns it")
	var them: Player = other_player()
	assert_not_null(them, "The other side's Player is here")
	assert_eq(them.get_multiplayer_authority(), int(theirs["peer"]), "owned by the other peer")
	assert_eq(String(them.name), str(theirs["peer"]), "and named by it")
	await wait_for(func() -> bool: return them.display_name == str(theirs["username"]), "wearing the other side's persona name, %s" % theirs["username"])


func test_server_owned_bodies_stand_where_the_host_says() -> void:
	if is_host:
		var positions: Dictionary = {}
		for path: String in SERVER_BODIES:
			positions[path] = (world_node(path) as Node3D).global_position
			assert_true((world_node(path) as Node).is_multiplayer_authority(), "%s is the server's" % path)
		mark("positions", positions)
		await await_step("checked")
	else:
		var host_positions: Dictionary = await await_step("positions")
		for path: String in SERVER_BODIES:
			var body: Node3D = world_node(path) as Node3D
			var at: Vector3 = host_positions[path]
			assert_false(body.is_multiplayer_authority(), "%s is only mirrored here" % path)
			await wait_for(func() -> bool: return body.global_position.distance_to(at) < 2.0, "%s stands where the host's does (here %s, host %s)" % [path, body.global_position, at])
		mark("checked")

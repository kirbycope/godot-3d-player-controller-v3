extends SteamTest
## Purpose: the horse answers whoever whistles, on either side, and carries one rider at a time. A whistle on the
## host moves the server's horse and the client's copy follows; a whistle on the client is relayed to the host by
## Horse._request_summon and the horse comes to the host's copy of the client. While the client is up, the host's
## attempt to mount is refused and the saddle is seen taken; it frees once the client gets off. The other way
## round is the same rule with the roles swapped, and the saddle is told apart from the authority.

const ARRIVE_SLACK: float = 1.5 ## Metres beyond arrive_distance the copy may lag its authority.
const ARRIVAL_TIMEOUT: float = 60.0 ## Seconds for the horse to cross the yard at a walk.


func test_a_whistle_from_each_side_brings_the_horse_to_the_whistler() -> void:
	var horse: Horse = world_node("Horse") as Horse
	if is_host:
		var answered: Horse = Horse.summon_nearest(own_player())
		assert_eq(answered, horse, "The world's horse answers the host's whistle")
		assert_eq(horse.summoner, own_player(), "aimed at the host")
		assert_eq(horse.summon_state, Horse.SummonState.COMING)
		mark("host_whistled")
		await wait_for(func() -> bool: return horse.summon_state == Horse.SummonState.ARRIVED, "The horse arrives beside the host", ARRIVAL_TIMEOUT)
		_assert_beside(horse, own_player(), other_player())
		mark("host_arrived")
		await await_step("client_whistled", ARRIVAL_TIMEOUT)
		await wait_for(func() -> bool: return horse.summoner == other_player(), "The client's whistle is relayed to the host, aimed at the host's copy of the client")
		await wait_for(func() -> bool: return horse.summon_state == Horse.SummonState.ARRIVED, "and the horse arrives beside them", ARRIVAL_TIMEOUT)
		_assert_beside(horse, other_player(), own_player())
		mark("host_saw_client_arrival")
	else:
		await await_step("host_whistled")
		await wait_for(func() -> bool: return horse.summon_state == Horse.SummonState.COMING, "The summon replicates to the client")
		await await_step("host_arrived", ARRIVAL_TIMEOUT)
		await wait_for(func() -> bool: return horse.summon_state == Horse.SummonState.ARRIVED, "and so does the arrival")
		_assert_beside(horse, other_player(), own_player())
		Horse.summon_nearest(own_player())
		mark("client_whistled")
		await await_step("host_saw_client_arrival", ARRIVAL_TIMEOUT)
		await wait_for(func() -> bool: return horse.summon_state == Horse.SummonState.ARRIVED, "The client's copy arrives beside the client too")
		_assert_beside(horse, own_player(), other_player())


func test_a_second_rider_is_refused_while_the_client_is_up() -> void:
	var horse: Horse = world_node("Horse") as Horse
	var me: Player = own_player()
	if is_host:
		var client_peer: int = await await_step("client_mounted")
		await wait_for(func() -> bool: return horse.rider_peer == client_peer, "The saddle is seen taken by the client")
		assert_eq(horse.get_multiplayer_authority(), client_peer, "and the horse is theirs to steer")
		me.mount(horse)
		await wait_physics_frames(30)
		assert_false(me.is_riding, "A second rider is put back off")
		assert_eq(horse.rider_peer, client_peer, "and the client keeps the saddle")
		if me.is_riding:
			me.dismount(true) # or the refusal that did not happen leaves the host in the saddle for every scenario after
		mark("host_refused")
		await await_step("client_off")
		await wait_for(func() -> bool: return horse.rider_peer == 0 and horse.get_multiplayer_authority() == 1, "The saddle is seen freed and the horse handed back once the client is off")
		mark("host_saw_free")
	else:
		me.mount(horse)
		await wait_for(func() -> bool: return me.is_riding and horse.rider_peer == multiplayer.get_unique_id(), "The client gets on")
		mark("client_mounted", multiplayer.get_unique_id())
		await await_step("host_refused")
		assert_true(me.is_riding, "The client is still up")
		assert_eq(horse.rider_peer, multiplayer.get_unique_id(), "and keeps the saddle")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding and horse.rider_peer == 0, "The client gets off and the saddle frees")
		mark("client_off")
		await await_step("host_saw_free")


## The host is a rider too while the authority stays the server's: the saddle is told apart from the authority.
func test_a_second_rider_is_refused_while_the_host_is_up() -> void:
	var horse: Horse = world_node("Horse") as Horse
	var me: Player = own_player()
	if is_host:
		me.mount(horse)
		await wait_for(func() -> bool: return me.is_riding and horse.rider_peer == 1, "The host gets on")
		mark("host_mounted")
		await await_step("client_refused")
		assert_true(me.is_riding, "The host is still up")
		assert_eq(horse.rider_peer, 1, "and keeps the saddle")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding and horse.rider_peer == 0, "The host gets off and the saddle frees")
		mark("host_off")
		await await_step("client_saw_free")
	else:
		await await_step("host_mounted")
		await wait_for(func() -> bool: return horse.rider_peer == 1, "The saddle is seen taken by the host")
		assert_eq(horse.get_multiplayer_authority(), 1, "with the horse the server's, as it was")
		me.mount(horse)
		await wait_physics_frames(30)
		assert_false(me.is_riding, "A second rider is put back off")
		assert_eq(horse.rider_peer, 1, "and the host keeps the saddle")
		if me.is_riding:
			me.dismount(true)
		mark("client_refused")
		await await_step("host_off")
		await wait_for(func() -> bool: return horse.rider_peer == 0, "The saddle is seen freed once the host is off")
		mark("client_saw_free")


func _assert_beside(horse: Horse, whistler: Player, bystander: Player) -> void:
	var to_whistler: float = horse.global_position.distance_to(whistler.global_position)
	assert_lt(to_whistler, horse.arrive_distance + ARRIVE_SLACK, "The horse stands beside the whistler (%.1f m)" % to_whistler)
	assert_lt(to_whistler, horse.global_position.distance_to(bystander.global_position), "and nearer them than the other Player")
	print("[steam_test] %s: horse at %s, whistler at %s, other at %s" % [role, horse.global_position, whistler.global_position, bystander.global_position])

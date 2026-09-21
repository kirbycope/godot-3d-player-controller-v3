extends SteamTest
## Purpose: a cast on the client puts the float on both sides and reeling in takes it away everywhere. The rod
## fires its Bobber through the ProjectileSpawner and adopts the copy the spawner hands back; retract sends
## Bobber.retract to the server, which frees its copy and so despawns the rest.


func test_a_cast_on_the_client_lands_the_float_on_both_sides_and_a_retract_takes_it_away() -> void:
	var projectiles: Node = world_node("ProjectileSpawner")
	if is_host:
		await await_step("client_cast")
		await wait_for(func() -> bool: return _bobber(projectiles) != null, "The client's float lands on the host")
		assert_eq(_bobber(projectiles).shooter, other_player(), "cast by the host's copy of the client")
		mark("host_saw_float")
		await await_step("client_retracted")
		await wait_for(func() -> bool: return _bobber(projectiles) == null, "and goes when they reel in")
	else:
		var me: Player = own_player()
		var pickup: FishingRod = world_node("FishingRod") as FishingRod
		assert_true(pickup.equip(me), "The client takes the rod")
		var rod: FishingRod = me.inventory.get_equipment_by_type(Equipment.EquipmentType.FISHING_ROD) as FishingRod
		assert_not_null(rod, "and holds it")
		print("[steam_test] client: rod %s under %s, cast timer %s, emote state %s, fishing %s" % [rod, rod.get_parent(), rod.cast_timer, rod.emote_state, me.is_fishing])
		rod.cast()
		await wait_for(func() -> bool: return rod.bobber != null, "The float leaves the rod", 10.0)
		assert_eq(rod.bobber, _bobber(projectiles), "and is the copy under the ProjectileSpawner")
		assert_eq(rod.bobber.shooter, me, "cast by the client")
		mark("client_cast")
		await await_step("host_saw_float")
		rod.retract()
		await wait_for(func() -> bool: return _bobber(projectiles) == null, "Reeling in takes the float away on the client")
		mark("client_retracted")
		me.inventory.unequip_all()
	await barrier("done")


func _bobber(projectiles: Node) -> Bobber:
	for child: Node in projectiles.get_children():
		if child is Bobber and not child.is_queued_for_deletion():
			return child as Bobber
	return null

extends SteamTest
## Purpose: a drop lands on both sides under one name and a take frees it everywhere. Inventory.drop_slot spawns
## the ItemPickup on every peer as Dropped_<peer>_<n>, so the host finds the client's apple by name; ItemPickup.take
## puts it in the taker's inventory and tells every copy to vanish.

const APPLE: Item = preload("res://resources/items/apple.tres")


func test_the_clients_drop_lands_on_the_host_who_takes_it_and_it_vanishes_on_both() -> void:
	var players: Node = world_node("PlayerSpawner")
	if is_host:
		var pickup_name: String = await await_step("client_dropped")
		await wait_for(func() -> bool: return players.has_node(pickup_name), "The client's drop lands on the host as %s" % pickup_name)
		var pickup: ItemPickup = players.get_node(pickup_name) as ItemPickup
		assert_eq(pickup.item.id, APPLE.id, "and it is the apple")
		assert_eq(pickup.count, 1)
		var before: int = own_player().inventory.count_of(APPLE)
		pickup.player = own_player()
		pickup.take()
		assert_eq(own_player().inventory.count_of(APPLE), before + 1, "The host takes it")
		await wait_for(func() -> bool: return not players.has_node(pickup_name), "and it is gone on the host")
		mark("host_took")
	else:
		var me: Player = own_player()
		var index: int = _slot_of(me.inventory, APPLE)
		assert_ne(index, -1, "The world gave the client apples to drop")
		var before: int = me.inventory.count_of(APPLE)
		var pickup: Node3D = me.inventory.drop_slot(APPLE.category, index, 1)
		assert_not_null(pickup, "The client drops one")
		var pickup_name: String = String(pickup.name)
		assert_true(pickup_name.begins_with("Dropped_%d_" % multiplayer.get_unique_id()), "named by the client's peer: %s" % pickup_name)
		assert_eq(me.inventory.count_of(APPLE), before - 1)
		mark("client_dropped", pickup_name)
		await await_step("host_took")
		await wait_for(func() -> bool: return not players.has_node(pickup_name), "The host's take vanishes it on the client too")
	await barrier("done")


func _slot_of(inventory: Inventory, item: Item) -> int:
	var slots: Array = inventory.get_slots(item.category)
	for i: int in slots.size():
		if slots[i] != null and (slots[i] as ItemSlot).item.is_same(item):
			return i
	return -1

extends SteamTest
## Purpose: a drop lands on both sides under one name and a take frees it everywhere. Inventory.drop_slot asks the
## world's ProjectileSpawner, which spawns the ItemPickup on every peer under itself (item_pickup.tscn is on its
## Auto Spawn List, so the host accepts a client's drop), under the same name on both; ItemPickup.take asks the server,
## which puts it in the taker's inventory and frees the spawned pickup, and the spawner takes every copy with it.

const APPLE: Item = preload("res://resources/items/apple.tres")


func test_the_clients_drop_lands_on_the_host_who_takes_it_and_it_vanishes_on_both() -> void:
	var spawner: Node = world_node("ProjectileSpawner")
	if is_host:
		var pickup_name: String = await await_step("client_dropped")
		await wait_for(func() -> bool: return spawner.has_node(pickup_name), "The client's drop lands on the host as %s" % pickup_name)
		var pickup: ItemPickup = spawner.get_node(pickup_name) as ItemPickup
		assert_eq(pickup.item.id, APPLE.id, "and it is the apple")
		assert_eq(pickup.count, 1)
		var before: int = own_player().inventory.count_of(APPLE)
		pickup.player = own_player()
		pickup.take()
		assert_eq(own_player().inventory.count_of(APPLE), before + 1, "The host takes it")
		await wait_for(func() -> bool: return not spawner.has_node(pickup_name), "and it is gone on the host")
		mark("host_took")
	else:
		var me: Player = own_player()
		var index: int = _slot_of(me.inventory, APPLE)
		assert_ne(index, -1, "The world gave the client apples to drop")
		var before: int = me.inventory.count_of(APPLE)
		var already: Array[Node] = spawner.get_children()
		assert_null(me.inventory.drop_slot(APPLE.category, index, 1), "A client's drop comes back through the spawner")
		assert_eq(me.inventory.count_of(APPLE), before - 1, "and leaves the client's bag at once")
		var landed: Array[Node] = []
		var spawned_back: Callable = func() -> bool:
			landed.assign(spawner.get_children().filter(func(node: Node) -> bool: return node is ItemPickup and not already.has(node)))
			return not landed.is_empty()
		await wait_for(spawned_back, "The host spawned the drop back on the client")
		var pickup_name: String = String(landed[0].name) if not landed.is_empty() else ""
		mark("client_dropped", pickup_name)
		await await_step("host_took")
		await wait_for(func() -> bool: return not spawner.has_node(pickup_name), "The host's take vanishes it on the client too")
	await barrier("done")


func _slot_of(inventory: Inventory, item: Item) -> int:
	var slots: Array = inventory.get_slots(item.category)
	for i: int in slots.size():
		if slots[i] != null and (slots[i] as ItemSlot).item.is_same(item):
			return i
	return -1

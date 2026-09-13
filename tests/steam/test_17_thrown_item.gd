extends SteamTest
## Purpose: a rock thrown on the host flies on both sides and lands as a pickup on both. HeldObject launches the
## ThrownItem through the world's ProjectileSpawner with the item's resource path, so the client's copy is the
## same rock thrown by the same Player; the server's copy lands it as an ItemPickup placed through the spawner.

const ROCK: Item = preload("res://resources/items/rock.tres")

var _rocks: Array[Dictionary] = [] ## One per ThrownItem that entered Projectiles: its item id and its thrower.


func test_a_rock_thrown_on_the_host_flies_on_both_sides() -> void:
	var projectiles: Node = world_node("Projectiles")
	projectiles.child_entered_tree.connect(_on_projectile_entered)
	if is_host:
		var me: Player = own_player()
		var held: HeldObject = me.held_object
		me.selected_throwable = ROCK
		await await_step("client_watching") # the rock lands within a second or two; the client is looking first
		assert_true(held.start_throwable_throw(), "The host takes a rock in hand")
		held.execute_instant_throw(Vector3.FORWARD, 1.0)
		await wait_for(func() -> bool: return _rock() != null, "The rock flies on the host")
		assert_eq(_rock()["thrower"], me, "thrown by the host")
		mark("host_threw")
		await await_step("client_saw_rock")
	else:
		mark("client_watching")
		await await_step("host_threw")
		await wait_for(func() -> bool: return _rock() != null, "The rock flies on the client too")
		assert_eq(_rock()["thrower"], other_player(), "thrown by the client's copy of the host")
		mark("client_saw_rock")
	projectiles.child_entered_tree.disconnect(_on_projectile_entered)
	await barrier("done")


func _on_projectile_entered(node: Node) -> void:
	if node is ThrownItem:
		node.ready.connect(func() -> void: _rocks.append({"item": (node as ThrownItem).item.id if (node as ThrownItem).item else &"", "thrower": (node as ThrownItem).thrower}))


## The first thrown rock seen, or null.
func _rock() -> Variant:
	for rock: Dictionary in _rocks:
		if rock["item"] == ROCK.id:
			return rock
	return null

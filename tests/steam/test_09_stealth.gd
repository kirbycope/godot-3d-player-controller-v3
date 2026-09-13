extends SteamTest
## Purpose: stealth ghosts the other side's copy, body and equipment alike, and lifts again. is_stealthed
## replicates and its setter runs Player._apply_stealth_look on the puppet, which swaps every mesh under the
## skeleton for the stealth shader; clearing it fades the ghosts out and puts the original materials back.


func test_stealth_ghosts_the_other_sides_copy_body_and_equipment_and_lifts_again() -> void:
	if is_host:
		await _stealth("host")
		await _watch("client")
	else:
		await _watch("host")
		await _stealth("client")


func _stealth(who: String) -> void:
	var me: Player = own_player()
	var carried: Array[Equipment] = me.inventory.get_all_weapons()
	assert_gt(carried.size(), 0, "%s still carries the piece from the equipment scenario" % who)
	me.inventory.equip_weapon(carried[0])
	mark(who + "_armed")
	await await_step(who + "_armed_seen")
	me.is_stealthed = true
	mark(who + "_hidden")
	await await_step(who + "_ghost_seen")
	me.is_stealthed = false
	mark(who + "_shown")
	await await_step(who + "_solid_seen")
	me.inventory.unequip_all()


func _watch(who: String) -> void:
	await await_step(who + "_armed")
	var them: Player = other_player()
	await wait_for(func() -> bool: return not them.inventory.equipment.is_empty(), "The %s's copy has its piece in hand" % who)
	mark(who + "_armed_seen")
	await await_step(who + "_hidden")
	await wait_for(func() -> bool: return them.is_stealthed, "The %s's copy is flagged stealthed" % who)
	await wait_for(func() -> bool: return not _ghosted_meshes(them).is_empty(), "and wears the stealth shader")
	var body: int = 0
	var equipment: int = 0
	for mesh: MeshInstance3D in _ghosted_meshes(them):
		if _under_equipment(mesh, them):
			equipment += 1
		else:
			body += 1
	assert_gt(body, 0, "on its body")
	assert_gt(equipment, 0, "and on its equipment")
	mark(who + "_ghost_seen")
	await await_step(who + "_shown")
	await wait_for(func() -> bool: return not them.is_stealthed, "The flag clears on the copy")
	await wait_for(func() -> bool: return _ghosted_meshes(them).is_empty(), "and it is solid again once the fade lands", them.stealth_fade_time + 5.0)
	mark(who + "_solid_seen")


## Every mesh under [param player]'s skeleton that wears the stealth shader on any surface.
func _ghosted_meshes(player: Player) -> Array[MeshInstance3D]:
	var ghosted: Array[MeshInstance3D] = []
	for node: Node in player.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_surface_override_material(surface)
			if material is ShaderMaterial and (material as ShaderMaterial).shader == Player.STEALTH_SHADER:
				ghosted.append(mesh)
				break
	return ghosted


## Whether [param mesh] belongs to a piece of equipment rather than the body.
func _under_equipment(mesh: Node, player: Player) -> bool:
	var node: Node = mesh.get_parent()
	while node != null and node != player.skeleton:
		if node is Equipment:
			return true
		node = node.get_parent()
	return false

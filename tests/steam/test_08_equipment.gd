extends SteamTest
## Purpose: what one side equips hangs on its copy on the other side, and stows with it. Inventory._send_equipment
## names each piece by its origin, the world pickup it came from, and the other side's copy rebuilds it from the
## same node through Inventory._sync_equipment; the host takes the sword and the client the axe.

const SWORD: String = "N_Hance_Studio_1/SK_Sword_1H_Newbie_01"
const AXE: String = "N_Hance_Studio_1/SK_Axe_1H_Newbie_01"


func test_a_piece_equipped_on_each_side_hangs_on_its_copy_on_the_other_and_stows_with_it() -> void:
	if is_host:
		await _equip_and_stow(SWORD, "host")
		await _watch("client")
	else:
		await _watch("host")
		await _equip_and_stow(AXE, "client")


func _equip_and_stow(path: String, who: String) -> void:
	var pickup: Equipment = world_node(path) as Equipment
	var me: Player = own_player()
	assert_true(pickup.equip(me), "%s takes the %s" % [who, pickup.name])
	var origin: String = String(pickup.get_path())
	assert_not_null(_equipped_from(me, origin), "and holds it")
	mark(who + "_equipped", origin)
	await await_step(who + "_seen")
	me.inventory.unequip_all()
	assert_true(me.inventory.equipment.is_empty(), "%s stows it" % who)
	mark(who + "_stowed")
	await await_step(who + "_stow_seen")


func _watch(who: String) -> void:
	var origin: String = await await_step(who + "_equipped")
	var them: Player = other_player()
	await wait_for(func() -> bool: return _equipped_from(them, origin) != null, "The %s's piece hangs on their copy here" % who)
	var piece: Equipment = _equipped_from(them, origin)
	var attachment: BoneAttachment3D = piece.get_parent() as BoneAttachment3D
	assert_not_null(attachment, "on a bone attachment")
	assert_eq(attachment.get_parent(), them.skeleton, "of the copy's skeleton")
	assert_eq(attachment.bone_name, piece.bone_attachment_bone_name, "on the bone the piece names")
	mark(who + "_seen")
	await await_step(who + "_stowed")
	await wait_for(func() -> bool: return them.inventory.equipment.is_empty(), "Stowing it takes it off the copy too")
	assert_gt(them.inventory.get_all_weapons().size(), 0, "though it is still carried")
	mark(who + "_stow_seen")


## The equipped piece of [param player] that came from the world pickup at [param origin], or null.
func _equipped_from(player: Player, origin: String) -> Equipment:
	for piece: Equipment in player.inventory.equipment:
		if piece.has_meta("origin") and String(piece.get_meta("origin")) == origin:
			return piece
	return null

extends SteamTest
## Purpose: a spell cast on the host plays on the client. Abilities._play_phase is sent by the caster's authority
## to every copy, so the channeling VFX appears in the hand of the host's copy on the client for the cast time,
## and the stealth ability's toggle reaches the copy through is_stealthed as the stealth scenario showed.

const FLASH_OF_LIGHT: Ability = preload("res://resources/abilities/flash_of_light.tres")


func test_a_heal_channelled_on_the_host_shows_in_the_hand_of_its_copy_on_the_client() -> void:
	if is_host:
		var me: Player = own_player()
		var abilities: Abilities = me.abilities
		me.health.damage(10.0, me.global_position)
		assert_true(me.can_heal(), "The host is hurt enough to heal")
		await await_step("client_watching") # the channel lasts the cast time; the client is looking first
		abilities.cast(FLASH_OF_LIGHT)
		assert_eq(abilities.casting, FLASH_OF_LIGHT, "The host channels Flash of Light")
		await wait_for(func() -> bool: return abilities.get("_channeling_vfx") != null, "with its channeling VFX in hand")
		mark("host_casting")
		await await_step("client_saw_channel")
		await wait_for(func() -> bool: return abilities.casting == null, "The cast finishes", FLASH_OF_LIGHT.cast_time + 5.0)
	else:
		var abilities: Abilities = other_player().abilities
		mark("client_watching")
		await await_step("host_casting")
		await wait_for(func() -> bool: return is_instance_valid(abilities.get("_channeling_vfx")), "The channeling VFX shows in the hand of the host's copy here")
		var vfx: Node3D = abilities.get("_channeling_vfx") as Node3D
		assert_true(other_player().is_ancestor_of(vfx), "under the copy")
		mark("client_saw_channel")
	await barrier("done")

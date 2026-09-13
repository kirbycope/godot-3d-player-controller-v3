extends SteamTest
## Purpose: an emote reaches the other side's copy. The emote layer of a puppet's AnimationTree advances on the
## replicated flags, so a throw wound up on one side (HeldObject.queue_throw sets is_throwing) takes the other
## side's copy into its Throw emote. What the copy then shows is another matter, and the pending test records it.

const ROCK: Item = preload("res://resources/items/rock.tres")
const EMOTE_BLEND_PATH: String = "parameters/EmoteSpineBlend2/blend_amount"


func test_a_throw_wound_up_on_each_side_takes_the_other_sides_copy_into_the_throw_emote() -> void:
	if is_host:
		await _throw("host")
		await _watch("client")
	else:
		await _watch("host")
		await _throw("client")


func test_the_copys_throw_emote_is_seen_and_ends() -> void:
	pending("On a puppet the emote layer is never weighted in: HeldObject raises EmoteSpineBlend2 on the authority alone (addons/3d_player_controller/scripts/held_object.gd:246) and nothing replicates it, so the copy's Throw plays at a blend of 0.00 and its emote machine stays in Throw instead of returning to Idle")


func _throw(who: String) -> void:
	var me: Player = own_player()
	var held: HeldObject = me.held_object
	me.selected_throwable = ROCK
	await await_step(who + "_watched") # a throw is over in a couple of seconds; the other side is looking first
	assert_true(held.start_throwable_throw(), "%s takes a rock in hand" % who)
	held.queue_throw(Vector3.FORWARD)
	assert_true(me.is_throwing, "and winds up the throw")
	assert_true(me.is_emoting)
	mark(who + "_throwing")
	await await_step(who + "_seen")
	await wait_for(func() -> bool: return not me.is_throwing and not me.is_emoting, "The throw plays out on the %s" % who, 15.0)
	mark(who + "_done")


func _watch(who: String) -> void:
	var them: Player = other_player()
	var playback: AnimationNodeStateMachinePlayback = them.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	mark(who + "_watched")
	await await_step(who + "_throwing")
	await wait_for(func() -> bool: return them.is_throwing, "The %s's copy is flagged throwing" % who)
	await wait_for(func() -> bool: return playback.get_current_node() == &"Throw", "and its emote layer enters Throw", 5.0)
	print("[steam_test] %s: the %s's copy plays %s with the spine blend at %.2f" % [role, who, playback.get_current_node(), float(them.animation_tree.get(EMOTE_BLEND_PATH))])
	mark(who + "_seen")
	await await_step(who + "_done")
	await wait_for(func() -> bool: return not them.is_throwing, "and the flag clears on the copy once the throw is over", 15.0)
	print("[steam_test] %s: after the throw the %s's copy is in %s" % [role, who, playback.get_current_node()])

extends SteamTest
## Purpose: push-to-talk over the network. The speaking indicator over the talker's head shows on the other side
## while they hold the key and goes when they let go, and a voice packet crosses without upsetting the copy that
## decodes it. Neither machine has a microphone, so the packet is synthetic: Steam refuses to decode it and the
## copy drops it, which is what a corrupt packet from a real session gets too. Hearing real audio is left to a
## person with headphones.

const PACKET_BYTES: int = 64


func test_the_speaking_indicator_and_a_voice_packet_cross_both_ways() -> void:
	if is_host:
		await _speak("host")
		await _listen("client")
	else:
		await _listen("host")
		await _speak("client")


func _speak(who: String) -> void:
	var me: Player = own_player()
	me.voice_chat.start_broadcasting()
	assert_true(me.voice_chat.is_broadcasting, "%s is broadcasting" % who)
	assert_true(me.voice_chat.indicator.visible, "with the indicator up over their own head")
	me.voice_chat._receive_voice_packet.rpc(_synthetic_packet())
	mark(who + "_talking")
	await await_step(who + "_heard")
	me.voice_chat.stop_broadcasting()
	mark(who + "_quiet")
	await await_step(who + "_silence_seen")


func _listen(who: String) -> void:
	await await_step(who + "_talking")
	var them: Player = other_player()
	await wait_for(func() -> bool: return them.voice_chat.indicator.visible, "The indicator over the %s's head shows here" % who)
	mark(who + "_heard")
	await await_step(who + "_quiet")
	await wait_for(func() -> bool: return not them.voice_chat.indicator.visible, "and goes when the %s stops" % who)
	mark(who + "_silence_seen")


func _synthetic_packet() -> PackedByteArray:
	var packet: PackedByteArray = PackedByteArray()
	packet.resize(PACKET_BYTES)
	for i: int in PACKET_BYTES:
		packet[i] = i * 4 % 256
	return packet

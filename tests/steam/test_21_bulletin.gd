extends SteamTest
## Purpose: a radio bulletin broadcast on one side plays on the other side's own radio at the same time.
## RadiOtPlayer3D.broadcast_bulletin carries the stream path, text and duration by RPC, and each peer plays it on
## the radio it controls and on no puppet's copy, so one bulletin is heard once per player.

const BULLETIN_STREAM: String = "res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3"
const BULLETIN_TEXT: String = "The Space Needle has been closed"


func test_a_bulletin_broadcast_on_the_host_plays_on_the_clients_own_radio() -> void:
	var radio: RadiOtPlayer3D = world.get("radi_ot_player") as RadiOtPlayer3D
	assert_not_null(radio, "This side's Player carries a radio")
	assert_true(radio.is_multiplayer_authority(), "and it is this peer's own")
	if is_host:
		await await_step("client_listening")
		radio.broadcast_bulletin(BULLETIN_STREAM, BULLETIN_TEXT, 3.0)
		assert_true(radio.is_bulletin_active(), "The bulletin plays here")
		mark("host_broadcast")
		await await_step("client_heard")
		await wait_for(func() -> bool: return not radio.is_bulletin_active(), "and ends here", 10.0)
	else:
		mark("client_listening")
		await await_step("host_broadcast")
		await wait_for(func() -> bool: return radio.is_bulletin_active(), "The client's own radio plays the host's bulletin")
		var puppets_radio: RadiOtPlayer3D = other_player().get_node_or_null("RadiOtPlayer3D") as RadiOtPlayer3D
		if puppets_radio:
			assert_false(puppets_radio.is_bulletin_active(), "and the host's copy here stays quiet, so it is heard once")
		mark("client_heard")
		await wait_for(func() -> bool: return not radio.is_bulletin_active(), "and it ends here too", 10.0)
	await barrier("done")

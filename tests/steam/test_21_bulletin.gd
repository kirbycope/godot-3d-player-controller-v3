extends SteamTest
## Purpose: a radio bulletin broadcast on one side plays on the other side's radio at the same time. The radio is
## the car's, of which every peer holds one copy: RadiOtPlayer3D.broadcast_bulletin carries the stream path, text
## and duration by RPC to every peer's copy of the sending radio, and each peer plays it on every radio it has, so
## both sides hear it once, at the car, whoever holds the car's authority.

const BULLETIN_STREAM: String = "res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3"
const BULLETIN_TEXT: String = "The Space Needle has been closed"


func test_a_bulletin_broadcast_on_the_host_plays_on_the_clients_copy_of_the_car_radio() -> void:
	var radio: RadiOtPlayer3D = world_node("HondaCRV/RadiOtPlayer3D") as RadiOtPlayer3D
	assert_not_null(radio, "The car carries a radio")
	if is_host:
		await await_step("client_listening")
		radio.broadcast_bulletin(BULLETIN_STREAM, BULLETIN_TEXT, 3.0)
		assert_true(radio.is_bulletin_active(), "The bulletin plays here")
		mark("host_broadcast")
		await await_step("client_heard")
		await wait_for(func() -> bool: return not radio.is_bulletin_active(), "and ends here", 10.0)
	else:
		assert_false(radio.is_multiplayer_authority(), "The car is the server's on this side, and its radio with it")
		mark("client_listening")
		await await_step("host_broadcast")
		await wait_for(func() -> bool: return radio.is_bulletin_active(), "The client's copy of the car radio plays the host's bulletin all the same")
		mark("client_heard")
		await wait_for(func() -> bool: return not radio.is_bulletin_active(), "and it ends here too", 10.0)
	await barrier("done")

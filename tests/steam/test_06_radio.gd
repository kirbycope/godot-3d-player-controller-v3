extends SteamTest
## Purpose: the car over the network. The host drives: the client sees the host's Player riding and the car where
## the host's is, and the host's own radio powers up with the engine and goes off with it. Then the client drives:
## getting in hands the car's authority to the driver's peer on every peer (Vehicle._set_authority), so the host
## sees the client at the wheel and has the car back once they are out. And the station is the car's: the driver's
## next-station action moves GtaCar.radio_station, which replicates, so the pick reaches the other side and every
## rider's own RadiOtPlayer3D follows it.



func test_the_host_drives_and_the_client_sees_the_driver_and_the_car_follow() -> void:
	var car: GtaCar = world_node("HondaCRV") as GtaCar
	var start: Vector3 = car.global_position
	if is_host:
		var me: Player = own_player()
		var radio: RadiOtPlayer3D = world.get("radi_ot_player") as RadiOtPlayer3D
		assert_false(radio.is_power_on(), "The radio is off on foot")
		me.mount(car)
		await wait_for(func() -> bool: return me.is_riding and car.current_driver_peer_id == 1, "The host is in the driver's seat")
		await wait_for(func() -> bool: return radio.is_power_on(), "The car radio powers up for the driver")
		radio.tune_next_station()
		# The throttle only reaches the wheels once the get-in clip has played, which a headless run never does, and a
		# velocity written onto the body is braked away the next step; the car's travel is the torch's and the duck's
		# story, a server body followed by the client. What this scenario is for is the seat and the radio.
		await wait_physics_frames(10)
		print("[steam_test] host: seated in the car at %s" % car.global_position)
		mark("host_driving", car.global_position)
		await await_step("client_saw_driver")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding, "The host gets out")
		await wait_for(func() -> bool: return not radio.is_power_on(), "and the radio goes off with the engine")
		mark("host_out")
		await await_step("client_saw_out")
	else:
		var at: Vector3 = await await_step("host_driving")
		await wait_for(func() -> bool: return other_player().is_riding, "The host's Player is seen riding")
		assert_eq(car.current_driver_peer_id, 1, "with the host as the driver")
		await wait_for(func() -> bool: return car.global_position.distance_to(at) < 2.0, "The car stands where the host's does (here %s, host %s)" % [car.global_position, at])
		print("[steam_test] client: the car moved %.1f m here" % car.global_position.distance_to(start))
		mark("client_saw_driver")
		await await_step("host_out")
		await wait_for(func() -> bool: return not other_player().is_riding, "and the host's Player is seen on foot again")
		mark("client_saw_out")


func test_a_client_at_the_wheel_is_seen_driving_on_the_host() -> void:
	var car: GtaCar = world_node("HondaCRV") as GtaCar
	if is_host:
		var at: Vector3 = await await_step("client_driving")
		await wait_for(func() -> bool: return other_player().is_riding, "The client's Player is seen riding")
		await wait_for(func() -> bool: return car.current_driver_peer_id == other_peer(), "with the client as the driver")
		assert_eq(car.get_multiplayer_authority(), other_peer(), "The car is the client's here, so its state is taken rather than rejected")
		assert_false(car.is_multiplayer_authority(), "and no longer the server's")
		await wait_for(func() -> bool: return car.global_position.distance_to(at) < 2.0, "The car stands where the client's does (here %s, client %s)" % [car.global_position, at])
		mark("host_saw_driver")
		await await_step("client_out")
		await wait_for(func() -> bool: return not other_player().is_riding, "The client's Player is seen on foot again")
		await wait_for(func() -> bool: return car.get_multiplayer_authority() == Vehicle.SERVER_PEER and car.current_driver_peer_id == Vehicle.SERVER_PEER, "and the car is the server's again, with nobody at the wheel")
		mark("host_saw_out")
	else:
		var me: Player = own_player()
		me.mount(car)
		await wait_for(func() -> bool: return me.is_riding and car.is_multiplayer_authority(), "The client is in the driver's seat and holds the car")
		assert_eq(car.current_driver_peer_id, multiplayer.get_unique_id(), "as the driver")
		await wait_physics_frames(10)
		print("[steam_test] client: seated in the car at %s" % car.global_position)
		mark("client_driving", car.global_position)
		await await_step("host_saw_driver")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding and not car.is_multiplayer_authority(), "The client gets out and the car is the server's again")
		await wait_for(func() -> bool: return car.current_driver_peer_id == Vehicle.SERVER_PEER, "with nobody at the wheel once the server has taken the car back")
		mark("client_out")
		await await_step("host_saw_out")


func test_the_station_the_driver_picks_reaches_the_other_side() -> void:
	var car: GtaCar = world_node("HondaCRV") as GtaCar
	var radio: RadiOtPlayer3D = world.get("radi_ot_player") as RadiOtPlayer3D
	if is_host:
		var me: Player = own_player()
		me.mount(car)
		await wait_for(func() -> bool: return me.is_riding and radio.is_power_on(), "The host is in the driver's seat with the radio on")
		var want: int = posmod(car.radio_station + 1, radio.get_station_count())
		me.inventory.custom_cycle_handler.call(1) # the driver's next-station action, as world.gd wires it while driving
		assert_eq(car.radio_station, want, "The tune action moves the car's station")
		await wait_for(func() -> bool: return radio.current_station_index == want, "and the driver's own radio follows the car")
		mark("host_tuned", want)
		await await_step("client_saw_station")
		me.dismount(true)
		await wait_for(func() -> bool: return not me.is_riding, "The host gets out")
		mark("host_out")
		await await_step("client_saw_out")
	else:
		var want: int = await await_step("host_tuned")
		await wait_for(func() -> bool: return car.radio_station == want, "The car's station here is the one the host picked")
		assert_false(radio.is_power_on(), "A Player on foot hears no radio; a rider's follows the car's station once in it")
		mark("client_saw_station")
		await await_step("host_out")
		await wait_for(func() -> bool: return not other_player().is_riding, "and the host's Player is seen on foot again")
		mark("client_saw_out")

extends SteamTest
## Purpose: the car over the network. The host drives: the client sees the host's Player riding and the car where
## the host's is, and the host's own radio powers up with the engine and goes off with it. The radio is each
## Player's own RadiOtPlayer3D, powered by world.gd for the local driver alone, and a client at the wheel does not
## cross at all; the two pending tests record both.



func test_the_host_drives_and_the_client_sees_the_driver_and_the_car_follow() -> void:
	var car: Vehicle = world_node("HondaCRV") as Vehicle
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
	pending("Vehicle.set_driver moves the car's authority on the driver's own peer only (addons/gta/scripts/vehicle.gd:136-148); unlike Horse._set_authority and LittleBuddy._set_authority there is no RPC, so the host's copy stays the server's, rejects the client's state as 'sync data from non-authority', the client's copy rejects the host's, and neither the driver's peer id nor the car's motion crosses")


func test_the_station_the_driver_picks_reaches_the_other_side() -> void:
	pending("Only the driver hears the radio: RadiOtPlayer3D lives on each Player (scenes/world_player.tscn) and world.gd powers the local one while riding; nothing replicates its station, and honda_crv.tscn has one seat")

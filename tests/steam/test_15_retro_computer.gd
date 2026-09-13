extends SteamTest
## Purpose: the retro computer seats one Player at a time across the network. RetroComputer.is_in_use is each
## peer's own, so a second Player is refused by reading the other peer's Player off the seat: the host sits, the
## client sees them at the keyboard and is refused; once the host stands and steps away, the client can sit and
## the host is refused in turn.

const STAND_AWAY: Vector3 = Vector3(0.0, 0.2, 3.0) ## Where a Player steps to after leaving the chair, in the computer's own space.


func test_the_seat_is_seen_taken_and_refuses_a_second_player_until_the_first_leaves() -> void:
	var computer: RetroComputer = world_node("RetroComputer") as RetroComputer
	var seat: Node3D = computer.player_seat
	if is_host:
		computer.equip(own_player())
		assert_true(computer.is_in_use, "The host sits down")
		mark("host_seated")
		await await_step("client_refused")
		await _stand_up(computer, "host")
		mark("host_left")
		await await_step("client_seated")
		await wait_for(func() -> bool: return other_player().is_sitting and other_player().global_position.distance_to(seat.global_position) < 0.5, "The client is seen at the keyboard")
		computer.equip(own_player())
		assert_false(computer.is_in_use, "and the host is refused while they are")
		mark("host_refused")
		await await_step("client_left")
	else:
		await await_step("host_seated")
		await wait_for(func() -> bool: return other_player().is_sitting, "The host is seen sitting")
		await wait_for(func() -> bool: return other_player().global_position.distance_to(seat.global_position) < 0.5, "at the keyboard")
		computer.equip(own_player())
		assert_false(computer.is_in_use, "A second Player is refused while the seat is taken")
		assert_false(own_player().is_sitting)
		mark("client_refused")
		await await_step("host_left")
		await wait_for(func() -> bool: return not other_player().is_sitting and other_player().global_position.distance_to(seat.global_position) > 0.5, "The host is seen leaving")
		computer.equip(own_player())
		assert_true(computer.is_in_use, "and the client can sit down")
		mark("client_seated")
		await await_step("host_refused")
		await _stand_up(computer, "client")
		mark("client_left")


## Stands this side's Player up and steps them clear of the seat, so the other side is not refused by proximity.
func _stand_up(computer: RetroComputer, who: String) -> void:
	computer.stop_using()
	await wait_for(func() -> bool: return not own_player().is_sitting, "The %s stands up once the typing lead-out has played" % who, 15.0)
	own_player().warp_to(Transform3D(Basis(), computer.to_global(STAND_AWAY)))

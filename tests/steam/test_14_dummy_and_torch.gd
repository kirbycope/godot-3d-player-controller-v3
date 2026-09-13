extends SteamTest
## Purpose: the training dummy flinches on both sides whoever strikes it (GuyNumberOne._travel is sent by the
## striking peer to every peer), and the torch, a server-owned rigid body, comes to rest on the client where it
## rests on the host. Nothing in the world calls Torch.extinguish or relight, so the flame is not exercised.

const REACTIONS: Array[StringName] = [&"GettingHit", &"ReactionHitOnLeftSide", &"ReactionHitOnRightSide"]


func test_a_strike_from_either_side_flinches_the_dummy_on_both() -> void:
	var dummy: CharacterBody3D = world_node("GuyNumberOne") as CharacterBody3D
	var playback: AnimationNodeStateMachinePlayback = dummy.get("playback")
	if is_host:
		mark("host_watching") # a flinch is over in a second; the host is looking before the client strikes
		await await_step("client_struck")
		await wait_for(func() -> bool: return playback.get_current_node() == &"GettingHit", "The client's strike flinches the host's dummy", 5.0)
		await wait_for(func() -> bool: return playback.get_current_node() == &"Idle", "which settles again", 10.0)
		mark("host_saw_flinch")
		await await_step("client_settled")
		dummy.call("register_hit")
		await wait_for(func() -> bool: return REACTIONS.has(playback.get_current_node()), "The host's strike flinches the host's dummy", 5.0)
		mark("host_struck")
		await await_step("client_saw_flinch")
	else:
		await await_step("host_watching")
		dummy.rpc("_travel", "GettingHit")
		await wait_for(func() -> bool: return playback.get_current_node() == &"GettingHit", "The client's strike flinches the client's dummy", 5.0)
		mark("client_struck")
		await await_step("host_saw_flinch")
		await wait_for(func() -> bool: return playback.get_current_node() == &"Idle", "which settles again", 10.0)
		mark("client_settled") # and the client is looking before the host strikes
		await await_step("host_struck")
		await wait_for(func() -> bool: return REACTIONS.has(playback.get_current_node()), "The host's strike flinches the client's dummy", 5.0)
		mark("client_saw_flinch")


func test_the_torch_comes_to_rest_on_the_client_where_it_rests_on_the_host() -> void:
	var torch: Torch = world_node("Torch") as Torch
	if is_host:
		assert_true(torch.is_multiplayer_authority(), "The server owns the torch")
		torch.apply_central_impulse(Vector3(0.0, 3.0, 1.5))
		await wait_physics_frames(10)
		await wait_for(func() -> bool: return torch.sleeping or torch.linear_velocity.length() < 0.05, "The torch comes to rest on the host", 20.0)
		mark("torch_rested", torch.global_position)
		await await_step("torch_seen")
	else:
		assert_false(torch.is_multiplayer_authority(), "The client only mirrors the torch")
		var at: Vector3 = await await_step("torch_rested")
		await wait_for(func() -> bool: return torch.global_position.distance_to(at) < 0.5, "The client's torch lies where the host's does (here %s, host %s)" % [torch.global_position, at])
		mark("torch_seen")

extends SteamTest
## Purpose: the giant duck shows on the client. The server's duck respawns as the giant; is_giant and its health
## replicate through its BodySynchronizer and their setters size the client's copy, show its knife and give it the
## giant's health. The host puts it back to a duckling after, so the boss fight does not run under the rest.


func test_the_giant_and_its_health_reach_the_client() -> void:
	var duck: FollowerNpc = world_node("Duck") as FollowerNpc
	var health: Health = duck.get("health") as Health
	if is_host:
		duck.call("_respawn_as_giant")
		assert_true(duck.get("is_giant"), "The server's duck is the giant")
		mark("giant")
		await await_step("giant_seen")
		duck.call("_become_duckling")
		assert_false(duck.get("is_giant"), "and a duckling again")
		mark("duckling")
		await await_step("duckling_seen")
	else:
		assert_false(duck.is_multiplayer_authority(), "The client only mirrors the duck")
		await await_step("giant")
		await wait_for(func() -> bool: return duck.get("is_giant") == true, "The giant replicates")
		assert_eq((duck.get("idle_model") as Node3D).scale, Vector3.ONE * 10.0, "and the client's copy grows")
		assert_true((duck.get("knife") as Node3D).visible, "with the knife out")
		await wait_for(func() -> bool: return health.max_health == float(duck.get("giant_health")), "and the giant's health")
		mark("giant_seen")
		await await_step("duckling")
		await wait_for(func() -> bool: return duck.get("is_giant") == false, "The duckling replicates back")
		mark("duckling_seen")

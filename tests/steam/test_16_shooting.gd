extends SteamTest
## Purpose: a round fired on the client is spawned by the server and lands on both peers as the same projectile.
## Firearm.fire hands the launch to the ProjectileSpawner, which asks the server over RPC; the server spawns the
## round under Projectiles and the MultiplayerSpawner replicates it, so each peer simulates the same shot. A
## round is gone within a frame or two of hitting something, so who shot it is read the moment it is ready.

const PISTOL: String = "JustCreate3D/Weapon_01"

var _rounds: Array[Dictionary] = [] ## One per Projectile that entered Projectiles: its class and its shooter.


func test_a_round_fired_on_the_client_flies_on_both_sides() -> void:
	var projectiles: Node = world_node("Projectiles")
	projectiles.child_entered_tree.connect(_on_projectile_entered)
	if is_host:
		mark("host_watching") # a round is gone within a second; the host is looking before the client fires
		await await_step("client_fired")
		await wait_for(func() -> bool: return not _rounds.is_empty(), "The client's round is spawned on the host")
		assert_true(_rounds[0]["is_projectile"], "as a Projectile")
		assert_eq(_rounds[0]["shooter"], other_player(), "shot by the host's copy of the client")
		mark("host_saw_round")
	else:
		var me: Player = own_player()
		var pickup: Firearm = world_node(PISTOL) as Firearm
		assert_true(pickup.equip(me), "The client takes the pistol")
		var gun: Firearm = pickup.equipment_instance as Firearm
		gun.reload()
		await wait_for(func() -> bool: return gun.rounds > 0, "and loads it from the magazine the world handed out", 10.0)
		await await_step("host_watching")
		var round: Projectile = gun.fire()
		assert_null(round, "A client's fire returns nothing; its copy arrives through the spawner")
		await wait_for(func() -> bool: return not _rounds.is_empty(), "The round flies on the client")
		assert_eq(_rounds[0]["shooter"], me, "shot by the client")
		mark("client_fired")
		await await_step("host_saw_round")
	projectiles.child_entered_tree.disconnect(_on_projectile_entered)
	await barrier("done")


## The spawner sets the launch data before the node enters the tree and the node launches itself on ready, so the
## shooter is read once it is ready, before the round can hit anything and go. The shot's own sound lands beside it
## under Projectiles as a speaker (Projectile.play_launch_sfx), which is not a round.
func _on_projectile_entered(node: Node) -> void:
	if node is Projectile:
		node.ready.connect(func() -> void: _rounds.append({"is_projectile": node is Projectile, "shooter": node.get("shooter")}))

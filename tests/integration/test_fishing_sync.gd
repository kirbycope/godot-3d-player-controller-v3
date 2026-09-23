extends GutTest

## Purpose: A float fired through the ProjectileSpawner on the host appears on a real ENet client with the
## caster as its shooter, draws its own line there, and the host's plunge and catch RPCs reach the client. The bait on
## the line is the rod owner's alone: a peer's copy of the rod neither takes a used lure nor eats one. The rest of the
## bite reaches the client too: the shadow drawn to the float and diving on the bite, the reel spinning on the
## client's copy of the rod and the rod's sounds at the float. A shot fish sinks on every peer and only the shooter's
## own peer pockets the chum.

const PORT: int = 47392
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BOBBER_SCENE: PackedScene = preload("res://scenes/bobber.tscn")
const ROD_SCENE: PackedScene = preload("res://scenes/fishing_rod.tscn")
const WORM: Lure = preload("res://resources/lures/worm.tres")
const CARP_PATH: String = "res://resources/fish/carp.tres"
const CARP: Fish = preload("res://resources/fish/carp.tres")
const CHUM: Lure = preload("res://resources/lures/chum.tres")
const REEL_SOUND: AudioStream = preload("res://assets/gravitysound/Animal SFX/Duck_1.ogg") ## Any clip stands in for the rod's reel sound.
const POOL_MATERIAL: Material = preload("res://resources/pool_water_material.tres")
const POOL_AT: Vector3 = Vector3(30.0, 0.0, 30.0) ## Well away from where the Players spawn.
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const PROJECTILE_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/projectile_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


func _build_branch(root: Node3D) -> void:
	var players := Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	root.add_child(projectiles)
	var player_spawner: PlayerSpawner = PLAYER_SPAWNER.new()
	player_spawner.name = "PlayerSpawner"
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.add_child(PLAYER_SCENE.instantiate()) # the template every peer's player is a copy of
	root.add_child(player_spawner)
	var projectile_spawner: ProjectileSpawner = PROJECTILE_SPAWNER.new()
	projectile_spawner.name = "ProjectileSpawner"
	projectile_spawner.spawn_path = NodePath("../Projectiles")
	root.add_child(projectile_spawner)
	# A pool with its shadows, at the same path on both sides, as the world's is
	var water := Buoyancy.new()
	water.name = "Water"
	water.add_to_group("WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10.0, 4.0, 10.0)
	water.add_child(shape)
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, 10.0)
	quad.orientation = PlaneMesh.FACE_Y
	surface.mesh = quad
	surface.material_override = POOL_MATERIAL
	surface.position.y = 2.0
	water.add_child(surface)
	water.water_mesh = surface
	water.fish = [CARP]
	water.position = POOL_AT + Vector3(0.0, -2.0, 0.0)
	root.add_child(water)
	var shadows := FishShadows.new()
	shadows.name = "FishShadows"
	shadows.water = water
	shadows.chum = CHUM
	shadows.count = 2
	water.shadows = shadows
	root.add_child(shadows)


func before_each() -> void:
	server_root = Node3D.new()
	server_root.name = "ServerBranch"
	client_root = Node3D.new()
	client_root.name = "ClientBranch"
	add_child(server_root)
	add_child(client_root)
	server_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT), OK, "ENet server should open on localhost")
	server_api.multiplayer_peer = server_peer
	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_api.multiplayer_peer = client_peer
	_build_branch(server_root)
	_build_branch(client_root)
	for i in 120:
		await wait_process_frames(1)
		if client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0:
			break
	assert_gt(client_api.get_peers().size(), 0, "Client should connect to the loopback server")
	await wait_process_frames(30)


func after_each() -> void:
	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


func test_host_float_appears_on_the_client_with_its_line_and_takes_rpcs() -> void:
	var host_player: Player = server_root.get_node("Players/1")
	var spawner: ProjectileSpawner = server_root.get_node("ProjectileSpawner")
	var origin: Transform3D = Transform3D(Basis(), host_player.global_position + Vector3(0.0, 1.3, -0.5))
	var host_bobber: Bobber = spawner.fire(BOBBER_SCENE, origin, Vector3(0.0, 0.6, -0.8).normalized(), 4.0, host_player)
	assert_not_null(host_bobber, "The host keeps its own copy")
	await wait_process_frames(20)
	var client_projectiles: Node = client_root.get_node("Projectiles")
	assert_eq(client_projectiles.get_child_count(), 1, "The client receives the float")
	var client_bobber: Bobber = client_projectiles.get_child(0)
	# Both branches share one tree here, so the absolute shooter path lands on the host branch's player 1;
	# in a real session the paths match on every peer
	assert_eq(String(client_bobber.shooter.name), "1", "The client's float knows the caster")
	assert_eq((client_bobber.line.mesh as ImmediateMesh).get_surface_count(), 1, "The client draws the line from the caster's hand")

	host_bobber.plunge.rpc(0.3, 1.0)
	await wait_process_frames(10)
	assert_lt(client_bobber.float_mesh.position.y, -0.05, "The plunge reaches the client")

	host_bobber.present_catch.rpc(CARP_PATH, 40.0)
	await wait_process_frames(5)
	assert_true(client_projectiles.get_children().any(func(n: Node) -> bool: return n is FishModel or n.name.ends_with("Model")), "The catch model shows on the client")

	host_bobber.retract.rpc()
	await wait_process_frames(20)
	assert_false(is_instance_valid(client_bobber) and client_bobber.is_inside_tree(), "Retracting on the host despawns the float on the client")


func test_only_the_rods_owner_puts_bait_on_the_line_or_eats_it() -> void:
	var host_player: Player = server_root.get_node("Players/1")
	var client_player: Player = client_root.get_node("Players/1") # the client's copy of the host's player
	assert_true(host_player.is_multiplayer_authority())
	assert_false(client_player.is_multiplayer_authority(), "The client only mirrors player 1")
	var host_pickup: FishingRod = ROD_SCENE.instantiate() as FishingRod
	server_root.add_child(host_pickup)
	assert_true(host_pickup.equip(host_player))
	await wait_process_frames(5)
	var host_rod: FishingRod = host_pickup.equipment_instance as FishingRod
	# The client's copy of the rod comes from the inventory's equipment sync, not from equipping one there.
	var client_rod: FishingRod = null
	for item: Equipment in client_player.inventory.get_all_weapons():
		if item is FishingRod:
			client_rod = item
	assert_not_null(client_rod, "The equipment sync gives the client's copy of the player the rod")
	assert_true(host_rod.is_multiplayer_authority())
	assert_false(client_rod.is_multiplayer_authority())
	host_player.inventory.add_item(WORM, 2)
	host_player.inventory.use_slot(WORM.category, 0)
	assert_eq(host_rod.lure, WORM, "The owner's Use puts the worm on the line")
	host_rod.consume_lure()
	assert_eq(host_player.inventory.count_of(WORM), 0, "and the owner's bite takes the next one from the bag")
	client_player.inventory.add_item(WORM, 2)
	client_player.inventory.use_slot(WORM.category, 0)
	assert_null(client_rod.lure, "A peer's copy of the rod does not listen to that inventory")
	client_rod.lure = WORM # were it set by hand, as an export might
	client_rod.consume_lure()
	assert_eq(client_rod.lure, WORM, "the copy never eats it")
	assert_eq(client_player.inventory.count_of(WORM), 1, "nor touches the bag")


## The host's own rod, equipped, and the client's copy of it from the equipment sync.
func _equip_rods(host_player: Player, client_copy: Player) -> Array[FishingRod]:
	var host_pickup: FishingRod = ROD_SCENE.instantiate() as FishingRod
	server_root.add_child(host_pickup)
	host_pickup.equip(host_player)
	await wait_process_frames(5)
	var client_rod: FishingRod = null
	for item: Equipment in client_copy.inventory.get_all_weapons():
		if item is FishingRod:
			client_rod = item
	return [host_pickup.equipment_instance as FishingRod, client_rod]


## M26: the rod sends every move of the bite to the other peers. The shadow the client sees near the float is drawn
## to it and dives on the bite, the reel spins on the client's copy of the rod and stops when the line comes in, and
## the rod's sound plays at the client's float.
func test_the_shadows_the_reel_and_the_rods_sounds_reach_the_client() -> void:
	var host_player: Player = server_root.get_node("Players/1")
	var client_copy: Player = client_root.get_node("Players/1")
	var rods: Array[FishingRod] = await _equip_rods(host_player, client_copy)
	var host_rod: FishingRod = rods[0]
	var client_rod: FishingRod = rods[1]
	assert_not_null(client_rod, "The client's copy of the host's player carries the rod")
	host_rod.lure = WORM # a metre of reach for the shadows
	host_rod.reel_sfx = REEL_SOUND
	var spawner: ProjectileSpawner = server_root.get_node("ProjectileSpawner")
	var at: Vector3 = POOL_AT + Vector3(1.0, 0.02, 1.0)
	var host_bobber: Bobber = spawner.fire(BOBBER_SCENE, Transform3D(Basis(), at), Vector3.DOWN, 0.1, host_player, host_rod)
	host_bobber.freeze = true
	host_bobber.global_position = at
	var client_projectiles: Node = client_root.get_node("Projectiles")
	await wait_until(func() -> bool: return client_projectiles.get_child_count() == 1, 2.0)
	var client_bobber: Bobber = client_projectiles.get_child(0)
	# Both branches share one tree, so the absolute shooter path lands on the host's player; a real session's paths
	# match on every peer, and the float there knows the client's copy of the caster
	client_bobber.shooter = client_copy
	var client_shadows: FishShadows = client_root.get_node("FishShadows")
	var lured: MeshInstance3D = client_shadows.shadows[0]
	client_shadows.park_shadows_for_test(lured, at)
	host_rod._adopt_bobber(host_bobber)
	host_rod.state = FishingRod.State.WAITING
	host_rod._on_bobber_landed_in_water(server_root.get_node("Water"))
	await wait_until(func() -> bool: return client_shadows.interested == lured, 2.0)
	assert_eq(client_shadows.interested, lured, "The shadow by the float on the client takes an interest too")
	host_rod.bite_timer.stop()
	host_rod.nibble_timer.stop()
	host_rod._on_bite_timer_timeout()
	await wait_until(func() -> bool: return not lured.visible, 2.0)
	assert_null(client_shadows.interested, "The bite sends it diving on the client")
	assert_false(lured.visible, "under the float and out of sight")
	host_rod.hook()
	await wait_until(func() -> bool: return client_rod.animation_player.is_playing(), 2.0)
	assert_eq(client_rod.animation_player.current_animation, String(FishingRod.REEL_ANIMATION), "The reel spins on the client's copy of the rod")
	assert_true(client_bobber.audio.playing, "and the rod's reel sound plays at the client's float")
	assert_eq(client_bobber.audio.stream, REEL_SOUND)
	host_rod.reel_timer.stop()
	host_rod.hook_timer.stop()
	host_rod._on_reel_timer_timeout()
	await wait_until(func() -> bool: return not client_rod.animation_player.is_playing(), 2.0)
	assert_false(client_rod.animation_player.is_playing(), "The reel stops on the client when the line comes in")


## M26: the server lands the hit on a fish, the fish sinks on every peer, and the chum goes into the shooter's own
## bag on the shooter's peer, never into the server's copy of that Player.
func test_a_shot_fish_sinks_everywhere_and_only_the_shooters_peer_pockets_the_chum() -> void:
	var client_id: int = client_api.get_unique_id()
	var shooter_path: String = "Players/" + str(client_id)
	await wait_until(func() -> bool: return client_root.has_node(shooter_path) and server_root.has_node(shooter_path), 2.0)
	var shooter_on_host: Player = server_root.get_node(shooter_path)
	var shooter: Player = client_root.get_node(shooter_path)
	var host_shadows: FishShadows = server_root.get_node("FishShadows")
	var client_shadows: FishShadows = client_root.get_node("FishShadows")
	var at: Vector3 = POOL_AT + Vector3(-1.0, 0.0, 0.0)
	host_shadows.park_shadows_for_test(host_shadows.shadows[0], at)
	client_shadows.park_shadows_for_test(client_shadows.shadows[0], at)
	watch_signals(client_shadows)
	var bullet: Projectile = preload("res://addons/3d_player_controller/scenes/projectile/bullet.tscn").instantiate()
	add_child_autofree(bullet)
	bullet.shooter = shooter_on_host # the server's copy of the round knows the server's copy of the shooter
	var carried: int = shooter.inventory.count_of(CHUM)
	var hit_at: Vector3 = host_shadows.shadows[0].global_position
	client_shadows.register_projectile_hit(bullet, hit_at, Vector3.UP) # what a client's own copy of the round would do
	host_shadows.register_projectile_hit(bullet, hit_at, Vector3.UP)
	await wait_until(func() -> bool: return shooter.inventory.count_of(CHUM) > carried, 2.0)
	assert_signal_emit_count(client_shadows, "shot", 1, "The server's hit sinks the fish on the client, once; the client's own copy of the round counts for nothing")
	assert_eq(shooter.inventory.count_of(CHUM), carried + 1, "The shooter's own peer pockets the chum")
	assert_eq(shooter_on_host.inventory.count_of(CHUM), 0, "and the server's copy of the shooter gets none")

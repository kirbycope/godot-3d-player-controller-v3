extends GutTest

## Purpose: On a real host/client session the host's ice arrow leaves an ice block on every peer through the
## ProjectileSpawner, exactly one per peer (the client's copy of the arrow decides nothing), and the host's fire
## arrow lights the grass on every peer through the spawner's ignite RPC. A client's Lightning and Chain Lightning
## go through the server too (ProjectileSpawner.strike_lightning and arc_lightning), so the bolt shows on every peer,
## and only for a caster the client owns. A client's round is spawned by the server, whose copy alone lands it: the
## beach ball it bursts and the balloon it pops go on every peer.

const PORT: int = 47394
const ICE_ARROW_SCENE: PackedScene = preload("res://scenes/ice_arrow.tscn")
const FIRE_ARROW_SCENE: PackedScene = preload("res://scenes/fire_arrow.tscn")
const GRASS_FIELD_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/grass_field.tscn")
const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const PROJECTILE_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/projectile_spawner.gd")
const LIGHTNING_FX: Script = preload("res://addons/weather_fx/scripts/lightning_fx.gd")
const LIGHTNING: LightningAbility = preload("res://resources/abilities/lightning.tres")
const CHAIN: ChainLightningAbility = preload("res://resources/abilities/chain_lightning.tres")
const BULLET_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/projectile/bullet.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/beach_ball.tscn")
const BALLOON_SCENE: PackedScene = preload("res://scenes/red_ballon.tscn")
const POND_X: float = 40.0

var world: Node3D
var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## A burnable patch as the grass sees it: in the BurnableGrass group with an ignite(), counting how often it was lit.
class GrassSpy extends Node3D:
	var ignitions: int = 0
	func ignite(_force: bool = false) -> void:
		ignitions += 1


## Something a chain of lightning jumps to: Focusable, with a take_hit.
class Enemy extends Node3D:
	var hits: int = 0
	func take_hit(_damage: float, _from: Vector3) -> void:
		hits += 1


func _build_branch(root: Node3D) -> void:
	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	root.add_child(projectiles)
	var projectile_spawner: ProjectileSpawner = PROJECTILE_SPAWNER.new()
	projectile_spawner.name = "ProjectileSpawner"
	projectile_spawner.spawn_path = NodePath("../Projectiles")
	projectile_spawner.add_to_group(&"ProjectileSpawner")
	projectile_spawner.add_spawnable_scene(BULLET_SCENE.resource_path) # a client's round is only spawned for a listed scene
	root.add_child(projectile_spawner)
	# The weather's lightning, which the spells borrow; the server's is first in its group, which the spawner asks
	var lightning: LightningFX = LIGHTNING_FX.new()
	lightning.name = "LightningFX"
	lightning.ignite_radius = 0.0
	var strike_timer := Timer.new()
	strike_timer.name = "StrikeTimer"
	lightning.add_child(strike_timer)
	root.add_child(lightning)


func _floor(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = at
	world.add_child(body)


func _pond() -> Buoyancy:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, 20.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	surface.position = Vector3(POND_X, 0.0, 0.0)
	world.add_child(surface)
	var pond := Buoyancy.new()
	pond.add_to_group(&"WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20.0, 4.0, 20.0)
	pond.add_child(shape)
	pond.position = Vector3(POND_X, -2.0, 0.0)
	pond.water_mesh = surface
	world.add_child(pond)
	return pond


func before_each() -> void:
	# Physics and groups are shared by both branches: one ground, one pond, one grass field for the session
	world = Node3D.new()
	add_child_autofree(world)
	_floor(Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0))
	_floor(Vector3(POND_X, -4.5, 0.0), Vector3(20.0, 1.0, 20.0))
	_pond()
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


func _ice_blocks_under(branch: Node3D) -> Array[Node]:
	return branch.get_node("Projectiles").get_children().filter(func(node: Node) -> bool: return node is IceBlock)


func test_the_hosts_ice_arrow_freezes_the_pond_on_every_peer_once() -> void:
	var spawner: ProjectileSpawner = server_root.get_node("ProjectileSpawner")
	var shooter := StaticBody3D.new() # a body, so the round can hold its shooter exception; the client resolves it too
	server_root.add_child(shooter)
	var arrow: Projectile = spawner.fire(ICE_ARROW_SCENE, Transform3D(Basis(), Vector3(POND_X, 3.0, 0.0)), Vector3.DOWN, 30.0, shooter)
	assert_not_null(arrow, "The host keeps its own copy")
	assert_true(arrow.is_multiplayer_authority(), "and it is the one that decides")
	await wait_process_frames(10)
	assert_eq(client_root.get_node("Projectiles").get_child_count(), 1, "The client flies the same arrow")
	assert_false(client_root.get_node("Projectiles").get_child(0).is_multiplayer_authority(), "as a copy off the authority")
	await wait_seconds(1.0)
	assert_eq(_ice_blocks_under(server_root).size(), 1, "The host has the slab")
	assert_eq(_ice_blocks_under(client_root).size(), 1, "The client got the same slab through the spawner, one only: its own copy of the arrow froze nothing")
	assert_eq(get_tree().get_nodes_in_group(&"IceBlock").size(), 2, "Two slabs in all, one per peer")
	assert_eq(server_root.get_node("Projectiles").get_child_count(), 1, "Both arrows were spent on the ice")
	assert_eq(client_root.get_node("Projectiles").get_child_count(), 1)
	var host_block: IceBlock = _ice_blocks_under(server_root)[0]
	var client_block: IceBlock = _ice_blocks_under(client_root)[0]
	assert_almost_eq(client_block.global_position, host_block.global_position, Vector3.ONE * 0.01, "at the same spot")


func test_the_hosts_fire_arrow_lights_the_grass_on_every_peer() -> void:
	var field: GrassField = GRASS_FIELD_SCENE.instantiate()
	field.ground_group = &"" # Flat: these tests light grass, they are not about the ground under it
	field.field_size = Vector2(20.0, 20.0)
	field.instance_count = 400
	world.add_child(field)
	var spy := GrassSpy.new()
	spy.add_to_group(&"BurnableGrass")
	world.add_child(spy)
	spy.global_position = Vector3(0.5, 0.0, 0.0)
	await wait_physics_frames(2)
	var spawner: ProjectileSpawner = server_root.get_node("ProjectileSpawner")
	var shooter := StaticBody3D.new() # a body, so the round can hold its shooter exception; the client resolves it too
	server_root.add_child(shooter)
	var arrow: Projectile = spawner.fire(FIRE_ARROW_SCENE, Transform3D(Basis(), Vector3(0.0, 3.0, 0.0)), Vector3.DOWN, 30.0, shooter)
	assert_not_null(arrow)
	await wait_seconds(1.0)
	assert_gt(field._burning_cells.size(), 0, "The grass under the impact is alight")
	assert_eq(spy.ignitions, 2, "Lit once by the host's own call and once by the client receiving the RPC; the client's copy of the arrow lit nothing on its own")


## A Node3D named [param node_name] in both branches, owned by [param owner_id] on both, as a Player is.
func _in_both(node_name: String, owner_id: int) -> void:
	for root: Node3D in [server_root, client_root]:
		var node := Node3D.new()
		node.name = node_name
		node.set_multiplayer_authority(owner_id)
		root.add_child(node)


## H15: the client casts Lightning; the server strikes on every peer for a caster the client owns, and refuses one
## cast in the host's name, which the old direct RPC on the LightningFX would have struck anyway.
func test_a_clients_lightning_strikes_on_every_peer_and_only_in_its_own_name() -> void:
	_in_both("Caster", client_api.get_unique_id())
	_in_both("HostCaster", 1)
	_in_both("Target", 1)
	var server_bolt: LightningFX = server_root.get_node("LightningFX")
	var client_bolt: LightningFX = client_root.get_node("LightningFX")
	watch_signals(server_bolt)
	watch_signals(client_bolt)
	var target: Node3D = client_root.get_node("Target")
	LIGHTNING.impact(client_root.get_node("HostCaster"), target)
	await wait_process_frames(20)
	assert_signal_not_emitted(server_bolt, "struck", "A bolt in the host's name is refused")
	assert_signal_not_emitted(client_bolt, "struck", "on every peer")
	LIGHTNING.impact(client_root.get_node("Caster"), target)
	assert_true(await wait_until(func() -> bool: return get_signal_emit_count(client_bolt, "struck") > 0, 2.0), "The client's own bolt comes back to it")
	assert_signal_emit_count(server_bolt, "struck", 1, "The server strikes for the client")
	assert_signal_emit_count(client_bolt, "struck", 1, "and every peer sees it once")


## H15: the client's Chain Lightning jumps on its own peer and each jump's arc is drawn on every peer by the server.
func test_a_clients_chain_lightning_arcs_on_every_peer() -> void:
	_in_both("Caster", client_api.get_unique_id())
	var first := Enemy.new()
	var second := Enemy.new()
	for enemy: Enemy in [first, second]:
		enemy.add_to_group(&"Focusable")
		client_root.add_child(enemy)
	second.position = Vector3(3.0, 0.0, 0.0)
	var server_bolt: LightningFX = server_root.get_node("LightningFX")
	var client_bolt: LightningFX = client_root.get_node("LightningFX")
	var arcs: Dictionary = {server_bolt: 0, client_bolt: 0}
	for bolt: LightningFX in [server_bolt, client_bolt]:
		bolt.child_entered_tree.connect(func(_child: Node) -> void: arcs[bolt] += 1)
	CHAIN.impact(client_root.get_node("Caster"), first)
	assert_eq(second.hits, 1, "The chain jumps to the second enemy")
	assert_true(await wait_until(func() -> bool: return arcs[client_bolt] > 0, 2.0), "The arc comes back to the client")
	assert_eq(arcs[server_bolt], 1, "The server draws the jump")
	assert_eq(arcs[client_bolt], 1, "and so does the client, once")


## H1: a round the client fires is spawned by the server, and the server's copy alone lands it; the beach ball it
## bursts and the balloon it pops go on the client as well.
func test_a_clients_round_bursts_the_ball_and_pops_the_balloon_on_every_peer() -> void:
	var balls: Array[BeachBall] = []
	var balloons: Array[RedBalloon] = []
	for root: Node3D in [server_root, client_root]:
		var shooter := StaticBody3D.new() # the client's Player, as far as the spawner is concerned
		shooter.name = "Shooter"
		shooter.set_multiplayer_authority(client_api.get_unique_id())
		root.add_child(shooter)
		var ball: BeachBall = BALL_SCENE.instantiate()
		ball.name = "BeachBall"
		ball.position = Vector3(-5.0, 0.6, 0.0)
		root.add_child(ball)
		balls.append(ball)
		var balloon: RedBalloon = BALLOON_SCENE.instantiate()
		balloon.name = "RedBalloon"
		balloon.position = Vector3(5.0, 3.0, 0.0)
		root.add_child(balloon)
		balloons.append(balloon)
	# Both branches share one physics space; the client's copies must not stand in the rounds' way
	balls[1].collision_layer = 0
	balls[1].collision_mask = 0
	balloons[1].hit_detection.collision_layer = 0
	await wait_physics_frames(10)
	watch_signals(balls[1])
	var spawner: ProjectileSpawner = client_root.get_node("ProjectileSpawner")
	var shooter: Node3D = client_root.get_node("Shooter")
	for target: Node3D in [balls[0], balloons[0]]:
		var origin: Transform3D = Transform3D(Basis(), target.global_position + Vector3.UP * 3.0)
		assert_null(spawner.fire(BULLET_SCENE, origin, Vector3.DOWN, 40.0, shooter), "A client's round comes back through the spawner")
	assert_true(await wait_until(func() -> bool: return balls[1].is_deflated and balloons[1].is_popped, 3.0), "The client's ball bursts and its balloon pops")
	assert_true(balls[0].is_deflated, "because the server's did")
	assert_true(balloons[0].is_popped)
	assert_signal_emit_count(balls[1], "deflated", 1, "once")

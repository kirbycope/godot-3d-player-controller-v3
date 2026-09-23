extends GutTest

## Purpose: the server owns the fish shadows. A real ENet client sees the server's shadows where the server has them,
## shown or hidden alike, and runs no wander of its own; a round the client fires at the fish it sees is the server's
## to land, and it finds that same fish, which sinks on both peers; and a client's rod drawing a shadow to its float
## and sending it diving moves the shadow the client sees. Each branch sits in a SubViewport with its own physics
## world, as two machines would, so a round can only ever find its own peer's fish.

const PORT: int = 47441
const BULLET: PackedScene = preload("res://addons/3d_player_controller/scenes/projectile/bullet.tscn")
const POOL_MATERIAL: Material = preload("res://resources/pool_water_material.tres")
const PROJECTILE_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/projectile_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## A branch in its own SubViewport, so its physics world is its own.
func _add_branch(branch_name: String) -> Node3D:
	var view := SubViewport.new()
	view.own_world_3d = true
	add_child_autofree(view)
	var root := Node3D.new()
	root.name = branch_name
	view.add_child(root)
	return root


## A ProjectileSpawner and a 10 m pool at the origin with three shadows, at the same paths on both sides as the
## world's are.
func _build_branch(root: Node3D) -> void:
	var projectile_spawner: ProjectileSpawner = PROJECTILE_SPAWNER.new()
	projectile_spawner.name = "ProjectileSpawner"
	projectile_spawner.add_spawnable_scene(BULLET.resource_path)
	root.add_child(projectile_spawner)
	var water := Buoyancy.new()
	water.name = "Water"
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
	water.position = Vector3(0.0, -2.0, 0.0)
	root.add_child(water)
	var shadows := FishShadows.new()
	shadows.name = "FishShadows"
	shadows.water = water
	shadows.count = 3
	water.shadows = shadows
	root.add_child(shadows)


func before_each() -> void:
	server_root = _add_branch("ServerBranch")
	client_root = _add_branch("ClientBranch")
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
	await wait_until(func() -> bool: return client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0, 2.0)
	assert_gt(client_api.get_peers().size(), 0, "Client should connect to the loopback server")
	await wait_process_frames(10)


func after_each() -> void:
	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


## Each client shadow is within [param tolerance] of the server's one of the same name, and shown or hidden alike.
func _assert_client_matches(host_shadows: FishShadows, client_shadows: FishShadows, tolerance: float, context: String) -> void:
	for i in host_shadows.shadows.size():
		var host_fish: MeshInstance3D = host_shadows.shadows[i]
		var client_fish: MeshInstance3D = client_shadows.shadows[i]
		assert_eq(client_fish.name, host_fish.name, "The same shadow on both peers")
		assert_almost_eq(client_fish.global_position, host_fish.global_position, Vector3.ONE * tolerance, "%s: %s is where the server has it" % [context, host_fish.name])
		assert_eq(client_fish.visible, host_fish.visible, "%s: %s shows as it does on the server" % [context, host_fish.name])


func test_the_client_sees_the_servers_shadows_where_the_server_has_them() -> void:
	var host_shadows: FishShadows = server_root.get_node("FishShadows")
	var client_shadows: FishShadows = client_root.get_node("FishShadows")
	assert_eq(client_shadows.shadows.size(), 3)
	var start: Vector3 = host_shadows.shadows[0].global_position
	_assert_client_matches(host_shadows, client_shadows, 0.1, "While they wander")
	await wait_process_frames(30)
	assert_gt(host_shadows.shadows[0].global_position.distance_to(start), 0.1, "The server's shadows swim about")
	_assert_client_matches(host_shadows, client_shadows, 0.1, "Half a second on")
	# Held still on the server, they hold still on the client: it wanders none of its own
	host_shadows.park_shadows_for_test(host_shadows.shadows[0], Vector3(1.0, 0.0, 1.0))
	host_shadows.shadows[2].hide()
	await wait_process_frames(30)
	_assert_client_matches(host_shadows, client_shadows, 0.001, "Parked")
	assert_false(client_shadows.shadows[2].visible, "A shadow hidden on the server is hidden on the client")


func test_a_round_the_client_fires_at_the_fish_it_sees_sinks_it_on_both_peers() -> void:
	var host_shadows: FishShadows = server_root.get_node("FishShadows")
	var client_shadows: FishShadows = client_root.get_node("FishShadows")
	# The client's own body, which the spawner insists the round belongs to. The request names it by absolute path,
	# which lands on this node on both sides here, as the branches share one tree
	var shooter := StaticBody3D.new()
	shooter.name = "Shooter"
	client_root.add_child(shooter)
	shooter.set_multiplayer_authority(client_api.get_unique_id())
	# The server holds its fish still at a spot the client learns only from the synchronizer
	var host_fish: MeshInstance3D = host_shadows.shadows[1]
	var seen: MeshInstance3D = client_shadows.shadows[1]
	host_shadows.park_shadows_for_test(host_fish, Vector3(2.0, 0.0, -1.5))
	await wait_until(func() -> bool: return seen.global_position.distance_to(host_fish.global_position) < 0.01, 2.0)
	watch_signals(host_shadows)
	watch_signals(client_shadows)
	var spawner: ProjectileSpawner = client_root.get_node("ProjectileSpawner")
	var origin: Transform3D = Transform3D(Basis(), seen.global_position + Vector3(0.0, 2.0, 0.0))
	assert_null(spawner.fire(BULLET, origin, Vector3.DOWN, 40.0, shooter), "The client's round is the server's to spawn")
	await wait_until(func() -> bool: return get_signal_emit_count(client_shadows, "shot") > 0, 2.0)
	assert_eq(get_signal_parameters(host_shadows, "shot"), [host_fish], "The server's round finds the fish the client aimed at")
	assert_signal_emit_count(client_shadows, "shot", 1, "and the client hears of it once")
	assert_eq(get_signal_parameters(client_shadows, "shot"), [seen], "for the fish it saw")
	await wait_until(func() -> bool: return not seen.visible, 2.0)
	assert_false(host_fish.visible, "The fish sinks on the server")
	assert_false(seen.visible, "and on the client")


## What a client's rod sends when its float lands and then when the fish bites: the server moves its shadow, and the
## client sees that shadow swim up beside the float and dive out of sight.
func test_a_clients_rod_draws_the_shadow_it_sees_and_sends_it_diving() -> void:
	var host_shadows: FishShadows = server_root.get_node("FishShadows")
	var client_shadows: FishShadows = client_root.get_node("FishShadows")
	var float_at: Vector3 = Vector3(-1.0, 0.0, 1.0)
	host_shadows.park_shadows_for_test(host_shadows.shadows[0], float_at + Vector3(1.5, 0.0, 0.0))
	var lured: MeshInstance3D = client_shadows.shadows[0]
	client_shadows.attract.rpc_id(1, float_at, 2.0)
	await wait_until(func() -> bool: return lured.global_position.distance_to(float_at) < 0.6, 3.0)
	assert_eq(host_shadows.interested, host_shadows.shadows[0], "The server's shadow by the float takes an interest")
	assert_lt(lured.global_position.distance_to(float_at), 0.6, "and the client sees it swim up beside the float")
	client_shadows.dive.rpc_id(1, float_at)
	await wait_until(func() -> bool: return not lured.visible, 2.0)
	assert_null(host_shadows.interested, "The bite sends it diving")
	assert_false(host_shadows.shadows[0].visible, "out of sight on the server")
	assert_false(lured.visible, "and on the client")

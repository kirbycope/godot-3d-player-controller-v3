extends GutTest

## Purpose: A float fired through the ProjectileSpawner on the host appears on a real ENet client with the
## caster as its shooter, draws its own line there, and the host's plunge and catch RPCs reach the client.

const PORT: int = 47392
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BOBBER_SCENE: PackedScene = preload("res://scenes/bobber.tscn")
const CARP_PATH: String = "res://resources/fish/carp.tres"
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
	player_spawner.player_scene = PLAYER_SCENE
	root.add_child(player_spawner)
	var projectile_spawner: ProjectileSpawner = PROJECTILE_SPAWNER.new()
	projectile_spawner.name = "ProjectileSpawner"
	projectile_spawner.spawn_path = NodePath("../Projectiles")
	root.add_child(projectile_spawner)


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

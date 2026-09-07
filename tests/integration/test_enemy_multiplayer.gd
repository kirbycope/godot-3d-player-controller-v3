extends GutTest

## Purpose: an enemy's shot on the host flashes its muzzle on the client too. EnemyNpc._fire runs on the NPC's
## authority (the server); the round reaches the client through the ProjectileSpawner and the `fired` signal by RPC,
## so each peer's MuzzleFlash plays from its own copy. Two scene branches with their own MultiplayerAPI talk over
## ENet on localhost, as test_multiplayer_spawning does.

const PORT: int = 47394
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const RIFLEMAN_SCENE: PackedScene = preload("res://scenes/enemy_rifleman.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const PROJECTILE_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/projectile_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## Builds one branch: Players + PlayerSpawner, Projectiles + ProjectileSpawner, and a rifleman at its post.
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
	projectile_spawner.add_to_group(&"ProjectileSpawner") # As the world's scene node is, so the enemy finds it
	root.add_child(projectile_spawner)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var rifleman: EnemyNpc = RIFLEMAN_SCENE.instantiate()
	rifleman.name = "Rifleman"
	enemies.add_child(rifleman)
	rifleman.global_position = Vector3(0.0, 0.0, 10.0) # Faces -Z, toward the Player spawned at the origin


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


func after_each() -> void:
	# Free the branches while their APIs still exist so synchronizers and spawners unregister cleanly
	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


func test_a_shot_on_the_host_flashes_the_muzzle_on_the_client() -> void:
	await wait_process_frames(30)
	var host: EnemyNpc = server_root.get_node("Enemies/Rifleman")
	var remote: EnemyNpc = client_root.get_node("Enemies/Rifleman")
	var remote_flash: MuzzleFlash = remote.get_node("Muzzle/MuzzleFlash")
	assert_true(host.is_multiplayer_authority(), "The server owns the enemy")
	assert_false(remote.is_multiplayer_authority(), "The client only mirrors it")
	assert_false(remote_flash.vfx.visible, "Nothing shows before the shot")
	host.target = server_root.get_node("Players/1")
	var host_shots: Array[Projectile] = []
	host.fired.connect(func(projectile: Projectile) -> void: host_shots.append(projectile))
	var remote_shots: Array[Projectile] = []
	remote.fired.connect(func(projectile: Projectile) -> void: remote_shots.append(projectile))
	# The client's round can land on its Player and free itself within the wait, so note it as it arrives
	var client_rounds: Array[Node] = []
	client_root.get_node("Projectiles").child_entered_tree.connect(func(round: Node) -> void: client_rounds.append(round))
	var bullet: Projectile = host._fire()
	assert_not_null(bullet, "The host's spawner hands the round back")
	assert_eq(host_shots, [bullet] as Array[Projectile], "fired carries the round on the authority")
	await wait_process_frames(10)
	assert_eq(remote_shots, [null] as Array[Projectile], "The client's copy fires too, without a round of its own")
	assert_true(remote_flash.vfx.visible, "The client sees the flash")
	assert_eq(client_rounds.size(), 1, "And the round arrives through the spawner")
	assert_eq(host_shots.size(), 1, "The client's flash never echoes back to the host")

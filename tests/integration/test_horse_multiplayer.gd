extends GutTest

## Purpose: a whistle on the client brings the server's horse, and the client's copy follows it. Horse.summon on a
## copy that is not the authority relays the request to the authority by RPC; the summon movement runs there and the
## horse's BodySynchronizer carries its transform, pace and summon state back, so the client's copy arrives too and
## plays SummonAudio. Getting on hands the horse to the rider's peer and getting off hands it back. Two scene
## branches with their own MultiplayerAPI talk over ENet on localhost, as test_enemy_multiplayer does.

const PORT: int = 47395
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const HORSE_SCENE: PackedScene = preload("res://scenes/horse.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## Builds one branch: a floor, Players + PlayerSpawner, and the horse 10 m from where the Players spawn.
func _build_branch(root: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(200.0, 1.0, 200.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var players := Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var player_spawner: PlayerSpawner = PLAYER_SPAWNER.new()
	player_spawner.name = "PlayerSpawner"
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.player_scene = PLAYER_SCENE
	root.add_child(player_spawner)
	var horse: Horse = HORSE_SCENE.instantiate()
	horse.name = "Horse"
	root.add_child(horse)
	horse.global_position = Vector3(0.0, 0.05, 10.0)


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
	# Both branches share one physics space; the client's mirror must not stand in the server's horse's way
	var mirror: Horse = client_root.get_node("Horse")
	mirror.collision_layer = 0
	mirror.collision_mask = 0
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


func _wait_for_node(root: Node, path: String) -> Node:
	for i: int in 120:
		var node: Node = root.get_node_or_null(path)
		if node:
			return node
		await wait_process_frames(1)
	return null


## The client's Player, spawned on both branches. Every other Player copy in the shared physics space (the server's
## own Player and the mirrors) has its collision turned off, or a copy sitting inside its authority would shove it
## about each frame and the mirror would follow it over the network, without end.
func _client_player() -> Player:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _wait_for_node(client_root, "Players/%d" % client_id)
	await _wait_for_node(server_root, "Players/%d" % client_id)
	for branch: Node3D in [server_root, client_root]:
		for copy: Node in branch.get_node("Players").get_children():
			if copy != client_player:
				(copy as Player).collision_layer = 0
				(copy as Player).collision_mask = 0
	return client_player


func test_a_whistle_on_the_client_brings_the_servers_horse_and_the_clients_copy_follows() -> void:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _client_player()
	assert_not_null(client_player, "The client's Player spawned on the client")
	await wait_physics_frames(20) # everything settles onto the floor
	var host_horse: Horse = server_root.get_node("Horse")
	var remote_horse: Horse = client_root.get_node("Horse")
	assert_true(host_horse.is_multiplayer_authority(), "The server owns the horse")
	assert_false(remote_horse.is_multiplayer_authority(), "The client only mirrors it")
	watch_signals(remote_horse)
	remote_horse.summon(client_player) # what the client's whistle does through Horse.summon_nearest
	await wait_physics_frames(10)
	assert_eq(host_horse.summon_state, Horse.SummonState.COMING, "The request reached the authority")
	assert_eq(host_horse.summoner, server_root.get_node("Players/%d" % client_id), "aimed at the server's copy of the whistler")
	assert_eq(remote_horse.summon_state, Horse.SummonState.COMING, "and the state replicated back")
	for i: int in 600:
		await get_tree().physics_frame
		if remote_horse.summon_state == Horse.SummonState.ARRIVED:
			break
	assert_eq(host_horse.summon_state, Horse.SummonState.ARRIVED, "The server's horse arrives")
	assert_eq(remote_horse.summon_state, Horse.SummonState.ARRIVED, "and so does the client's copy")
	assert_signal_emitted(remote_horse, "arrived")
	assert_true((remote_horse.get_node("SummonAudio") as AudioStreamPlayer3D).playing, "which calls out there too")
	await wait_physics_frames(5)
	assert_lt(remote_horse.global_position.distance_to(host_horse.global_position), 0.5, "The copy stands where the server's horse does")
	assert_lt(remote_horse.global_position.distance_to(client_player.global_position), host_horse.arrive_distance + 0.5, "beside the whistler")
	assert_almost_eq(remote_horse.speed, 0.0, 0.01, "The pace replicated with it")


func test_a_client_rider_takes_the_horse_with_them_and_hands_it_back_on_dismount() -> void:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _client_player()
	assert_not_null(client_player)
	await wait_physics_frames(20)
	var host_horse: Horse = server_root.get_node("Horse")
	var remote_horse: Horse = client_root.get_node("Horse")
	var host_sync: MultiplayerSynchronizer = host_horse.get_node("BodySynchronizer")
	client_player.mount(remote_horse)
	await wait_physics_frames(10)
	assert_eq(client_player.riding, remote_horse)
	assert_eq(remote_horse.get_multiplayer_authority(), client_id, "The rider's peer drives the horse")
	assert_eq(host_horse.get_multiplayer_authority(), client_id, "and the server agrees")
	assert_eq(host_sync.get_multiplayer_authority(), client_id, "synchronizer included")
	var start: Vector3 = host_horse.global_position
	for i: int in 90:
		client_player.player_input.motion = Vector2(0.0, 1.0)
		await get_tree().physics_frame
	client_player.player_input.motion = Vector2.ZERO
	assert_gt(host_horse.global_position.distance_to(start), 1.0, "The ride shows on the server")
	assert_gt(host_horse.speed, 0.0, "pace and all")
	client_player.dismount()
	await wait_physics_frames(10)
	assert_null(client_player.riding)
	assert_eq(remote_horse.get_multiplayer_authority(), 1, "Off again, the server has the horse back")
	assert_eq(host_horse.get_multiplayer_authority(), 1)
	assert_eq(host_sync.get_multiplayer_authority(), 1)

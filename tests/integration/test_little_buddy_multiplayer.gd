extends GutTest

## Purpose: a client carrying the buddy owns it while it is in their hands. Picking it up hands its authority (and
## so its synchronizer) to the carrier's peer and puts every copy on that Player's spring arm, so the server's copy
## rides along instead of writing its old position back; dropping it hands it back to the server and puts every
## copy back into the scene. Two scene branches with their own MultiplayerAPI talk over ENet on localhost, as
## test_horse_multiplayer does.

const PORT: int = 47399
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BUDDY_SCENE: PackedScene = preload("res://scenes/little_buddy.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## Builds one branch: a floor, Players + PlayerSpawner, and the buddy 6 m from where the Players spawn.
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
	var buddy: CharacterBody3D = BUDDY_SCENE.instantiate() as CharacterBody3D
	buddy.name = "LittleBuddy"
	root.add_child(buddy)
	buddy.global_position = Vector3(0.0, 0.05, 6.0)


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
	# Both branches share one physics space; the client's mirror must not stand in the server's buddy's way
	var mirror: CharacterBody3D = client_root.get_node("LittleBuddy")
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


func test_a_client_carrier_takes_the_buddy_with_them_and_hands_it_back_on_drop() -> void:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _client_player()
	assert_not_null(client_player, "The client's Player spawned on the client")
	await wait_physics_frames(20) # everything settles onto the floor
	var host_buddy: CharacterBody3D = server_root.get_node("LittleBuddy")
	var remote_buddy: CharacterBody3D = client_root.get_node("LittleBuddy")
	var host_sync: MultiplayerSynchronizer = host_buddy.get_node("BodySynchronizer")
	var carrier_on_host: Player = server_root.get_node("Players/%d" % client_id)
	host_buddy.player = server_root.get_node("Players/1") # so a drop puts it back into the server's branch
	assert_true(host_buddy.is_multiplayer_authority(), "The server owns the buddy")
	assert_false(remote_buddy.is_multiplayer_authority(), "The client only mirrors it")

	remote_buddy.player = client_player # what looking at it does
	remote_buddy.pick_up()
	await wait_physics_frames(10)
	assert_true(remote_buddy.is_held)
	assert_eq(remote_buddy.get_multiplayer_authority(), client_id, "The carrier's peer owns the buddy")
	assert_eq(host_buddy.get_multiplayer_authority(), client_id, "and the server agrees")
	assert_eq(host_sync.get_multiplayer_authority(), client_id, "synchronizer included")
	assert_eq(remote_buddy.get_parent(), client_player.item_spring_arm, "On the carrier's arm")
	assert_eq(host_buddy.get_parent(), carrier_on_host.item_spring_arm, "and on the server's copy of the carrier's arm")
	assert_true(host_buddy.collision_shape.disabled, "Carried, it bumps nothing on the server either")
	assert_lt(host_buddy.global_position.distance_to(carrier_on_host.global_position), 4.0, "The server's copy is in the carrier's hands, not 6 m off where it stood")

	remote_buddy.drop()
	await wait_physics_frames(10)
	assert_false(remote_buddy.is_held)
	assert_eq(remote_buddy.get_multiplayer_authority(), 1, "Dropped, the server has the buddy back")
	assert_eq(host_buddy.get_multiplayer_authority(), 1)
	assert_eq(host_sync.get_multiplayer_authority(), 1)
	assert_ne(host_buddy.get_parent(), carrier_on_host.item_spring_arm, "and off the arm on the server")
	assert_false(host_buddy.collision_shape.disabled)
	for buddy: Node in [host_buddy, remote_buddy]:
		if not server_root.is_ancestor_of(buddy) and not client_root.is_ancestor_of(buddy):
			buddy.free() # a drop returns to the current scene, which the test runner has none of

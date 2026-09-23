extends GutTest

## Purpose: the boat's one seat is the server's to give. A client's Action asks the server; the first Player to ask
## gets it and sits, and a second asking while it is taken is refused. The server's `occupant_peer` reaches every
## peer through the boat's SeatSynchronizer, whose setter hides the dummy passenger while a real Player sits there,
## and standing up or leaving the game frees the seat. Two scene branches with their own MultiplayerAPI talk over ENet
## on localhost, as test_horse_multiplayer does.

const PORT: int = 47431
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BOAT_SCENE: PackedScene = preload("res://scenes/boat.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")

var server_root: Node3D
var client_root: Node3D
var client_path: NodePath
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## Builds one branch: a floor, Players + PlayerSpawner, and the boat 4 m from where the Players spawn.
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
	player_spawner.add_child(PLAYER_SCENE.instantiate()) # the template every peer's player is a copy of
	root.add_child(player_spawner)
	var boat: Node3D = BOAT_SCENE.instantiate()
	boat.name = "Boat"
	root.add_child(boat)
	boat.global_position = Vector3(0.0, 0.3, 4.0)


func before_each() -> void:
	server_root = Node3D.new()
	server_root.name = "ServerBranch"
	client_root = Node3D.new()
	client_root.name = "ClientBranch"
	add_child(server_root)
	add_child(client_root)
	client_path = client_root.get_path()
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
	# Both branches share one physics space; the client's copy of the boat must not stand in the way
	var mirror: AnimatableBody3D = client_root.get_node("Boat")
	mirror.collision_layer = 0
	mirror.collision_mask = 0
	for i in 120:
		await wait_process_frames(1)
		if client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0:
			break
	assert_gt(client_api.get_peers().size(), 0, "Client should connect to the loopback server")


func after_each() -> void:
	# Free the branches while their APIs still exist so synchronizers and spawners unregister cleanly; a test where
	# the client quits has freed its branch already
	var server_path: NodePath = server_root.get_path()
	server_root.free()
	if is_instance_valid(client_root):
		client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


## The client's Player, spawned on both branches, with every other copy's collision off so no copy shoves another.
func _client_player() -> Player:
	var client_id: int = client_api.get_unique_id()
	var own_path: String = "Players/" + str(client_id)
	await wait_until(func() -> bool: return client_root.has_node(own_path) and server_root.has_node(own_path), 2.0)
	var client_player: Player = client_root.get_node(own_path)
	for branch: Node3D in [server_root, client_root]:
		for copy: Node in branch.get_node("Players").get_children():
			if copy != client_player:
				(copy as Player).collision_layer = 0
				(copy as Player).collision_mask = 0
	return client_player


## Action on [param boat], the way the keyboard gives it while [param player] looks at it.
func _press_action_at(boat: Node, player: Player) -> void:
	boat.display_menu(player)
	var press := InputEventAction.new()
	press.action = "action"
	press.pressed = true
	boat._input(press)


func test_the_first_player_to_ask_gets_the_seat_and_every_peer_sees_them_in_it() -> void:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _client_player()
	var host_player: Player = server_root.get_node("Players/1")
	await wait_physics_frames(10)
	var host_boat: Node3D = server_root.get_node("Boat")
	var remote_boat: Node3D = client_root.get_node("Boat")
	assert_true(host_boat.seat_01_dummy.visible, "An empty seat shows the dummy passenger")
	_press_action_at(remote_boat, client_player)
	await wait_until(func() -> bool: return client_player.is_sitting, 2.0)
	assert_true(client_player.is_sitting, "The server gives the client the seat, and it sits down")
	assert_eq(host_boat.occupant_peer, client_id, "The server knows who sits there")
	await wait_until(func() -> bool: return remote_boat.occupant_peer == client_id, 2.0)
	assert_eq(remote_boat.occupant_peer, client_id, "and the seat replicates")
	assert_false(host_boat.seat_01_dummy.visible, "Nobody sees the dummy inside the real Player: not the server")
	assert_false(remote_boat.seat_01_dummy.visible, "nor the client")
	_press_action_at(host_boat, host_player)
	await wait_physics_frames(10)
	assert_false(host_player.is_sitting, "A second Player asking for the taken seat is refused")
	assert_eq(host_boat.occupant_peer, client_id, "and the seat stays the first one's")
	client_player.state_machine.travel(NodeStateMachine.States.SITTING, NodeStateMachine.States.STANDING)
	await wait_until(func() -> bool: return remote_boat.occupant_peer == 0, 2.0)
	assert_eq(host_boat.occupant_peer, 0, "Standing up frees the seat on the server")
	assert_eq(remote_boat.occupant_peer, 0, "and everywhere")
	assert_true(host_boat.seat_01_dummy.visible, "The dummy passenger is back")
	assert_true(remote_boat.seat_01_dummy.visible)
	_press_action_at(host_boat, host_player)
	await wait_physics_frames(2)
	assert_true(host_player.is_sitting, "The free seat takes the next Player who asks")


func test_a_seated_player_who_leaves_the_game_frees_the_seat() -> void:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _client_player()
	await wait_physics_frames(10)
	var host_boat: Node3D = server_root.get_node("Boat")
	_press_action_at(client_root.get_node("Boat"), client_player)
	await wait_until(func() -> bool: return host_boat.occupant_peer == client_id, 2.0)
	assert_eq(host_boat.occupant_peer, client_id)
	client_root.free() # the client quits
	client_api.multiplayer_peer.close()
	await wait_until(func() -> bool: return host_boat.occupant_peer == 0, 2.0)
	assert_eq(host_boat.occupant_peer, 0, "The leaver's seat is free again")
	assert_true(host_boat.seat_01_dummy.visible)

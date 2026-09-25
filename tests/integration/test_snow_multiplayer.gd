extends GutTest

## Purpose: snow deformation across peers. The deformation texture is never sent anywhere; every peer
## derives it from positions that are already replicated, so the questions worth asking are whether a
## peer's window follows its own Player rather than a stranger's, and whether a Player somebody else
## is driving still leaves tracks on this screen. Two scene branches with their own MultiplayerAPI
## talk over ENet on localhost, as test_horse_multiplayer does.
##
## The compute passes are off here, because a headless run has no RenderingDevice. That is the point:
## everything below is the CPU half, which decides what would be carved, and it runs either way.
## `stamps_this_frame` counts what was handed in whether or not a GPU took it.

const PORT: int = 47411
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const SNOW: GDScript = preload("res://addons/snow_deformation/snow_deformation.gd")
const FOOT_STAMPER: GDScript = preload("res://addons/snow_deformation/foot_stamper.gd")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## One peer's whole world: a floor, the Players and their spawner, and a SnowDeformation over it.
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
	# The template is left exactly as it comes. PlayerSpawner spawns by duplicating it, and a child
	# added here makes that duplication fail outright; feet go on the spawned copies instead.
	player_spawner.add_child(PLAYER_SCENE.instantiate())
	root.add_child(player_spawner)
	var snow: SnowDeformation = SNOW.new()
	snow.name = "SnowDeformation"
	snow.create_surface = false # No mesh or shader is needed to ask what would be carved.
	snow.press_bodies = false # The Players are the subject here, and they stamp for themselves.
	snow.snow_depth = 0.35
	root.add_child(snow)


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


## Both Players, on both branches, with every copy but the client's own taken out of the shared physics
## space so the copies do not shove each other about.
func _settle() -> Dictionary:
	var client_id: int = client_api.get_unique_id()
	var client_player: Player = await _wait_for_node(client_root, "Players/%d" % client_id)
	var mirror: Player = await _wait_for_node(server_root, "Players/%d" % client_id)
	for branch: Node3D in [server_root, client_root]:
		for copy: Node in branch.get_node("Players").get_children():
			if copy != client_player:
				(copy as Player).collision_layer = 0
				(copy as Player).collision_mask = 0
			_give_feet(copy as Player)
	await wait_physics_frames(20)
	return {"id": client_id, "player": client_player, "mirror": mirror}


## Every Player copy on every branch gets feet of its own. That is the whole point: each peer stamps
## every Player it can see locally, so no track ever has to cross the network.
func _give_feet(player: Player) -> void:
	if player.get_node_or_null("FootStamper") != null:
		return
	var stamper: Node = FOOT_STAMPER.new()
	stamper.name = "FootStamper"
	stamper.skeleton_path = NodePath("../PlayerModel/Armature/GeneralSkeleton")
	stamper.sole_offset = 0.0
	player.add_child(stamper)


func test_each_peers_window_follows_its_own_player_not_the_other_ones() -> void:
	var settled: Dictionary = await _settle()
	var client_player: Player = settled["player"]
	var client_snow: SnowDeformation = client_root.get_node("SnowDeformation")
	var server_snow: SnowDeformation = server_root.get_node("SnowDeformation")
	# Both branches hold a Player for each peer, so "the first one in the group" is a coin toss.
	client_snow.call("_resolve_focus")
	server_snow.call("_resolve_focus")
	assert_eq(client_snow.get("_focus"), client_player, "The client's window follows the Player the client drives")
	var server_focus: Node3D = server_snow.get("_focus")
	assert_not_null(server_focus, "The server's window found a Player")
	assert_true(server_focus.is_multiplayer_authority(), "and it is the one the server drives, not the client's copy")
	assert_ne(server_focus, settled["mirror"], "specifically not the client's mirror sitting in the server's branch")


func test_a_player_another_peer_drives_still_leaves_tracks_on_this_screen() -> void:
	var settled: Dictionary = await _settle()
	var client_player: Player = settled["player"]
	var mirror: Player = settled["mirror"]
	assert_false(mirror.is_multiplayer_authority(), "The server's copy of the client's Player is not the server's to drive")

	var server_snow: SnowDeformation = server_root.get_node("SnowDeformation")
	# Only the client's Player is put in the snow; the server's own is lifted clear, so anything the
	# server's branch stamps can only have come from the copy of somebody else's Player.
	var server_player: Player = server_root.get_node("Players/%d" % server_api.get_unique_id())
	server_player.global_position = Vector3(0.0, 40.0, 0.0)
	client_player.global_position = Vector3(3.0, 0.0, 3.0)
	await wait_physics_frames(10)

	# stamps_last_frame rather than stamps_this_frame: the manager zeroes the live counter the moment
	# it hands a frame's stamps to the GPU, in _process, so a physics loop reading it races that and
	# sees zero however much is being carved. The carried-over count is what a readout is meant to use.
	# stamps_total, not the per-frame counters: those are zeroed the moment a frame is uploaded, and
	# _process runs several times between two physics frames, so a physics loop sampling them races
	# the reset and reads zero however much is actually being carved.
	var before: int = server_snow.stamps_total
	for i in 40:
		await wait_physics_frames(1)
	var carved_on_the_server: int = server_snow.stamps_total - before
	assert_gt(carved_on_the_server, 0, "The server's screen shows the tracks of the Player the client is driving")


func test_the_snow_costs_no_bandwidth() -> void:
	var server_snow: SnowDeformation = server_root.get_node("SnowDeformation")
	for child: Node in server_snow.get_children():
		assert_false(child is MultiplayerSynchronizer, "Nothing about the deformation is replicated")
	assert_false(server_snow.has_method("_rpc_stamp"), "and there is no RPC carrying stamps either: every peer derives the same texture from positions that are already on the wire")

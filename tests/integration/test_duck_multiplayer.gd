extends GutTest

## Purpose: the giant duck and its animation show on a client. The server's duck respawns as the giant and picks
## the walking or eating model; `is_giant`, `anim_state` and the health replicate through its BodySynchronizer, and
## their setters size the client's copy, show its knife and switch its model. Two scene branches with their own
## MultiplayerAPI talk over ENet on localhost, as test_horse_multiplayer does.

const PORT: int = 47398
const DUCK_SCENE: PackedScene = preload("res://scenes/duck.tscn")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


## Builds one branch: a floor and the duck standing on it.
func _build_branch(root: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(200.0, 1.0, 200.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	duck.name = "Duck"
	root.add_child(duck)
	duck.global_position = Vector3(0.0, 0.05, 0.0)


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
	# Both branches share one physics space; the client's mirror must not stand in the server's duck's way
	var mirror: CharacterBody3D = client_root.get_node("Duck")
	mirror.collision_layer = 0
	mirror.collision_mask = 0
	for i in 120:
		await wait_process_frames(1)
		if client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0:
			break
	assert_gt(client_api.get_peers().size(), 0, "Client should connect to the loopback server")


func after_each() -> void:
	# Free the branches while their APIs still exist so synchronizers unregister cleanly
	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


func test_the_giant_its_animation_and_its_health_reach_the_client() -> void:
	await wait_physics_frames(10)
	var host: CharacterBody3D = server_root.get_node("Duck")
	var remote: CharacterBody3D = client_root.get_node("Duck")
	assert_true(host.is_multiplayer_authority(), "The server owns the duck")
	assert_false(remote.is_multiplayer_authority(), "The client only mirrors it")
	assert_false(remote.is_giant)
	host.call("_respawn_as_giant")
	for i: int in 60:
		await wait_process_frames(1)
		if remote.is_giant:
			break
	assert_true(remote.is_giant, "The giant replicates")
	assert_eq(remote.idle_model.scale, Vector3.ONE * 10.0, "and the client's copy grows")
	assert_true(remote.knife.visible, "with the knife out")
	assert_eq(remote.health.max_health, host.giant_health, "and the giant's health")
	host.set_physics_process(false) # or the server's duck stands back to idle every frame
	host.anim_state = &"walk"
	for i: int in 60:
		await wait_process_frames(1)
		if remote.anim_state == &"walk":
			break
	assert_eq(remote.anim_state, &"walk", "The animation state replicates")
	assert_true(remote.walk_model.visible, "and the client's copy walks")
	assert_false(remote.idle_model.visible)
	assert_true(remote.animation_player_walk.is_playing())
	host.health.damage(10.0, host.global_position)
	for i: int in 60:
		await wait_process_frames(1)
		if remote.health.health < host.giant_health:
			break
	assert_eq(remote.health.health, host.health.health, "The health follows")

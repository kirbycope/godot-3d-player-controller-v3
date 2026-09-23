extends GutTest

## Purpose: the Guide's firewood can come from any of the world's choppable trees, and felling one credits the chop
## quest of the peer whose Player landed the felling hit and no one else's. Two copies of the world, each in a
## branch with its own MultiplayerAPI, talk over ENet on localhost as test_horse_multiplayer's branches do.

const PORT: int = 47412
const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const QA_QUEST: Quest = preload("res://resources/quests/qa_errand.tres")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer
var server_world: Node
var client_world: Node


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
	server_world = WORLD_SCENE.instantiate()
	server_root.add_child(server_world)
	client_world = WORLD_SCENE.instantiate()
	client_root.add_child(client_world)
	for i: int in 300:
		await wait_process_frames(1)
		if is_instance_valid(server_world.player) and is_instance_valid(client_world.player):
			break
	assert_not_null(client_world.player, "The client's Player spawned in the client's world")
	for world: Node in [server_world, client_world]:
		(world.player as Player).quest_log.start(QA_QUEST)


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


## Swings an axe in [param feller]'s hands at [param tree] until it falls; each swing asks the server.
func _fell(tree: Choppable, feller: Player) -> void:
	var axe: Equipment = autofree(Equipment.new())
	axe.can_log = true
	axe.player = feller
	for i: int in tree.hits_per_yield * tree.total_yields:
		tree.register_weapon_hit(axe)


func _server_tree(tree_name: String) -> Choppable:
	return server_world.get_node("Quaternius/" + tree_name) as Choppable


func _client_tree(tree_name: String) -> Choppable:
	return client_world.get_node("Quaternius/" + tree_name) as Choppable


func test_several_trees_count_toward_the_chop_quest() -> void:
	var trees: Array[Node] = server_world.get_node("Quaternius").get_children().filter(func(node: Node) -> bool: return node is Choppable)
	assert_gt(trees.size(), 1, "More than one tree can be felled for the Guide")
	for tree: Node in trees:
		assert_true(tree.is_connected(&"depleted", Callable(server_world, &"_on_tree_chopped")), "%s counts toward the quest" % tree.name)


func test_a_client_felling_a_tree_credits_only_the_client() -> void:
	var tree: Choppable = _client_tree("Tree02")
	_fell(tree, client_world.player)
	for i: int in 120:
		await wait_process_frames(1)
		if tree.is_spent:
			break
	await wait_process_frames(10) # the credit comes back from the server after the felling hit
	assert_true(_server_tree("Tree02").is_spent, "The server felled the tree on the client's hits")
	assert_true(tree.is_spent, "and the client sees it down")
	assert_eq((client_world.player as Player).inventory.count_of(tree.item), 1, "The log is in the client's own bag")
	assert_eq((server_world.player as Player).inventory.count_of(tree.item), 0, "and not the host's")
	assert_true((client_world.player as Player).quest_log.is_objective_done(QA_QUEST, &"chop_tree"), "The client landed the felling hit, so the client gets the firewood")
	assert_false((server_world.player as Player).quest_log.is_objective_done(QA_QUEST, &"chop_tree"), "The host did not")


func test_the_host_felling_a_tree_credits_only_the_host() -> void:
	var tree: Choppable = _server_tree("Tree03")
	_fell(tree, server_world.player)
	for i: int in 120:
		await wait_process_frames(1)
		if _client_tree("Tree03").is_spent:
			break
	await wait_process_frames(10)
	assert_true(_client_tree("Tree03").is_spent, "The client sees the host's tree come down")
	assert_true((server_world.player as Player).quest_log.is_objective_done(QA_QUEST, &"chop_tree"), "The host gets the firewood")
	assert_false((client_world.player as Player).quest_log.is_objective_done(QA_QUEST, &"chop_tree"), "A client watching it fall does not")


## The log's authority, the server, simulates the fall; the client's copy stays frozen under its BodySynchronizer
## and follows the server's log, rather than falling on its own.
func test_the_fallen_log_is_the_servers_on_every_peer() -> void:
	var host_log: RigidBody3D = _server_tree("Tree01").log_body
	var mirror_log: RigidBody3D = _client_tree("Tree01").log_body
	assert_true(mirror_log.get_node("BodySynchronizer") is SyncedBody, "The log carries a BodySynchronizer")
	mirror_log.collision_layer = 0 # both copies share one physics space; the mirror must not stand in the host log's way
	mirror_log.collision_mask = 0
	_fell(_server_tree("Tree01"), server_world.player)
	for i: int in 120:
		await wait_process_frames(1)
		if _client_tree("Tree01").is_spent:
			break
	assert_false(host_log.freeze, "The host's log falls")
	assert_true(mirror_log.freeze, "The client's log stays frozen for the replicated transform")
	await wait_until(func() -> bool: return host_log.linear_velocity.length() < 0.05 and host_log.angular_velocity.length() < 0.05, 6.0)
	await wait_process_frames(10) # the last of the fall crosses the wire
	assert_almost_eq(mirror_log.global_position, host_log.global_position, Vector3.ONE * 0.05, "and comes to rest where the host's log lies")

extends GutTest

## Purpose: Plushies ride inside their balloons while the circle spins and only start simulating once popped.

const CIRCLE_SCENE: PackedScene = preload("res://scenes/ballon_circle.tscn")
const BULLET_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/projectile/bullet.tscn")


func test_plushies_stay_inside_orbiting_balloons() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	add_child_autofree(circle)
	await wait_physics_frames(10)
	for balloon: RedBalloon in circle.get_node("Pivot").get_children():
		assert_eq(balloon.godot_plush.process_mode, Node.PROCESS_MODE_DISABLED, "%s plush must not simulate while carried" % balloon.name)
		assert_lt(balloon.godot_plush.global_position.distance_to(balloon.global_position), 0.5, "%s plush should ride with its balloon" % balloon.name)


func test_popping_releases_the_plush() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	add_child_autofree(circle)
	await wait_physics_frames(1)
	var balloon: RedBalloon = circle.get_node("Pivot/RedBallon")
	var plush: RigidBody3D = balloon.godot_plush
	var bullet: Projectile = BULLET_SCENE.instantiate()
	add_child_autofree(bullet)
	balloon.register_projectile_hit(bullet, balloon.global_position, Vector3.UP)
	await wait_physics_frames(1)
	assert_true(is_instance_valid(plush) and plush.is_inside_tree(), "Plush survives the pop")
	assert_eq(plush.process_mode, Node.PROCESS_MODE_INHERIT, "Popping re-enables the plush")
	assert_false(plush.freeze, "Popping unfreezes the plush on its authority")
	assert_true(plush.top_level, "and it stops turning with the ring")
	assert_true(is_instance_valid(balloon) and balloon.is_inside_tree(), "The balloon hides rather than frees, so its synchronizer stays")
	assert_true(balloon.is_popped)
	assert_false(balloon.visuals.visible, "The popped balloon is not drawn")
	assert_eq(balloon.hit_detection.process_mode, Node.PROCESS_MODE_DISABLED, "and its hit area is out of the physics space")


## A client's copy: the plush's SyncedBody froze it for the replicated transform, and a pop must not unfreeze it
## there, or local gravity fights the server's transforms. Setting is_popped is also what a late joiner receives.
func test_a_puppet_pop_leaves_the_plush_to_its_synchronizer() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	circle.set_multiplayer_authority(2) # a client's copy: the server owns the balloons and their plushies
	add_child_autofree(circle)
	await wait_physics_frames(1)
	var balloon: RedBalloon = circle.get_node("Pivot/RedBallon")
	assert_true(balloon.godot_plush.freeze, "SyncedBody froze the puppet plush")
	balloon.is_popped = true
	await wait_physics_frames(1)
	assert_false(balloon.visuals.visible, "The replicated pop hides the balloon")
	assert_eq(balloon.godot_plush.process_mode, Node.PROCESS_MODE_INHERIT, "and releases the plush")
	assert_true(balloon.godot_plush.freeze, "but leaves it frozen, driven by the server's transforms")
	assert_false(balloon.pop.playing, "A late joiner hears no pop")


func test_is_popped_is_replicated_for_late_joiners() -> void:
	var balloon: RedBalloon = load("res://scenes/red_ballon.tscn").instantiate()
	add_child_autofree(balloon)
	var sync: MultiplayerSynchronizer = balloon.get_node("PopSynchronizer")
	var config: SceneReplicationConfig = sync.replication_config
	assert_true(config.has_property(NodePath(".:is_popped")), "is_popped is replicated")
	assert_true(config.property_get_spawn(NodePath(".:is_popped")), "including to a peer joining later")


## Two branches with their own MultiplayerAPI over ENet on localhost: the server pops a balloon, then a client
## joins and finds it popped, with its plush frozen under the server's transforms.
func test_a_peer_joining_after_the_pop_sees_it_popped() -> void:
	const PORT: int = 47411
	var server_root := Node3D.new()
	server_root.name = "ServerBranch"
	var client_root := Node3D.new()
	client_root.name = "ClientBranch"
	add_child(server_root)
	add_child(client_root)
	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT), OK, "ENet server should open on localhost")
	server_api.multiplayer_peer = server_peer
	var host_circle: Node3D = CIRCLE_SCENE.instantiate()
	host_circle.name = "Circle"
	server_root.add_child(host_circle)
	await wait_physics_frames(1)
	var host_balloon: RedBalloon = host_circle.get_node("Pivot/RedBallon")
	host_balloon.pop_balloon()
	assert_true(host_balloon.is_popped, "The server pops its balloon before anyone joins")

	# The client's peer comes first, as in the game, so its copy knows from _ready that the server owns it
	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_api.multiplayer_peer = client_peer
	var late_circle: Node3D = CIRCLE_SCENE.instantiate()
	late_circle.name = "Circle"
	client_root.add_child(late_circle)
	var late_balloon: RedBalloon = late_circle.get_node("Pivot/RedBallon")
	for i: int in 120:
		await wait_process_frames(1)
		if late_balloon.is_popped:
			break
	assert_true(late_balloon.is_popped, "The late joiner receives the pop")
	assert_false(late_balloon.visuals.visible, "and sees no balloon")
	assert_true(late_balloon.godot_plush.freeze, "Its plush stays frozen for the server's transforms")
	assert_false((late_circle.get_node("Pivot/RedBallon2") as RedBalloon).is_popped, "The other balloons are still up")

	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


func test_the_ring_spins_by_default_and_hides_strings_by_path() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	add_child_autofree(circle)
	await wait_physics_frames(1)
	assert_true(circle.play, "The ring ships spinning")
	var before: float = circle.get_node("Pivot").rotation.z
	await wait_seconds(0.3)
	assert_ne(circle.get_node("Pivot").rotation.z, before, "The pivot turns")
	for balloon: Node3D in circle.get_node("Pivot").get_children():
		assert_false(balloon.get_node("Visuals/String").visible, "The world ring hides its strings")
	circle.show_balloon_string = true
	for balloon: Node3D in circle.get_node("Pivot").get_children():
		assert_true(balloon.get_node("Visuals/String").visible, "Toggling the export reaches every string by path")



func test_the_ring_spins_on_a_puppet_too() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	circle.set_multiplayer_authority(2) # a client's copy: the server owns the world
	add_child_autofree(circle)
	await wait_physics_frames(1)
	var before: float = circle.get_node("Pivot").rotation.z
	await wait_seconds(0.3)
	assert_ne(circle.get_node("Pivot").rotation.z, before, "Decoration spins on every peer, not only the authority")

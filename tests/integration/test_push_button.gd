extends GutTest

## Purpose: the push button (built in place in world.tscn, so the test builds the same nodes) reaches the Player's
## right hand out with IK along the ButtonPushing emote, presses down at the press ratio and lets go once the emote
## ends. The press goes to every peer, from a peer whose Player is at the button.

const PUSH_BUTTON_SCRIPT: Script = preload("res://scenes/push_button.gd")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const PROMPT_SCENE: PackedScene = preload("res://addons/controls/action_prompt.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const PORT: int = 47413


func _build_button() -> PushButton:
	var button: PushButton = PUSH_BUTTON_SCRIPT.new()
	var prompt: Node = PROMPT_SCENE.instantiate()
	prompt.name = "ActionPrompt"
	button.add_child(prompt)
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	library.add_animation("push", Animation.new())
	animation_player.add_animation_library("", library)
	button.add_child(animation_player)
	var ik_target := Marker3D.new()
	ik_target.name = "IKTarget"
	button.add_child(ik_target)
	return button


func test_action_reaches_out_presses_the_button_and_lets_go() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	var button: PushButton = _build_button()
	button.position = Vector3(0.0, 1.0, -1.0)
	root.add_child(button)
	await wait_physics_frames(5)
	button.display_menu(player)
	assert_true(button.action_prompt.visible, "Looking at it shows the prompt")
	button.equip(player)
	assert_true(button.is_pushing)
	assert_true(player.is_emoting, "Action plays the ButtonPushing emote")
	assert_true(player.right_hand_ik.active, "with the right hand reaching for the button")
	await wait_until(func() -> bool: return button.has_pressed, 4.0)
	assert_eq(button.animation_player.current_animation, "push", "The hand landing presses it")
	await wait_until(func() -> bool: return not button.is_pushing, 4.0)
	assert_false(button.is_pushing, "The emote over, the push is done")
	assert_false(player.right_hand_ik.active, "and the hand is let go")


## Two branches with their own MultiplayerAPI over ENet on localhost, as test_horse_multiplayer's: the client's press
## pushes the server's copy of the button down too, and a press from a peer whose Player is nowhere near is ignored.
func test_a_clients_press_goes_down_on_every_peer() -> void:
	var branches: Array[Node3D] = []
	var apis: Array[SceneMultiplayer] = []
	for branch_name: String in ["ServerBranch", "ClientBranch"]:
		var branch := Node3D.new()
		branch.name = branch_name
		add_child(branch)
		var api := SceneMultiplayer.new()
		get_tree().set_multiplayer(api, branch.get_path())
		branches.append(branch)
		apis.append(api)
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT), OK, "ENet server should open on localhost")
	apis[0].multiplayer_peer = server_peer
	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	apis[1].multiplayer_peer = client_peer
	for branch: Node3D in branches:
		var players := Node3D.new()
		players.name = "Players"
		branch.add_child(players)
		var player_spawner: PlayerSpawner = PLAYER_SPAWNER.new()
		player_spawner.name = "PlayerSpawner"
		player_spawner.spawn_path = NodePath("../Players")
		player_spawner.add_child(PLAYER_SCENE.instantiate())
		branch.add_child(player_spawner)
		var button: PushButton = _build_button()
		button.name = "PushButton"
		button.position = Vector3(0.0, 1.0, -1.0)
		branch.add_child(button)
	var client_id: int = apis[1].get_unique_id()
	for i: int in 120:
		await wait_process_frames(1)
		if branches[0].has_node("Players/%d" % client_id) and branches[1].has_node("Players/%d" % client_id):
			break
	assert_true(branches[0].has_node("Players/%d" % client_id), "The client's Player spawned on the server")
	var host_button: PushButton = branches[0].get_node("PushButton")
	var client_button: PushButton = branches[1].get_node("PushButton")

	client_button._press.rpc()
	await wait_until(func() -> bool: return host_button.animation_player.is_playing(), 2.0)
	assert_eq(client_button.animation_player.current_animation, "push", "The pusher sees the button go down")
	assert_eq(host_button.animation_player.current_animation, "push", "and so does the server")

	host_button.animation_player.stop()
	host_button.position = Vector3(0.0, 1.0, -40.0) # no Player of the client's stands anywhere near it now
	client_button._press.rpc()
	await wait_process_frames(20)
	assert_false(host_button.animation_player.is_playing(), "A press from a peer whose Player is not at the button is ignored")

	var paths: Array[NodePath] = [branches[0].get_path(), branches[1].get_path()]
	for branch: Node3D in branches:
		branch.free()
	server_peer.close()
	client_peer.close()
	for path: NodePath in paths:
		get_tree().set_multiplayer(null, path)

class_name SteamTest
extends GutTest
## Base of the two-machine Steam scenarios under tests/steam: one Godot on each PC running the same files in the
## same order, one as the lobby host and one as the client, in lockstep over [SteamTestSync]. Never part of the CI
## run: it needs two signed-in Steam clients and a real lobby between them, which tools/steam_test.py arranges.
##
## The environment says which side this is. STEAM_TEST_ROLE is "host" or "client" and STEAM_TEST_ID names the
## run, so the client can find this host's lobby among every other public Spacewar lobby by its "steam_test" lobby
## data. The session is built once, by the first scenario's before_all, and lives on the sync node under /root
## until the last scenario's after_all: GUT frees each test script once it has run, and a fresh lobby per file
## would repeat the slowest part of the run for every scenario.
##
## A scenario has an [code]if is_host:[/code] half and an [code]else:[/code] half and hands off between them with
## [method mark], [method await_step] and [method barrier]; every assertion sits on the side that observes the effect.

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const SYNC_NODE_NAME: String = "SteamTestSync"
const LOBBY_DATA_KEY: String = "steam_test" ## Lobby data the host tags its lobby with; the value is the run id.
## GodotSteam constant mirrors, as world.gd keeps them: the Steam class is absent on web exports.
const STEAM_LOBBY_COMPARISON_EQUAL: int = 0
const STEAM_LOBBY_DISTANCE_FILTER_WORLDWIDE: int = 3
const STEAM_CHAT_ROOM_ENTER_RESPONSE_SUCCESS: int = 1
const SESSION_TIMEOUT: float = 180.0 ## Seconds to find the lobby, and again for both Players to be spawned; the other machine may start late while its name is off the network.
const LOBBY_SEARCH_INTERVAL: float = 2.0 ## Seconds between the client's lobby list requests.
const STEP_TIMEOUT: float = 120.0 ## Seconds one side waits for the other at a step: a Steam relay stall of a minute between the machines has been seen, and the wait has to outlive it.
const RESYNC_TIMEOUT: float = 300.0 ## Seconds for the barriers that bring both sides back in step: a test's start, and the end of the run.
## Where each side's Player stands between scenarios: open ground west of the horse, clear of the tree, the ores,
## the weapon pickups and each other, so nothing a scenario left behind is standing in the next one's way.
const STAND_HOST: Vector3 = Vector3(-8.0, 0.2, 10.0)
const STAND_CLIENT: Vector3 = Vector3(-8.0, 0.2, 2.0)

var role: String = OS.get_environment("STEAM_TEST_ROLE")
var run_id: String = OS.get_environment("STEAM_TEST_ID")
var is_host: bool = role == "host"
var steam: Object ## The Steam singleton.
var steamworks: Node ## The /root/Steamworks autoload.
var sync: SteamTestSync
var world: Node3D

var _lobby_matches: Array = []
var _lobby_list_pending: bool = false
var _lobby_join_response: int = -1 ## The lobby_joined response; -1 until it arrives.


func before_all() -> void:
	if role != "host" and role != "client":
		_abort("STEAM_TEST_ROLE must be host or client, not '%s'" % role)
		return
	if run_id.is_empty():
		_abort("STEAM_TEST_ID is empty")
		return
	steamworks = get_node_or_null("/root/Steamworks")
	if steamworks == null:
		_abort("The Steamworks autoload is not registered")
		return
	steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null or int(steamworks.get("steam_id")) == 0:
		# The autoload tried at startup and its signal is long gone; try once more to get the reason
		var reasons: Array[String] = []
		steamworks.connect("steam_failed", func(reason: String) -> void: reasons.append(reason))
		steamworks.call("initialize")
		_abort(reasons[0] if not reasons.is_empty() else "Steam did not initialise")
		return
	sync = get_node_or_null("/root/" + SYNC_NODE_NAME) as SteamTestSync
	if sync == null:
		sync = SteamTestSync.new()
		sync.name = SYNC_NODE_NAME
		get_tree().root.add_child(sync)
	if sync.world == null:
		await _start_session()
	world = sync.world


## Every scenario starts with both Players on their feet at their stands and both sides at the same line: a test
## that ends with a Player riding, sitting or hidden would otherwise hand that state to the next one, and a side
## that finishes a test early would otherwise start the next one while the other side's last wait is still looking.
func before_each() -> void:
	if world == null:
		fail_test("No Steam session; see the abort above")
		return
	if not is_instance_valid(own_player()):
		fail_test("This side's Player has been freed; Players holds %s" % [world_node("Players").get_children()])
		return
	reset_own_player()
	var test_name: String = str(gut.get_current_test_object().name)
	await barrier("start " + test_name, null, RESYNC_TIMEOUT)
	var me: Player = own_player()
	print("[steam_test] %s: %s from %s under %s, riding %s, emote playback %s" % [role, test_name, me.global_position, me.get_parent().name, me.is_riding, me.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH) != null])


## What every peer still shows as owned by someone other than the server, so a handoff that did not reach this
## side can be read off the two logs side by side.
func after_each() -> void:
	if world == null or not is_instance_valid(own_player()):
		return
	var owned: PackedStringArray = []
	var every: PackedStringArray = []
	for node: Node in get_tree().root.find_children("*", "MultiplayerSynchronizer", true, false):
		every.append("%s:%d" % [node.get_path(), node.get_multiplayer_authority()])
		if node.get_multiplayer_authority() != 1:
			owned.append("%s:%d" % [world.get_path_to(node.get_parent()), node.get_multiplayer_authority()])
	every.sort()
	print("[steam_test] %s: not the server's here: %s" % [role, ", ".join(owned) if not owned.is_empty() else "nothing"])
	print("[steam_test] %s: synchronizers: %s" % [role, " | ".join(every)])


## The last scenario of the run leaves the lobby and closes the peer, once the other side has finished too.
func after_all() -> void:
	if sync == null or sync.world == null or not _is_last_script():
		return
	# The end of the session is not a test of the game: the other side's last mark can be the one packet a relay
	# stall holds back, so a missing one is noted and the session is closed either way. The side that arrives
	# second finds the other's mark waiting and would close before its own left; a moment's grace lets it out.
	sync.mark(_step_name("session_end"))
	var deadline: int = Time.get_ticks_msec() + int(RESYNC_TIMEOUT * 1000.0)
	while not sync.reached(_step_name("session_end")) and not sync.other_peer_gone and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not sync.reached(_step_name("session_end")):
		print("[steam_test] %s: the other side's session_end never arrived; closing anyway" % role)
	await get_tree().create_timer(2.0).timeout
	_end_session()


# --- Lockstep -----------------------------------------------------------------------------------------------------

## Tells the other side this side reached [param step], with [param value] along for the ride.
func mark(step: String, value: Variant = null) -> void:
	sync.mark(_step_name(step), value)


## Waits for the other side to mark [param step]; fails the test if it does not within [param timeout] seconds.
## Returns the value the other side marked it with.
func await_step(step: String, timeout: float = STEP_TIMEOUT) -> Variant:
	var value: Variant = await sync.await_step(_step_name(step), timeout)
	assert_true(sync.reached(_step_name(step)), "The other side never reached '%s' within %.0f s" % [step, timeout])
	return value


## Marks [param step] and waits for the other side's mark of it; both sides leave the barrier together.
func barrier(step: String, value: Variant = null, timeout: float = STEP_TIMEOUT) -> Variant:
	mark(step, value)
	return await await_step(step, timeout)


## Steps are named per scenario file, so two scenarios can both have a "done".
func _step_name(step: String) -> String:
	# The file and the test, so two tests in one file can both say "client_riding" without the second finding the
	# first's mark already waiting (which is how a value of null once landed in an int); after_all has no test
	var test_name: String = str(gut.get_current_test_object().name) if gut.get_current_test_object() else ""
	return "%s/%s/%s" % [(get_script() as Script).resource_path.get_file().get_basename(), test_name, step]


# --- Helpers ------------------------------------------------------------------------------------------------------

## The Player this peer controls.
func own_player() -> Player:
	return sync.world.get("player") as Player


## The other peer's Player, as this peer sees it.
func other_player() -> Player:
	for node: Node in get_tree().get_nodes_in_group("Player"):
		if node is Player and not node.is_multiplayer_authority():
			return node as Player
	return null


## The peer id of the other side.
func other_peer() -> int:
	return other_player().get_multiplayer_authority()


## A node of the world by path.
func world_node(path: String) -> Node:
	return sync.world.get_node(path)


## A node of the world by name, wherever it is: something the other side has already picked up or mounted has
## moved onto its Player, and its RPC can land here before this side's test body has looked for it.
func find_world_node(name: String) -> Node:
	return sync.world.find_child(name, true, false)


## This side's stand, see [constant STAND_HOST].
func stand_position() -> Vector3:
	return STAND_HOST if is_host else STAND_CLIENT


## Puts this side's Player back on its feet, unarmed, in plain sight, at its stand.
func reset_own_player() -> void:
	var me: Player = own_player()
	if me.is_riding:
		me.dismount(true)
	if me.is_sitting:
		me.state_machine.travel(NodeStateMachine.States.SITTING, NodeStateMachine.States.STANDING)
	me.is_stealthed = false
	me.inventory.unequip_all()
	me.warp_to(Transform3D(Basis(), stand_position()))


## Polls [param predicate] every frame until it is true, for up to [param seconds]; asserts the outcome with
## [param message] and returns it, so a scenario can stop early when the wait failed.
func wait_for(predicate: Callable, message: String, seconds: float = 10.0) -> bool:
	var ok: bool = await _wait_for(predicate, seconds)
	assert_true(ok, message)
	return ok


## A pressed action event, for the scripts that read the "action" key in their own _input.
func action_press(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


# --- Session ------------------------------------------------------------------------------------------------------

## Fails fast: the whole run is meaningless without a session, so say why and stop the process.
func _abort(reason: String) -> void:
	printerr("STEAM TEST ABORT (%s): %s" % [role, reason])
	get_tree().quit(1)


func _start_session() -> void:
	print("[steam_test] %s: run %s as Steam id %d (%s)" % [role, run_id, int(steamworks.get("steam_id")), steamworks.get("username")])
	if is_host:
		steamworks.set("lobby_id", 0)
		_add_world() # the world creates the lobby when it finds none
		if not await _wait_for(func() -> bool: return int(steamworks.get("lobby_id")) != 0, STEP_TIMEOUT):
			_abort("The world never created its Steam lobby")
			return
		var lobby_id: int = int(steamworks.get("lobby_id"))
		steam.call("setLobbyData", lobby_id, LOBBY_DATA_KEY, run_id)
		print("[steam_test] host: lobby %d tagged %s=%s" % [lobby_id, LOBBY_DATA_KEY, run_id])
	else:
		var lobby_id: int = await _find_lobby()
		if lobby_id == 0:
			_abort("No lobby tagged %s=%s appeared within %.0f s" % [LOBBY_DATA_KEY, run_id, SESSION_TIMEOUT])
			return
		steam.connect("lobby_joined", _on_lobby_joined)
		steam.call("joinLobby", lobby_id)
		if not await _wait_for(func() -> bool: return _lobby_join_response != -1, STEP_TIMEOUT):
			_abort("Steam never answered the join of lobby %d" % lobby_id)
			return
		if _lobby_join_response != STEAM_CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
			_abort("Joining lobby %d failed with response %d" % [lobby_id, _lobby_join_response])
			return
		steamworks.set("lobby_id", lobby_id)
		print("[steam_test] client: joined lobby %d" % lobby_id)
		_add_world() # SteamPeer connects to the lobby owner on ready
	if not await _wait_for(_both_players_spawned, SESSION_TIMEOUT):
		_abort("Both Players never spawned within %.0f s" % SESSION_TIMEOUT)
		return
	own_player().warp_to(Transform3D(Basis(), stand_position()))
	# A Player that leaves the world mid-run is the end of every scenario after it, so say when and which
	world_node("Players").child_exiting_tree.connect(func(node: Node) -> void:
		print("[steam_test] %s: Players lost %s during %s" % [role, node.name, gut.get_current_test_object().name if gut.get_current_test_object() else "no test"]))
	print("[steam_test] %s: session up as peer %d, %d players" % [role, multiplayer.get_unique_id(), get_tree().get_nodes_in_group("Player").size()])


func _add_world() -> void:
	var scene: PackedScene = load(WORLD_SCENE_PATH)
	sync.world = scene.instantiate() as Node3D
	sync.world.name = "World"
	sync.add_child(sync.world)


func _both_players_spawned() -> bool:
	if sync.world.get("player") == null:
		return false
	var players: int = 0
	for node: Node in get_tree().get_nodes_in_group("Player"):
		if node is Player:
			players += 1
	return players == 2


## Asks Steam for the lobby tagged with this run every [constant LOBBY_SEARCH_INTERVAL] seconds until it appears
## or [constant SESSION_TIMEOUT] passes; 0 when it never does.
func _find_lobby() -> int:
	steam.connect("lobby_match_list", _on_lobby_match_list)
	var deadline: int = Time.get_ticks_msec() + int(SESSION_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_lobby_matches = []
		_lobby_list_pending = true
		steam.call("addRequestLobbyListStringFilter", LOBBY_DATA_KEY, run_id, STEAM_LOBBY_COMPARISON_EQUAL)
		steam.call("addRequestLobbyListDistanceFilter", STEAM_LOBBY_DISTANCE_FILTER_WORLDWIDE)
		steam.call("requestLobbyList")
		await _wait_for(func() -> bool: return not _lobby_list_pending, LOBBY_SEARCH_INTERVAL)
		for lobby_id: int in _lobby_matches:
			if str(steam.call("getLobbyData", lobby_id, LOBBY_DATA_KEY)) == run_id:
				return lobby_id
		print("[steam_test] client: no lobby tagged %s yet, %d listed" % [run_id, _lobby_matches.size()])
		await get_tree().create_timer(LOBBY_SEARCH_INTERVAL).timeout
	return 0


func _on_lobby_match_list(lobbies: Array) -> void:
	_lobby_matches = lobbies
	_lobby_list_pending = false


func _on_lobby_joined(_lobby_id: int, _permissions: int, _locked: int, response: int) -> void:
	_lobby_join_response = response


func _end_session() -> void:
	var lobby_id: int = int(steamworks.get("lobby_id"))
	if lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	steamworks.set("lobby_id", 0)
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	sync.world.queue_free()
	sync.world = null
	print("[steam_test] %s: left lobby %d and closed the peer" % [role, lobby_id])


func _is_last_script() -> bool:
	var scripts: Array = gut.get_test_collector().scripts
	return not scripts.is_empty() and scripts[-1].path == (get_script() as Script).resource_path

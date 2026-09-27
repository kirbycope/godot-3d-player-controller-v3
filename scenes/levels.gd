class_name Levels
extends RefCounted
## The levels this game can go to and the chat command that takes it there: type "/level" for the list, "/level
## palmanova" to go. Registered with the player controller's chat by [member Main] before any Player exists, the way
## the extra control schemes are, so it works in every level. It is for a game with nobody else in it: in a session
## with other peers the others would be left behind in the old level, since only the world carries the spawners a
## joined Player needs, so the command says so and does nothing.

## Name typed after "/level" -> the scene it loads.
const LEVELS: Dictionary[String, String] = {
	"world": "res://scenes/world.tscn",
	"snow": "res://scenes/snow_demo.tscn",
	"palmanova": "res://scenes/palmanova.tscn",
}
const LOADING_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/ui/loading.tscn")


static func register() -> void:
	ChatWindow.register_command("level", "/level [name]: lists the levels, or goes to one (single player)", level)


## The "/level" command: what to say and, when there is one, the scene to load. Pure, so it can be tested without a
## scene change: [param peers] is how many other peers are in the session and [param current] the scene now running.
static func choose(args: PackedStringArray, peers: int, current: String) -> Dictionary:
	var names: String = ", ".join(LEVELS.keys())
	if args.is_empty():
		return {"message": "Levels: %s. /level <name> goes there." % names, "path": ""}
	var name: String = args[0].to_lower()
	if not LEVELS.has(name):
		return {"message": "No level called %s. Levels: %s." % [args[0], names], "path": ""}
	if peers > 0:
		return {"message": "/level is for a game with nobody else in it: the others would be left in this level.", "path": ""}
	if LEVELS[name] == current:
		return {"message": "Already in %s." % name, "path": ""}
	return {"message": "Going to %s." % name, "path": LEVELS[name]}


## What the chat calls: answers in the history and, when a level was picked, loads it behind the loading screen,
## which sits over everything until the old level has gone.
static func level(args: PackedStringArray, chat: ChatWindow) -> void:
	var tree: SceneTree = chat.get_tree()
	var peers: int = chat.multiplayer.get_peers().size() if chat.multiplayer.has_multiplayer_peer() else 0
	var current: String = tree.current_scene.scene_file_path if tree.current_scene else ""
	var choice: Dictionary = choose(args, peers, current)
	chat.append_system(choice["message"])
	if String(choice["path"]).is_empty():
		return
	var loading: Loading = LOADING_SCENE.instantiate()
	tree.root.add_child(loading)
	if tree.current_scene:
		tree.current_scene.tree_exited.connect(loading.queue_free)
	loading.load_scene(choice["path"])

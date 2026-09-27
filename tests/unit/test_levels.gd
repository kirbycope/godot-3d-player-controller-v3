extends GutTest

## Purpose: "/level" in the chat lists this game's levels and goes to the one named, in a game with nobody else in
## it; with other peers in the session, or an unknown name, it only answers. The scene change itself is not run here
## (it would replace the test runner); the choice is pure and the command is checked up to the loading screen.

const CHAT_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/ui/chat.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")


func after_each() -> void:
	ChatWindow.forget_registered_commands()


func test_the_choice_lists_refuses_and_picks() -> void:
	var listed: Dictionary = Levels.choose(PackedStringArray(), 0, "res://scenes/world.tscn")
	assert_string_contains(listed["message"], "palmanova", "No name lists the levels")
	assert_eq(listed["path"], "", "and goes nowhere")
	var unknown: Dictionary = Levels.choose(PackedStringArray(["mars"]), 0, "res://scenes/world.tscn")
	assert_string_contains(unknown["message"], "No level called mars", "An unknown name says so")
	assert_eq(unknown["path"], "")
	var crowded: Dictionary = Levels.choose(PackedStringArray(["palmanova"]), 1, "res://scenes/world.tscn")
	assert_string_contains(crowded["message"], "nobody else", "With another peer in the session it refuses")
	assert_eq(crowded["path"], "")
	var same: Dictionary = Levels.choose(PackedStringArray(["world"]), 0, "res://scenes/world.tscn")
	assert_string_contains(same["message"], "Already in world")
	assert_eq(same["path"], "")
	var go: Dictionary = Levels.choose(PackedStringArray(["Palmanova"]), 0, "res://scenes/world.tscn")
	assert_eq(go["path"], "res://scenes/palmanova.tscn", "A known name, any case, is the level to load")
	assert_string_contains(go["message"], "Going to palmanova")
	for name: String in Levels.LEVELS:
		assert_true(ResourceLoader.exists(Levels.LEVELS[name]), name + " is a scene that exists")


func test_the_command_is_registered_with_the_chat_and_lists_from_it() -> void:
	Levels.register()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(1)
	var chat: ChatWindow = player.chat
	assert_true(chat.commands.has("level"), "The Player's chat carries /level")
	chat.send("/level")
	assert_string_contains(chat.history.get_parsed_text(), "Levels: world, snow, palmanova", "and /level lists them")
	chat.send("/level nowhere")
	assert_string_contains(chat.history.get_parsed_text(), "No level called nowhere")
	assert_null(get_tree().root.get_node_or_null("Loading"), "and nothing started loading")

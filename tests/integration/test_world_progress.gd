extends GutTest

## Purpose: The QA world carries the player controller's progression kit: a Checkpoint by the spawn, the lethal
## KillZone under the map, a SaveGame that keeps the clock and weather with the Player, the harvestables and the
## enemies, and the Guide, whose errand counts a felled tree and a landed fish. Continue on the title screen asks
## the SaveGame to load once the Player is in.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const QA_QUEST: Quest = preload("res://resources/quests/qa_errand.tres")
const CARP: Fish = preload("res://resources/fish/carp.tres")
const TEST_PATH: String = "user://gut/test_world_savegame.json"

var world: Node
var player: Player
var saver: SaveGame


func before_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	player = world.get_node("PlayerSpawner/1")
	saver = world.get_node("SaveGame")
	saver.save_path = TEST_PATH
	saver.save_on_checkpoint = false


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveGame.load_requested = false


func test_the_world_has_the_progression_kit() -> void:
	assert_true(world.get_node("Checkpoint") is Checkpoint)
	assert_true(world.get_node("KillZone") is KillZone)
	assert_true((world.get_node("KillZone") as KillZone).lethal, "Falling off the map is a death, not a teleport")
	assert_true(world.get_node("Guide") is TalkingNpc)
	assert_eq((world.get_node("Guide") as TalkingNpc).display_name, "Guide")
	assert_true((world.get_node("PlayerSpawner") as PlayerSpawner).local_player_spawned.is_connected(saver.load_for_player), "A requested load waits for the spawned Player, wired in the scene")
	assert_true(world.is_in_group(SaveGame.GROUP), "The world saves its clock and weather")
	assert_true(world.get_node("Enemies/Swordsman").is_in_group(SaveGame.GROUP))


func test_the_save_keeps_the_clock_the_weather_the_player_and_the_trees() -> void:
	var clock: DateAndTime = world.get_node("DateAndTime")
	var weather: WeatherFX = world.get_node("WeatherFX")
	clock.set_time(21, 30)
	weather.set_weather(ClimateData.WeatherType.RAIN)
	player.warp_to(Transform3D(Basis(), Vector3(6.0, 0.0, 6.0)))
	var tree: Choppable = world.find_child("Tree01", true, false)
	tree.hits = 1
	assert_eq(saver.save_game(), OK)
	clock.set_time(6, 0)
	weather.set_weather(ClimateData.WeatherType.BLUE_SKY)
	player.warp_to(Transform3D(Basis(), Vector3.ZERO))
	tree.hits = 0
	assert_true(saver.load_game())
	assert_eq(clock.get_hour(), 21)
	assert_eq(clock.get_minute(), 30)
	assert_eq(weather.active_weather, ClimateData.WeatherType.RAIN)
	assert_almost_eq(player.global_position, Vector3(6.0, 0.0, 6.0), Vector3.ONE * 0.1)
	assert_eq(tree.hits, 1, "A tree keeps its hits")


func test_the_guides_errand_counts_wood_and_fish() -> void:
	var guide: TalkingNpc = world.get_node("Guide")
	var conversation: Conversation = guide.get_node("Conversation")
	var quest_log: QuestLog = player.quest_log
	Dialogic.Settings.text_speed = 0.0
	assert_true(guide.talk(player))
	await wait_process_frames(3)
	assert_true(conversation.is_talking(), "Talk starts the Guide's Dialogic timeline")
	assert_eq(Dialogic.current_timeline, conversation.timeline)
	assert_true(player.is_paused)
	Dialogic.handle_next_event() # past the greeting, to the question
	await wait_seconds(0.4) # Dialogic ignores a choice for its block delay after showing the question
	Dialogic.Choices.select_choice(1) # "What do you need?"
	await wait_process_frames(3)
	assert_true(quest_log.is_active(QA_QUEST), "Taking the errand starts it")
	assert_true(quest_log.is_objective_done(QA_QUEST, &"talk_guide"))
	conversation.end()
	await wait_process_frames(3)
	assert_false(conversation.is_talking())
	assert_false(player.is_paused, "The Player is let go when the conversation ends")
	assert_null(guide.talker)
	var tree: Choppable = world.find_child("Tree01", true, false)
	var axe: Equipment = autofree(Equipment.new())
	axe.can_log = true
	axe.player = player
	for i: int in tree.hits_per_yield * tree.total_yields:
		tree.register_weapon_hit(axe)
	assert_true(tree.is_spent)
	assert_true(quest_log.is_objective_done(QA_QUEST, &"chop_tree"), "Felling a tree is the firewood")
	var fishing_log: FishingLog = player.get_node("FishingLog")
	fishing_log.record_catch(CARP, 30.0)
	assert_true(quest_log.is_objective_done(QA_QUEST, &"catch_fish"), "Landing a fish is supper")
	assert_true(quest_log.is_complete(QA_QUEST))
	assert_eq(player.inventory.count_of(preload("res://resources/items/apple.tres")), 3 + 3, "Three apples on top of the QA kit's three")


## The run's own save path (tests/gut_pre_run.gd points SaveGame.DEFAULT_SAVE_PATH under user://gut/), so the
## player's save is never touched.
func test_continue_shows_only_with_a_save_and_requests_a_load() -> void:
	assert_true(SaveGame.DEFAULT_SAVE_PATH.begins_with("user://gut/"), "The run saves in its own folder")
	DirAccess.remove_absolute(SaveGame.DEFAULT_SAVE_PATH)
	var title: TitleScreen = TITLE_SCENE.instantiate()
	add_child_autofree(title)
	assert_false(title.button_continue.visible, "No save, no Continue")
	title.free()
	saver.save_path = SaveGame.DEFAULT_SAVE_PATH
	saver.save_game()
	title = TITLE_SCENE.instantiate()
	add_child_autofree(title)
	assert_true(title.button_continue.visible, "A save shows Continue")
	assert_false(title.menu_single_player.visible, "Continue lives behind Single-Player, not on the main menu")
	title.button_single_player.emit_signal("pressed")
	assert_true(title.menu_single_player.visible, "Single-Player opens the New Game and Continue panel")
	assert_true(title.button_continue.has_focus(), "With a save, Continue takes the focus in that panel")
	watch_signals(title)
	title._on_button_continue_pressed()
	assert_signal_emitted(title, "continue_pressed")
	DirAccess.remove_absolute(SaveGame.DEFAULT_SAVE_PATH)


## H8: Continue loads the save into a fresh world, whose PlayerSpawner sits before the SaveGame and spawns the Player
## in its own _ready, before the SaveGame is ready (world.tscn wires the spawn to SaveGame.load_for_player, which
## test_the_world_has_the_progression_kit checks).
func test_continue_loads_the_save_once_the_spawned_player_is_in() -> void:
	(world.get_node("DateAndTime") as DateAndTime).set_time(21, 30)
	saver.save_path = SaveGame.DEFAULT_SAVE_PATH
	assert_eq(saver.save_game(), OK)
	world.free()
	SaveGame.load_requested = true
	var fresh: Node = WORLD_SCENE.instantiate()
	add_child_autofree(fresh)
	await wait_physics_frames(3)
	var clock: DateAndTime = fresh.get_node("DateAndTime")
	assert_false(SaveGame.load_requested, "The request was taken")
	assert_eq(clock.get_hour(), 21, "and the save is back in the world")
	assert_eq(clock.get_minute(), 30)
	DirAccess.remove_absolute(SaveGame.DEFAULT_SAVE_PATH)

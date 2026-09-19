extends GutTest

## Purpose: the whistle that calls a horse is heard. world_player.tscn carries a WhistleAudio whose stream is an
## AudioStreamRandomizer of the three AudioHero human whistles, so the same player never whistles identically
## twice, and world.gd plays it when Player.whistled fires, before Horse.summon_nearest answers it.

const WORLD_PLAYER_SCENE: PackedScene = preload("res://scenes/world_player.tscn")
const WORLD_SCRIPT: Script = preload("res://scenes/world.gd")

var player: Player


func before_each() -> void:
	player = WORLD_PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	await wait_physics_frames(1)


func test_the_player_carries_three_whistles_to_pick_between() -> void:
	var whistle_audio: AudioStreamPlayer3D = player.get_node_or_null("WhistleAudio") as AudioStreamPlayer3D
	assert_not_null(whistle_audio, "The world's Player has a WhistleAudio")

	var randomizer: AudioStreamRandomizer = whistle_audio.stream as AudioStreamRandomizer
	assert_not_null(randomizer, "whose stream is a randomizer rather than one clip")
	assert_eq(randomizer.streams_count, 3, "of the three whistles")
	for at: int in randomizer.streams_count:
		var stream: AudioStream = randomizer.get_stream(at)
		assert_not_null(stream, "Stream %d is loaded" % at)
		assert_string_contains(stream.resource_path, "assets/audiohero/Whistles-HumanWhistles",
			"and comes from the AudioHero whistles")
	assert_false(whistle_audio.playing, "Nothing is whistling at rest")


## The whistle is a sound in the world, so it carries to whoever is near rather than only to the whistler.
func test_the_whistle_is_heard_where_the_player_stands() -> void:
	var whistle_audio: AudioStreamPlayer3D = player.get_node("WhistleAudio")
	assert_gt(whistle_audio.max_distance, 0.0, "It has a range rather than carrying forever")
	assert_eq(whistle_audio.get_parent(), player, "and travels with the Player, so it sounds where they are")


## What world.gd does with Player.whistled: the sound first, then the horse. Driven through the same handler the
## scene connects, rather than a copy of it.
func test_whistling_plays_it() -> void:
	var world: Node = WORLD_SCRIPT.new()
	var whistle_audio: AudioStreamPlayer3D = player.get_node("WhistleAudio")
	assert_false(whistle_audio.playing)

	world._on_player_whistled(player)

	assert_true(whistle_audio.playing, "Whistling is heard")
	world.free()

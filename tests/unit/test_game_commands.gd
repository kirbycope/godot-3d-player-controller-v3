extends GutTest

## Purpose: "/time" and "/weather" in the chat read and set the level's clock and sky, for the host or a Player alone,
## and only answer for a client in a session; the parsing and the host rule are pure and checked as such.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const WEATHER_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/weather_fx.tscn")
const CLOCK_SCRIPT: Script = preload("res://addons/date_and_time/scripts/date_and_time.gd")


func after_each() -> void:
	ChatWindow.forget_registered_commands()


func test_times_parse_on_the_24_hour_clock() -> void:
	assert_almost_eq(GameCommands.parse_time("7"), 7.0, 0.001)
	assert_almost_eq(GameCommands.parse_time("18:30"), 18.5, 0.001)
	assert_almost_eq(GameCommands.parse_time("0:00"), 0.0, 0.001)
	assert_eq(GameCommands.parse_time("24"), -1.0, "24 is not an hour")
	assert_eq(GameCommands.parse_time("7:60"), -1.0, "nor 60 a minute")
	assert_eq(GameCommands.parse_time("noon"), -1.0)
	assert_eq(GameCommands.parse_time("7:5:1"), -1.0)


func test_only_the_host_or_a_player_alone_sets_shared_things() -> void:
	assert_true(GameCommands.may_set_shared(0, false), "Alone, anyone")
	assert_true(GameCommands.may_set_shared(2, true), "the host of a session")
	assert_false(GameCommands.may_set_shared(2, false), "not a client")


func test_time_and_weather_read_and_set_the_levels_clock_and_sky() -> void:
	GameCommands.register()
	var level: Node3D = Node3D.new()
	add_child_autofree(level)
	var clock: DateAndTime = CLOCK_SCRIPT.new()
	clock.name = "DateAndTime"
	clock.editor_time_enabled = false
	clock.current_time = 9.0
	level.add_child(clock)
	var sky: WeatherFX = WEATHER_SCENE.instantiate()
	sky.name = "WeatherFX"
	level.add_child(sky)
	sky.date_and_time_node = clock
	var player: Player = PLAYER_SCENE.instantiate()
	level.add_child(player)
	await wait_physics_frames(2)
	var chat: ChatWindow = player.chat
	assert_true(chat.commands.has("time") and chat.commands.has("weather") and chat.commands.has("level"), "The chat carries the game's commands")
	chat.send("/time")
	assert_string_contains(chat.history.get_parsed_text(), "It is 09:00", "/time reads the clock")
	chat.send("/time 18:30")
	assert_almost_eq(clock.current_time, 18.5, 0.001, "/time hh:mm sets it")
	chat.send("/time later")
	assert_string_contains(chat.history.get_parsed_text(), "Usage: /time", "and nonsense gets the usage")
	chat.send("/weather")
	assert_string_contains(chat.history.get_parsed_text(), "Weather: clear, cloudy", "/weather lists the skies")
	chat.send("/weather storm")
	assert_true(sky.force_weather, "/weather storm forces the sky")
	assert_eq(sky.manual_weather, ClimateData.WeatherType.STORM, "to a storm")
	chat.send("/weather auto")
	assert_false(sky.force_weather, "/weather auto lets it run again")

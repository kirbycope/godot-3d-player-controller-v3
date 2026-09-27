extends GutTest

## Purpose: resting at the world's campfire skips the clock to the chosen hour (on to tomorrow once it has passed),
## moves the weather on a forecast cycle for every four hours skipped, and is offered only by a lit fire with nothing
## hunting the Player.

const REST_SCENE: PackedScene = preload("res://scenes/campfire_rest.tscn")

var rest: CampfireRest
var clock: DateAndTime


func before_each() -> void:
	WeatherFX.active_precipitation_strength = 0.0
	clock = DateAndTime.new()
	clock.name = "DateAndTime"
	clock.is_running = false
	add_child_autofree(clock)
	rest = REST_SCENE.instantiate() as CampfireRest
	rest.date_and_time = clock
	add_child_autofree(rest)
	await wait_physics_frames(1)


func test_the_hours_until_come_round_today_or_tomorrow() -> void:
	assert_eq(CampfireRest.hours_until(22.0, 6.0), 8.0, "From ten at night, morning is eight hours off")
	assert_eq(CampfireRest.hours_until(8.0, 12.0), 4.0, "From eight, noon is four")
	assert_eq(CampfireRest.hours_until(6.0, 6.0), 24.0, "Morning, resting until morning is a whole day")


func test_resting_skips_the_clock_to_the_hour() -> void:
	clock.current_time = 22.0
	var day: int = clock.day
	rest.rest_until(6.0)
	assert_almost_eq(clock.current_time, 6.0, 0.001, "It is morning")
	assert_eq(clock.day, day + 1, "the next day")


func test_resting_moves_the_weather_on() -> void:
	var weather: WeatherFX = (load("res://addons/weather_fx/scenes/weather_fx.tscn") as PackedScene).instantiate() as WeatherFX
	add_child_autofree(weather)
	rest.weather_fx = weather
	await wait_physics_frames(1)
	clock.current_time = 20.0
	var before: Array = weather.get("_forecast").duplicate()
	rest.rest_until(12.0) # sixteen hours: four cycles
	var after: Array = weather.get("_forecast")
	assert_eq(after.slice(0, after.size() - 4), before.slice(4), "Four cycles went by")


func test_a_rest_is_offered_only_by_a_lit_fire() -> void:
	var player: Player = (load("res://addons/3d_player_controller/scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	await wait_physics_frames(1)
	assert_true(rest.can_rest(player), "A lit fire and nothing hunting: rest")
	rest.campfire.lit = false
	assert_false(rest.can_rest(player), "Out, no rest")


## M2: the reach (2.5 m) covers the flames, where the fire's warmth on top of the air costs a Player feeling
## temperature health, so the offer is withdrawn there and comes back a step out, still inside the reach.
func test_no_rest_is_offered_from_inside_the_flames() -> void:
	var player: Player = (load("res://addons/3d_player_controller/scenes/player.tscn") as PackedScene).instantiate() as Player
	player.enable_temperature = true
	add_child_autofree(player)
	await wait_physics_frames(1)
	player.controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	var body: BodyTemperature = player.body_temperature
	player.global_position = rest.global_position + Vector3(2.0, 0.0, 0.0)
	await wait_physics_frames(1) # the body feels where it stands now
	assert_eq(body.damage_for(body.feel()), 0.0, "Two metres out the fire is warm, not hot")
	assert_false(rest.is_burning(player))
	assert_true(rest.can_rest(player), "so the rest is offered inside the reach")
	rest.display_menu(player)
	assert_true(rest.action_prompt.visible, "The prompt is up")
	assert_eq(player.controls.prompt_action_label, "Rest", "and the HUD's Action button reads Rest")
	player.global_position = rest.global_position
	assert_gt(body.damage_for(body.feel()), 0.0, "In the flames the heat costs health")
	assert_true(rest.is_burning(player))
	assert_false(rest.can_rest(player), "and no rest is offered")
	await wait_physics_frames(2) # the body feels the heat and says so
	assert_false(rest.action_prompt.visible, "The prompt went down as the Player walked into the fire")
	assert_eq(player.controls.prompt_action_label, "", "and the HUD got its Action label back")
	player.global_position = rest.global_position + Vector3(2.0, 0.0, 0.0)
	await wait_physics_frames(2)
	assert_true(rest.action_prompt.visible, "and came back a step out")
	assert_eq(player.controls.prompt_action_label, "Rest", "with the HUD reading Rest again")
	rest.hide_menu()
	assert_eq(player.controls.prompt_action_label, "", "hide_menu releases the HUD label")
	assert_false(body.felt_temperature_changed.is_connected(rest._on_felt_temperature_changed), "hide_menu lets go of the body")
	player.enable_temperature = false
	player.global_position = rest.global_position
	assert_false(rest.is_burning(player), "A Player who feels no temperature is not burned")


func test_the_scene_wires_the_timeline_signal_and_saves_the_fade_clear() -> void:
	assert_true(rest.conversation.signal_received.is_connected(rest._on_signal_received), "The rest timeline's signal reaches rest_until through the scene")
	assert_eq(rest.fade.modulate.a, 0.0, "The fade is saved clear, so it does not paint over the editor view")
	assert_eq(rest.fade.color, Color(0, 0, 0, 1), "and goes to black")

extends GutTest

## Purpose: the world's sun follows the clock: WeatherFX is handed the world's light and turns it with the hour, the
## Date and Time demo's rule.

const WORLD: PackedScene = preload("res://scenes/world.tscn")


func _node_property(state: SceneState, node_name: String, property: String) -> Variant:
	for i: int in state.get_node_count():
		if state.get_node_name(i) != node_name:
			continue
		for p: int in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == property:
				return state.get_node_property_value(i, p)
	return null


func test_the_world_hands_weatherfx_its_sun_and_environment() -> void:
	var state: SceneState = WORLD.get_state()
	assert_eq(_node_property(state, "WeatherFX", "sun_light"), NodePath("../DirectionalLight3D"), "The sun turns with the hour")
	assert_eq(_node_property(state, "WeatherFX", "world_environment"), NodePath("../WorldEnvironment"), "and the fog follows the weather")


func test_the_sun_rule_matches_the_date_and_time_demo() -> void:
	var weather: WeatherFX = load("res://addons/weather_fx/scenes/weather_fx.tscn").instantiate()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	add_child_autofree(sun)
	add_child_autofree(weather)
	weather.sun_light = sun
	weather.manual_time_of_day = 12.0
	weather._update_sun_lighting()
	assert_almost_eq(sun.rotation.x, -((12.0 - 6.0) / 24.0) * TAU, 0.001, "Noon puts the sun 90 degrees up, as the demo does")
	assert_almost_eq(sun.rotation.y, deg_to_rad(-30.0), 0.001)
	weather.manual_time_of_day = 18.0
	weather._update_sun_lighting()
	assert_almost_eq(sun.rotation.x, -((18.0 - 6.0) / 24.0) * TAU, 0.001, "Sunset lays it flat")


func test_the_world_drives_the_binbun_sky_from_the_weather() -> void:
	var state: SceneState = WORLD.get_state()
	var environment: Environment = _node_property(state, "WorldEnvironment", "environment")
	assert_true(environment.sky.resource_path.begins_with("res://addons/weather_fx/assets/BinbunSky/"), "The sky is a Binbun one from the weather_fx addon, a shader that runs everywhere")
	assert_null(_node_property(state, "WorldEnvironment", "compositor"), "No compositor effects: nothing that needs Forward+")
	assert_eq(_node_property(state, "WeatherClouds", "world_environment"), NodePath("../WorldEnvironment"))
	assert_eq(_node_property(state, "WeatherClouds", "weather"), NodePath("../WeatherFX"))
	assert_eq(_node_property(state, "WeatherClouds", "night_sun"), NodePath("../DirectionalLight3D"), "and the sky clouds dim with the sun")

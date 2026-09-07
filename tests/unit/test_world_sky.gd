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
	assert_true(environment.sky.resource_path.contains("BinbunSky"), "The sky is a Binbun one, a shader that runs everywhere")
	assert_null(_node_property(state, "WorldEnvironment", "compositor"), "No compositor on disk: nothing that needs Forward+ until runtime")
	assert_eq(_node_property(state, "WeatherClouds", "world_environment"), NodePath("../WorldEnvironment"))
	assert_eq(_node_property(state, "WeatherClouds", "weather"), NodePath("../WeatherFX"))


func test_the_world_carries_the_volumetric_clouds_driver_for_forward_plus() -> void:
	var state: SceneState = WORLD.get_state()
	assert_eq(_node_property(state, "WeatherClouds", "volumetric_clouds"), NodePath("VolumetricClouds"), "WeatherClouds owns the SunshineClouds2 driver")
	var script: Script = _node_property(state, "VolumetricClouds", "script")
	assert_eq(script.resource_path, "res://addons/SunshineClouds2/SunshineCloudsDriver.gd")
	assert_eq(_node_property(state, "VolumetricClouds", "tracked_directional_lights"), [NodePath("../../DirectionalLight3D")], "Lit by the world's sun")
	assert_same(_node_property(state, "VolumetricClouds", "ambience_sample_environment"), _node_property(state, "WorldEnvironment", "environment"), "sampling the world's Environment")
	var text: String = FileAccess.get_file_as_string("res://scenes/world.tscn")
	assert_false(text.contains("world_clouds.tres"), "The SunshineClouds effect is not on disk in the scene: WeatherClouds loads it at runtime, on Forward+ only")
	assert_false(text.contains("SunshineClouds.gd"), "so Compatibility and the web export never load its compute shaders")
	assert_true(FileAccess.file_exists("res://resources/clouds/world_clouds.tres"), "The project clouds resource it loads")

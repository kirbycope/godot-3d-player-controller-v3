extends GutTest

## Purpose: WeatherClouds drives the Binbun sky shader from the weather: cloud density and colour per weather type,
## the wind's heading and strength as the scroll, eased over time, all on a copy of the sky so the asset is untouched.

const SKY: Sky = preload("res://assets/BinbunSky/skies/stylized/stylized_sky_01.tres")

var environment: WorldEnvironment
var clouds: WeatherClouds


func before_each() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.sky = SKY
	add_child_autofree(environment)
	clouds = WeatherClouds.new()
	clouds.world_environment = environment
	add_child_autofree(clouds)


func _param(name: StringName) -> Variant:
	return clouds.sky_material().get_shader_parameter(name)


func test_it_works_on_a_copy_of_the_sky_and_starts_clear() -> void:
	assert_ne(environment.environment.sky, SKY, "The sky was copied")
	assert_ne(environment.environment.sky.sky_material, SKY.sky_material, "and so was its material")
	assert_almost_eq(float(_param(&"cloud_density")), clouds.clear_density, 0.001)
	assert_almost_eq(float(SKY.sky_material.get_shader_parameter(&"cloud_density")), 0.5, 0.001, "The asset keeps its own value")


func test_density_and_colour_follow_the_weather() -> void:
	clouds.apply_weather(ClimateData.WeatherType.CLOUDY)
	clouds.snap()
	assert_almost_eq(float(_param(&"cloud_density")), clouds.cloudy_density, 0.001, "Overcast")
	assert_eq(_param(&"cloud_color"), clouds.cloudy_color)
	clouds.apply_weather(ClimateData.WeatherType.RAIN)
	clouds.snap()
	assert_almost_eq(float(_param(&"cloud_density")), clouds.rain_density, 0.001, "Rain")
	assert_eq(_param(&"cloud_color"), clouds.rain_color)
	assert_lt(clouds.clear_density, clouds.cloudy_density)
	assert_lt(clouds.cloudy_density, clouds.rain_density)
	assert_lt(clouds.rain_color.get_luminance(), clouds.clear_color.get_luminance(), "Rain clouds are darker")


func test_a_change_rolls_in_over_time() -> void:
	clouds.transition_seconds = 0.5
	clouds.apply_weather(ClimateData.WeatherType.CLOUDY)
	await wait_process_frames(2)
	var partway: float = _param(&"cloud_density")
	assert_gt(partway, clouds.clear_density, "On its way")
	assert_lt(partway, clouds.cloudy_density, "but not there yet")


func test_the_wind_scrolls_the_clouds() -> void:
	clouds._on_wind_changed(10.0, Vector3(0.0, 0.3, -1.0))
	clouds.snap()
	var scroll: Vector2 = _param(&"wind_speed")
	assert_almost_eq(scroll.x, 0.0, 0.001)
	assert_almost_eq(scroll.y, -10.0 * clouds.wind_scroll_scale, 0.001, "Down the wind, as fast as it blows")
	clouds._on_wind_changed(0.0, Vector3.ZERO)
	clouds.snap()
	scroll = _param(&"wind_speed")
	assert_almost_eq(scroll.length(), clouds.wind_min_scroll, 0.001, "Never dead still")
	assert_lt(scroll.y, 0.0, "and keeps its last heading")


func test_it_stays_quiet_without_a_binbun_sky() -> void:
	var plain: WorldEnvironment = WorldEnvironment.new()
	plain.environment = Environment.new()
	add_child_autofree(plain)
	var quiet: WeatherClouds = WeatherClouds.new()
	quiet.world_environment = plain
	add_child_autofree(quiet)
	quiet.apply_weather(ClimateData.WeatherType.RAIN)
	quiet.snap()
	assert_null(quiet.sky_material())
	assert_false(quiet.is_processing(), "Nothing to drive")

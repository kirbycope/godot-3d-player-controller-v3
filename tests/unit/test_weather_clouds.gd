extends GutTest

## Purpose: WeatherClouds drives the Binbun sky shader from the weather: cloud density and colour per weather type,
## the wind's heading and strength as the scroll, eased over time on a copy of the sky so the asset is untouched,
## and it only processes while the sky is on its way somewhere. On Forward+ it also builds the SunshineClouds2
## volumetric clouds at runtime (a Compositor on the WorldEnvironment, the driver kept and running) and eases their
## coverage and wind with the sky; on any other renderer it frees the driver and creates nothing.

const SKY: Sky = preload("res://assets/BinbunSky/skies/stylized/stylized_sky_01.tres")
const CLOUDS_RESOURCE: String = "res://resources/clouds/world_clouds.tres"

var environment: WorldEnvironment
var clouds: WeatherClouds


## Clouds that believe they run on the given renderer, so both branches are covered headless.
class RendererClouds:
	extends WeatherClouds

	var renderer: String
	var driver: String

	func _init(rendering_method: String, rendering_driver: String = "vulkan") -> void:
		renderer = rendering_method
		driver = rendering_driver

	func _rendering_method() -> String:
		return renderer

	func _rendering_driver() -> String:
		return driver


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
	assert_false(clouds.is_processing(), "Snapped to clear at start, nothing to ease")


func test_it_writes_to_one_cached_copy_of_the_material() -> void:
	var material: ShaderMaterial = clouds._material
	assert_not_null(material)
	assert_eq(material, environment.environment.sky.sky_material, "The copy in the environment is the one it holds")
	clouds.apply_weather(ClimateData.WeatherType.CLOUDY)
	clouds.snap()
	clouds._on_wind_changed(5.0, Vector3.FORWARD)
	await wait_process_frames(2)
	assert_eq(clouds._material, material, "The same object across writes, never resolved again")
	assert_eq(clouds.sky_material(), material)


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
	assert_true(clouds.is_processing(), "A new target starts the easing")
	await wait_process_frames(2)
	var partway: float = _param(&"cloud_density")
	assert_gt(partway, clouds.clear_density, "On its way")
	assert_lt(partway, clouds.cloudy_density, "but not there yet")
	assert_true(clouds.is_processing(), "and still easing")


func test_it_settles_on_the_target_and_stops_processing() -> void:
	clouds.transition_seconds = 0.02
	clouds.apply_weather(ClimateData.WeatherType.RAIN)
	clouds._on_wind_changed(10.0, Vector3(1.0, 0.0, 0.0))
	assert_true(clouds.is_processing())
	await wait_process_frames(20)
	assert_false(clouds.is_processing(), "Within reach of the target it snaps and stops")
	assert_eq(float(_param(&"cloud_density")), clouds.rain_density, "exactly on the target")
	assert_eq(_param(&"cloud_color"), clouds.rain_color)
	assert_eq(_param(&"wind_speed"), Vector2(10.0 * clouds.wind_scroll_scale, 0.0))
	clouds.apply_weather(ClimateData.WeatherType.BLUE_SKY)
	assert_true(clouds.is_processing(), "The next change starts it again")
	clouds.snap()
	assert_false(clouds.is_processing(), "and a snap ends it at once")
	assert_eq(float(_param(&"cloud_density")), clouds.clear_density)


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
	assert_false(quiet.is_processing(), "Nothing to drive, so nothing to ease")
	quiet.snap()
	assert_null(quiet.sky_material())
	assert_null(quiet._material)
	assert_false(quiet.is_processing())


## Replaces [member clouds] with ones on the given renderer that carry a SunshineClouds2 driver, the way world.tscn
## does, and returns the driver.
func _volumetric_clouds(renderer: String, rendering_driver: String = "vulkan") -> SunshineCloudsDriverGD:
	clouds.free()
	clouds = RendererClouds.new(renderer, rendering_driver)
	clouds.world_environment = environment
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	add_child_autofree(sun)
	var driver: SunshineCloudsDriverGD = SunshineCloudsDriverGD.new()
	driver.name = "VolumetricClouds"
	driver.tracked_directional_lights = [sun]
	clouds.add_child(driver)
	clouds.volumetric_clouds = driver
	add_child_autofree(clouds)
	return driver


func test_forward_plus_builds_the_volumetric_clouds_on_the_environment() -> void:
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus")
	assert_true(is_instance_valid(driver), "The driver stays")
	assert_same(clouds.volumetric_clouds, driver)
	assert_not_null(environment.compositor, "The WorldEnvironment got a Compositor at runtime")
	assert_eq(environment.compositor.compositor_effects.size(), 1, "with one effect")
	var effect: CompositorEffect = environment.compositor.compositor_effects[0]
	assert_true(effect is SunshineCloudsGD, "the SunshineClouds one")
	assert_eq(effect.resource_path, CLOUDS_RESOURCE, "loaded from the project resource")
	assert_same(driver.clouds_resource, effect, "The driver drives that same effect")
	assert_true(driver.update_continuously, "and is running")
	assert_same(driver.ambience_sample_environment, environment.environment, "sampling the world's Environment")
	assert_true(clouds.sky_material() != null, "The Binbun sky is still driven underneath")
	assert_false(clouds.is_processing(), "Snapped to clear at start, nothing to ease")


func test_other_renderers_free_the_driver_and_build_nothing() -> void:
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("gl_compatibility")
	await wait_process_frames(1)
	assert_false(is_instance_valid(driver), "The driver is freed")
	assert_null(clouds.volumetric_clouds)
	assert_null(environment.compositor, "and no Compositor is made: Compatibility never touches the compute shaders")
	assert_not_null(clouds._material, "The sky layer still runs")
	clouds.apply_weather(ClimateData.WeatherType.RAIN)
	clouds.snap()
	assert_almost_eq(float(_param(&"cloud_density")), clouds.rain_density, 0.001)
	var mobile: SunshineCloudsDriverGD = _volumetric_clouds("mobile")
	await wait_process_frames(1)
	assert_false(is_instance_valid(mobile), "Mobile has no compositor effects either")
	assert_null(environment.compositor)


func test_forward_plus_on_d3d12_builds_nothing_either() -> void:
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus", "d3d12")
	await wait_process_frames(1)
	assert_false(is_instance_valid(driver), "The clouds' compute pipelines fail to build on D3D12, so the driver is freed")
	assert_null(clouds.volumetric_clouds)
	assert_null(environment.compositor, "and no Compositor is made")
	assert_not_null(clouds._material, "The sky layer still runs")
	var metal: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus", "metal")
	await wait_process_frames(1)
	assert_true(is_instance_valid(metal), "Metal is a driver the addon supports")
	assert_not_null(environment.compositor)


func test_the_weather_sets_the_volumetric_coverage_through_the_easing() -> void:
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus")
	var effect: SunshineCloudsGD = driver.clouds_resource
	var clear: float = clouds.coverage_for(clouds.clear_density)
	assert_almost_eq(effect.clouds_coverage, clear, 0.001, "Clear at start")
	assert_lt(clear, clouds.coverage_for(clouds.cloudy_density), "More cover when overcast")
	assert_lt(clouds.coverage_for(clouds.cloudy_density), clouds.coverage_for(clouds.rain_density), "and most in rain")
	assert_almost_eq(clouds.coverage_for(clouds.rain_density), clouds.volumetric_coverage_max, 0.001)
	assert_almost_eq(clouds.coverage_for(0.0), clouds.volumetric_coverage_min, 0.001)
	assert_almost_eq(clouds.coverage_for(99.0), clouds.volumetric_coverage_max, 0.001, "Clamped to full cover")
	clouds.transition_seconds = 0.5
	clouds.apply_weather(ClimateData.WeatherType.RAIN)
	assert_true(clouds.is_processing(), "A new target starts the easing")
	await wait_process_frames(2)
	assert_gt(effect.clouds_coverage, clear, "On its way")
	assert_lt(effect.clouds_coverage, clouds.volumetric_coverage_max, "but not there yet")
	assert_almost_eq(effect.clouds_coverage, clouds.coverage_for(float(_param(&"cloud_density"))), 0.001, "In step with the sky")
	clouds.snap()
	assert_almost_eq(effect.clouds_coverage, clouds.volumetric_coverage_max, 0.001, "A snap lands it")
	assert_false(clouds.is_processing())


func test_the_volumetric_wind_follows_the_weather_wind() -> void:
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus")
	clouds._on_wind_changed(10.0, Vector3(0.0, 0.3, -1.0))
	clouds.snap()
	var wind: Vector3 = driver.wind_direction
	assert_almost_eq(wind.x, 0.0, 0.001)
	assert_eq(wind.y, 0.0, "The clouds blow level")
	assert_almost_eq(wind.z, -10.0 * clouds.wind_scroll_scale * clouds.volumetric_wind_scale, 0.001, "Down the wind, as fast as it blows")
	clouds.transition_seconds = 0.5
	clouds._on_wind_changed(10.0, Vector3.RIGHT)
	await wait_process_frames(2)
	assert_gt(driver.wind_direction.x, 0.0, "Turning towards the new wind")
	assert_lt(driver.wind_direction.z, 0.0, "and not there yet")
	clouds._on_wind_changed(0.0, Vector3.ZERO)
	clouds.snap()
	assert_almost_eq(driver.wind_direction.length(), clouds.wind_min_scroll * clouds.volumetric_wind_scale, 0.001, "Never dead still")


func test_the_effect_is_inert_without_a_rendering_device() -> void:
	assert_null(RenderingServer.get_rendering_device(), "Headless has no RenderingDevice, so the compute shaders are never built here")
	var driver: SunshineCloudsDriverGD = _volumetric_clouds("forward_plus")
	var effect: SunshineCloudsGD = driver.clouds_resource
	assert_false(effect.enabled, "The addon disables itself without a device")
	assert_false(effect.pipeline.is_valid())
	assert_eq(effect.effect_callback_type, CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT, "Drawn before the transparents")
	assert_not_null(effect.large_scale_noise, "The noise textures come from the addon")
	assert_true(effect.large_scale_noise.resource_path.begins_with("res://addons/SunshineClouds2/"))

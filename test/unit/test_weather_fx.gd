extends GutTest

var wfx: WeatherFX


func before_each() -> void:
	wfx = WeatherFX.new()
	add_child_autofree(wfx)


func test_all_twenty_biomes_exist() -> void:
	assert_eq(ClimateData.BIOME_DEFINITIONS.size(), 20)
	for i in range(20):
		var zone: ClimateData.BiomeZone = i as ClimateData.BiomeZone
		var data = ClimateData.get_biome_data(zone)
		assert_not_null(data)
		assert_eq(data["day_temps"].size(), 11)
		assert_eq(data["night_temps"].size(), 11)


func test_temperature_interpolation_at_altitude() -> void:
	# Zone 0 Temperate Plains: 0m = 25°C, 100m = 20°C
	var temp_0 = ClimateData.get_temperature(ClimateData.BiomeZone.TEMPERATE_PLAINS, 0.0, true)
	var temp_50 = ClimateData.get_temperature(ClimateData.BiomeZone.TEMPERATE_PLAINS, 50.0, true)
	var temp_100 = ClimateData.get_temperature(ClimateData.BiomeZone.TEMPERATE_PLAINS, 100.0, true)
	assert_almost_eq(temp_0, 25.0, 0.01)
	assert_almost_eq(temp_50, 22.5, 0.01)
	assert_almost_eq(temp_100, 20.0, 0.01)


func test_freezing_point_conversion() -> void:
	assert_true(ClimateData.is_freezing(0.0))
	assert_true(ClimateData.is_freezing(-5.0))
	assert_false(ClimateData.is_freezing(0.1))


func test_forecast_queue_generation() -> void:
	var forecast = wfx.get_forecast()
	assert_eq(forecast.size(), 5)


func test_advance_cycle() -> void:
	var initial_forecast = wfx.get_forecast()
	var next_expected = initial_forecast[1]
	wfx.advance_cycle()
	var new_forecast = wfx.get_forecast()
	assert_eq(new_forecast.size(), 5)
	assert_eq(new_forecast[0], next_expected)


func test_manual_weather_override() -> void:
	wfx.set_weather(ClimateData.WeatherType.STORM)
	assert_true(wfx.force_weather)
	assert_eq(wfx.get_current_weather(), ClimateData.WeatherType.STORM)

	wfx.resume_forecast()
	assert_false(wfx.force_weather)


func test_play_pause_weather() -> void:
	wfx.play()
	assert_true(wfx.is_playing)
	wfx.pause()
	assert_false(wfx.is_playing)


func test_hud_forecast_display_updates_on_biome_change() -> void:
	var display = WeatherForecastDisplay.new()
	display.weather_fx_node = wfx
	add_child_autofree(display)

	# Initially TEMPERATE_PLAINS
	assert_true(display._info_label.text.contains("Temperate Plains"))

	# Change biome to ARCTIC_TUNDRA
	wfx.current_biome = ClimateData.BiomeZone.ARCTIC_TUNDRA
	assert_true(display._info_label.text.contains("Arctic Tundra"))


func test_weather_fx_scene_audio_and_vfx() -> void:
	var scene = load("res://addons/weather_fx/weather_fx.tscn")
	assert_not_null(scene)
	var instance: WeatherFX = scene.instantiate()
	assert_not_null(instance)
	add_child_autofree(instance)

	assert_not_null(instance.rain_particles)
	assert_not_null(instance.snow_particles)
	assert_not_null(instance.audio_rain_light)
	assert_not_null(instance.audio_rain_heavy)
	assert_not_null(instance.audio_storm)
	assert_not_null(instance.audio_wind)

	assert_not_null(instance.audio_rain_light.stream)
	assert_not_null(instance.audio_rain_heavy.stream)
	assert_not_null(instance.audio_storm.stream)
	assert_not_null(instance.audio_wind.stream)

	# Verify rain weather activates rain audio and particles
	instance.set_weather(ClimateData.WeatherType.RAIN)
	assert_true(instance.rain_particles.emitting)
	assert_true(instance.audio_rain_light.playing)

	# Verify heavy rain
	instance.set_weather(ClimateData.WeatherType.HEAVY_RAIN)
	assert_true(instance.rain_particles.emitting)
	assert_true(instance.audio_rain_heavy.playing)

	# Verify storm
	instance.set_weather(ClimateData.WeatherType.STORM)
	assert_true(instance.rain_particles.emitting)
	assert_true(instance.audio_storm.playing)
	assert_true(instance.audio_wind.playing)

	# Verify blue sky clears all audio and particles
	instance.set_weather(ClimateData.WeatherType.BLUE_SKY)
	assert_false(instance.rain_particles.emitting)
	assert_false(instance.audio_rain_light.playing)
	assert_false(instance.audio_rain_heavy.playing)
	assert_false(instance.audio_storm.playing)
	assert_false(instance.audio_wind.playing)


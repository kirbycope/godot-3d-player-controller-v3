extends GutTest

## Purpose: Integration test suite verifying interoperability between DateAndTime and WeatherFX addons.

var dt: DateAndTime
var wfx: WeatherFX
var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)

	dt = DateAndTime.new()
	dt.is_running = false
	dt.editor_time_enabled = false
	dt.system_sync = false
	root.add_child(dt)

	wfx = WeatherFX.new()
	wfx.date_and_time_node = dt
	root.add_child(wfx)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null
	dt = null
	wfx = null


func test_weather_fx_links_to_date_and_time_node() -> void:
	assert_not_null(wfx.date_and_time_node, "WeatherFX should be linked to DateAndTime node")
	assert_eq(wfx.get_current_time_hours(), dt.current_time, "WeatherFX time should match DateAndTime current_time")


func test_diurnal_temperature_changes_with_date_and_time() -> void:
	wfx.current_biome = ClimateData.BiomeZone.TEMPERATE_PLAINS
	wfx.current_altitude = 0.0

	# Peak afternoon temperature at 16:00
	dt.set_time(16, 0, 0)
	assert_true(wfx.is_daylight(), "16:00 should be daylight")
	var peak_temp: float = wfx.calculate_temperature(wfx.get_current_time_hours(), 0.0)
	assert_almost_eq(peak_temp, 25.0, 0.1, "Temperate Plains peak afternoon temp at 0m should be 25°C")

	# Coldest night trough temperature at 04:00
	dt.set_time(4, 0, 0)
	assert_false(wfx.is_daylight(), "04:00 should not be daylight")
	var cold_temp: float = wfx.calculate_temperature(wfx.get_current_time_hours(), 0.0)
	assert_almost_eq(cold_temp, 23.0, 0.1, "Temperate Plains coldest early morning temp at 0m should be 23°C")

	# Verify day is warmer than night
	assert_gt(peak_temp, cold_temp, "Afternoon temperature must be warmer than early morning night temperature")


func test_time_progression_signal_updates_weather_state() -> void:
	dt.set_time(12, 0, 0)
	assert_true(wfx.is_daylight())

	# Advancing time across day/night boundary (from 12:00 to 22:00)
	dt.add_hours(10.0)
	assert_almost_eq(dt.current_time, 22.0, 0.01)
	assert_false(wfx.is_daylight(), "WeatherFX daylight should update to false when time advances past 18:00")


func test_date_and_time_node_reassignment() -> void:
	# Create a secondary DateAndTime node
	var dt2 := DateAndTime.new()
	dt2.set_time(6, 30, 0)
	root.add_child(dt2)

	wfx.date_and_time_node = dt2
	assert_eq(wfx.get_current_time_hours(), dt2.current_time, "WeatherFX should read time from new DateAndTime instance")
	assert_true(wfx.is_daylight())

	# Clearing the node falls back to manual_time_of_day
	wfx.date_and_time_node = null
	wfx.manual_time_of_day = 23.0
	assert_eq(wfx.get_current_time_hours(), 23.0, "WeatherFX should fall back to manual_time_of_day")
	assert_false(wfx.is_daylight())


func test_hud_date_time_and_weather_forecast_coexistence() -> void:
	var hud := CanvasLayer.new()
	root.add_child(hud)

	var dt_display := DateAndTimeDisplay.new()
	dt_display.date_and_time_node = dt
	dt_display.botw_style = true
	dt_display.minute_increment = 5
	hud.add_child(dt_display)

	var wf_display := WeatherForecastDisplay.new()
	wf_display.weather_fx_node = wfx
	hud.add_child(wf_display)

	var tg_display := TemperatureGaugeDisplay.new()
	tg_display.weather_fx_node = wfx
	hud.add_child(tg_display)

	# Set afternoon time & verify display states
	dt.set_time(14, 27, 0)
	assert_eq(dt_display._rtl.text, "[i]2:25[/i]", "DateAndTimeDisplay should render rounded BotW time")

	wfx.current_biome = ClimateData.BiomeZone.DESERT_DUNES
	assert_true(wf_display._info_label.text.contains("Desert Dunes"), "WeatherForecastDisplay should update biome")

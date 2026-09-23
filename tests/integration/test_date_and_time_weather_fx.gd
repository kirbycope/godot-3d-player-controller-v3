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


const DT_DISPLAY_SCENE: PackedScene = preload("res://addons/date_and_time/scenes/date_and_time_display.tscn")
const WF_DISPLAY_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/weather_forecast_display.tscn")


func test_hud_date_time_and_weather_forecast_coexistence() -> void:
	var hud := CanvasLayer.new()
	root.add_child(hud)

	var dt_display: DateAndTimeDisplay = DT_DISPLAY_SCENE.instantiate()
	dt_display.date_and_time_node = dt
	dt_display.botw_style = true
	dt_display.minute_increment = 5
	hud.add_child(dt_display)

	var wf_display: WeatherForecastDisplay = WF_DISPLAY_SCENE.instantiate()
	wf_display.weather_fx = wfx
	hud.add_child(wf_display)

	# The clock face: Breath of the Wild styling, 12-hour, rounded down to the five minutes
	dt.set_time(13, 47, 0)
	var rich_time: RichTextLabel = dt_display.get_node("%TimeRichLabel")
	assert_true((dt_display.get_node("%BotwBox") as Control).visible, "The BotW face shows")
	assert_false((dt_display.get_node("%TimeLabel") as Control).visible, "and the plain label does not")
	assert_eq(rich_time.text, "[i]1:45[/i]", "13:47 reads 1:45 on the BotW face")
	# The forecast beside it: the biome and temperature, and one icon per forecast cycle, the current one first
	var info: Label = wf_display.get_node("%InfoLabel")
	assert_true(info.text.begins_with(ClimateData.get_biome_display_name(wfx.current_biome)), "The forecast names the biome: " + info.text)
	assert_true(info.text.ends_with("°C"), "and the temperature: " + info.text)
	var icons: HBoxContainer = wf_display.get_node("%ForecastIcons")
	var forecast: Array[ClimateData.WeatherType] = wfx.get_forecast()
	assert_eq(icons.get_child_count(), forecast.size(), "One icon per forecast cycle")
	assert_eq((icons.get_child(0) as TextureRect).texture, ClimateData.get_weather_icon(forecast[0]), "the current weather first")
	# Both keep drawing while the other runs: the clock moves on and the forecast rolls over
	dt.set_time(22, 3, 0)
	assert_eq(rich_time.text, "[i]10:00[/i]", "The clock face follows the time")
	wfx.advance_cycle()
	assert_eq(icons.get_child_count(), wfx.forecast_length, "The forecast strip redraws on the next cycle")
	assert_eq((icons.get_child(0) as TextureRect).texture, ClimateData.get_weather_icon(wfx.get_forecast()[0]))
	assert_eq(rich_time.text, "[i]10:00[/i]", "with the clock face untouched")



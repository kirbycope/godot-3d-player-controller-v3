extends GutTest

const DISPLAY_SCENE: PackedScene = preload("res://addons/date_and_time/scenes/date_and_time_display.tscn")

var _date_and_time: DateAndTime


func before_each() -> void:
	_date_and_time = DateAndTime.new()
	_date_and_time.is_running = false
	_date_and_time.editor_time_enabled = false
	_date_and_time.system_sync = false
	add_child_autofree(_date_and_time)


func _make_display(botw: bool) -> DateAndTimeDisplay:
	var display: DateAndTimeDisplay = DISPLAY_SCENE.instantiate()
	display.date_and_time_node = _date_and_time
	display.botw_style = botw
	display.use_12_hour = true
	add_child_autofree(display)
	return display


func test_initial_values() -> void:
	assert_eq(_date_and_time.year, 2026, "Default year should be 2026")
	assert_eq(_date_and_time.month, 1, "Default month should be 1")
	assert_eq(_date_and_time.day, 1, "Default day should be 1")
	assert_almost_eq(_date_and_time.current_time, 12.0, 0.001, "Default time should be 12.0")


func test_set_time() -> void:
	_date_and_time.set_time(14, 30, 15)
	assert_eq(_date_and_time.get_hour(), 14)
	assert_eq(_date_and_time.get_minute(), 30)
	assert_eq(_date_and_time.get_second(), 15)
	assert_eq(_date_and_time.get_formatted_time(), "14:30:15")


func test_set_date() -> void:
	_date_and_time.set_date(2025, 12, 25)
	assert_eq(_date_and_time.year, 2025)
	assert_eq(_date_and_time.month, 12)
	assert_eq(_date_and_time.day, 25)
	assert_eq(_date_and_time.get_formatted_date(), "2025-12-25")


func test_leap_year() -> void:
	_date_and_time.year = 2024
	assert_true(_date_and_time.is_leap_year(), "2024 is a leap year")
	_date_and_time.month = 2
	assert_eq(_date_and_time.max_days_per_month(), 29, "Feb in 2024 has 29 days")
	_date_and_time.year = 2023
	assert_false(_date_and_time.is_leap_year(), "2023 is not a leap year")
	assert_eq(_date_and_time.max_days_per_month(), 28, "Feb in 2023 has 28 days")
	_date_and_time.year = 1900
	assert_false(_date_and_time.is_leap_year(), "1900 is not a leap year")
	_date_and_time.year = 2000
	assert_true(_date_and_time.is_leap_year(), "2000 is a leap year")


func test_day_clamped_when_month_or_year_changes() -> void:
	_date_and_time.set_date(2023, 1, 31)
	_date_and_time.month = 2
	assert_eq(_date_and_time.day, 28, "Jan 31 -> Feb clamps to Feb 28 in a non-leap year")
	_date_and_time.set_date(2024, 2, 29)
	_date_and_time.year = 2023
	assert_eq(_date_and_time.day, 28, "Feb 29 2024 -> 2023 clamps to Feb 28")


func test_time_wrapping_forward() -> void:
	_date_and_time.set_date(2026, 1, 31)
	_date_and_time.current_time = 23.0
	_date_and_time.add_hours(2.0)
	assert_almost_eq(_date_and_time.current_time, 1.0, 0.001)
	assert_eq(_date_and_time.day, 1, "Should wrap to day 1")
	assert_eq(_date_and_time.month, 2, "Should wrap to Feb")


func test_time_wrapping_year_boundaries() -> void:
	watch_signals(_date_and_time)
	_date_and_time.set_date(2025, 12, 31)
	_date_and_time.current_time = 23.0
	_date_and_time.add_hours(2.0)
	assert_eq(_date_and_time.get_formatted_date(), "2026-01-01", "Dec 31 23:00 + 2h is Jan 1 of the next year")
	assert_signal_emitted_with_parameters(_date_and_time, "year_changed", [2026])
	_date_and_time.add_hours(-2.0)
	assert_eq(_date_and_time.get_formatted_date(), "2025-12-31", "Backward wrap crosses day, month and year")
	assert_almost_eq(_date_and_time.current_time, 23.0, 0.001)


func test_tick_math() -> void:
	_date_and_time.minutes_per_day = 24.0
	_date_and_time.time_scale = 1.0
	_date_and_time.is_running = true
	assert_false(_date_and_time._tick_timer.is_stopped(), "Timer runs while is_running")
	assert_almost_eq(_date_and_time._tick_timer.wait_time, 1.0, 0.0001, "24 min/day = one in-game minute per real second")
	assert_eq(_date_and_time._minutes_per_tick, 1)
	_date_and_time.time_scale = 2.0
	assert_almost_eq(_date_and_time._tick_timer.wait_time, 0.5, 0.0001, "time_scale halves the tick interval")
	_date_and_time.time_scale = 1.0
	_date_and_time.minutes_per_day = 0.08
	assert_eq(_date_and_time._minutes_per_tick, 5, "5 s/day ticks 5 minutes at the 60 Hz floor")
	assert_almost_eq(_date_and_time._tick_timer.wait_time, DateAndTime.MIN_TICK_SECONDS, 0.0001)
	_date_and_time.time_scale = 0.0
	assert_true(_date_and_time._tick_timer.is_stopped(), "time_scale 0 stops the timer")
	_date_and_time.time_scale = 1.0
	_date_and_time.is_running = false
	assert_true(_date_and_time._tick_timer.is_stopped(), "Pausing stops the timer")


func test_tick_emits_per_minute_signals() -> void:
	_date_and_time.set_time(10, 59, 0)
	watch_signals(_date_and_time)
	_date_and_time._on_tick()
	assert_eq(_date_and_time.get_formatted_time(), "11:00:00", "One tick advances one minute")
	assert_signal_emit_count(_date_and_time, "time_changed", 1)
	assert_signal_emit_count(_date_and_time, "minute_changed", 1)
	assert_signal_emit_count(_date_and_time, "hour_changed", 1)
	assert_signal_emit_count(_date_and_time, "day_changed", 0)
	_date_and_time.set_time(23, 59, 0)
	_date_and_time._on_tick()
	assert_signal_emit_count(_date_and_time, "day_changed", 1)
	assert_signal_emit_count(_date_and_time, "month_changed", 0)


func test_timer_drives_clock() -> void:
	_date_and_time.minutes_per_day = 0.1
	_date_and_time.time_scale = 100.0
	watch_signals(_date_and_time)
	_date_and_time.is_running = true
	assert_signal_emitted(_date_and_time, "clock_resumed")
	await wait_for_signal(_date_and_time.minute_changed, 1.0)
	assert_signal_emitted(_date_and_time, "minute_changed", "Timer ticks advance the clock")
	_date_and_time.is_running = false
	assert_signal_emitted(_date_and_time, "clock_paused")


func test_is_day() -> void:
	_date_and_time.set_time(12, 0, 0)
	assert_true(_date_and_time.is_day(6.0, 18.0), "12:00 should be day")
	assert_false(_date_and_time.is_day(18.0, 6.0), "12:00 is night when sunrise > sunset")
	_date_and_time.set_time(22, 0, 0)
	assert_false(_date_and_time.is_day(6.0, 18.0), "22:00 should not be day")
	assert_true(_date_and_time.is_day(18.0, 6.0), "22:00 is day when sunrise > sunset")


func test_datetime_dict() -> void:
	_date_and_time.set_from_datetime_dict({"year": 2027, "month": 6, "day": 15, "hour": 8, "minute": 45, "second": 30})
	var result: Dictionary = _date_and_time.get_datetime_dict()
	assert_eq(result.year, 2027)
	assert_eq(result.month, 6)
	assert_eq(result.day, 15)
	assert_eq(result.hour, 8)
	assert_eq(result.minute, 45)
	assert_eq(result.second, 30)


func test_botw_display_text() -> void:
	var display: DateAndTimeDisplay = _make_display(true)
	display.minute_increment = 5
	assert_true(display._botw_box.visible)
	assert_false(display._standard_label.visible)
	_date_and_time.set_time(14, 27, 0)
	assert_eq(display.get_display_text(), "2:25", "14:27 rounds down to 2:25")
	assert_eq(display._rich_label.text, "[i]2:25[/i]")
	_date_and_time.set_time(0, 3, 0)
	assert_eq(display.get_display_text(), "12:00")
	display.show_date = true
	assert_eq(display.get_display_text(), "2026-01-01  12:00")


func test_standard_display_text() -> void:
	var display: DateAndTimeDisplay = _make_display(false)
	display.minute_increment = 0
	assert_false(display._botw_box.visible)
	assert_true(display._standard_label.visible)
	_date_and_time.set_time(14, 30, 0)
	assert_eq(display.get_display_text(), "02:30 PM")
	assert_eq(display._standard_label.text, "02:30 PM")
	display.use_12_hour = false
	display.show_seconds = true
	assert_eq(display.get_display_text(), "14:30:00")
	display.date_and_time_node = null
	assert_eq(display.get_display_text(), "--:--")


func test_date_and_time_demo_scene_instantiation() -> void:
	var demo: Node = load("res://addons/date_and_time/scenes/demo/demo.tscn").instantiate()
	add_child_autofree(demo)
	assert_not_null(demo.date_and_time)
	assert_almost_eq(demo.date_and_time.minutes_per_day, 1.0, 0.001, "Demo defaults to 24x pace")
	assert_eq(demo.speed_option_button.item_count, 5)
	assert_true(demo.date_and_time.time_changed.is_connected(demo._on_time_changed), "Scene wires DateAndTime signals")

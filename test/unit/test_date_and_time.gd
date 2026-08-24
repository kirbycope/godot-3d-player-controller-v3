extends GutTest

var dt: DateAndTime


func before_each() -> void:
	dt = DateAndTime.new()
	add_child_autofree(dt)


func test_initial_values() -> void:
	assert_eq(dt.day, 1)
	assert_eq(dt.month, 1)
	assert_eq(dt.year, 2026)
	assert_true(dt.is_running)


func test_time_formatting() -> void:
	dt.set_time(14, 30, 45)
	assert_eq(dt.get_hour(), 14)
	assert_eq(dt.get_minute(), 30)
	assert_eq(dt.get_second(), 45)
	assert_eq(dt.get_formatted_time(), "14:30:45")


func test_date_formatting() -> void:
	dt.set_date(2026, 8, 16)
	assert_eq(dt.get_formatted_date(), "2026-08-16")


func test_leap_year() -> void:
	dt.year = 2024
	assert_true(dt.is_leap_year())
	dt.month = 2
	assert_eq(dt.max_days_per_month(), 29)

	dt.year = 2025
	assert_false(dt.is_leap_year())
	assert_eq(dt.max_days_per_month(), 28)


func test_time_wrapping_advances_day() -> void:
	dt.set_date(2026, 1, 1)
	dt.set_time(23, 0, 0)
	dt.add_hours(2.0)
	assert_eq(dt.day, 2)
	assert_almost_eq(dt.current_time, 1.0, 0.001)


func test_play_pause() -> void:
	dt.play()
	assert_true(dt.is_running)
	dt.pause()
	assert_false(dt.is_running)
	dt.toggle_pause()
	assert_true(dt.is_running)


func test_datetime_dict_conversion() -> void:
	var target_dict: Dictionary = {
		"year": 2026,
		"month": 12,
		"day": 25,
		"hour": 10,
		"minute": 15,
		"second": 0,
	}
	dt.set_from_datetime_dict(target_dict)
	var out_dict: Dictionary = dt.get_datetime_dict()
	assert_eq(out_dict.year, 2026)
	assert_eq(out_dict.month, 12)
	assert_eq(out_dict.day, 25)
	assert_eq(out_dict.hour, 10)
	assert_eq(out_dict.minute, 15)


func test_botw_time_display_rounding_and_format() -> void:
	var display: DateAndTimeDisplay = DateAndTimeDisplay.new()
	display.date_and_time_node = dt
	display.botw_style = true
	display.minute_increment = 5
	display.use_12_hour = true
	add_child_autofree(display)

	# 14:27 should round down to 14:25, which in 12-hour is 2:25
	dt.set_time(14, 27, 0)
	assert_eq(display._rtl.text, "[i]2:25[/i]")

	# 0:03 should round to 12:00
	dt.set_time(0, 3, 0)
	assert_eq(display._rtl.text, "[i]12:00[/i]")


func test_standard_time_display_format() -> void:
	var display: DateAndTimeDisplay = DateAndTimeDisplay.new()
	display.date_and_time_node = dt
	display.botw_style = false
	display.minute_increment = 0
	display.use_12_hour = true
	add_child_autofree(display)

	dt.set_time(14, 30, 0)
	assert_eq(display._standard_label.text, "02:30 PM")

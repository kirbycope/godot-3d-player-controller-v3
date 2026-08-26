extends GutTest

var _date_and_time: DateAndTime

func before_each():
	_date_and_time = DateAndTime.new()
	_date_and_time.is_running = false
	_date_and_time.editor_time_enabled = false
	_date_and_time.system_sync = false
	add_child_autofree(_date_and_time)

func test_initial_values():
	assert_eq(_date_and_time.year, 2026, "Default year should be 2026")
	assert_eq(_date_and_time.month, 1, "Default month should be 1")
	assert_eq(_date_and_time.day, 1, "Default day should be 1")
	assert_almost_eq(_date_and_time.current_time, 12.0, 0.001, "Default time should be 12.0")

func test_set_time():
	_date_and_time.set_time(14, 30, 15)
	assert_eq(_date_and_time.get_hour(), 14)
	assert_eq(_date_and_time.get_minute(), 30)
	assert_eq(_date_and_time.get_second(), 15)
	assert_eq(_date_and_time.get_formatted_time(), "14:30:15")

func test_set_date():
	_date_and_time.set_date(2025, 12, 25)
	assert_eq(_date_and_time.year, 2025)
	assert_eq(_date_and_time.month, 12)
	assert_eq(_date_and_time.day, 25)
	assert_eq(_date_and_time.get_formatted_date(), "2025-12-25")

func test_leap_year():
	_date_and_time.year = 2024
	assert_true(_date_and_time.is_leap_year(), "2024 is a leap year")
	_date_and_time.month = 2
	assert_eq(_date_and_time.max_days_per_month(), 29, "Feb in 2024 has 29 days")

	_date_and_time.year = 2023
	assert_false(_date_and_time.is_leap_year(), "2023 is not a leap year")
	_date_and_time.month = 2
	assert_eq(_date_and_time.max_days_per_month(), 28, "Feb in 2023 has 28 days")

	_date_and_time.year = 1900
	assert_false(_date_and_time.is_leap_year(), "1900 is not a leap year")
	_date_and_time.year = 2000
	assert_true(_date_and_time.is_leap_year(), "2000 is a leap year")

func test_time_wrapping_forward():
	_date_and_time.set_date(2026, 1, 31)
	_date_and_time.current_time = 23.0
	_date_and_time.add_hours(2.0)
	assert_almost_eq(_date_and_time.current_time, 1.0, 0.001)
	assert_eq(_date_and_time.day, 1, "Should wrap to day 1")
	assert_eq(_date_and_time.month, 2, "Should wrap to Feb")

func test_is_day():
	_date_and_time.set_time(12, 0, 0)
	assert_true(_date_and_time.is_day(6.0, 18.0), "12:00 should be day")
	_date_and_time.set_time(22, 0, 0)
	assert_false(_date_and_time.is_day(6.0, 18.0), "22:00 should not be day")

func test_datetime_dict():
	var dict = {
		"year": 2027,
		"month": 6,
		"day": 15,
		"hour": 8,
		"minute": 45,
		"second": 30
	}
	_date_and_time.set_from_datetime_dict(dict)
	var result = _date_and_time.get_datetime_dict()
	assert_eq(result.year, 2027)
	assert_eq(result.month, 6)
	assert_eq(result.day, 15)
	assert_eq(result.hour, 8)
	assert_eq(result.minute, 45)
	assert_eq(result.second, 30)

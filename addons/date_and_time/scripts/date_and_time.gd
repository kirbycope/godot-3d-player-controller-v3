# Copyright (c) 2023-2025 Cory Petkovsek and Contributors
# Copyright (c) 2021 J. Cuellar
# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name DateAndTime
extends Node

## DateAndTime tracks in-game and in-editor time progression, calendar dates, and signals.
## A child Timer ticks once per in-game minute (or once per real second while `system_sync`
## is on); every tick advances `current_time` and emits `time_changed`.

signal time_changed(current_time: float)
signal minute_changed(minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal month_changed(month: int)
signal year_changed(year: int)
signal clock_paused()
signal clock_resumed()

const HOURS_PER_DAY: float = 24.0
const MINUTES_PER_HOUR: float = 60.0
## Ticks are never scheduled closer together than this; faster paces advance several minutes per tick.
const MIN_TICK_SECONDS: float = 1.0 / 60.0

var _previous_minute: int = -1
var _previous_hour: int = -1
var _minutes_per_tick: int = 1
var _tick_timer: Timer = Timer.new()

@export_group("Clock Controls")

## Starts or stops automatic time progression.
@export var is_running: bool = true:
	set(value):
		if is_running == value:
			return
		is_running = value
		_update_timer()
		if is_running:
			clock_resumed.emit()
		else:
			clock_paused.emit()

## Allows time to progress in the editor when is_running is true.
@export var editor_time_enabled: bool = true:
	set(value):
		editor_time_enabled = value
		_update_timer()

## The real-world minutes for a full 24-hour in-game day (e.g. 24.0 means 1 real minute = 1 in-game hour).
@export_range(0.1, 1440.0, 0.1) var minutes_per_day: float = 24.0:
	set(value):
		minutes_per_day = value
		_update_timer()

## Speed multiplier for time progression.
@export_range(0.0, 100.0, 0.1) var time_scale: float = 1.0:
	set(value):
		time_scale = value
		_update_timer()

## Synchronize with system (OS) clock in real-time.
@export var system_sync: bool = false:
	set(value):
		system_sync = value
		if system_sync:
			_update_time_from_os()
		_update_timer()

@export_group("Time & Date")

## The current in-game time in hours [0.0 .. 23.9999].
@export_range(0.0, 23.9999, 0.001) var current_time: float = 12.0:
	set(value):
		var old_value: float = current_time
		current_time = value
		_wrap_time()
		if not is_equal_approx(old_value, current_time):
			_notify_time_change()

## Current day of the month [1..31].
@export_range(1, 31) var day: int = 1:
	set(value):
		if day != value:
			day = value
			_wrap_date()
			day_changed.emit(day)

## Current month of the year [1..12].
@export_range(1, 12) var month: int = 1:
	set(value):
		if month != value:
			month = value
			_wrap_month()
			day = mini(day, max_days_per_month())
			month_changed.emit(month)

## Current year.
@export_range(-9999, 9999) var year: int = 2026:
	set(value):
		if year != value:
			year = value
			day = mini(day, max_days_per_month())
			year_changed.emit(year)


func _init() -> void:
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)


func _ready() -> void:
	_previous_minute = get_minute()
	_previous_hour = get_hour()
	if system_sync:
		_update_time_from_os()
	_update_timer()


func _update_timer() -> void:
	if not _tick_timer.is_inside_tree():
		return
	var can_progress: bool = is_running and (editor_time_enabled or not Engine.is_editor_hint())
	if not can_progress or (not system_sync and is_zero_approx(time_scale)):
		_tick_timer.stop()
		return
	if system_sync:
		_tick_timer.start(1.0)
		return
	var seconds_per_minute: float = minutes_per_day / (HOURS_PER_DAY * time_scale)
	_minutes_per_tick = maxi(1, ceili(MIN_TICK_SECONDS / seconds_per_minute))
	_tick_timer.start(seconds_per_minute * _minutes_per_tick)


func _on_tick() -> void:
	if system_sync:
		_update_time_from_os()
	else:
		current_time += _minutes_per_tick / MINUTES_PER_HOUR


func _wrap_time() -> void:
	while current_time >= HOURS_PER_DAY:
		current_time -= HOURS_PER_DAY
		day += 1
	while current_time < 0.0:
		current_time += HOURS_PER_DAY
		day -= 1


func _wrap_date() -> void:
	while day > max_days_per_month():
		day -= max_days_per_month()
		month += 1
	while day < 1:
		month -= 1
		day += max_days_per_month()


func _wrap_month() -> void:
	while month > 12:
		month -= 12
		year += 1
	while month < 1:
		month += 12
		year -= 1


func _notify_time_change() -> void:
	time_changed.emit(current_time)
	var new_hour: int = get_hour()
	var new_minute: int = get_minute()
	if new_hour != _previous_hour:
		_previous_hour = new_hour
		hour_changed.emit(new_hour)
	if new_minute != _previous_minute:
		_previous_minute = new_minute
		minute_changed.emit(new_minute)


func _update_time_from_os() -> void:
	set_from_datetime_dict(Time.get_datetime_dict_from_system())


## Stops the clock (pauses and resets time to 0:00:00).
func stop() -> void:
	is_running = false
	current_time = 0.0


## Sets current time from hours, minutes, and seconds.
func set_time(h: int, m: int = 0, s: int = 0) -> void:
	current_time = float(h) + float(m) / 60.0 + float(s) / 3600.0


## Sets current date.
func set_date(p_year: int, p_month: int, p_day: int) -> void:
	year = p_year
	month = p_month
	day = p_day


## Adds hours to current time (can be fractional or negative).
func add_hours(amount: float) -> void:
	current_time += amount


## Returns current hour as an integer [0..23].
func get_hour() -> int:
	return int(floor(current_time))


## Returns current minute as an integer [0..59].
func get_minute() -> int:
	return int(floor(fmod(current_time, 1.0) * 60.0))


## Returns current second as an integer [0..59].
func get_second() -> int:
	return int(floor(fmod(current_time * 60.0, 1.0) * 60.0))


## Returns true if current year is a leap year.
func is_leap_year() -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


## Returns total days in current month.
func max_days_per_month() -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		2:
			return 29 if is_leap_year() else 28
		_:
			return 30


## Returns true if time is considered daytime (default 6:00 AM to 6:00 PM).
func is_day(sunrise_hour: float = 6.0, sunset_hour: float = 18.0) -> bool:
	if sunrise_hour <= sunset_hour:
		return current_time >= sunrise_hour and current_time < sunset_hour
	return current_time >= sunrise_hour or current_time < sunset_hour


## Formatted time string "HH:MM:SS".
func get_formatted_time() -> String:
	return "%02d:%02d:%02d" % [get_hour(), get_minute(), get_second()]


## Formatted date string "YYYY-MM-DD".
func get_formatted_date() -> String:
	return "%04d-%02d-%02d" % [year, month, day]


## Returns dictionary compatible with Godot's Time datetime dict.
func get_datetime_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"hour": get_hour(),
		"minute": get_minute(),
		"second": get_second(),
	}


## Sets date and time from datetime dictionary.
func set_from_datetime_dict(dict: Dictionary) -> void:
	set_date(dict.get("year", year), dict.get("month", month), dict.get("day", day))
	set_time(dict.get("hour", 0), dict.get("minute", 0), dict.get("second", 0))


## Returns Unix timestamp for the current in-game datetime.
func get_unix_timestamp() -> int:
	return Time.get_unix_time_from_datetime_dict(get_datetime_dict())


## Sets datetime from Unix timestamp.
func set_from_unix_timestamp(timestamp: int) -> void:
	set_from_datetime_dict(Time.get_datetime_dict_from_unix_time(timestamp))

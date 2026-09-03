# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Demo controller for DateAndTime showcasing time flow, day/night lighting,
## calendar progression, and HUD styling options. UI signals are wired in demo.tscn.

@onready var date_and_time: DateAndTime = $DateAndTime
@onready var date_and_time_display: DateAndTimeDisplay = %DateAndTimeDisplay
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var time_slider: HSlider = %TimeSlider
@onready var time_value_label: Label = %TimeValueLabel
@onready var play_pause_button: Button = %PlayPauseButton
@onready var speed_option_button: OptionButton = %SpeedOptionButton
@onready var format_button: Button = %FormatButton
@onready var show_date_button: Button = %ShowDateButton
@onready var rounding_button: Button = %RoundingButton
@onready var sync_os_button: Button = %SyncOSButton
@onready var day_spinbox: SpinBox = %DaySpinBox
@onready var month_spinbox: SpinBox = %MonthSpinBox
@onready var year_spinbox: SpinBox = %YearSpinBox
@onready var status_label: Label = %StatusLabel

var _camera_distance: float = 8.0
var _camera_yaw: float = 30.0
var _camera_pitch: float = -15.0
var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	day_spinbox.set_value_no_signal(date_and_time.day)
	month_spinbox.set_value_no_signal(date_and_time.month)
	year_spinbox.set_value_no_signal(date_and_time.year)
	play_pause_button.text = "Pause" if date_and_time.is_running else "Resume"
	format_button.text = "12h" if date_and_time_display.use_12_hour else "24h"
	show_date_button.text = "Date: ON" if date_and_time_display.show_date else "Date: OFF"
	rounding_button.text = "%d Min Round" % date_and_time_display.minute_increment if date_and_time_display.minute_increment > 0 else "Exact Min"
	sync_os_button.text = "OS Sync: ON" if date_and_time.system_sync else "OS Sync: OFF"
	_on_time_changed(date_and_time.current_time)


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		_camera_yaw += 60.0 * delta
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		_camera_yaw -= 60.0 * delta
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		_camera_pitch = clampf(_camera_pitch + 40.0 * delta, -80.0, 80.0)
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		_camera_pitch = clampf(_camera_pitch - 40.0 * delta, -80.0, 80.0)
	camera_pivot.rotation_degrees = Vector3(_camera_pitch, _camera_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _camera_distance)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = button.pressed
			_last_mouse_pos = button.position
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = clampf(_camera_distance - 0.8, 2.0, 30.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 0.8, 2.0, 30.0)
	elif event is InputEventMouseMotion and _is_dragging:
		var motion: InputEventMouseMotion = event
		var delta_pos: Vector2 = motion.position - _last_mouse_pos
		_last_mouse_pos = motion.position
		_camera_yaw -= delta_pos.x * 0.4
		_camera_pitch = clampf(_camera_pitch - delta_pos.y * 0.4, -80.0, 80.0)


func _on_time_changed(t: float) -> void:
	time_slider.set_value_no_signal(t)
	time_value_label.text = date_and_time.get_formatted_time()
	var is_day: bool = date_and_time.is_day()
	sun_light.rotation = Vector3(-((t - 6.0) / 24.0) * TAU, deg_to_rad(-30.0), 0.0)
	sun_light.light_energy = 1.0 if is_day else 0.15
	sun_light.light_color = Color(1.0, 0.95, 0.85) if is_day else Color(0.35, 0.45, 0.7)
	_update_status_display()


func _update_status_display() -> void:
	status_label.text = "Time: %s\nDate: %s\nState: %s\nRunning: %s (Scale: %.1fx)" % [
		date_and_time.get_formatted_time(),
		date_and_time.get_formatted_date(),
		"Daytime (Sun)" if date_and_time.is_day() else "Nighttime (Moon)",
		"YES" if date_and_time.is_running else "PAUSED",
		date_and_time.time_scale,
	]


func _on_time_slider_changed(value: float) -> void:
	date_and_time.current_time = value


func _on_play_pause_pressed() -> void:
	date_and_time.is_running = not date_and_time.is_running
	play_pause_button.text = "Pause" if date_and_time.is_running else "Resume"


func _on_speed_selected(index: int) -> void:
	date_and_time.minutes_per_day = 24.0 / float(speed_option_button.get_item_id(index))


func _on_format_pressed() -> void:
	date_and_time_display.use_12_hour = not date_and_time_display.use_12_hour
	format_button.text = "12h" if date_and_time_display.use_12_hour else "24h"


func _on_show_date_pressed() -> void:
	date_and_time_display.show_date = not date_and_time_display.show_date
	show_date_button.text = "Date: ON" if date_and_time_display.show_date else "Date: OFF"


func _on_rounding_pressed() -> void:
	match date_and_time_display.minute_increment:
		5:
			date_and_time_display.minute_increment = 0
			rounding_button.text = "Exact Min"
		0:
			date_and_time_display.minute_increment = 10
			rounding_button.text = "10 Min Round"
		_:
			date_and_time_display.minute_increment = 5
			rounding_button.text = "5 Min Round"


func _on_sync_os_pressed() -> void:
	date_and_time.system_sync = not date_and_time.system_sync
	sync_os_button.text = "OS Sync: ON" if date_and_time.system_sync else "OS Sync: OFF"


func _on_day_spin_box_value_changed(value: float) -> void:
	date_and_time.day = int(value)


func _on_month_spin_box_value_changed(value: float) -> void:
	date_and_time.month = int(value)


func _on_year_spin_box_value_changed(value: float) -> void:
	date_and_time.year = int(value)


func _on_day_changed(new_day: int) -> void:
	day_spinbox.set_value_no_signal(new_day)


func _on_month_changed(new_month: int) -> void:
	month_spinbox.set_value_no_signal(new_month)


func _on_year_changed(new_year: int) -> void:
	year_spinbox.set_value_no_signal(new_year)

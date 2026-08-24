# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Demo controller for DateAndTime showcasing time flow, day/night lighting,
## calendar progression, and HUD styling options.

@onready var date_and_time: DateAndTime = $DateAndTime
@onready var date_and_time_display: DateAndTimeDisplay = %DateAndTimeDisplay
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

# UI Nodes
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
	_setup_speed_options()
	_setup_ui_signals()
	_update_ui_state()


func _process(delta: float) -> void:
	_update_sun_lighting()
	_update_status_display()
	_handle_camera_input(delta)


# ------------------------------------------------------------------------------
# UI Setup
# ------------------------------------------------------------------------------
func _setup_speed_options() -> void:
	speed_option_button.clear()
	speed_option_button.add_item("1x (24 min/day)", 1)
	speed_option_button.add_item("5x (4.8 min/day)", 5)
	speed_option_button.add_item("24x (1 min/day)", 24)
	speed_option_button.add_item("60x (24 sec/day)", 60)
	speed_option_button.add_item("300x (5 sec/day)", 300)
	speed_option_button.selected = 2  # Default to 24x (1 min full day) for good demo pacing
	date_and_time.minutes_per_day = 1.0


func _setup_ui_signals() -> void:
	time_slider.value_changed.connect(_on_time_slider_changed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	speed_option_button.item_selected.connect(_on_speed_selected)
	format_button.pressed.connect(_on_format_pressed)
	show_date_button.pressed.connect(_on_show_date_pressed)
	rounding_button.pressed.connect(_on_rounding_pressed)
	sync_os_button.pressed.connect(_on_sync_os_pressed)

	day_spinbox.value_changed.connect(func(v): date_and_time.day = int(v))
	month_spinbox.value_changed.connect(func(v): date_and_time.month = int(v))
	year_spinbox.value_changed.connect(func(v): date_and_time.year = int(v))

	date_and_time.time_changed.connect(_on_time_changed)
	date_and_time.day_changed.connect(func(d): day_spinbox.set_value_no_signal(d))
	date_and_time.month_changed.connect(func(m): month_spinbox.set_value_no_signal(m))
	date_and_time.year_changed.connect(func(y): year_spinbox.set_value_no_signal(y))


# ------------------------------------------------------------------------------
# UI Callbacks
# ------------------------------------------------------------------------------
func _on_time_slider_changed(value: float) -> void:
	date_and_time.current_time = value
	time_value_label.text = date_and_time.get_formatted_time()


func _on_time_changed(t: float) -> void:
	time_slider.set_value_no_signal(t)
	time_value_label.text = date_and_time.get_formatted_time()


func _on_play_pause_pressed() -> void:
	date_and_time.is_running = not date_and_time.is_running
	play_pause_button.text = "Resume" if not date_and_time.is_running else "Pause"


func _on_speed_selected(index: int) -> void:
	var mult = speed_option_button.get_item_id(index)
	date_and_time.minutes_per_day = 24.0 / float(mult)


func _on_format_pressed() -> void:
	date_and_time_display.use_12_hour = not date_and_time_display.use_12_hour
	format_button.text = "12h" if date_and_time_display.use_12_hour else "24h"


func _on_show_date_pressed() -> void:
	date_and_time_display.show_date = not date_and_time_display.show_date
	show_date_button.text = "Date: ON" if date_and_time_display.show_date else "Date: OFF"


func _on_rounding_pressed() -> void:
	if date_and_time_display.minute_increment == 5:
		date_and_time_display.minute_increment = 0
		rounding_button.text = "Exact Min"
	elif date_and_time_display.minute_increment == 0:
		date_and_time_display.minute_increment = 10
		rounding_button.text = "10 Min Round"
	else:
		date_and_time_display.minute_increment = 5
		rounding_button.text = "5 Min Round"


func _on_sync_os_pressed() -> void:
	date_and_time.system_sync = not date_and_time.system_sync
	sync_os_button.text = "OS Sync: ON" if date_and_time.system_sync else "OS Sync: OFF"


# ------------------------------------------------------------------------------
# State Updates & Environment
# ------------------------------------------------------------------------------
func _update_ui_state() -> void:
	time_slider.set_value_no_signal(date_and_time.current_time)
	time_value_label.text = date_and_time.get_formatted_time()
	day_spinbox.set_value_no_signal(date_and_time.day)
	month_spinbox.set_value_no_signal(date_and_time.month)
	year_spinbox.set_value_no_signal(date_and_time.year)
	play_pause_button.text = "Pause" if date_and_time.is_running else "Resume"
	format_button.text = "12h" if date_and_time_display.use_12_hour else "24h"
	show_date_button.text = "Date: ON" if date_and_time_display.show_date else "Date: OFF"
	rounding_button.text = "%d Min Round" % date_and_time_display.minute_increment if date_and_time_display.minute_increment > 0 else "Exact Min"
	sync_os_button.text = "OS Sync: ON" if date_and_time.system_sync else "OS Sync: OFF"


func _update_status_display() -> void:
	var t_str = date_and_time.get_formatted_time()
	var d_str = date_and_time.get_formatted_date()
	var is_day = date_and_time.current_time >= 6.0 and date_and_time.current_time < 18.0
	var cycle_state = "Daytime (Sun)" if is_day else "Nighttime (Moon)"

	status_label.text = "Time: %s\nDate: %s\nState: %s\nRunning: %s (Scale: %.1fx)" % [
		t_str,
		d_str,
		cycle_state,
		"YES" if date_and_time.is_running else "PAUSED",
		date_and_time.time_scale
	]


func _update_sun_lighting() -> void:
	if not is_instance_valid(sun_light):
		return
	var t = date_and_time.current_time
	# Map 0h - 24h to sun angle
	var sun_rot_x = ((t - 6.0) / 24.0) * TAU
	sun_light.rotation = Vector3(-sun_rot_x, deg_to_rad(-30.0), 0.0)
	
	var is_day = t >= 6.0 and t < 18.0
	sun_light.light_energy = 1.0 if is_day else 0.15
	sun_light.light_color = Color(1.0, 0.95, 0.85) if is_day else Color(0.35, 0.45, 0.7)


# ------------------------------------------------------------------------------
# Interactive Camera Controls
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = clampf(_camera_distance - 0.8, 2.0, 30.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 0.8, 2.0, 30.0)

	elif event is InputEventMouseMotion and _is_dragging:
		var delta_pos = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta_pos.x * 0.4
		_camera_pitch = clampf(_camera_pitch - delta_pos.y * 0.4, -80.0, 80.0)


func _handle_camera_input(delta: float) -> void:
	if not is_instance_valid(camera_pivot) or not is_instance_valid(camera):
		return

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

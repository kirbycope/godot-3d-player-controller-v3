# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Demo controller for the radi-ot 3D radio addon. Buttons are wired in demo.tscn.

const AUDIO_SPACE_NEEDLE: AudioStream = preload(
	"res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3"
)
const AUDIO_COASTAL_WIND: AudioStream = preload(
	"res://addons/radi_ot/assets/audio/eleven_labs/david/weather_alert_coastal_wind.mp3"
)
const HINT_TEXT: String = "[J] Prev Station   [L] Next Station   [M] Power"

@export var radio_player: RadiOtPlayer3D

var _camera_distance: float = 4.0
var _camera_height: float = 1.6
var _camera_angle_offset: float = 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var click_to_start: CanvasLayer = $ClickToStart


func _ready() -> void:
	if radio_player == null:
		return
	radio_player.get_hud().hint_text = HINT_TEXT
	var horiz_dist: float = Vector2(_camera.position.x, _camera.position.z).length()
	_camera_distance = horiz_dist if horiz_dist > 0.0 else 4.0
	_camera_height = _camera.position.y
	if _camera.position.x != 0.0 or _camera.position.z != 0.0:
		_camera_angle_offset = atan2(_camera.position.x, _camera.position.z)
	# Browsers block audio until the page receives a click or touch.
	click_to_start.visible = OS.has_feature("web")


func _input(event: InputEvent) -> void:
	if click_to_start.visible and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		click_to_start.hide()
		radio_player.tune_to_station_index(0)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or radio_player == null or not radio_player.is_power_on():
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key_event: InputEventKey = event
	if key_event.physical_keycode == KEY_L or key_event.keycode == KEY_L:
		radio_player.tune_next_station()
	elif key_event.physical_keycode == KEY_J or key_event.keycode == KEY_J:
		radio_player.tune_previous_station()
	elif key_event.physical_keycode == KEY_M or key_event.keycode == KEY_M:
		radio_player.toggle_power()


func _process(_delta: float) -> void:
	var time: float = (Time.get_ticks_msec() / 1000.0 * 0.2) + _camera_angle_offset
	_camera.position = Vector3(sin(time) * _camera_distance, _camera_height, cos(time) * _camera_distance)
	_camera.look_at(Vector3(0.0, 0.5, 0.0))


func _on_bulletin_btn_1_pressed() -> void:
	radio_player.urgent_bulletin(
		AUDIO_SPACE_NEEDLE,
		"Unidentified phenomena reported over the Space Needle! Citizens are advised to stay indoors."
	)


func _on_bulletin_btn_2_pressed() -> void:
	radio_player.urgent_bulletin(
		AUDIO_COASTAL_WIND,
		"Severe coastal wind advisory in effect across Puget Sound and SR-99 Alaskan Way."
	)


func _on_cancel_bulletin_btn_pressed() -> void:
	radio_player.cancel_bulletin()


func _on_previous_station_pressed() -> void:
	radio_player.tune_previous_station()


func _on_next_station_pressed() -> void:
	radio_player.tune_next_station()

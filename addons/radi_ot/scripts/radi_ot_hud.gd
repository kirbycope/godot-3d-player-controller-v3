@tool
class_name RadiOtHUD
extends CanvasLayer

## CanvasLayer HUD display for radi-ot Seattle radio station information,
## frequency dial, signal visualizer, keyboard hints, and emergency bulletin ticker.

@export var show_tuning_hints: bool = true
@export var auto_hide_after_seconds: float = 6.0

var _auto_hide_timer: float = 0.0
var _is_bulletin_active: bool = false
var _target_frequency: float = 90.3
var _displayed_frequency: float = 90.3
var _power_on: bool = true

@onready var _panel_container: Control = $Control/PanelContainer as Control
@onready var _logo_rect: TextureRect = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/LogoTextureRect as TextureRect
@onready var _station_name_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StationNameLabel as Label
@onready var _frequency_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/FrequencyLabel as Label
@onready var _tagline_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/TaglineLabel as Label
@onready var _genre_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/GenreLabel as Label
@onready var _status_badge: Control = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StatusBadge as Control
@onready var _status_dot: TextureRect = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StatusBadge/StatusDot as TextureRect
@onready var _status_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StatusBadge/StatusLabel as Label
@onready var _dial_bar: ProgressBar = $Control/PanelContainer/MarginContainer/VBoxContainer/DialContainer/DialProgressBar as ProgressBar
@onready var _bulletin_banner: PanelContainer = $Control/BulletinBanner as PanelContainer
@onready var _bulletin_text_label: Label = $Control/BulletinBanner/MarginContainer/HBoxContainer/BulletinLabel as Label
@onready var _hint_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/HintLabel as Label


func _ready() -> void:
	if _dial_bar != null:
		_dial_bar.min_value = 88.0
		_dial_bar.max_value = 108.0
	if _bulletin_banner != null:
		_bulletin_banner.visible = false
	if _hint_label != null:
		_hint_label.visible = show_tuning_hints
	_auto_hide_timer = auto_hide_after_seconds


func _process(delta: float) -> void:
	# Smoothly animate frequency dial towards target
	if absf(_displayed_frequency - _target_frequency) > 0.01:
		_displayed_frequency = move_toward(_displayed_frequency, _target_frequency, delta * 30.0)
		if _dial_bar != null:
			_dial_bar.value = _displayed_frequency

	# Auto hide panel if idle and not in bulletin
	if auto_hide_after_seconds > 0.0 and not _is_bulletin_active:
		if _auto_hide_timer > 0.0:
			_auto_hide_timer -= delta
			if _panel_container != null:
				_panel_container.modulate.a = move_toward(_panel_container.modulate.a, 1.0, delta * 4.0)
		else:
			if _panel_container != null:
				_panel_container.modulate.a = move_toward(_panel_container.modulate.a, 0.4, delta * 2.0)


func show_hud() -> void:
	_auto_hide_timer = auto_hide_after_seconds
	if _panel_container != null:
		_panel_container.modulate.a = 1.0


func update_station_info(station: RadioStation) -> void:
	show_hud()
	if station == null:
		if _logo_rect != null:
			_logo_rect.texture = null
			_logo_rect.visible = false
		if _station_name_label != null:
			_station_name_label.text = "RADIO OFF"
		if _frequency_label != null:
			_frequency_label.text = "--.- MHz"
		if _tagline_label != null:
			_tagline_label.text = "Press [M] to power on"
		if _genre_label != null:
			_genre_label.text = ""
		return

	_target_frequency = station.frequency

	if _logo_rect != null:
		_logo_rect.texture = station.logo
		_logo_rect.visible = station.logo != null

	if _station_name_label != null:
		_station_name_label.text = "%s - %s" % [station.call_sign, station.station_name]
	if _frequency_label != null:
		_frequency_label.text = station.get_display_frequency()
	if _tagline_label != null:
		_tagline_label.text = station.tagline
	if _genre_label != null:
		_genre_label.text = "• %s •" % station.genre.to_upper()


func set_buffering_state(is_buffering: bool) -> void:
	if _status_badge == null:
		return

	if is_buffering:
		if _status_label != null:
			_status_label.text = "TUNING..."
		_status_badge.modulate = Color(1.0, 0.8, 0.2)
	else:
		if _status_label != null:
			_status_label.text = "ON AIR"
		_status_badge.modulate = Color(0.2, 1.0, 0.5)


func set_power_state(is_on: bool) -> void:
	_power_on = is_on
	show_hud()
	if _status_badge != null:
		if is_on:
			if _status_label != null:
				_status_label.text = "ON AIR"
			_status_badge.modulate = Color(0.2, 1.0, 0.5)
		else:
			if _status_label != null:
				_status_label.text = "POWER OFF"
			_status_badge.modulate = Color(0.6, 0.6, 0.6)


func show_urgent_bulletin(text: String) -> void:
	_is_bulletin_active = true
	show_hud()

	if _bulletin_banner != null:
		_bulletin_banner.visible = true
	if _bulletin_text_label != null:
		_bulletin_text_label.text = "[EMERGENCY SEATTLE BROADCAST] %s" % text


func hide_urgent_bulletin() -> void:
	_is_bulletin_active = false
	if _bulletin_banner != null:
		_bulletin_banner.visible = false
	show_hud()

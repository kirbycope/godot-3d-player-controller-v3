@tool
class_name RadiOtHUD
extends CanvasLayer

## CanvasLayer HUD for radi-ot: station info, animated frequency dial, signal badge, optional key
## hints and the emergency bulletin banner. The panel auto-hides via the AutoHideTimer child.

const FADE_SECONDS: float = 0.5
const DIAL_MHZ_PER_SECOND: float = 30.0

@export_group("HUD Settings")
## Fade the panel out `toast_hide_seconds` after it was last shown (bulletins keep it visible).
@export var toast_hide: bool = true
@export var toast_hide_seconds: float = 5.0
## Key hints shown under the dial; empty hides the hint row. Set it from the scene that binds the keys.
@export var hint_text: String = "":
	set(value):
		hint_text = value
		if is_node_ready():
			_hint_label.text = hint_text
			_hint_label.visible = not hint_text.is_empty()

var _is_bulletin_active: bool = false
var _fade_tween: Tween

@onready var _panel_container: PanelContainer = %PanelContainer
@onready var _logo_rect: TextureRect = %LogoTextureRect
@onready var _station_name_label: Label = %StationNameLabel
@onready var _frequency_label: Label = %FrequencyLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _genre_label: Label = %GenreLabel
@onready var _status_badge: HBoxContainer = %StatusBadge
@onready var _status_label: Label = %StatusLabel
@onready var _dial_bar: ProgressBar = %DialProgressBar
@onready var _bulletin_banner: PanelContainer = %BulletinBanner
@onready var _bulletin_text_label: Label = %BulletinLabel
@onready var _hint_label: Label = %HintLabel
@onready var _auto_hide_timer: Timer = %AutoHideTimer


func _ready() -> void:
	_hint_label.text = hint_text
	_hint_label.visible = not hint_text.is_empty()
	_panel_container.visible = not toast_hide
	_panel_container.modulate.a = 0.0 if toast_hide else 1.0


## Shows the panel; with `toast_hide` it fades out after `duration` (default `toast_hide_seconds`).
func show_hud(duration: float = -1.0) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_panel_container.visible = true
	_panel_container.modulate.a = 1.0
	if toast_hide:
		_auto_hide_timer.start(duration if duration > 0.0 else toast_hide_seconds)


func hide_hud() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_auto_hide_timer.stop()
	_panel_container.visible = false
	_panel_container.modulate.a = 0.0


func show_toast(duration: float = -1.0) -> void:
	show_hud(duration)


func hide_toast() -> void:
	hide_hud()


func update_station_info(station: RadioStation) -> void:
	show_hud()
	if station == null:
		_logo_rect.texture = null
		_logo_rect.visible = false
		_station_name_label.text = "RADIO OFF"
		_frequency_label.text = "--.- MHz"
		_tagline_label.text = "Powered off"
		_genre_label.text = ""
		return
	var dial_seconds: float = absf(_dial_bar.value - station.frequency) / DIAL_MHZ_PER_SECOND
	create_tween().tween_property(_dial_bar, "value", station.frequency, dial_seconds)
	_logo_rect.texture = station.logo
	_logo_rect.visible = station.logo != null
	_station_name_label.text = "%s - %s" % [station.call_sign, station.station_name]
	_frequency_label.text = station.get_display_frequency()
	_tagline_label.text = station.tagline
	_genre_label.text = "• %s •" % station.genre.to_upper()


func set_buffering_state(is_buffering: bool) -> void:
	_status_label.text = "TUNING..." if is_buffering else "ON AIR"
	_status_badge.modulate = Color(1.0, 0.8, 0.2) if is_buffering else Color(0.2, 1.0, 0.5)


func set_error_state(message: String) -> void:
	show_hud()
	_status_label.text = "NO SIGNAL"
	_status_badge.modulate = Color(1.0, 0.3, 0.3)
	_tagline_label.text = message


func set_power_state(is_on: bool) -> void:
	show_hud()
	_status_label.text = "ON AIR" if is_on else "POWER OFF"
	_status_badge.modulate = Color(0.2, 1.0, 0.5) if is_on else Color(0.6, 0.6, 0.6)


func show_urgent_bulletin(text: String) -> void:
	_is_bulletin_active = true
	show_hud()
	_auto_hide_timer.stop()
	_bulletin_banner.visible = true
	_bulletin_text_label.text = "[EMERGENCY SEATTLE BROADCAST] %s" % text


func hide_urgent_bulletin() -> void:
	_is_bulletin_active = false
	_bulletin_banner.visible = false
	show_hud()


func _on_auto_hide_timer_timeout() -> void:
	if _is_bulletin_active:
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel_container, "modulate:a", 0.0, FADE_SECONDS)
	_fade_tween.tween_callback(_panel_container.hide)

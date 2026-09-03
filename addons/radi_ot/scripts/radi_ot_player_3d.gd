@tool
@icon("res://addons/radi_ot/assets/icons/radio_icon.svg")
class_name RadiOtPlayer3D
extends AudioStreamPlayer3D

## 3D Seattle Radio Station streaming player for Godot 4.8.
## Instantiate res://addons/radi_ot/scenes/radi_ot_player_3d.tscn: the streamer, static and
## bulletin players, bulletin Timer and HUD are its children and are wired there. The node sits in
## the "radio" group so audio settings can call `set_volume()` on every radio in the tree.

signal station_changed(station: RadioStation)
signal stream_buffering_started
signal stream_playback_started
signal stream_playback_failed(error_message: String)
signal bulletin_started(bulletin_text: String)
signal bulletin_finished
signal radio_toggled(is_playing: bool)

@export var station_collection: RadioStationCollection

var current_station_index: int = 0:
	set(value):
		current_station_index = value
		if is_inside_tree():
			_tune_current_station()

@export_group("Audio")
@export var play_static_while_buffering: bool = true
@export var static_volume_db: float = -6.0
## Tunes the current station on ready. Ignored on web, where browsers block autoplay.
@export var auto_play_on_ready: bool = false

@export_group("HUD")
@export var enable_hud: bool = true:
	set(value):
		enable_hud = value
		if is_node_ready():
			_hud.visible = enable_hud

var _power_on: bool = true
var _is_bulletin_active: bool = false

@onready var _streamer: RadiOtStreamer = $RadiOtStreamer
@onready var _static_player: AudioStreamPlayer3D = $StaticPlayer3D
@onready var _bulletin_player: AudioStreamPlayer3D = $BulletinPlayer3D
@onready var _bulletin_timer: Timer = $BulletinTimer
@onready var _hud: RadiOtHUD = $RadiOtHUD


func _ready() -> void:
	_hud.visible = enable_hud
	_static_player.stream = RadiOtStaticGenerator.get_static_stream()
	_static_player.volume_db = static_volume_db
	for child: AudioStreamPlayer3D in [_static_player, _bulletin_player]:
		child.max_distance = max_distance
		child.unit_size = unit_size
		child.bus = bus
		child.attenuation_model = attenuation_model
		child.panning_strength = panning_strength
		child.doppler_tracking = doppler_tracking
	_streamer.set_volume(db_to_linear(volume_db))
	_hud.update_station_info(get_current_station())
	if not Engine.is_editor_hint() and auto_play_on_ready and _power_on and not OS.has_feature("web"):
		_tune_current_station()


# -----------------------------------------------------------------------------
# Public Radio Control API
# -----------------------------------------------------------------------------

func tune_next_station() -> void:
	tune_to_station_index(current_station_index + 1)


func tune_previous_station() -> void:
	tune_to_station_index(current_station_index - 1)


## Tunes to `index`, wrapping around the collection in both directions.
func tune_to_station_index(index: int) -> void:
	if station_collection == null or station_collection.stations.is_empty():
		return
	current_station_index = posmod(index, station_collection.stations.size())


func tune_to_frequency(frequency: float) -> void:
	if station_collection == null:
		return
	var idx: int = station_collection.find_closest_station_by_frequency(frequency)
	if idx >= 0:
		tune_to_station_index(idx)


func tune_to_call_sign(call_sign: String) -> void:
	if station_collection == null:
		return
	var idx: int = station_collection.find_station_by_call_sign(call_sign)
	if idx >= 0:
		tune_to_station_index(idx)


func toggle_power() -> void:
	set_power(not _power_on)


func set_power(is_enabled: bool) -> void:
	_power_on = is_enabled
	if _power_on:
		_tune_current_station()
	else:
		_stop_all_audio()
	_hud.set_power_state(_power_on)
	radio_toggled.emit(_power_on)


func is_power_on() -> bool:
	return _power_on


## Interrupts the live stream with a bulletin; live radio resumes when it finishes.
## `duration` defaults to the stream length (or 5 s without a stream).
func urgent_bulletin(stream: AudioStream, text: String, duration: float = 0.0) -> void:
	if not _power_on:
		set_power(true)
	_is_bulletin_active = true
	_static_player.stop()
	_streamer.pause_for_bulletin()
	_hud.show_urgent_bulletin(text)
	if stream != null:
		_bulletin_player.stream = stream
		_bulletin_player.play()
	bulletin_started.emit(text)
	if duration <= 0.0:
		duration = stream.get_length() + 0.15 if stream != null and stream.get_length() > 0.0 else 5.0
	_bulletin_timer.start(duration)


func cancel_bulletin() -> void:
	_on_bulletin_finished()


func is_bulletin_active() -> bool:
	return _is_bulletin_active


func is_buffering() -> bool:
	return _streamer.is_buffering()


func get_current_station() -> RadioStation:
	if station_collection == null:
		return null
	return station_collection.get_station_at(current_station_index)


func get_station_count() -> int:
	if station_collection == null:
		return 0
	return station_collection.get_station_count()


func get_hud() -> RadiOtHUD:
	return _hud


## Sets the linear volume of the stream, bulletin and this player (called through the "radio" group).
func set_volume(linear: float) -> void:
	volume_db = linear_to_db(linear) if linear > 0.0 else -80.0
	if is_node_ready():
		_bulletin_player.volume_db = volume_db
		_streamer.set_volume(linear)


# -----------------------------------------------------------------------------
# Internal audio routing
# -----------------------------------------------------------------------------

func _tune_current_station() -> void:
	if Engine.is_editor_hint():
		_hud.update_station_info(get_current_station())
		return
	if not _power_on or _is_bulletin_active:
		return
	var station: RadioStation = get_current_station()
	if station == null:
		return
	_hud.update_station_info(station)
	_hud.set_buffering_state(true)
	_streamer.play_station(station)
	station_changed.emit(station)


func _stop_all_audio() -> void:
	_streamer.stop()
	_static_player.stop()
	_bulletin_player.stop()
	_bulletin_timer.stop()
	_is_bulletin_active = false
	_hud.hide_urgent_bulletin()


func _on_buffering_started() -> void:
	if _is_bulletin_active:
		return
	if play_static_while_buffering and not _static_player.playing:
		_static_player.play()
	_hud.set_buffering_state(true)
	stream_buffering_started.emit()


func _on_playback_started() -> void:
	_static_player.stop()
	if not _is_bulletin_active:
		_hud.set_buffering_state(false)
	stream_playback_started.emit()


func _on_playback_failed(err_msg: String) -> void:
	_static_player.stop()
	if not _is_bulletin_active:
		_hud.set_error_state(err_msg)
	stream_playback_failed.emit(err_msg)


func _on_bulletin_finished() -> void:
	if not _is_bulletin_active:
		return
	_is_bulletin_active = false
	_bulletin_timer.stop()
	_bulletin_player.stop()
	_hud.hide_urgent_bulletin()
	if _power_on:
		if _streamer.is_playing():
			_streamer.resume_after_bulletin()
		else:
			_tune_current_station()
	bulletin_finished.emit()

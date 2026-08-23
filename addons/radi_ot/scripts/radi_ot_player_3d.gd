@tool
@icon("res://addons/radi_ot/assets/icons/radio_icon.svg")
class_name RadiOtPlayer3D
extends AudioStreamPlayer3D

## 3D Seattle Radio Station streaming player for Godot 4.8.
## Streams live radio, plays optional buffering static, provides CanvasLayer HUD
## and an urgent_bulletin() system for game narrative progression.

signal station_changed(station: RadioStation)
signal stream_buffering_started
signal stream_playback_started
signal stream_playback_failed(error_message: String)
signal bulletin_started(bulletin_text: String)
signal bulletin_finished
signal radio_toggled(is_playing: bool)

const DEFAULT_STATIONS_PATH: String = (
	"res://addons/radi_ot/resources/stations/seattle_stations_default.tres"
)

@export var station_collection: RadioStationCollection

var current_station_index: int = 0:
	set(value):
		current_station_index = value
		if is_inside_tree() and _power_on and not Engine.is_editor_hint():
			_tune_current_station()

@export_group("Audio")
@export var play_static_while_buffering: bool = true
@export var static_volume_db: float = -6.0
@export var auto_play_on_ready: bool = false

@export_group("HUD")
@export var enable_hud: bool = true

var _power_on: bool = true
var _is_bulletin_active: bool = false
var _streamer: RadiOtStreamer
var _static_player: AudioStreamPlayer3D
var _bulletin_player: AudioStreamPlayer3D
var _hud: RadiOtHUD
var _bulletin_timer: Timer


func _ready() -> void:
	if station_collection == null and ResourceLoader.exists(DEFAULT_STATIONS_PATH):
		station_collection = load(DEFAULT_STATIONS_PATH) as RadioStationCollection

	_setup_internal_nodes()

	if enable_hud and _hud != null:
		_hud.update_station_info(get_current_station())

	var is_web: bool = (
		OS.has_feature("web")
		or ProjectSettings.get_setting("rendering/renderer/rendering_method") not in ["forward_plus", "mobile"]
	)
	if not Engine.is_editor_hint() and auto_play_on_ready and _power_on and not is_web:
		_tune_current_station()


# -----------------------------------------------------------------------------
# Public Radio Control API
# -----------------------------------------------------------------------------

func tune_next_station() -> void:
	if station_collection == null or station_collection.get_station_count() == 0:
		return
	var count: int = station_collection.get_station_count()
	current_station_index = (current_station_index + 1) % count
	_tune_current_station()


func tune_previous_station() -> void:
	if station_collection == null or station_collection.get_station_count() == 0:
		return
	var count: int = station_collection.get_station_count()
	current_station_index = (current_station_index - 1 + count) % count
	_tune_current_station()


func tune_to_station_index(index: int) -> void:
	if station_collection == null or station_collection.get_station_count() == 0:
		return
	current_station_index = posmod(index, station_collection.get_station_count())
	_tune_current_station()


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
	if not _power_on:
		_stop_all_audio()
	else:
		_tune_current_station()

	if _hud != null:
		_hud.set_power_state(_power_on)
	radio_toggled.emit(_power_on)


func is_power_on() -> bool:
	return _power_on


func urgent_bulletin(stream: AudioStream, text: String, duration: float = 0.0) -> void:
	## Interrupts current radio stream to broadcast a fake/urgent news story.
	## Resumes live radio station when the bulletin finishes.
	if not _power_on:
		set_power(true)

	_is_bulletin_active = true
	_stop_static()

	if _streamer != null:
		_streamer.pause_for_bulletin()

	if _hud != null:
		_hud.show_urgent_bulletin(text)

	var stream_len: float = 0.0
	if stream != null:
		stream_len = stream.get_length()

	if _bulletin_player != null and stream != null and is_inside_tree():
		_bulletin_player.stream = stream
		_bulletin_player.play()

	bulletin_started.emit(text)

	var effective_duration: float = duration
	if effective_duration <= 0.0:
		if stream_len > 0.0:
			effective_duration = stream_len + 0.15
		else:
			effective_duration = 5.0

	if _bulletin_timer != null and _bulletin_timer.is_inside_tree():
		_bulletin_timer.start(effective_duration)


func cancel_bulletin() -> void:
	if not _is_bulletin_active:
		return
	_on_bulletin_finished()


func is_bulletin_active() -> bool:
	return _is_bulletin_active


func is_buffering() -> bool:
	if _streamer == null:
		return false
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


# -----------------------------------------------------------------------------
# Internal Setup & Audio Routing
# -----------------------------------------------------------------------------

func _setup_internal_nodes() -> void:
	# Streamer node
	if _streamer == null:
		_streamer = RadiOtStreamer.new()
		_streamer.name = "RadiOtStreamer"
		_streamer.set_target_player(self)
		add_child(_streamer)
		_streamer.buffering_started.connect(_on_buffering_started)
		_streamer.playback_started.connect(_on_playback_started)
		_streamer.playback_failed.connect(_on_playback_failed)

	# Static audio player
	if _static_player == null:
		_static_player = AudioStreamPlayer3D.new()
		_static_player.name = "StaticPlayer3D"
		_static_player.volume_db = static_volume_db
		_static_player.max_distance = max_distance
		_static_player.unit_size = unit_size
		_static_player.bus = bus
		_static_player.attenuation_model = attenuation_model
		_static_player.panning_strength = panning_strength
		_static_player.doppler_tracking = doppler_tracking
		_static_player.stream = RadiOtStaticGenerator.get_static_stream()
		add_child(_static_player)

	# Bulletin audio player
	if _bulletin_player == null:
		_bulletin_player = AudioStreamPlayer3D.new()
		_bulletin_player.name = "BulletinPlayer3D"
		_bulletin_player.volume_db = volume_db
		_bulletin_player.max_distance = max_distance
		_bulletin_player.unit_size = unit_size
		_bulletin_player.bus = bus
		_bulletin_player.attenuation_model = attenuation_model
		_bulletin_player.panning_strength = panning_strength
		_bulletin_player.doppler_tracking = doppler_tracking
		add_child(_bulletin_player)
		_bulletin_player.finished.connect(_on_bulletin_finished)

	# Bulletin timer
	if _bulletin_timer == null:
		_bulletin_timer = Timer.new()
		_bulletin_timer.one_shot = true
		add_child(_bulletin_timer)
		_bulletin_timer.timeout.connect(_on_bulletin_finished)

	# CanvasLayer HUD
	if enable_hud and _hud == null:
		var hud_scene: PackedScene = load("res://addons/radi_ot/scenes/radi_ot_hud.tscn")
		if hud_scene != null:
			_hud = hud_scene.instantiate() as RadiOtHUD
			add_child(_hud)


func _tune_current_station() -> void:
	if Engine.is_editor_hint():
		if _hud != null:
			_hud.update_station_info(get_current_station())
		return

	if not _power_on or _is_bulletin_active:
		return

	var station: RadioStation = get_current_station()
	if station == null:
		return

	if play_static_while_buffering:
		_play_static()

	if _hud != null:
		_hud.update_station_info(station)
		_hud.set_buffering_state(true)

	if _streamer != null:
		_streamer.play_station(station)

	station_changed.emit(station)


func _play_static() -> void:
	if Engine.is_editor_hint():
		return
	if _static_player != null and is_inside_tree() and not _static_player.playing:
		_static_player.volume_db = static_volume_db
		_static_player.play()


func _stop_static() -> void:
	if _static_player != null and is_inside_tree() and _static_player.playing:
		_static_player.stop()


func _stop_all_audio() -> void:
	if _streamer != null:
		_streamer.stop()
	_stop_static()
	if _bulletin_player != null and is_inside_tree() and _bulletin_player.playing:
		_bulletin_player.stop()
	if _bulletin_timer != null and is_inside_tree():
		_bulletin_timer.stop()
	_is_bulletin_active = false
	if _hud != null:
		_hud.hide_urgent_bulletin()


func _on_buffering_started() -> void:
	if play_static_while_buffering and not _is_bulletin_active:
		_play_static()
	if _hud != null and not _is_bulletin_active:
		_hud.set_buffering_state(true)
	stream_buffering_started.emit()


func _on_playback_started() -> void:
	_stop_static()
	if _hud != null and not _is_bulletin_active:
		_hud.set_buffering_state(false)
	stream_playback_started.emit()


func _on_playback_failed(err_msg: String) -> void:
	_stop_static()
	if _hud != null and not _is_bulletin_active:
		_hud.set_buffering_state(false)
	stream_playback_failed.emit(err_msg)


func _on_bulletin_finished() -> void:
	if not _is_bulletin_active:
		return

	_is_bulletin_active = false
	if _bulletin_timer != null and _bulletin_timer.is_inside_tree():
		_bulletin_timer.stop()
	if _bulletin_player != null and is_inside_tree() and _bulletin_player.playing:
		_bulletin_player.stop()

	if _hud != null:
		_hud.hide_urgent_bulletin()

	if _power_on:
		if _streamer != null and _streamer.is_playing():
			_streamer.resume_after_bulletin()
		else:
			_tune_current_station()

	bulletin_finished.emit()

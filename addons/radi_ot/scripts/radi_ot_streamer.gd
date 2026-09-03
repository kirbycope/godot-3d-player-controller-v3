@tool
class_name RadiOtStreamer
extends Node3D

## Backend audio stream manager for radi-ot.
## Web builds hand the URL to an HTML5 Audio element and mirror the target player's spatial
## attenuation onto its volume. Desktop builds pull the MP3 stream over HTTPClient, cut it into
## chunks on validated MPEG frame headers whenever enough bytes are buffered, and play the chunks
## through two ping-pong AudioStreamPlayer3D channels whose `finished` signals swap playback.

signal buffering_started
signal playback_started
signal playback_failed(error_message: String)

enum StreamState { IDLE, CONNECTING, REQUESTING, STREAMING, ERROR }

## ~5 s of 128 kbps MP3 buffered before playback starts.
const INITIAL_CHUNK_BYTES: int = 81920
## ~2 s of 128 kbps MP3 per queued chunk.
const TARGET_CHUNK_BYTES: int = 32768
## ~1 s chunks are accepted while a channel is waiting for audio.
const STARVED_CHUNK_BYTES: int = 16384
const MAX_QUEUED_CHUNKS: int = 2
## Consumed bytes are dropped from the raw buffer once this many have been read.
const COMPACT_THRESHOLD_BYTES: int = 262144
const MAX_REDIRECTS: int = 4
## Connect, first-byte and stall timeout; expiry reports `playback_failed`.
const STREAM_TIMEOUT_SECONDS: float = 10.0
const WEB_SPATIAL_INTERVAL_SECONDS: float = 0.1
const JS_INIT: String = """
	if (!window._radi_ot_audio) {
		window._radi_ot_audio = new Audio();
		window._radi_ot_audio.crossOrigin = "anonymous";
		window._radi_ot_audio.preload = "none";
	}
"""
const JS_PLAY: String = """
	var audio = window._radi_ot_audio;
	audio.src = '%s';
	audio.volume = 1.0;
	var playPromise = audio.play();
	if (playPromise !== undefined) {
		playPromise.catch(function(err) { console.warn('radi-ot web stream error:', err); });
	}
"""
const JS_STOP: String = """
	window._radi_ot_audio.pause();
	window._radi_ot_audio.removeAttribute('src');
	window._radi_ot_audio.load();
"""
const JS_VOLUME: String = "window._radi_ot_audio.volume = %f;"

## The AudioStreamPlayer3D whose spatial settings the stream channels (desktop) or the
## HTML5 Audio volume (web) mirror.
@export var target_player: AudioStreamPlayer3D

var _is_web_platform: bool = OS.has_feature("web")
var _is_bulletin_paused: bool = false
var _is_buffering: bool = false
var _is_playing: bool = false
var _volume_linear: float = 1.0
var _last_web_volume: float = -1.0

var _http_client: HTTPClient
var _stream_state: StreamState = StreamState.IDLE
var _channels: Array[AudioStreamPlayer3D] = []
var _active_channel_idx: int = 0
var _incoming_raw_bytes: PackedByteArray = PackedByteArray()
var _read_offset: int = 0
var _chunk_queue: Array[AudioStreamMP3] = []
var _waiting_for_chunk: bool = false
var _timeout_timer: Timer = Timer.new()

var _redirect_count: int = 0
var _current_host: String = ""
var _current_port: int = 80
var _current_path: String = "/"
var _current_use_ssl: bool = false


func _ready() -> void:
	set_process(not _is_web_platform and not Engine.is_editor_hint())
	if _is_web_platform:
		JavaScriptBridge.eval(JS_INIT, true)
		var spatial_timer: Timer = Timer.new()
		spatial_timer.wait_time = WEB_SPATIAL_INTERVAL_SECONDS
		spatial_timer.autostart = true
		spatial_timer.timeout.connect(_update_web_spatial_audio)
		add_child(spatial_timer)
		return
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = STREAM_TIMEOUT_SECONDS
	_timeout_timer.timeout.connect(_on_desktop_stream_error.bind("Stream timed out after %.0f s." % STREAM_TIMEOUT_SECONDS))
	add_child(_timeout_timer)
	for i: int in 2:
		var channel: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		channel.name = "StreamChannel%d" % i
		channel.finished.connect(_on_channel_finished)
		add_child(channel)
		_channels.append(channel)


## Polls the HTTP client (no signal exists for it) and feeds received bytes into the chunk queue.
func _process(_delta: float) -> void:
	if _http_client == null or _stream_state == StreamState.IDLE:
		return
	_http_client.poll()
	var status: HTTPClient.Status = _http_client.get_status()
	match _stream_state:
		StreamState.CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				var headers: PackedStringArray = ["User-Agent: radi-ot/1.0", "Icy-MetaData: 0", "Connection: close"]
				var err: Error = _http_client.request(HTTPClient.METHOD_GET, _current_path, headers)
				if err != OK:
					_on_desktop_stream_error("HTTP request error: %d" % err)
				else:
					_stream_state = StreamState.REQUESTING
			elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Connection failed (status %d)" % status)
		StreamState.REQUESTING:
			if _http_client.has_response() or status == HTTPClient.STATUS_BODY:
				var code: int = _http_client.get_response_code()
				if code >= 300 and code < 400:
					_handle_redirect()
				elif code == 200 or code == 0:
					_stream_state = StreamState.STREAMING
				else:
					_on_desktop_stream_error("HTTP error status: %d" % code)
			elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Request failed (status %d)" % status)
		StreamState.STREAMING:
			if status == HTTPClient.STATUS_BODY:
				_on_bytes_received(_http_client.read_response_body_chunk())
			elif status == HTTPClient.STATUS_CONNECTED and _http_client.has_response():
				var conn: StreamPeer = _http_client.get_connection()
				if conn != null and conn.get_available_bytes() > 0:
					var read: Array = conn.get_partial_data(mini(conn.get_available_bytes(), 65536))
					if read[0] == OK:
						_on_bytes_received(read[1])
			elif status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Stream disconnected (status %d)" % status)


func play_station(station: RadioStation) -> void:
	if Engine.is_editor_hint():
		return
	if station == null:
		stop()
		return
	_sync_channel_properties()
	_is_buffering = true
	_is_playing = false
	buffering_started.emit()
	var url: String = station.stream_url.strip_edges()
	if _is_web_platform:
		_play_web_stream(url)
	else:
		_stop_desktop_stream()
		_redirect_count = 0
		_connect_to_url(url)


func stop() -> void:
	_is_playing = false
	_is_buffering = false
	_is_bulletin_paused = false
	if _is_web_platform:
		JavaScriptBridge.eval(JS_STOP, true)
	else:
		_stop_desktop_stream()


func pause_for_bulletin() -> void:
	_is_bulletin_paused = true
	if _is_web_platform:
		_update_web_spatial_audio()
		return
	for channel: AudioStreamPlayer3D in _channels:
		channel.stream_paused = true


func resume_after_bulletin() -> void:
	_is_bulletin_paused = false
	if _is_web_platform:
		_update_web_spatial_audio()
		return
	for channel: AudioStreamPlayer3D in _channels:
		channel.stream_paused = false
	if _waiting_for_chunk:
		_play_next_queued_chunk()


func set_volume(linear: float) -> void:
	_volume_linear = clampf(linear, 0.0, 1.0)
	if _is_web_platform:
		_update_web_spatial_audio()
	else:
		_sync_channel_properties()


func is_buffering() -> bool:
	return _is_buffering


func is_playing() -> bool:
	return _is_playing


# -----------------------------------------------------------------------------
# Web (HTML5) implementation
# -----------------------------------------------------------------------------

func _play_web_stream(url: String) -> void:
	if url.is_empty():
		_is_buffering = false
		playback_failed.emit("Empty stream URL.")
		return
	JavaScriptBridge.eval(JS_PLAY % url.replace("'", "\\'"), true)
	_is_playing = true
	_is_buffering = false
	_last_web_volume = -1.0
	playback_started.emit()
	_update_web_spatial_audio()


## Mirrors the target player's distance attenuation onto the HTML5 Audio volume. Runs from a
## 10 Hz Timer and only evaluates JavaScript when the resulting volume changed.
func _update_web_spatial_audio() -> void:
	if not _is_playing or target_player == null or not target_player.is_inside_tree():
		return
	var attenuation: float = 1.0
	var camera: Camera3D = target_player.get_viewport().get_camera_3d()
	if camera != null:
		var distance: float = camera.global_position.distance_to(target_player.global_position)
		var ratio: float = maxf(distance, target_player.unit_size) / target_player.unit_size
		match target_player.attenuation_model:
			AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE:
				attenuation = 1.0 / ratio
			AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE:
				attenuation = 1.0 / (ratio * ratio)
			AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC:
				attenuation = db_to_linear(-20.0 * log(ratio))
		if target_player.max_distance > 0.0 and distance > target_player.max_distance:
			attenuation = 0.0
	var final_volume: float = 0.0 if _is_bulletin_paused else clampf(_volume_linear * attenuation, 0.0, 1.0)
	if is_equal_approx(final_volume, _last_web_volume):
		return
	_last_web_volume = final_volume
	JavaScriptBridge.eval(JS_VOLUME % final_volume, true)


# -----------------------------------------------------------------------------
# Desktop ping-pong implementation
# -----------------------------------------------------------------------------

func _sync_channel_properties() -> void:
	if target_player == null:
		return
	for channel: AudioStreamPlayer3D in _channels:
		channel.max_distance = target_player.max_distance
		channel.unit_size = target_player.unit_size
		channel.volume_db = target_player.volume_db
		channel.bus = target_player.bus
		channel.attenuation_model = target_player.attenuation_model
		channel.panning_strength = target_player.panning_strength
		channel.doppler_tracking = target_player.doppler_tracking
		channel.max_polyphony = target_player.max_polyphony


func _parse_url(url: String) -> Dictionary:
	var use_ssl: bool = url.begins_with("https://")
	var work_url: String = url.trim_prefix("https://").trim_prefix("http://")
	var slash_pos: int = work_url.find("/")
	var host_part: String = work_url if slash_pos == -1 else work_url.substr(0, slash_pos)
	var path_part: String = "/" if slash_pos == -1 else work_url.substr(slash_pos)
	var host: String = host_part
	var port: int = 443 if use_ssl else 80
	var colon_pos: int = host_part.find(":")
	if colon_pos != -1:
		host = host_part.substr(0, colon_pos)
		port = host_part.substr(colon_pos + 1).to_int()
	return {"host": host, "port": port, "path": path_part, "use_ssl": use_ssl}


func _connect_to_url(url: String) -> void:
	var parsed: Dictionary = _parse_url(url)
	_current_host = parsed.host
	_current_port = parsed.port
	_current_path = parsed.path
	_current_use_ssl = parsed.use_ssl
	_http_client = HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if _current_use_ssl else null
	var err: Error = _http_client.connect_to_host(_current_host, _current_port, tls_options)
	if err != OK:
		_on_desktop_stream_error("Cannot initiate connection to %s:%d (error %d)" % [_current_host, _current_port, err])
		return
	_stream_state = StreamState.CONNECTING
	_waiting_for_chunk = true
	_timeout_timer.start()


func _handle_redirect() -> void:
	if _redirect_count >= MAX_REDIRECTS:
		_on_desktop_stream_error("Too many HTTP redirects.")
		return
	_redirect_count += 1
	var headers: Dictionary = _http_client.get_response_headers_as_dictionary()
	var new_location: String = ""
	for key: String in headers:
		if key.to_lower() == "location":
			new_location = headers[key]
			break
	if new_location.is_empty():
		_on_desktop_stream_error("HTTP redirect missing Location header.")
		return
	if new_location.begins_with("/"):
		new_location = "%s%s%s" % ["https://" if _current_use_ssl else "http://", _current_host, new_location]
	_stop_desktop_stream()
	_connect_to_url(new_location)


func _on_bytes_received(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return
	_timeout_timer.start()
	_incoming_raw_bytes.append_array(bytes)
	_fill_chunk_queue()
	if not _is_playing and not _chunk_queue.is_empty():
		_is_playing = true
		_is_buffering = false
		playback_started.emit()
	if _waiting_for_chunk:
		_play_next_queued_chunk()


## The single place chunks are cut from the raw buffer: whenever enough unread bytes are buffered
## and the queue has room, everything between the first and the last validated frame header
## becomes one AudioStreamMP3.
func _fill_chunk_queue() -> void:
	var min_bytes: int = TARGET_CHUNK_BYTES
	if not _is_playing:
		min_bytes = INITIAL_CHUNK_BYTES
	elif _waiting_for_chunk:
		min_bytes = STARVED_CHUNK_BYTES
	if _chunk_queue.size() >= MAX_QUEUED_CHUNKS or _incoming_raw_bytes.size() - _read_offset < min_bytes:
		return
	var start: int = _find_mp3_frame(_incoming_raw_bytes, _read_offset)
	if start == -1:
		_read_offset = _incoming_raw_bytes.size() - 3
		return
	var end: int = _find_last_mp3_frame(_incoming_raw_bytes)
	if end <= start:
		return
	var chunk: AudioStreamMP3 = AudioStreamMP3.new()
	chunk.data = _incoming_raw_bytes.slice(start, end)
	_chunk_queue.append(chunk)
	_read_offset = end
	if _read_offset >= COMPACT_THRESHOLD_BYTES:
		_incoming_raw_bytes = _incoming_raw_bytes.slice(_read_offset)
		_read_offset = 0


## True when the four bytes at `i` form an MPEG audio frame header with no reserved
## version, layer, bitrate or sample-rate fields.
static func _is_mp3_frame_header(bytes: PackedByteArray, i: int) -> bool:
	if i + 3 >= bytes.size() or bytes[i] != 0xFF or (bytes[i + 1] & 0xE0) != 0xE0:
		return false
	return (bytes[i + 1] & 0x18) != 0x08 and (bytes[i + 1] & 0x06) != 0x00 \
		and (bytes[i + 2] & 0xF0) != 0xF0 and (bytes[i + 2] & 0x0C) != 0x0C


static func _find_mp3_frame(bytes: PackedByteArray, from: int) -> int:
	for i: int in range(from, bytes.size() - 3):
		if _is_mp3_frame_header(bytes, i):
			return i
	return -1


static func _find_last_mp3_frame(bytes: PackedByteArray) -> int:
	for i: int in range(bytes.size() - 4, -1, -1):
		if _is_mp3_frame_header(bytes, i):
			return i
	return -1


func _on_channel_finished() -> void:
	if _is_playing:
		_play_next_queued_chunk()


func _play_next_queued_chunk() -> void:
	_waiting_for_chunk = _is_bulletin_paused or _chunk_queue.is_empty()
	if _waiting_for_chunk:
		return
	_active_channel_idx = 1 - _active_channel_idx
	var channel: AudioStreamPlayer3D = _channels[_active_channel_idx]
	channel.stream = _chunk_queue.pop_front()
	channel.play()


func _stop_desktop_stream() -> void:
	_stream_state = StreamState.IDLE
	_timeout_timer.stop()
	if _http_client != null:
		_http_client.close()
		_http_client = null
	_incoming_raw_bytes.clear()
	_read_offset = 0
	_chunk_queue.clear()
	_waiting_for_chunk = false
	for channel: AudioStreamPlayer3D in _channels:
		channel.stop()


func _on_desktop_stream_error(error_message: String) -> void:
	_stop_desktop_stream()
	_stream_state = StreamState.ERROR
	_is_buffering = false
	_is_playing = false
	playback_failed.emit(error_message)

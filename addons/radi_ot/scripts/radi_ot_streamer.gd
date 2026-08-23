@tool
class_name RadiOtStreamer
extends Node3D

## Backend audio stream manager for radi-ot.
## Handles dual-platform continuous streaming for Web (Compatibility)
## and Steam/Desktop (Forward+) via seamless Ping-Pong double-buffered channels.

signal buffering_started
signal playback_started
signal playback_failed(error_message: String)

enum StreamState {
	IDLE,
	CONNECTING,
	REQUESTING,
	STREAMING,
	ERROR,
}

const INITIAL_CHUNK_BYTES: int = 81920 # ~5.1s of 128kbps MP3 (prevents starvation)
const TARGET_CHUNK_BYTES: int = 32768 # ~2.0s of 128kbps MP3

var _is_bulletin_paused: bool = false
var _is_web_platform: bool = false
var _is_buffering: bool = false
var _is_playing: bool = false
var _current_url: String = ""
var _volume_linear: float = 1.0
var _muted: bool = false

# Desktop HTTP streaming variables
var _http_client: HTTPClient
var _stream_state: StreamState = StreamState.IDLE
var _target_player_3d: AudioStreamPlayer3D

# Ping-Pong Double Buffered Players
var _channel_a: AudioStreamPlayer3D
var _channel_b: AudioStreamPlayer3D
var _active_channel_idx: int = 0
var _incoming_raw_bytes: PackedByteArray = PackedByteArray()
var _chunk_queue: Array[AudioStreamMP3] = []
var _waiting_for_chunk: bool = false
var _chunk_swap_triggered: bool = false

var _redirect_count: int = 0
var _max_redirects: int = 4
var _current_host: String = ""
var _current_port: int = 80
var _current_path: String = "/"
var _current_use_ssl: bool = false


func _init() -> void:
	_is_web_platform = OS.has_feature("web")


func _ready() -> void:
	if _is_web_platform:
		_setup_web_streamer()
	else:
		_setup_desktop_channels()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_web_platform:
		if _is_playing and _target_player_3d != null:
			_update_web_spatial_audio()
	else:
		_poll_desktop_stream()


func set_target_player(player: AudioStreamPlayer3D) -> void:
	_target_player_3d = player
	if _channel_a != null and is_instance_valid(_channel_a):
		var cur_parent: Node = _channel_a.get_parent()
		var new_parent: Node = _target_player_3d if _target_player_3d != null else self
		if cur_parent != new_parent:
			if cur_parent != null:
				cur_parent.remove_child(_channel_a)
			new_parent.add_child(_channel_a)
			_channel_a.position = Vector3.ZERO

	if _channel_b != null and is_instance_valid(_channel_b):
		var cur_parent: Node = _channel_b.get_parent()
		var new_parent: Node = _target_player_3d if _target_player_3d != null else self
		if cur_parent != new_parent:
			if cur_parent != null:
				cur_parent.remove_child(_channel_b)
			new_parent.add_child(_channel_b)
			_channel_b.position = Vector3.ZERO

	_setup_desktop_channels()
	_sync_channel_properties()


func play_station(station: RadioStation) -> void:
	if Engine.is_editor_hint():
		return
	if station == null:
		stop()
		return

	_sync_channel_properties()
	var url: String = station.stream_url.strip_edges()
	_current_url = url
	_is_buffering = true
	_is_playing = false
	buffering_started.emit()

	if _is_web_platform:
		_play_web_stream(url)
	else:
		_start_desktop_stream(url)


func stop() -> void:
	_is_playing = false
	_is_buffering = false
	_is_bulletin_paused = false
	_current_url = ""

	if _is_web_platform:
		_stop_web_stream()
	else:
		_stop_desktop_stream()


func pause_for_bulletin() -> void:
	_is_bulletin_paused = true
	if _is_web_platform:
		_set_web_muted(true)
	else:
		_set_desktop_paused(true)


func resume_after_bulletin() -> void:
	_is_bulletin_paused = false
	if _is_web_platform:
		_set_web_muted(false)
	else:
		_set_desktop_paused(false)
		if _is_playing:
			var active_player: AudioStreamPlayer3D = _get_active_player()
			if active_player == null or not active_player.playing:
				if not _chunk_queue.is_empty():
					_play_next_queued_chunk()
				elif _incoming_raw_bytes.size() >= 16384:
					_extract_maximal_chunk()


func set_volume(linear_volume: float) -> void:
	_volume_linear = clampf(linear_volume, 0.0, 1.0)
	if _is_web_platform:
		_update_web_spatial_audio()
	else:
		_sync_channel_properties()


func is_buffering() -> bool:
	return _is_buffering


func is_playing() -> bool:
	return _is_playing


# -----------------------------------------------------------------------------
# Web (HTML5 / Compatibility) Implementation
# -----------------------------------------------------------------------------

func _setup_web_streamer() -> void:
	if not _is_web_platform:
		return

	var js_init_code: String = """
		(function() {
			if (!window._radi_ot_audio) {
				window._radi_ot_audio = new Audio();
				window._radi_ot_audio.crossOrigin = "anonymous";
				window._radi_ot_audio.preload = "none";
			}
		})();
	"""
	JavaScriptBridge.eval(js_init_code, true)


func _play_web_stream(url: String) -> void:
	if url.is_empty():
		_is_buffering = false
		playback_failed.emit("Empty stream URL.")
		return

	var escaped_url: String = url.replace("'", "\\'")
	var js_code: String = """
		(function() {
			if (!window._radi_ot_audio) {
				window._radi_ot_audio = new Audio();
				window._radi_ot_audio.crossOrigin = "anonymous";
			}
			var audio = window._radi_ot_audio;
			audio.src = '%s';
			audio.volume = 1.0;
			var playPromise = audio.play();
			if (playPromise !== undefined) {
				playPromise.then(function() {
					window._radi_ot_state = 'playing';
				}).catch(function(err) {
					console.warn('radi-ot web stream error:', err);
					window._radi_ot_state = 'error';
				});
			}
		})();
	""" % escaped_url
	JavaScriptBridge.eval(js_code, true)

	_is_playing = true
	_is_buffering = false
	playback_started.emit()


func _stop_web_stream() -> void:
	if not _is_web_platform:
		return

	var js_stop_code: String = """
		(function() {
			if (window._radi_ot_audio) {
				window._radi_ot_audio.pause();
				window._radi_ot_audio.removeAttribute('src');
				window._radi_ot_audio.load();
			}
		})();
	"""
	JavaScriptBridge.eval(js_stop_code, true)


func _set_web_muted(muted: bool) -> void:
	_muted = muted
	if not _is_web_platform:
		return

	var js_code: String = """
		(function() {
			if (window._radi_ot_audio) {
				window._radi_ot_audio.muted = %s;
			}
		})();
	""" % ("true" if muted else "false")
	JavaScriptBridge.eval(js_code, true)


func _update_web_spatial_audio() -> void:
	if not _is_web_platform or _target_player_3d == null or not _target_player_3d.is_inside_tree():
		return

	var viewport: Viewport = _target_player_3d.get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	var final_volume: float = _volume_linear

	if camera != null:
		var distance: float = camera.global_position.distance_to(
			_target_player_3d.global_position
		)
		var max_dist: float = _target_player_3d.max_distance
		var unit_size: float = _target_player_3d.unit_size

		var attenuation: float = 1.0
		if distance > unit_size and max_dist > 0.0:
			attenuation = clampf(1.0 - ((distance - unit_size) / max_dist), 0.0, 1.0)
			attenuation = pow(attenuation, _target_player_3d.attenuation_model)
		final_volume = _volume_linear * attenuation

	if _muted:
		final_volume = 0.0

	var js_vol: String = """
		(function() {
			if (window._radi_ot_audio) {
				window._radi_ot_audio.volume = %f;
			}
		})();
	""" % clampf(final_volume, 0.0, 1.0)
	JavaScriptBridge.eval(js_vol, true)


# -----------------------------------------------------------------------------
# Desktop (Steam / Forward+) Ping-Pong Implementation
# -----------------------------------------------------------------------------

func _setup_desktop_channels() -> void:
	var parent_node: Node = _target_player_3d if _target_player_3d != null else self

	if _channel_a == null:
		_channel_a = AudioStreamPlayer3D.new()
		_channel_a.name = "StreamChannelA"
		parent_node.add_child(_channel_a)
		_channel_a.position = Vector3.ZERO
		_channel_a.finished.connect(_on_channel_a_finished)

	if _channel_b == null:
		_channel_b = AudioStreamPlayer3D.new()
		_channel_b.name = "StreamChannelB"
		parent_node.add_child(_channel_b)
		_channel_b.position = Vector3.ZERO
		_channel_b.finished.connect(_on_channel_b_finished)

	_sync_channel_properties()


func _sync_channel_properties() -> void:
	if _target_player_3d == null:
		return

	if _channel_a != null:
		_channel_a.max_distance = _target_player_3d.max_distance
		_channel_a.unit_size = _target_player_3d.unit_size
		_channel_a.volume_db = _target_player_3d.volume_db
		_channel_a.bus = _target_player_3d.bus
		_channel_a.attenuation_model = _target_player_3d.attenuation_model
		_channel_a.panning_strength = _target_player_3d.panning_strength
		_channel_a.doppler_tracking = _target_player_3d.doppler_tracking
		_channel_a.max_polyphony = _target_player_3d.max_polyphony
		_channel_a.position = Vector3.ZERO

	if _channel_b != null:
		_channel_b.max_distance = _target_player_3d.max_distance
		_channel_b.unit_size = _target_player_3d.unit_size
		_channel_b.volume_db = _target_player_3d.volume_db
		_channel_b.bus = _target_player_3d.bus
		_channel_b.attenuation_model = _target_player_3d.attenuation_model
		_channel_b.panning_strength = _target_player_3d.panning_strength
		_channel_b.doppler_tracking = _target_player_3d.doppler_tracking
		_channel_b.max_polyphony = _target_player_3d.max_polyphony
		_channel_b.position = Vector3.ZERO


func _set_desktop_paused(is_paused: bool) -> void:
	if _channel_a != null and _channel_a.is_inside_tree():
		_channel_a.stream_paused = is_paused
	if _channel_b != null and _channel_b.is_inside_tree():
		_channel_b.stream_paused = is_paused


func _parse_url(url: String) -> Dictionary:
	var use_ssl: bool = false
	var work_url: String = url

	if work_url.begins_with("https://"):
		use_ssl = true
		work_url = work_url.substr(8)
	elif work_url.begins_with("http://"):
		use_ssl = false
		work_url = work_url.substr(7)

	var slash_pos: int = work_url.find("/")
	var host_part: String = work_url if slash_pos == -1 else work_url.substr(0, slash_pos)
	var path_part: String = "/" if slash_pos == -1 else work_url.substr(slash_pos)

	var host: String = host_part
	var port: int = 443 if use_ssl else 80

	var colon_pos: int = host_part.find(":")
	if colon_pos != -1:
		host = host_part.substr(0, colon_pos)
		port = host_part.substr(colon_pos + 1).to_int()

	return {
		"host": host,
		"port": port,
		"path": path_part,
		"use_ssl": use_ssl,
	}


func _start_desktop_stream(url: String) -> void:
	_stop_desktop_stream()
	_redirect_count = 0
	_connect_to_url(url)


func _connect_to_url(url: String) -> void:
	var parsed: Dictionary = _parse_url(url)
	_current_host = parsed.host
	_current_port = parsed.port
	_current_path = parsed.path
	_current_use_ssl = parsed.use_ssl
	_incoming_raw_bytes.clear()
	_chunk_queue.clear()
	_waiting_for_chunk = false
	_active_channel_idx = 0

	_http_client = HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if _current_use_ssl else null
	var err: Error = _http_client.connect_to_host(_current_host, _current_port, tls_options)

	if err != OK:
		_on_desktop_stream_error("Cannot initiate connection to %s:%d (error %d)" % [
			_current_host, _current_port, err
		])
		return

	_stream_state = StreamState.CONNECTING


func _poll_desktop_stream() -> void:
	if _http_client == null or _stream_state == StreamState.IDLE:
		return

	_http_client.poll()
	var status: int = _http_client.get_status()

	match _stream_state:
		StreamState.CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				var headers: PackedStringArray = [
					"User-Agent: radi-ot/1.0",
					"Icy-MetaData: 0",
					"Connection: close",
				]
				var req_err: Error = _http_client.request(
					HTTPClient.METHOD_GET,
					_current_path,
					headers
				)
				if req_err != OK:
					_on_desktop_stream_error("HTTP request error: %d" % req_err)
				else:
					_stream_state = StreamState.REQUESTING
			elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Connection failed (status %d)" % status)

		StreamState.REQUESTING:
			if _http_client.has_response() or status == HTTPClient.STATUS_BODY:
				var resp_code: int = _http_client.get_response_code()
				if resp_code >= 300 and resp_code < 400:
					_handle_redirect()
					return
				elif resp_code == 200 or resp_code == 0:
					_stream_state = StreamState.STREAMING
				else:
					_on_desktop_stream_error("HTTP error status: %d" % resp_code)
			elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Request failed (status %d)" % status)

		StreamState.STREAMING:
			if status == HTTPClient.STATUS_BODY:
				var chunk: PackedByteArray = _http_client.read_response_body_chunk()
				if not chunk.is_empty():
					_incoming_raw_bytes.append_array(chunk)
					_process_incoming_chunks()
			elif _http_client.has_response() and status == HTTPClient.STATUS_CONNECTED:
				var conn: StreamPeer = _http_client.get_connection()
				if conn != null and conn.get_available_bytes() > 0:
					var read_res: Array = conn.get_partial_data(mini(conn.get_available_bytes(), 65536))
					if read_res[0] == OK and not (read_res[1] as PackedByteArray).is_empty():
						_incoming_raw_bytes.append_array(read_res[1])
						_process_incoming_chunks()
			elif status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR:
				_on_desktop_stream_error("Stream disconnected (status %d)" % status)

	# Trigger ping-pong chunk extraction at the last possible moment or when waiting for chunk
	if _is_playing:
		if _is_bulletin_paused:
			if _incoming_raw_bytes.size() >= TARGET_CHUNK_BYTES and _chunk_queue.size() < 4:
				_extract_maximal_chunk()
		else:
			var active_player: AudioStreamPlayer3D = _get_active_player()
			if active_player != null and active_player.playing and not active_player.stream_paused:
				var stream_len: float = active_player.stream.get_length() if active_player.stream != null else 0.0
				var pos: float = active_player.get_playback_position()
				if stream_len > 0.0 and (stream_len - pos) <= 0.8:
					if _chunk_queue.is_empty() and _incoming_raw_bytes.size() > 16384:
						_extract_maximal_chunk()
			elif _waiting_for_chunk or active_player == null or not active_player.playing:
				if _chunk_queue.is_empty() and _incoming_raw_bytes.size() >= 16384:
					_extract_maximal_chunk()
				elif not _chunk_queue.is_empty():
					_play_next_queued_chunk()


func _handle_redirect() -> void:
	if _redirect_count >= _max_redirects:
		_on_desktop_stream_error("Too many HTTP redirects.")
		return

	_redirect_count += 1
	var headers_dict: Dictionary = _http_client.get_response_headers_as_dictionary()
	var new_location: String = ""
	for key in headers_dict:
		if (key as String).to_lower() == "location":
			new_location = headers_dict[key]
			break

	if new_location.is_empty():
		_on_desktop_stream_error("HTTP redirect missing Location header.")
		return

	if new_location.begins_with("/"):
		var scheme: String = "https://" if _current_use_ssl else "http://"
		new_location = "%s%s%s" % [scheme, _current_host, new_location]

	_stop_desktop_stream()
	_connect_to_url(new_location)


func _find_first_mp3_sync(bytes: PackedByteArray) -> int:
	var total_size: int = bytes.size()
	for i in range(total_size - 1):
		if bytes[i] == 0xFF and (bytes[i + 1] & 0xE0) == 0xE0:
			return i
	return -1


func _find_last_mp3_sync_before(bytes: PackedByteArray, end_idx: int) -> int:
	var total_size: int = mini(bytes.size(), end_idx)
	for i in range(total_size - 2, -1, -1):
		if bytes[i] == 0xFF and (bytes[i + 1] & 0xE0) == 0xE0:
			return i
	return -1


func _process_incoming_chunks() -> void:
	if not _is_playing:
		# Initial startup chunk
		if _incoming_raw_bytes.size() >= INITIAL_CHUNK_BYTES:
			_extract_maximal_chunk()
			
			if not _chunk_queue.is_empty():
				var stream_1: AudioStreamMP3 = _chunk_queue.pop_front()
				_setup_desktop_channels()
				_active_channel_idx = 0
				_is_playing = true
				_is_buffering = false
				playback_started.emit()

				if not _is_bulletin_paused:
					if _channel_a != null and _channel_a.is_inside_tree():
						_channel_a.stream = stream_1
						_channel_a.play()
				else:
					_chunk_queue.push_front(stream_1)
					_waiting_for_chunk = true
	else:
		if _waiting_for_chunk and not _is_bulletin_paused and _incoming_raw_bytes.size() >= 16384:
			_extract_maximal_chunk()


func _extract_maximal_chunk() -> void:
	var sync_idx: int = _find_first_mp3_sync(_incoming_raw_bytes)
	if sync_idx == -1:
		return
		
	var slice_end: int = _find_last_mp3_sync_before(_incoming_raw_bytes, _incoming_raw_bytes.size())
	if slice_end <= sync_idx + 8192: # Ensure it's at least ~0.5s long
		return 

	var chunk_data: PackedByteArray = _incoming_raw_bytes.slice(sync_idx, slice_end)
	_incoming_raw_bytes = _incoming_raw_bytes.slice(slice_end)

	var stream_next: AudioStreamMP3 = AudioStreamMP3.new()
	stream_next.data = chunk_data
	stream_next.loop = false

	if stream_next.get_length() > 0.5:
		_chunk_queue.append(stream_next)

		if _waiting_for_chunk and not _is_bulletin_paused:
			_waiting_for_chunk = false
			_play_next_queued_chunk()


func _on_channel_a_finished() -> void:
	if _active_channel_idx == 0 and _is_playing and not _is_bulletin_paused:
		_play_next_queued_chunk()


func _on_channel_b_finished() -> void:
	if _active_channel_idx == 1 and _is_playing and not _is_bulletin_paused:
		_play_next_queued_chunk()


func _play_next_queued_chunk() -> void:
	if _is_bulletin_paused:
		_waiting_for_chunk = true
		return

	if _chunk_queue.is_empty():
		_waiting_for_chunk = true
		return

	var next_stream: AudioStreamMP3 = _chunk_queue.pop_front()
	_active_channel_idx = 1 if _active_channel_idx == 0 else 0
	var next_player: AudioStreamPlayer3D = _get_active_player()

	if next_player != null and next_player.is_inside_tree():
		next_player.stream = next_stream
		next_player.play()


func _get_active_player() -> AudioStreamPlayer3D:
	return _channel_a if _active_channel_idx == 0 else _channel_b


func _stop_desktop_stream() -> void:
	_stream_state = StreamState.IDLE
	if _http_client != null:
		_http_client.close()
		_http_client = null

	_incoming_raw_bytes.clear()
	_chunk_queue.clear()
	_waiting_for_chunk = false
	_chunk_swap_triggered = false

	if _channel_a != null and _channel_a.is_inside_tree() and _channel_a.playing:
		_channel_a.stop()
	if _channel_b != null and _channel_b.is_inside_tree() and _channel_b.playing:
		_channel_b.stop()


func _on_desktop_stream_error(error_message: String) -> void:
	_stream_state = StreamState.ERROR
	_is_buffering = false
	playback_failed.emit(error_message)

extends GutTest

## GUT Unit tests for RadiOtStreamer internal logic and URL parsing.

const RadiOtStreamerScript: GDScript = preload("res://addons/radi_ot/scripts/radi_ot_streamer.gd")

var _streamer: RadiOtStreamer


func before_each() -> void:
	_streamer = RadiOtStreamerScript.new()
	add_child_autofree(_streamer)


func test_parse_url_http() -> void:
	var parsed: Dictionary = _streamer._parse_url("http://live-mp3-128.kexp.org:8080/kexp128.mp3")
	assert_eq(parsed.get("host"), "live-mp3-128.kexp.org", "Host should match")
	assert_eq(parsed.get("port"), 8080, "Port should match custom port 8080")
	assert_eq(parsed.get("path"), "/kexp128.mp3", "Path should match")
	assert_false(parsed.get("use_ssl"), "HTTP should set use_ssl to false")


func test_parse_url_https() -> void:
	var parsed: Dictionary = _streamer._parse_url("https://kexp.streamguys1.com/kexp160.aac")
	assert_eq(parsed.get("host"), "kexp.streamguys1.com", "Host should match")
	assert_eq(parsed.get("port"), 443, "Default HTTPS port should be 443")
	assert_eq(parsed.get("path"), "/kexp160.aac", "Path should match")
	assert_true(parsed.get("use_ssl"), "HTTPS should set use_ssl to true")


func test_find_first_mp3_sync_valid() -> void:
	# Create a dummy buffer with padding then MP3 sync word (0xFF 0xFB)
	var data: PackedByteArray = PackedByteArray([0x00, 0x00, 0x00, 0xFF, 0xFB, 0x90, 0x44])
	var sync_idx: int = _streamer._find_first_mp3_sync(data)
	assert_eq(sync_idx, 3, "Should find MP3 sync at index 3")


func test_find_first_mp3_sync_not_found() -> void:
	var data: PackedByteArray = PackedByteArray([0x00, 0x11, 0x22, 0x33, 0x44])
	var sync_idx: int = _streamer._find_first_mp3_sync(data)
	assert_eq(sync_idx, -1, "Should return -1 when no sync word is found")


func test_find_last_mp3_sync_before() -> void:
	# Two sync words at index 1 and index 5
	var data: PackedByteArray = PackedByteArray([
		0x00, 0xFF, 0xFB, 0x00, 0x00, 0xFF, 0xFA, 0x00, 0x00
	])
	var last_sync: int = _streamer._find_last_mp3_sync_before(data, data.size())
	assert_eq(last_sync, 5, "Last sync before end should be at index 5")

	var prev_sync: int = _streamer._find_last_mp3_sync_before(data, 5)
	assert_eq(prev_sync, 1, "Last sync before index 5 should be at index 1")


func test_stop_resets_streamer_state() -> void:
	_streamer.stop()
	assert_false(_streamer.is_playing(), "Streamer should not be playing after stop()")
	assert_false(_streamer.is_buffering(), "Streamer should not be buffering after stop()")


func test_audio_stream_mp3_chunk_data() -> void:
	var dummy_mp3_chunk: PackedByteArray = PackedByteArray([
		0xFF, 0xFB, 0x90, 0x44, 0x00, 0x00, 0x00, 0x00,
	])
	dummy_mp3_chunk.resize(417)
	var mp3_stream: AudioStreamMP3 = AudioStreamMP3.new()
	mp3_stream.data = dummy_mp3_chunk

	assert_not_null(mp3_stream, "AudioStreamMP3 should instantiate")
	assert_eq(mp3_stream.data.size(), 417, "AudioStreamMP3 data size should match chunk size")

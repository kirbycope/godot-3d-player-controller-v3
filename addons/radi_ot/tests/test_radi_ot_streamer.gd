extends GutTest

## GUT Unit tests for RadiOtStreamer URL parsing and MP3 chunk extraction.

const RadiOtStreamerScript: GDScript = preload("res://addons/radi_ot/scripts/radi_ot_streamer.gd")
const FRAME_BYTES: int = 417

var _streamer: RadiOtStreamer


func before_each() -> void:
	_streamer = RadiOtStreamerScript.new()
	add_child_autofree(_streamer)


## Builds `frame_count` fake MPEG-1 Layer III frames (valid header, zero payload).
func _make_frames(frame_count: int) -> PackedByteArray:
	var frame: PackedByteArray = PackedByteArray([0xFF, 0xFB, 0x90, 0x44])
	frame.resize(FRAME_BYTES)
	var data: PackedByteArray = PackedByteArray()
	for i: int in frame_count:
		data.append_array(frame)
	return data


func test_parse_url_http() -> void:
	var parsed: Dictionary = _streamer._parse_url("http://live-mp3-128.kexp.org:8080/kexp128.mp3")
	assert_eq(parsed.host, "live-mp3-128.kexp.org", "Host should match")
	assert_eq(parsed.port, 8080, "Port should match custom port 8080")
	assert_eq(parsed.path, "/kexp128.mp3", "Path should match")
	assert_false(parsed.use_ssl, "HTTP should set use_ssl to false")


func test_parse_url_https() -> void:
	var parsed: Dictionary = _streamer._parse_url("https://kexp.streamguys1.com/kexp160.aac")
	assert_eq(parsed.host, "kexp.streamguys1.com", "Host should match")
	assert_eq(parsed.port, 443, "Default HTTPS port should be 443")
	assert_eq(parsed.path, "/kexp160.aac", "Path should match")
	assert_true(parsed.use_ssl, "HTTPS should set use_ssl to true")


func test_find_mp3_frame_skips_fake_sync_words() -> void:
	# 0xFF 0xE0 has the 11-bit sync but a reserved layer; 0xFF 0xFB 0x90 0x44 is a real header.
	var data: PackedByteArray = PackedByteArray([0x00, 0xFF, 0xE0, 0x00, 0x00, 0xFF, 0xFB, 0x90, 0x44, 0x00])
	assert_eq(RadiOtStreamer._find_mp3_frame(data, 0), 5, "First valid frame header is at index 5")
	assert_eq(RadiOtStreamer._find_last_mp3_frame(data), 5, "Last valid frame header is at index 5")
	assert_eq(RadiOtStreamer._find_mp3_frame(PackedByteArray([0x00, 0x11, 0x22, 0x33, 0x44]), 0), -1)
	assert_false(RadiOtStreamer._is_mp3_frame_header(PackedByteArray([0xFF, 0xFB, 0xF0, 0x44]), 0), "Bad bitrate index rejected")
	assert_false(RadiOtStreamer._is_mp3_frame_header(PackedByteArray([0xFF, 0xFB, 0x9C, 0x44]), 0), "Reserved sample rate rejected")


func test_fill_chunk_queue_cuts_on_valid_frames() -> void:
	var garbage: PackedByteArray = PackedByteArray([0x01, 0x02, 0xFF, 0xE0, 0x00, 0x00])
	var data: PackedByteArray = garbage.duplicate()
	data.append_array(_make_frames(RadiOtStreamer.INITIAL_CHUNK_BYTES / FRAME_BYTES + 2))
	_streamer._incoming_raw_bytes = data
	_streamer._fill_chunk_queue()
	assert_eq(_streamer._chunk_queue.size(), 1, "One chunk is cut once INITIAL_CHUNK_BYTES are buffered")
	var chunk: PackedByteArray = _streamer._chunk_queue[0].data
	assert_eq(chunk[0], 0xFF)
	assert_eq(chunk[1], 0xFB, "Chunk starts at the first valid header, not the fake sync word")
	assert_eq(chunk.size() % FRAME_BYTES, 0, "Chunk ends on a frame boundary")
	assert_eq(_streamer._read_offset, data.size() - FRAME_BYTES, "The trailing frame stays buffered for the next chunk")
	_streamer._fill_chunk_queue()
	assert_eq(_streamer._chunk_queue.size(), 1, "Too few unread bytes: no second chunk")


func test_stop_resets_streamer_state() -> void:
	_streamer._incoming_raw_bytes = _make_frames(4)
	_streamer._read_offset = FRAME_BYTES
	_streamer.stop()
	assert_false(_streamer.is_playing(), "Streamer should not be playing after stop()")
	assert_false(_streamer.is_buffering(), "Streamer should not be buffering after stop()")
	assert_eq(_streamer._read_offset, 0)
	assert_true(_streamer._incoming_raw_bytes.is_empty())
	assert_true(_streamer._timeout_timer.is_stopped())

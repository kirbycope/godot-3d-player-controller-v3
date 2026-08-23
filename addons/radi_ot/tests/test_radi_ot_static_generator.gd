extends GutTest

## GUT Unit tests for RadiOtStaticGenerator procedurally generated static audio.

const RadiOtStaticGeneratorScript: GDScript = preload(
	"res://addons/radi_ot/scripts/radi_ot_static_generator.gd"
)


func test_get_static_stream_properties() -> void:
	var stream: AudioStreamWAV = RadiOtStaticGeneratorScript.get_static_stream(1.0, 22050)
	assert_not_null(stream, "Static stream should not be null")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Static format should be 16-bit")
	assert_eq(stream.mix_rate, 22050, "Mix rate should match requested 22050 Hz")
	assert_false(stream.stereo, "Static stream should be mono")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Loop mode should be LOOP_FORWARD")
	assert_false(stream.data.is_empty(), "Static audio data byte buffer should not be empty")
	assert_gt(stream.data.size(), 0, "Data buffer size should be greater than 0")
	assert_eq(stream.data.size(), stream.loop_end * 2, "Data buffer size should match loop_end * 2 bytes")


func test_static_generator_caching() -> void:
	var stream1: AudioStreamWAV = RadiOtStaticGeneratorScript.get_static_stream(1.0, 22050)
	var stream2: AudioStreamWAV = RadiOtStaticGeneratorScript.get_static_stream(1.0, 22050)
	assert_eq(stream1, stream2, "Static generator should return the cached stream on subsequent calls")

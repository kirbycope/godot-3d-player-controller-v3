extends GutTest

## GUT Unit tests for RadiOtStaticGenerator procedurally generated static audio.


func test_get_static_stream_properties() -> void:
	var stream: AudioStreamWAV = RadiOtStaticGenerator.get_static_stream()
	assert_not_null(stream, "Static stream should not be null")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Static format should be 16-bit")
	assert_eq(stream.mix_rate, RadiOtStaticGenerator.SAMPLE_RATE, "Mix rate should match SAMPLE_RATE")
	assert_false(stream.stereo, "Static stream should be mono")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Loop mode should be LOOP_FORWARD")
	assert_eq(stream.data.size(), stream.loop_end * 2, "Data buffer size should match loop_end * 2 bytes")
	assert_almost_eq(stream.get_length(), RadiOtStaticGenerator.DURATION_SECONDS, 0.001, "Stream lasts DURATION_SECONDS")


func test_static_generator_caching() -> void:
	assert_eq(RadiOtStaticGenerator.get_static_stream(), RadiOtStaticGenerator.get_static_stream(), "Static generator returns the cached stream")

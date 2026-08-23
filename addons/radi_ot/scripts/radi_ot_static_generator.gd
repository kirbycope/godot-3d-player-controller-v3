@tool
class_name RadiOtStaticGenerator
extends RefCounted

## Procedural radio static and white noise synthesizer for radi-ot.
## Generates a lightweight looping AudioStreamWAV for tuning and buffering static.

static var _cached_static_stream: AudioStreamWAV


static func get_static_stream(duration_seconds: float = 1.5, sample_rate: int = 22050) -> AudioStreamWAV:
	if _cached_static_stream != null:
		return _cached_static_stream

	var sample_count: int = int(duration_seconds * float(sample_rate))
	var pcm_bytes: PackedByteArray = PackedByteArray()
	pcm_bytes.resize(sample_count * 2) # 16-bit mono = 2 bytes per sample

	var last_sample: float = 0.0
	for i in range(sample_count):
		# Mix white noise and low-pass filtered noise for realistic radio texture
		var white: float = randf_range(-1.0, 1.0)
		var crackle: float = 1.0
		if randf() < 0.005:
			crackle = randf_range(1.5, 2.5)

		# 1-pole low pass filter + crackle
		var sample_val: float = (last_sample * 0.45) + (white * 0.55 * crackle)
		last_sample = sample_val

		# Envelope taper near ends for seamless loop
		var taper: float = 1.0
		var edge_samples: int = int(float(sample_rate) * 0.05)
		if i < edge_samples:
			taper = float(i) / float(edge_samples)
		elif i > sample_count - edge_samples:
			taper = float(sample_count - i) / float(edge_samples)

		sample_val = clampf(sample_val * taper * 0.35, -1.0, 1.0)
		var int_val: int = int(sample_val * 32767.0)

		# 16-bit signed integer little-endian
		var byte_idx: int = i * 2
		pcm_bytes.encode_s16(byte_idx, int_val)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = pcm_bytes

	_cached_static_stream = stream
	return stream

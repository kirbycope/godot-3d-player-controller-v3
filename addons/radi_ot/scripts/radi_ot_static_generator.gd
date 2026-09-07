@tool
class_name RadiOtStaticGenerator
extends RefCounted

## Procedural radio static synthesizer for radi-ot.
## Generates one cached looping 16-bit mono AudioStreamWAV for tuning and buffering static.

const DURATION_SECONDS: float = 1.5
const SAMPLE_RATE: int = 22050

static var _cached_static_stream: AudioStreamWAV


static func get_static_stream() -> AudioStreamWAV:
	if _cached_static_stream != null:
		return _cached_static_stream
	var sample_count: int = int(DURATION_SECONDS * float(SAMPLE_RATE))
	var edge_samples: int = int(float(SAMPLE_RATE) * 0.05)
	var pcm_bytes: PackedByteArray = PackedByteArray()
	pcm_bytes.resize(sample_count * 2)
	var last_sample: float = 0.0
	for i: int in sample_count:
		# White noise through a 1-pole low pass with occasional crackle.
		var crackle: float = randf_range(1.5, 2.5) if randf() < 0.005 else 1.0
		var sample_val: float = (last_sample * 0.45) + (randf_range(-1.0, 1.0) * 0.55 * crackle)
		last_sample = sample_val
		# Taper both ends for a seamless loop.
		var taper: float = 1.0
		if i < edge_samples:
			taper = float(i) / float(edge_samples)
		elif i > sample_count - edge_samples:
			taper = float(sample_count - i) / float(edge_samples)
		pcm_bytes.encode_s16(i * 2, int(clampf(sample_val * taper * 0.35, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = pcm_bytes
	_cached_static_stream = stream
	return stream

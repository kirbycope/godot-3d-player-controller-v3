@tool
class_name RadioStation
extends Resource

## Data model for a radio station in radi-ot.
## Represents a broadcast channel with live streaming URLs, metadata, and fallback audio.

@export var station_name: String = "KEXP 90.3 FM"
@export var call_sign: String = "KEXP"
@export var frequency: float = 90.3
@export var stream_url: String = "https://kexp.streamguys1.com/kexp128.mp3"
@export var genre: String = "Alternative / Indie"
@export var tagline: String = "Where the Music Matters"
@export_multiline var description: String = "Seattle's iconic listener-powered station."
@export var logo: Texture2D
@export var fallback_audio: AudioStream


func get_display_frequency() -> String:
	return "%.1f MHz" % frequency


func get_full_title() -> String:
	if tagline.is_empty():
		return "%s (%.1f FM)" % [call_sign, frequency]
	return "%s %.1f - %s" % [call_sign, frequency, tagline]

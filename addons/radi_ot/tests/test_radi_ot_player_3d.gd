extends GutTest

## GUT Unit tests for RadiOtPlayer3D node.

const RadiOtPlayer3DScript: GDScript = preload("res://addons/radi_ot/scripts/radi_ot_player_3d.gd")
const DEFAULT_COLLECTION_PATH: String = (
	"res://addons/radi_ot/resources/stations/seattle_stations_default.tres"
)

var _player: RadiOtPlayer3D


func before_each() -> void:
	_player = RadiOtPlayer3DScript.new()
	_player.enable_hud = false
	_player.auto_play_on_ready = false
	var collection: RadioStationCollection = load(DEFAULT_COLLECTION_PATH) as RadioStationCollection
	_player.station_collection = collection
	add_child_autofree(_player)


func test_initial_state() -> void:
	assert_true(_player.is_power_on(), "Radio player should start powered on by default")
	assert_false(_player.is_bulletin_active(), "Bulletin should not be active initially")
	assert_not_null(_player.get_current_station(), "Current station should not be null")
	assert_eq(_player.get_current_station().call_sign, "KEXP", "Initial station should be KEXP")


func test_station_navigation_next_and_previous() -> void:
	watch_signals(_player)

	# Next station
	_player.tune_next_station()
	assert_signal_emitted(_player, "station_changed", "station_changed should emit on tune_next_station")
	assert_eq(_player.get_current_station().call_sign, "C89.5", "Next station after KEXP should be C89.5")

	# Previous station
	_player.tune_previous_station()
	assert_eq(_player.get_current_station().call_sign, "KEXP", "Previous station from C89.5 should be KEXP")

	# Previous station from 0 wraps to end
	var count: int = _player.get_station_count()
	_player.tune_previous_station()
	assert_eq(_player.current_station_index, count - 1, "Tuning previous from index 0 should wrap to last index")


func test_tune_to_call_sign() -> void:
	_player.tune_to_call_sign("KMGP")
	assert_not_null(_player.get_current_station(), "Station should exist")
	assert_eq(_player.get_current_station().call_sign, "KMGP", "Should tune directly to KMGP")

	_player.tune_to_call_sign("knkx")
	assert_eq(_player.get_current_station().call_sign, "KNKX", "Should tune case-insensitively to KNKX")


func test_tune_to_frequency() -> void:
	_player.tune_to_frequency(88.5)
	assert_eq(_player.get_current_station().call_sign, "KNKX", "88.5 MHz should tune to KNKX")

	_player.tune_to_frequency(98.1)
	assert_eq(_player.get_current_station().call_sign, "KING-FM", "98.1 MHz should tune to KING-FM")


func test_power_management() -> void:
	watch_signals(_player)

	assert_true(_player.is_power_on(), "Initial power is on")

	_player.set_power(false)
	assert_false(_player.is_power_on(), "Power should be off after set_power(false)")
	assert_signal_emitted_with_parameters(_player, "radio_toggled", [false], 0)

	_player.toggle_power()
	assert_true(_player.is_power_on(), "Power should be on after toggle_power()")
	assert_signal_emitted_with_parameters(_player, "radio_toggled", [true], 1)


func test_urgent_bulletin_lifecycle() -> void:
	watch_signals(_player)

	var alert_text: String = "Special Report: Severe Weather Warning in Seattle"
	_player.urgent_bulletin(null, alert_text, 0.0)

	assert_true(_player.is_bulletin_active(), "Bulletin should be active after urgent_bulletin()")
	assert_signal_emitted_with_parameters(_player, "bulletin_started", [alert_text], 0)

	_player.cancel_bulletin()
	assert_false(_player.is_bulletin_active(), "Bulletin should be inactive after cancel_bulletin()")
	assert_signal_emitted(_player, "bulletin_finished", "bulletin_finished signal emitted on cancel")


func test_urgent_bulletin_with_audio_stream() -> void:
	watch_signals(_player)

	var stream: AudioStream = load(
		"res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3"
	)
	assert_not_null(stream, "Space Needle breaking news audio stream should load")

	_player.urgent_bulletin(stream, "Breaking News Alert", 0.0)
	assert_true(_player.is_bulletin_active(), "Bulletin is active with audio stream")

	_player.cancel_bulletin()
	assert_false(_player.is_bulletin_active(), "Bulletin canceled successfully")


func test_urgent_bulletin_auto_finishes_and_resumes() -> void:
	watch_signals(_player)

	# Trigger bulletin with a very short duration to test auto-finish
	_player.urgent_bulletin(null, "Flash Alert", 0.05)
	assert_true(_player.is_bulletin_active(), "Bulletin active initially")

	# Wait for bulletin_finished signal (with 2.0s max timeout for CI stability)
	await wait_for_signal(_player.bulletin_finished, 2.0)
	assert_false(_player.is_bulletin_active(), "Bulletin auto-finishes after timer")
	assert_signal_emitted(_player, "bulletin_finished", "bulletin_finished emitted automatically")


func test_spatial_audio_follows_parent_transform() -> void:
	var dummy_parent: Node3D = Node3D.new()
	add_child_autofree(dummy_parent)
	dummy_parent.position = Vector3(50.0, 10.0, -25.0)

	var radio_instance: RadiOtPlayer3D = RadiOtPlayer3DScript.new()
	radio_instance.enable_hud = false
	dummy_parent.add_child(radio_instance)
	radio_instance.position = Vector3(0.0, 1.5, 0.0)

	# Verify global transform propagation to internal stream channels and players
	var expected_global_pos: Vector3 = Vector3(50.0, 11.5, -25.0)
	assert_eq(radio_instance.global_position, expected_global_pos, "Radio should follow parent Node3D")
	assert_eq(radio_instance._static_player.global_position, expected_global_pos, "Static player should follow radio position")
	assert_eq(radio_instance._bulletin_player.global_position, expected_global_pos, "Bulletin player should follow radio position")
	assert_eq(radio_instance._streamer._channel_a.global_position, expected_global_pos, "StreamChannelA should follow radio position")
	assert_eq(radio_instance._streamer._channel_b.global_position, expected_global_pos, "StreamChannelB should follow radio position")

	# Move parent
	dummy_parent.global_position = Vector3(100.0, 5.0, 200.0)
	var new_expected: Vector3 = Vector3(100.0, 6.5, 200.0)
	assert_eq(radio_instance.global_position, new_expected, "Radio should update when parent moves")
	assert_eq(radio_instance._streamer._channel_a.global_position, new_expected, "StreamChannelA should update when parent moves")
	assert_eq(radio_instance._streamer._channel_b.global_position, new_expected, "StreamChannelB should update when parent moves")


func test_hud_instantiation() -> void:
	var hud_player: RadiOtPlayer3D = RadiOtPlayer3DScript.new()
	hud_player.enable_hud = true
	var collection: RadioStationCollection = load(DEFAULT_COLLECTION_PATH) as RadioStationCollection
	hud_player.station_collection = collection
	add_child_autofree(hud_player)

	assert_not_null(hud_player.get_hud(), "HUD should be instantiated when enable_hud is true")



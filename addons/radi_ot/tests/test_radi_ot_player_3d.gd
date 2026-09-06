extends GutTest

## GUT Unit tests for the RadiOtPlayer3D scene.

const PLAYER_SCENE: PackedScene = preload("res://addons/radi_ot/scenes/radi_ot_player_3d.tscn")

var _player: RadiOtPlayer3D


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.enable_hud = false
	_player.auto_play_on_ready = false
	add_child_autofree(_player)


func test_scene_children_and_group() -> void:
	assert_true(_player.is_in_group("radio"), "Player scene joins the radio group")
	assert_not_null(_player._streamer)
	assert_not_null(_player._static_player)
	assert_not_null(_player._bulletin_player)
	assert_not_null(_player._bulletin_timer)
	assert_not_null(_player.get_hud())
	assert_false(_player.get_hud().visible, "enable_hud=false hides the HUD")
	assert_eq(_player._streamer.target_player, _player, "Streamer mirrors the player scene root")
	assert_true(_player._streamer.buffering_started.is_connected(_player._on_buffering_started))
	assert_true(_player._bulletin_timer.timeout.is_connected(_player._on_bulletin_finished))


func test_initial_state() -> void:
	assert_true(_player.is_power_on(), "Radio player should start powered on by default")
	assert_false(_player.is_bulletin_active(), "Bulletin should not be active initially")
	assert_eq(_player.get_current_station().call_sign, "KEXP", "Initial station should be KEXP")


func test_station_navigation_next_and_previous() -> void:
	watch_signals(_player)
	_player.tune_next_station()
	assert_signal_emit_count(_player, "station_changed", 1, "station_changed emits once per tune")
	assert_eq(_player.get_current_station().call_sign, "C89.5", "Next station after KEXP should be C89.5")
	_player.tune_previous_station()
	assert_eq(_player.get_current_station().call_sign, "KEXP", "Previous station from C89.5 should be KEXP")
	var count: int = _player.get_station_count()
	_player.tune_previous_station()
	assert_eq(_player.current_station_index, count - 1, "Tuning previous from index 0 wraps to the last index")
	_player.tune_to_station_index(count + 1)
	assert_eq(_player.current_station_index, 1, "tune_to_station_index wraps forward")


func test_tune_to_call_sign() -> void:
	_player.tune_to_call_sign("KMGP")
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
	assert_almost_eq(_player._bulletin_timer.wait_time, 5.0, 0.01, "No stream defaults to a 5 s bulletin")
	_player.cancel_bulletin()
	assert_false(_player.is_bulletin_active(), "Bulletin should be inactive after cancel_bulletin()")
	assert_signal_emitted(_player, "bulletin_finished", "bulletin_finished signal emitted on cancel")


func test_urgent_bulletin_with_audio_stream() -> void:
	var stream: AudioStream = load("res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3")
	assert_not_null(stream, "Space Needle breaking news audio stream should load")
	_player.urgent_bulletin(stream, "Breaking News Alert", 0.0)
	assert_true(_player.is_bulletin_active(), "Bulletin is active with audio stream")
	assert_true(_player._bulletin_player.playing, "Bulletin player plays the stream")
	_player.cancel_bulletin()
	assert_false(_player.is_bulletin_active(), "Bulletin canceled successfully")


func test_urgent_bulletin_auto_finishes_and_resumes() -> void:
	watch_signals(_player)
	_player.urgent_bulletin(null, "Flash Alert", 0.05)
	assert_true(_player.is_bulletin_active(), "Bulletin active initially")
	await wait_for_signal(_player.bulletin_finished, 2.0)
	assert_false(_player.is_bulletin_active(), "Bulletin auto-finishes after timer")
	assert_signal_emitted(_player, "bulletin_finished", "bulletin_finished emitted automatically")


func test_spatial_audio_follows_parent_transform() -> void:
	var dummy_parent: Node3D = Node3D.new()
	add_child_autofree(dummy_parent)
	dummy_parent.position = Vector3(50.0, 10.0, -25.0)
	var radio_instance: RadiOtPlayer3D = PLAYER_SCENE.instantiate()
	radio_instance.enable_hud = false
	dummy_parent.add_child(radio_instance)
	radio_instance.position = Vector3(0.0, 1.5, 0.0)
	var expected: Vector3 = Vector3(50.0, 11.5, -25.0)
	assert_eq(radio_instance.global_position, expected, "Radio should follow parent Node3D")
	assert_eq(radio_instance._static_player.global_position, expected, "Static player should follow radio position")
	assert_eq(radio_instance._bulletin_player.global_position, expected, "Bulletin player should follow radio position")
	assert_eq(radio_instance._streamer._channels[0].global_position, expected, "StreamChannel0 should follow radio position")
	assert_eq(radio_instance._streamer._channels[1].global_position, expected, "StreamChannel1 should follow radio position")
	dummy_parent.global_position = Vector3(100.0, 5.0, 200.0)
	assert_eq(radio_instance._streamer._channels[0].global_position, Vector3(100.0, 6.5, 200.0), "Channels update when parent moves")


func test_set_volume_reaches_both_channels() -> void:
	_player.set_volume(0.5)
	assert_almost_eq(_player.volume_db, linear_to_db(0.5), 0.001)
	assert_almost_eq(_player._bulletin_player.volume_db, linear_to_db(0.5), 0.001)
	for channel: AudioStreamPlayer3D in _player._streamer._channels:
		assert_almost_eq(channel.volume_db, linear_to_db(0.5), 0.001, "Stream channels mirror the player volume")
	_player.set_volume(0.0)
	assert_almost_eq(_player.volume_db, -80.0, 0.001, "Zero volume is silent")


func test_radi_ot_demo_scene_instantiation() -> void:
	var demo: Node = load("res://addons/radi_ot/scenes/demo/demo.tscn").instantiate()
	add_child_autofree(demo)
	assert_not_null(demo.radio_player)
	assert_eq(demo.radio_player.get_hud().hint_text, demo.HINT_TEXT, "Demo sets the HUD hint text")
	assert_true(demo.get_node("UI/PreviousStation").pressed.is_connected(demo._on_previous_station_pressed))
	assert_almost_eq(demo._camera_height, 0.8, 0.01, "Demo should preserve initial camera pos.y height")
	assert_almost_eq(demo._camera_distance, 1.6, 0.01, "Demo should preserve initial camera horizontal distance")


func test_radi_ot_demo_camera_custom_height_and_distance() -> void:
	var demo: Node = load("res://addons/radi_ot/scenes/demo/demo.tscn").instantiate()
	var cam: Camera3D = demo.get_node("Camera3D")
	cam.position = Vector3(0.0, 2.5, 6.0)
	add_child_autofree(demo)
	assert_almost_eq(demo._camera_height, 2.5, 0.01, "Camera node pos.y should be respected")
	assert_almost_eq(demo._camera_distance, 6.0, 0.01, "Camera node horizontal distance should be respected")

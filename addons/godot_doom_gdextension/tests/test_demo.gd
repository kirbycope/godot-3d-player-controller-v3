extends GutTest

## Purpose: The demo scene boots the engine full screen with the controls card, wires the music up when Godot
## MIDI Player is present, and says so instead of failing where the library is not built.

const DEMO_SCENE = preload("res://addons/godot_doom_gdextension/scenes/demo/demo.tscn")

var demo: PureDoomDemo


func before_each() -> void:
	demo = DEMO_SCENE.instantiate() as PureDoomDemo
	add_child_autofree(demo)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # The demo captures it; leave the rest of the suite alone


func test_engine_fills_the_screen_and_the_card_shows() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		assert_true(demo.missing.visible, "Without the library the demo should say so")
		assert_null(demo.engine)
		pass_test("PureDoom is not built for this platform")
		return
	assert_not_null(demo.engine, "The demo should instantiate the PureDoom node")
	assert_eq(demo.engine.get_parent(), demo.screen, "It belongs in the aspect ratio container")
	assert_true(demo.engine.call(&"is_running"), "The demo boots straight into E1M1")
	assert_false(demo.missing.visible)
	assert_true(demo.overlay.visible, "The controls card shows beside the screen")
	assert_true("Fire" in demo.overlay.actions.text)


func test_music_is_wired_to_the_midi_player_when_it_is_installed() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	if not ResourceLoader.exists(PureDoomDemo.MIDI_PLAYER_SCENE):
		assert_null(demo.midi_player, "Without Godot MIDI Player the demo runs silent")
		pass_test("Godot MIDI Player is not installed")
		return
	assert_not_null(demo.midi_player, "The SoundFont should bring up the MIDI player")
	assert_true(demo.engine.is_connected(&"midi_message", Callable(demo.midi_player, &"receive_raw_midi_message")))
	await wait_seconds(1.5)
	assert_gt(demo.midi_player.get_now_playing_polyphony(), 0, "E1M1's music should be sounding")


func test_the_engine_quitting_stops_the_music_and_reports_the_code() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	demo._on_engine_exited(0)
	assert_true(demo.missing.visible)
	assert_true("code 0" in demo.missing.text, "The exit code should be reported on screen")
	assert_false(demo.engine.visible)
	assert_false(demo.overlay.visible)
	assert_false(demo.mouse_captured, "Quitting DOOM should give the cursor back")
	_assert_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## DOOM turns on relative mouse motion, so the demo takes the cursor as soon as it boots. Browsers only grant
## pointer lock inside a user gesture, so on web an interstitial holds the capture back until the first click.
func test_the_mouse_is_captured_on_ready() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	assert_eq(demo.click_to_start.visible, OS.has_feature("web"), "The interstitial is a web-only workaround")
	assert_true(demo.mouse_captured, "The demo should take the cursor as it boots")
	_assert_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func test_escape_gives_the_cursor_back_and_a_click_takes_it_again() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	demo.click_to_start.hide() # As the first click on web leaves it, and as it already is everywhere else
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	demo._input(escape)
	assert_false(demo.mouse_captured, "Escape should not trap the cursor")
	_assert_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	demo._input(click)
	assert_true(demo.mouse_captured, "Clicking back in should take it again")
	_assert_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func test_the_interstitial_captures_on_the_first_click() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	demo.release_mouse()
	demo.click_to_start.show() # What web starts with
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	demo._input(click)
	assert_false(demo.click_to_start.visible, "The click dismisses the interstitial")
	assert_true(demo.mouse_captured, "and pointer lock is asked for from inside it")
	_assert_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Headless has no display server, so Input.mouse_mode never leaves MOUSE_MODE_VISIBLE there; what the demo
## intends is asserted through mouse_captured either way, and the real mode only under a real window.
func _assert_mouse_mode(expected: Input.MouseMode) -> void:
	if DisplayServer.get_name() == "headless":
		return
	assert_eq(Input.mouse_mode, expected, "The cursor should follow what the demo intends")

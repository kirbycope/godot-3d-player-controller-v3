extends GutTest

## Purpose: Checks the PureDoom GDExtension node boots the shareware WAD, renders frames and pauses cleanly.
## Skipped on platforms without a built library.

var doom: Control


func before_each() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		return
	doom = ClassDB.instantiate(&"PureDoom") as Control
	add_child_autofree(doom)


func test_engine_boots_and_renders_frames() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	assert_false(doom.call(&"is_running"))
	doom.call(&"start")
	assert_true(doom.call(&"is_running"), "start() should run the engine")
	await wait_process_frames(40)
	var texture = doom.texture
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(320, 200), "DOOM renders at 320x200")
	# The title-less warp into E1M1 draws something other than a black frame (read on the CPU: headless has no GPU texture)
	var image: Image = doom.call(&"get_frame")
	var lit = 0
	for x in range(0, 320, 16):
		for y in range(0, 200, 16):
			if image.get_pixel(x, y).get_luminance() > 0.05:
				lit += 1
	assert_gt(lit, 0, "The frame should not be black once the level is running")


func test_music_arrives_as_midi_events() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	var messages = []
	doom.connect(&"midi_message", func(event: InputEventMIDI) -> void: messages.append(event))
	doom.call(&"start")
	await wait_seconds(1.0)
	assert_gt(messages.size(), 0, "E1M1's music should be sequenced out as MIDI events")
	var has_note = false
	for event in messages:
		if event.message == MIDI_MESSAGE_NOTE_ON:
			has_note = true
	assert_true(has_note, "At least one note on should have played")


## Typing the level-warp cheat loads a new map, the path that once read a dangling argv and crashed.
func test_changing_level_keeps_the_engine_alive() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	doom.call(&"start")
	await wait_process_frames(5)
	for character in "idclev12":
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = OS.find_keycode_from_string(character)
			key.pressed = pressed
			Input.parse_input_event(key)
			await wait_process_frames(1)
	await wait_seconds(1.0)
	assert_true(doom.call(&"is_running"), "The engine should still be running on the new level")
	var image: Image = doom.call(&"get_frame")
	var lit = 0
	for x in range(0, 320, 16):
		for y in range(0, 200, 16):
			if image.get_pixel(x, y).get_luminance() > 0.05:
				lit += 1
	assert_gt(lit, 0, "The new level should be drawing")


func test_pad_back_toggles_the_menu_and_dpad_cycles_weapons() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	doom.call(&"start")
	await wait_process_frames(5)
	assert_eq(doom.call(&"get_weapon_slot"), 2, "You start with the pistol in hand")
	assert_false(doom.call(&"is_menu_open"))
	await _press_joy(JOY_BUTTON_BACK)
	await wait_seconds(0.3)
	assert_true(doom.call(&"is_menu_open"), "Back should open DOOM's menu")
	await _press_joy(JOY_BUTTON_BACK)
	await wait_seconds(0.3)
	assert_false(doom.call(&"is_menu_open"), "Back again should close it")
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	await wait_seconds(1.5)
	assert_eq(doom.call(&"get_weapon_slot"), 1, "Cycling right from the pistol skips the weapons you do not own and wraps to the fist")


func test_tab_toggles_the_automap() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	if not doom.has_method(&"is_automap_open"):
		fail_test("This library predates is_automap_open; rebuild it")
		return
	doom.call(&"start")
	await wait_until(_level_is_drawing, 3.0) # Into E1M1; the automap only answers on a level
	assert_true(_level_is_drawing(), "The level should be drawing before Tab is pressed")
	assert_false(doom.call(&"is_automap_open"))
	await _press_key(KEY_TAB)
	await wait_until(func() -> bool: return doom.call(&"is_automap_open"), 1.0) # Read on the engine's next tic
	assert_true(doom.call(&"is_automap_open"), "Tab should open the automap")
	await _press_key(KEY_TAB)
	await wait_until(func() -> bool: return not doom.call(&"is_automap_open"), 1.0)
	assert_false(doom.call(&"is_automap_open"), "Tab again should close it")


## DOOM draws nothing until the level is loaded, so any lit pixel means E1M1 is up.
func _level_is_drawing() -> bool:
	var image: Image = doom.call(&"get_frame")
	for x in range(0, 320, 16):
		for y in range(0, 200, 16):
			if image.get_pixel(x, y).get_luminance() > 0.05:
				return true
	return false


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2) # Input is flushed on the next frame, so the engine sees the press before the release


func _press_joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2) # Input is flushed on the next frame, so the engine sees the press before the release


func test_stop_pauses_and_start_resumes() -> void:
	if doom == null:
		pass_test("PureDoom is not built for this platform")
		return
	doom.call(&"start")
	await wait_process_frames(3)
	doom.call(&"stop")
	assert_false(doom.call(&"is_running"))
	assert_false(doom.is_processing(), "A stopped engine should not tick")
	doom.call(&"start")
	assert_true(doom.call(&"is_running"))
	assert_true(doom.is_processing())

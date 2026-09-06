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

extends GutTest

## Purpose: The controls card beside the monitor lists the default card's lines in plain text and rewords them
## per input device.

const OVERLAY_SCENE = preload("res://addons/pure_doom/scenes/pure_doom_controls_overlay.tscn")

var overlay: PureDoomControlsOverlay


func before_each() -> void:
	overlay = OVERLAY_SCENE.instantiate() as PureDoomControlsOverlay
	add_child_autofree(overlay)


func test_default_card_has_both_columns() -> void:
	assert_not_null(overlay.controls)
	assert_gt(overlay.controls.movement.size(), 0)
	assert_gt(overlay.controls.actions.size(), 0)
	assert_true(overlay.movement.text.begins_with("[color=white]MOVEMENT"))
	assert_true(overlay.actions.text.begins_with("[color=white]ACTIONS"))
	assert_true("Space" in overlay.actions.text, "Keyboard is the default wording")
	assert_true("Use, open" in overlay.actions.text)


func test_wording_follows_the_input_type() -> void:
	overlay.input_type = "xbox"
	assert_true("[color=white]A[/color]\n  Use, open" in overlay.actions.text)
	assert_false("Space" in overlay.actions.text)
	overlay.input_type = "nintendo"
	assert_true("[color=white]B[/color]\n  Use, open" in overlay.actions.text)
	overlay.input_type = "playstation"
	assert_true("[color=white]Cross[/color]\n  Use, open" in overlay.actions.text)
	overlay.input_type = "touch"
	assert_true("[color=white]A[/color]\n  Use, open" in overlay.actions.text, "Touch shows the Xbox wording, like the touch HUD")


func test_lines_without_text_for_a_device_are_dropped() -> void:
	overlay.input_type = "keyboard"
	assert_true("Strafe (hold)" in overlay.movement.text)
	assert_true("1 to 7" in overlay.actions.text)
	overlay.input_type = "xbox"
	assert_false("Strafe (hold)" in overlay.movement.text, "The strafe modifier is keyboard-only")
	assert_true("D-pad left, right" in overlay.actions.text, "Pads cycle weapons with the d-pad")


func test_text_for_falls_back_to_keyboard() -> void:
	var line := PureDoomControl.new()
	line.keyboard = "Tab"
	assert_eq(line.text_for("keyboard"), "Tab")
	assert_eq(line.text_for("unknown"), "Tab")
	assert_eq(line.text_for("xbox"), "")

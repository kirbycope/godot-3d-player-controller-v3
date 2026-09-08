extends GutTest

## Purpose: doom_raycaster.tscn runs the GDScript DOOM on its own for Run Current Scene: it registers the addon's
## actions, boots at once, captures the mouse, and plays the raycaster even where the real engine's library is built.
## Input reaches the game only while the mouse is captured; the click that takes it back never fires the shotgun.

const SCENE: PackedScene = preload("res://scenes/doom_raycaster.tscn")

var arcade: Control


func before_each() -> void:
	arcade = partial_double(SCENE).instantiate()
	stub(arcade, "_mouse_captured").to_return(true) # Headless cannot capture the mouse, so the scene is told it has
	add_child_autofree(arcade)
	await wait_process_frames(1)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_boots_straight_into_the_raycaster_with_the_actions_registered() -> void:
	var doom: Doom = arcade.doom
	assert_false(doom.use_engine, "The engine is off for this scene")
	for action: String in ["move_left", "move_right", "move_up", "move_down", "look_left", "look_right", "shoot", "action"]:
		assert_true(InputMap.has_action(action), action + " is registered")
	assert_eq(doom.screen, Doom.Screen.BOOTING, "Boots on its own, no computer to switch it on")
	if not _headless():
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "The mouse turns the view")
	_boot_into_the_game()
	assert_eq(doom.screen, Doom.Screen.PLAYING, "The raycaster, whatever library is built")
	assert_null(doom.engine, "The real engine was never created")
	assert_true(doom.is_physics_processing())
	assert_eq(arcade.viewport.size, Vector2i(320, 200), "The screen keeps its pixels; the TextureRect scales them")
	assert_eq(arcade.screen.texture, arcade.viewport.get_texture())
	var shoot: InputEventAction = InputEventAction.new()
	shoot.action = "shoot"
	shoot.pressed = true
	var ammo: int = doom.ammo
	arcade._input(shoot)
	await wait_process_frames(1)
	assert_eq(doom.ammo, ammo - 1, "Input pushed into the screen's viewport reaches the game")


func test_input_while_captured_reaches_the_game() -> void:
	_boot_into_the_game()
	var doom: Doom = arcade.doom
	var ammo: int = doom.ammo
	var angle: float = doom.player_angle
	arcade._input(_click())
	arcade._input(_motion())
	assert_eq(doom.ammo, ammo - 1, "A click fires while the mouse is captured")
	assert_ne(doom.player_angle, angle, "Motion turns the view while the mouse is captured")


func test_a_click_while_released_takes_the_mouse_back_without_firing() -> void:
	stub(arcade, "_mouse_captured").to_return(false)
	_boot_into_the_game()
	var doom: Doom = arcade.doom
	var ammo: int = doom.ammo
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arcade._input(_click())
	assert_true(arcade.get_viewport().is_input_handled(), "The click is spent on taking the mouse back")
	assert_eq(doom.ammo, ammo, "The recapturing click never reaches the shotgun")
	if not _headless():
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED)


func test_motion_while_released_never_reaches_the_game() -> void:
	stub(arcade, "_mouse_captured").to_return(false)
	_boot_into_the_game()
	var doom: Doom = arcade.doom
	var angle: float = doom.player_angle
	arcade._input(_motion())
	assert_eq(doom.player_angle, angle, "The view does not turn while the mouse is free")


## A headless run cannot capture the mouse, so its mode never changes there.
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func test_escape_releases_the_mouse_and_a_click_takes_it_back() -> void:
	if _headless():
		pass_test("Headless has no mouse to capture")
		return
	stub(arcade, "_mouse_captured").to_call_super() # A real window: the scene reads the real mouse mode
	var escape: InputEventAction = InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	arcade._input(escape)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	arcade._input(_click())
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED)


## Runs the boot timer through the DOS prompt and the startup log so the raycaster is playing.
func _boot_into_the_game() -> void:
	var doom: Doom = arcade.doom
	for i: int in Doom.COMMAND.length():
		doom._on_boot_timer_timeout()
	for i: int in Doom.BOOT_LINES.size() + 1:
		doom._on_boot_timer_timeout()


## A captured cursor sits at the window's centre, outside the 320x200 screen rect; inside it the Doom control's own
## GUI would take the event before the game's _unhandled_input.
const CURSOR: Vector2 = Vector2(640.0, 400.0)


func _click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = CURSOR
	return click


func _motion() -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, 0.0)
	motion.position = CURSOR
	return motion

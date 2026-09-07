extends GutTest

## Purpose: doom_raycaster.tscn runs the GDScript DOOM on its own for Run Current Scene: it registers the addon's
## actions, boots at once, captures the mouse, and plays the raycaster even where the real engine's library is built.

const SCENE: PackedScene = preload("res://scenes/doom_raycaster.tscn")

var arcade: Control


func before_each() -> void:
	arcade = SCENE.instantiate()
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
	for i: int in Doom.COMMAND.length():
		doom._on_boot_timer_timeout()
	for i: int in Doom.BOOT_LINES.size() + 1:
		doom._on_boot_timer_timeout()
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


## A headless run cannot capture the mouse, so its mode never changes there.
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func test_escape_releases_the_mouse_and_a_click_takes_it_back() -> void:
	if _headless():
		pass_test("Headless has no mouse to capture")
		return
	var escape: InputEventAction = InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	arcade._input(escape)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arcade._input(click)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED)

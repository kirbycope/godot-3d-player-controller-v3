extends GutTest

## Purpose: Integration test for the RetroComputer: using it hands the view to its screen camera, pauses the
## Player and feeds input to the game on its screen; "start" gives everything back.

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const COMPUTER_SCENE = preload("res://scenes/retro_computer.tscn")

var root: Node3D
var player: Player
var computer: RetroComputer


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)

	computer = COMPUTER_SCENE.instantiate() as RetroComputer
	computer.position = Vector3(0, 0, -2)
	root.add_child(computer)

	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null
	player = null
	computer = null


func test_prompt_shows_while_looking_at_it() -> void:
	assert_false(computer.action_prompt.visible)
	computer.display_menu(player)
	assert_true(computer.action_prompt.visible)
	computer.hide_menu()
	assert_false(computer.action_prompt.visible)


func test_using_the_computer_takes_the_camera_and_boots_doom() -> void:
	player.controls.current_input_type = player.controls.InputType.KEYBOARD_MOUSE
	computer.equip(player)
	assert_true(computer.is_in_use)
	assert_true(player.is_paused, "The Player should be frozen at the keyboard")
	assert_true(computer.screen_camera.current, "The view should move to the screen")
	assert_false(player.camera.current)
	assert_eq(computer.doom.screen, Doom.Screen.BOOTING)
	assert_true(computer.is_processing_input(), "The computer should take over input while in use")
	assert_false(computer.action_prompt.visible)
	assert_false(player.controls.visible, "The on-screen controls should hide for keyboard and pad players")
	assert_false(player.crosshair.visible, "The crosshair should hide over the monitor")
	assert_true(computer.controls_overlay.visible, "The controls card should show beside the monitor")
	assert_eq(computer.controls_overlay.input_type, "keyboard")
	player.controls.current_input_type = player.controls.InputType.SONY
	assert_eq(computer.controls_overlay.input_type, "playstation", "The card should follow the input device")


func test_input_reaches_the_game_and_start_leaves() -> void:
	computer.equip(player)
	computer.doom.start_level()
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	computer._input(motion)
	assert_almost_eq(computer.doom.player_angle, 50.0 * computer.doom.mouse_sensitivity, 0.0001, "Mouse motion should turn the game view")

	var start = InputEventAction.new()
	start.action = "start"
	start.pressed = true
	computer._input(start)
	assert_false(computer.is_in_use)
	assert_false(player.is_paused, "Leaving should unfreeze the Player")
	assert_true(player.camera.current, "Leaving should give the Player their camera back")
	assert_false(computer.screen_camera.current)
	assert_false(computer.is_processing_input())
	assert_true(player.controls.visible, "Leaving should bring the on-screen controls back")
	assert_true(player.crosshair.visible, "Leaving should bring the crosshair back")
	assert_false(computer.controls_overlay.visible, "Leaving should hide the controls card")
	assert_eq(computer.doom.screen, Doom.Screen.PROMPT, "The screen should drop back to the DOS prompt")


func test_ragdolling_at_the_keyboard_releases_the_player() -> void:
	computer.equip(player)
	player.is_ragdolling = true
	var motion = InputEventMouseMotion.new()
	computer._input(motion)
	assert_false(computer.is_in_use, "A knocked-down Player should be released from the computer")
	assert_true(player.camera.current)
	assert_eq(computer.doom.screen, Doom.Screen.PROMPT)


func test_riding_player_cannot_use_it() -> void:
	player.is_riding = true
	computer.equip(player)
	assert_false(computer.is_in_use)
	assert_false(player.is_paused)

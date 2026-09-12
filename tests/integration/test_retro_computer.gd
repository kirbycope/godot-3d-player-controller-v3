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
	assert_true(player.controls.visible, "The HUD stays up, re-labelled for DOOM")
	assert_false(player.crosshair.visible, "The crosshair should hide over the monitor")
	assert_eq(player.controls.key_s_label.text, "Move, strafe", "and the HUD says what DOOM does, not what the game does")


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
	assert_eq(player.controls.key_s_label.text, "Move", "and the HUD goes back to the game's own words")
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


## Swapping device puts the Controls' own labels back, so the DOOM words have to go on again or the HUD
## silently reverts to naming the game's actions while the Player is still at the keyboard.
func test_the_doom_words_survive_a_change_of_device() -> void:
	player.controls.current_input_type = player.controls.InputType.MICROSOFT
	computer.equip(player)
	assert_eq(player.controls.joypad_button_2_label.text, "Fire")
	player.controls.current_input_type = player.controls.InputType.SONY
	assert_eq(player.controls.joypad_button_2_label.text, "Fire", "and they stay on through the swap")


func test_using_it_seats_the_player_and_starts_them_typing() -> void:
	computer.equip(player)
	assert_true(player.is_sitting, "The Player should be in the chair")
	assert_true(player.is_typing_at_keyboard, "The typing pose drives off this flag")
	assert_almost_eq(player.global_position, computer.player_seat.global_position, Vector3.ONE * 0.001,
			"The Player should be warped onto the seat marker")


func test_the_head_turns_onto_the_screen_and_lets_go_again() -> void:
	var modifier: LookAtModifier3D = player.head_look_at_modifier as LookAtModifier3D
	assert_false(modifier.active, "Nothing should be driving the head before sitting down")
	computer.equip(player)
	assert_true(modifier.active, "Sitting down should point the head at the CRT")
	assert_eq(modifier.get_node(modifier.target_node), computer.screen, "It should look at the screen itself")
	assert_eq(modifier.bone_name, "Head", "The spine modifier is a separate one used for aiming")
	computer.stop_using()
	assert_false(modifier.active, "Getting up should release the head")
	assert_eq(modifier.target_node, NodePath(""), "and clear the target with it")


func test_first_person_gets_a_square_view_and_third_person_the_shoulder_shot() -> void:
	(player.camera as Camera).perspective = Camera.Perspective.FIRST_PERSON
	computer.equip(player)
	assert_eq(computer.screen_camera.fov, computer.first_person_camera_fov,
			"First person should take the square-on framing")
	assert_almost_eq(computer.screen_camera.position.x, computer.first_person_camera_position.x, 0.001,
			"and sit on the screen's own axis rather than off to one side")
	computer.stop_using()

	(player.camera as Camera).perspective = Camera.Perspective.THIRD_PERSON
	computer.equip(player)
	assert_eq(computer.screen_camera.fov, computer.seated_camera_fov,
			"Third person should take the over-the-shoulder framing")


func test_the_hud_names_doom_not_the_player_controller() -> void:
	player.controls.current_input_type = player.controls.InputType.MICROSOFT
	computer.equip(player)
	assert_eq(player.controls.joypad_axis_5_plus_label.text, "Fire")
	assert_eq(player.controls.joypad_button_0_label.text, "Use, open")
	assert_eq(player.controls.joypad_button_6_label.text, "Get Up")
	assert_eq(player.controls.joypad_button_13_label.text, "Weapon")
	computer.stop_using()
	assert_eq(player.controls.joypad_button_0_label.text, "Action",
			"Leaving should give the player controller its own labels back")


func test_the_keyboard_gets_the_two_clusters_its_glyphs_can_tell_the_truth_about() -> void:
	player.controls.current_input_type = player.controls.InputType.KEYBOARD_MOUSE
	computer.equip(player)
	assert_eq(player.controls.key_s_label.text, "Move, strafe", "WASD really is DOOM's movement")
	assert_eq(player.controls.key_down_label.text, "Turn", "and the arrows really do turn")
	assert_eq(player.controls.key_i_label.text, "",
			"IJKL are blanked: set_labels would otherwise mirror the d-pad onto keys DOOM does not use")


func test_sitting_back_down_cancels_a_pending_stand_up() -> void:
	computer.equip(player)
	computer.stop_using()
	assert_true(player.locomotion_node_changed.is_connected(computer._on_player_locomotion_node_changed),
			"Leaving waits for the lead-out before standing the Player up")
	computer.equip(player)
	assert_false(player.locomotion_node_changed.is_connected(computer._on_player_locomotion_node_changed),
			"Sitting back down first must cancel it, or it stands them up at the keyboard")
	assert_true(computer.is_in_use)
	assert_true(player.is_sitting)

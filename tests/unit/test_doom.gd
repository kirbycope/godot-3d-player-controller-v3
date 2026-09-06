extends GutTest

## Purpose: Unit tests for the Doom raycaster on the retro computer's screen: the prompt, booting, the map,
## movement against walls, shooting, biting and restarting.

const DOOM_SCENE = preload("res://scenes/doom.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")

var doom: Doom


func before_each() -> void:
	# The controls register the move, look and shoot actions the game reads
	add_child_autofree(CONTROLS_SCENE.instantiate())
	doom = DOOM_SCENE.instantiate() as Doom
	add_child_autofree(doom)


func test_starts_asleep_at_the_prompt() -> void:
	assert_eq(doom.screen, Doom.Screen.PROMPT)
	assert_true(doom.boot_label.visible, "The DOS prompt should show while asleep")
	assert_false(doom.is_physics_processing(), "Nothing should simulate while asleep")


func test_boot_types_the_command_then_starts_the_level() -> void:
	doom.boot()
	assert_eq(doom.screen, Doom.Screen.BOOTING)
	for i in Doom.COMMAND.length():
		doom._on_boot_timer_timeout()
	assert_true(doom.boot_label.text.ends_with("C:\\>DOOM.EXE"), "The command should be typed at the prompt")
	for i in Doom.BOOT_LINES.size() + 1:
		doom._on_boot_timer_timeout()
	assert_false(doom.boot_label.visible, "The log should clear once the level starts")
	if ClassDB.class_exists(&"PureDoom"):
		assert_eq(doom.screen, Doom.Screen.ENGINE, "With the library built, the real engine takes the screen")
		assert_true(doom.engine.visible)
		assert_true(doom.engine.call(&"is_running"))
		doom.sleep()
		assert_false(doom.engine.call(&"is_running"), "Sleeping pauses the engine")
		assert_false(doom.engine.visible)
	else:
		assert_eq(doom.screen, Doom.Screen.PLAYING)
		assert_true(doom.is_physics_processing())


func test_music_plays_through_the_soundfont() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		pass_test("PureDoom is not built for this platform")
		return
	doom.soundfont = "res://addons/pure_doom/assets/gzdoom.sf2"
	doom.start_game()
	assert_not_null(doom.midi_player, "A SoundFont should bring up the MIDI player")
	await wait_seconds(1.5)
	assert_gt(doom.midi_player.get_now_playing_polyphony(), 0, "E1M1's music should be sounding")
	doom.sleep()
	await wait_process_frames(2)
	assert_eq(doom.midi_player.get_now_playing_polyphony(), 0, "Sleeping should silence the music")


func test_level_places_player_and_demons_from_map() -> void:
	doom.start_level()
	var demon_count = 0
	for row in Doom.MAP:
		demon_count += row.count("E")
	assert_eq(doom.demons.size(), demon_count)
	assert_eq(doom.player_position, Vector2(1.5, 1.5))
	assert_false(doom.is_wall(doom.player_position))
	for demon in doom.demons:
		assert_false(doom.is_wall(demon.position))
	assert_eq(doom.health, 100)
	assert_eq(doom.ammo, 50)
	assert_eq(doom.kills, 0)


func test_walls_stop_movement() -> void:
	doom.start_level()
	var blocked = doom.slide(Vector2(1.5, 1.5), Vector2(-2.0, 0.0), 0.25)
	assert_eq(blocked, Vector2(1.5, 1.5), "Walking into the west wall should not move")
	var moved = doom.slide(Vector2(1.5, 1.5), Vector2(1.0, 0.0), 0.25)
	assert_eq(moved, Vector2(2.5, 1.5), "Open floor should be walkable")
	assert_true(doom.is_wall(Vector2(0.5, 0.5)))
	assert_true(doom.is_wall(Vector2(-1.0, 3.0)), "Off the map counts as wall")


func test_shotgun_kills_demon_in_line_of_fire() -> void:
	doom.start_level()
	doom.demons.resize(1)
	var demon = doom.demons[0]
	demon.position = doom.player_position + Vector2(2.0, 0.0)
	doom.fire()
	assert_eq(demon.health, 80 - doom.shotgun_damage)
	assert_eq(doom.ammo, 49)
	assert_true(demon.is_awake, "A shot wakes the demon")
	doom.fire()
	assert_eq(demon.health, 80 - doom.shotgun_damage, "The shotgun should not fire again during its cooldown")
	doom.fire_cooldown = 0.0
	doom.fire()
	assert_lte(demon.health, 0)
	assert_eq(doom.kills, 1)
	assert_eq(doom.screen, Doom.Screen.WON, "Killing the last demon wins the level")


func test_shotgun_misses_demon_behind_a_wall() -> void:
	doom.start_level()
	doom.demons.resize(1)
	var demon = doom.demons[0]
	demon.position = Vector2(8.5, 1.5) # The wall segment at column 7 is in the way
	doom.fire()
	assert_eq(demon.health, 80)
	assert_eq(doom.ammo, 49, "The shell is still spent")


func test_demon_bites_until_you_die_and_fire_restarts() -> void:
	doom.start_level()
	doom.demons.resize(1)
	var demon = doom.demons[0]
	demon.position = doom.player_position + Vector2(1.0, 0.0)
	demon.is_awake = true
	doom.health = doom.demon_bite
	doom._physics_process(0.1)
	assert_eq(doom.health, 0)
	assert_eq(doom.screen, Doom.Screen.DEAD)
	var shoot = InputEventAction.new()
	shoot.action = "shoot"
	shoot.pressed = true
	doom._unhandled_input(shoot)
	assert_eq(doom.screen, Doom.Screen.PLAYING, "Fire restarts the level")
	assert_eq(doom.health, 100)


func test_mouse_motion_turns_the_view() -> void:
	doom.start_level()
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 0)
	doom._unhandled_input(motion)
	assert_almost_eq(doom.player_angle, 100.0 * doom.mouse_sensitivity, 0.0001)


func test_sleep_returns_to_the_prompt() -> void:
	doom.start_level()
	doom.sleep()
	assert_eq(doom.screen, Doom.Screen.PROMPT)
	assert_true(doom.boot_label.visible)
	assert_false(doom.is_physics_processing())

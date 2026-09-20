extends GutTest

## Purpose: the world is played on Tears of the Kingdom's pad with the buttons on screen. world.gd puts its own
## control_scheme on the Player as it spawns, after the Player has applied the saved settings in its own _ready,
## so the world's choice is the one that sticks. The HUD is left to the saved On-Screen setting, Auto unless
## the player changed it, so the buttons show on a touchscreen and otherwise only as contextual hints; the demo
## levels are where the whole set is drawn. show_controls forces the whole set; clearing either export leaves
## the Player alone.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")
const TOTK: ControlScheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")

var world: Node
var player: Player


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)
	player = world.get_node("Players/1")


func test_the_world_is_played_on_the_zelda_layout() -> void:
	assert_eq(world.control_scheme, TOTK, "The world asks for Tears of the Kingdom's pad")
	assert_eq(player.control_scheme, TOTK, "and the spawned Player is on it")
	assert_true(player.lock_on_enabled(), "so Focus locks on")
	assert_eq(player.controls.action_button_0, &"sprint", "The bottom button dashes, as the game has it")
	assert_eq(player.controls.action_button_1, &"action", "and the right one is Action")


func test_the_hud_follows_the_saved_setting() -> void:
	assert_false(world.show_controls, "The world does not force its controls on")
	assert_eq(player.hud_mode_override, -1, "so the Player is on the saved On-Screen setting")
	assert_true(player.controls.visible, "The HUD node is up either way")
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	assert_eq(player.controls.contextual_only, not settings.hud_shown(player.controls.current_input_type, DisplayServer.is_touchscreen_available()), "and the setting decides whether the whole set or only the contextual hints are drawn")


func test_show_controls_forces_the_whole_set() -> void:
	var forced: Node = WORLD_SCENE.instantiate()
	forced.show_controls = true
	add_child_autofree(forced)
	await wait_physics_frames(2)
	var forced_player: Player = forced.get_node("Players/1")
	assert_eq(forced_player.hud_mode_override, PlayerSettingsResource.HudMode.SHOWN, "The export still forces the whole HUD for a world that wants it")
	assert_false(forced_player.controls.contextual_only)

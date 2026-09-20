extends GutTest

## Purpose: the world is played on Tears of the Kingdom's pad with the buttons on screen. world.gd puts its own
## control_scheme on the Player as it spawns, after the Player has applied the saved settings in its own _ready,
## so the world's choice is the one that sticks; show_controls draws the whole HUD rather than only the
## contextual buttons. Clearing either export leaves the Player alone.

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


func test_the_buttons_are_on_screen() -> void:
	assert_true(world.show_controls, "The world draws its controls")
	assert_eq(player.hud_mode_override, PlayerSettingsResource.HudMode.SHOWN)
	assert_true(player.controls.visible, "so the HUD is up")
	assert_false(player.controls.contextual_only, "showing every button, not only the ones that mean something now")

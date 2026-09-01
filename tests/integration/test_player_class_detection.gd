extends GutTest

## Purpose: Integration tests proving WeatherFX detects the player via the "Player" group
## (O(1) lookup, class_name fallback) and that updraft proximity VFX activates for a nearby player.

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")
const FIRE_TRAIL_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/fire_trail_node.tscn")

var player: Player


func before_each() -> void:
	WeatherFX._player_cache = null
	WeatherFX._player_search_cooldown_frame = -1
	WeatherFX.active_precipitation_strength = 0.0

	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)


func after_each() -> void:
	WeatherFX._player_cache = null
	WeatherFX._player_search_cooldown_frame = -1


func test_is_player_node_matches_player_class() -> void:
	assert_true(player.is_in_group("Player"), "The Player scene root must be in the Player group")
	assert_true(WeatherFX.is_player_node(player), "The Player scene must be detected by WeatherFX")


func test_find_player_locates_and_caches_the_player() -> void:
	var found: Node3D = WeatherFX.find_player(get_tree())
	assert_eq(found, player, "find_player should locate the Player via the group")
	assert_eq(WeatherFX.find_player(get_tree()), player, "Second lookup should also resolve")


func test_updraft_vfx_activates_when_player_is_near() -> void:
	var fire = FIRE_TRAIL_SCENE.instantiate()
	add_child_autofree(fire)
	fire.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)

	fire._process(0.05)
	var updraft_vfx: Node3D = fire.get_node("UpdraftVFX") as Node3D
	assert_true(updraft_vfx.visible, "Updraft VFX should activate when the Player is within trigger distance")

	# And deactivate when the player moves far away
	player.global_position += Vector3(50.0, 0.0, 0.0)
	fire._process(0.05)
	assert_false(updraft_vfx.visible, "Updraft VFX should deactivate when the Player leaves trigger distance")

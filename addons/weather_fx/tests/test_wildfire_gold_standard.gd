extends GutTest

## Purpose: Unit tests for BotW gold-standard wildfire physics that live with the WeatherFX addon —
## fire front creep speed band, shared wind spread math, burnout group cleanup,
## BurnableGrass -> GrassField propagation delegation, and Player-class duck typing.

const GrassFieldScript: Script = preload("res://addons/weather_fx/scripts/grass_field.gd")
const BurnableGrassScript: Script = preload("res://addons/weather_fx/scripts/burnable_grass.gd")
const FIRE_TRAIL_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/fire_trail_node.tscn")

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	WeatherFX.active_wind_strength = 0.0
	WeatherFX.active_wind_direction = Vector3(1.0, 0.0, 0.0)
	WeatherFX.active_precipitation_strength = 0.0
	WeatherFX._player_cache = null
	WeatherFX._player_search_cooldown_frame = -1


func after_each() -> void:
	WeatherFX.active_wind_strength = 0.0
	WeatherFX.active_precipitation_strength = 0.0
	WeatherFX._player_cache = null
	WeatherFX._player_search_cooldown_frame = -1


func test_creep_speed_stays_in_botw_band_even_in_storm_wind() -> void:
	WeatherFX.active_wind_strength = 16.0

	var field = GrassFieldScript.new()
	field.field_size = Vector2(40.0, 40.0)
	field.instance_count = 20
	root.add_child(field)
	field.regenerate()

	field.ignite_at(Vector3.ZERO, 2.0, 8.0)
	assert_gt(field._creeper_heads.size(), 0, "Ignition should spawn creeper heads")
	for head in field._creeper_heads:
		assert_between(head.speed, GrassFieldScript.CREEP_SPEED_MIN, GrassFieldScript.CREEP_SPEED_MAX,
				"Fire front creep speed must stay within the BotW 1.2-1.8 m/s band regardless of wind strength")

	# Branch heads must respect the band too
	field._spawn_branch_head(Vector2.ZERO, Vector2.RIGHT, 0.4)
	var branch = field._creeper_heads[field._creeper_heads.size() - 1]
	assert_between(branch.speed, GrassFieldScript.CREEP_SPEED_MIN, GrassFieldScript.CREEP_SPEED_MAX,
			"Branch head creep speed must stay within the BotW band")


func test_wind_spread_factor_math() -> void:
	assert_almost_eq(WeatherFX.get_wind_spread_factor(0.0, 6.0), 1.0, 0.001, "Crosswind should not change spread range")
	assert_almost_eq(WeatherFX.get_wind_spread_factor(1.0, 6.0, 0.35), 3.1, 0.001, "Downwind should boost spread range")
	assert_almost_eq(WeatherFX.get_wind_spread_factor(-1.0, 6.0), 0.5, 0.001, "Upwind should suppress spread range")
	assert_almost_eq(WeatherFX.get_wind_spread_factor(1.0, 100.0), 3.5, 0.001, "Downwind boost must be capped")


func test_fire_trail_burnout_removes_updraft_groups() -> void:
	var fire = FIRE_TRAIL_SCENE.instantiate()
	root.add_child(fire)
	var area: Area3D = fire.get_node("ThermalUpdraftArea") as Area3D
	assert_true(area.is_in_group("Updraft"), "Burning trail node should register an Updraft area")
	assert_true(area.is_in_group("Thermal"), "Burning trail node should register a Thermal area")

	fire._burn_out()

	assert_false(area.monitoring, "Burned-out updraft area should stop monitoring")
	assert_false(area.is_in_group("Updraft"), "Burned-out updraft area must leave the Updraft group (no ghost lift)")
	assert_false(area.is_in_group("Thermal"), "Burned-out updraft area must leave the Thermal group")


func test_burnable_grass_delegates_creeping_to_grass_field() -> void:
	var field = GrassFieldScript.new()
	field.field_size = Vector2(40.0, 40.0)
	field.instance_count = 20
	root.add_child(field)
	field.regenerate()

	var grass = BurnableGrassScript.new()
	root.add_child(grass)
	grass.global_position = Vector3.ZERO
	grass._setup_components()

	assert_eq(field._active_fires.size(), 0)
	grass.ignite()
	assert_gt(field._active_fires.size(), 0, "Igniting BurnableGrass should hand creeping propagation to the overlapping GrassField")


func test_is_player_node_prefers_group_then_class() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	body.name = "Player" # A node merely NAMED Player must not match
	assert_false(WeatherFX.is_player_node(body), "Plain CharacterBody3D must not be detected as the Player")
	assert_false(WeatherFX.is_player_node(null))

	body.add_to_group("Player")
	assert_true(WeatherFX.is_player_node(body), "Any node in the Player group must be detected (clean decoupling)")
	assert_eq(WeatherFX.find_player(get_tree()), body, "find_player should use the O(1) Player group lookup")
	body.remove_from_group("Player")


func test_updraft_vfx_falls_back_to_camera_proximity_without_player() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(2.0, 1.0, 0.0)

	var fire = FIRE_TRAIL_SCENE.instantiate()
	root.add_child(fire)
	fire.global_position = Vector3.ZERO

	fire._process(0.05)
	var updraft_vfx: Node3D = fire.get_node("UpdraftVFX") as Node3D
	assert_true(updraft_vfx.visible, "Without a Player class in the tree, updraft VFX proximity should fall back to the camera")

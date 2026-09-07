extends GutTest

## Purpose: Integration test suite for interactive world mechanics (Choppable trees, Mineable ores, Water swimming, and Weather zones).

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const TREE_01_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")
const ORE_SMALL_SCENE: PackedScene = preload("res://scenes/ore_small.tscn")
const BURNABLE_GRASS_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/burnable_grass.tscn")
const WeatherFXScript: Script = preload("res://addons/weather_fx/scripts/weather_fx.gd")
const WeatherZoneScript: Script = preload("res://addons/weather_fx/scripts/weather_zone.gd")

var root: Node3D
var player: Player


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)

	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null
	player = null


func test_choppable_tree_logging_and_felling() -> void:
	var choppable: Choppable = TREE_01_SCENE.instantiate() as Choppable
	root.add_child(choppable)
	choppable.hits_to_finish = 3

	# Initial state
	assert_false(choppable.is_depleted, "Tree should start intact")
	assert_eq(choppable.hits_taken, 0)
	assert_eq(choppable.progress_bar.max_value, 3)
	assert_true(choppable.standing_node.visible, "Standing tree should be visible")
	assert_false(choppable.stump_node.visible, "Stump should be hidden")

	# First chop
	choppable.register_hit()
	assert_eq(choppable.hits_taken, 1)
	assert_eq(choppable.progress_bar.value, 1)
	assert_false(choppable.is_depleted)

	# Second chop
	choppable.register_hit()
	assert_eq(choppable.hits_taken, 2)
	assert_eq(choppable.progress_bar.value, 2)
	assert_false(choppable.is_depleted)

	# Third chop should fell the tree
	choppable.register_hit()
	assert_true(choppable.is_depleted, "Tree should be felled after 3 chops")
	assert_false(choppable.standing_node.visible, "Standing tree should be hidden after felling")
	assert_true(choppable.stump_node.visible, "Stump should be shown after felling")

	# Subsequent chops ignored
	choppable.register_hit()
	assert_eq(choppable.hits_taken, 3)


func test_mineable_ore_depletion() -> void:
	var mineable: Mineable = ORE_SMALL_SCENE.instantiate() as Mineable
	root.add_child(mineable)
	mineable.hits_to_finish = 2

	# Initial state
	assert_false(mineable.is_depleted, "Ore should start intact")
	assert_eq(mineable.hits_taken, 0)
	assert_eq(mineable.progress_bar.max_value, 2)
	assert_true(mineable.with_nodes.visible, "Unmined ore nodes should be visible")
	assert_false(mineable.without_nodes.visible, "Depleted ore base should be hidden")

	# First hit
	mineable.register_hit()
	assert_eq(mineable.hits_taken, 1)
	assert_eq(mineable.progress_bar.value, 1)
	assert_false(mineable.is_depleted)

	# Second hit depletes ore
	mineable.register_hit()
	assert_true(mineable.is_depleted, "Ore should be depleted after 2 hits")
	assert_false(mineable.with_nodes.visible, "Unmined ore nodes should be hidden")
	assert_true(mineable.without_nodes.visible, "Depleted ore base should be shown")

	# Subsequent hits ignored
	mineable.register_hit()
	assert_eq(mineable.hits_taken, 2)


func test_player_water_area_swimming_transition() -> void:
	var water_area := Area3D.new()
	root.add_child(water_area)

	assert_null(player.current_water_area)
	assert_false(player.is_swimming)

	# Player enters water area
	player.enter_water(water_area)
	assert_eq(player.current_water_area, water_area, "Current water area should be set on entry")
	assert_true(player.is_swimming, "Player should enter swimming state")
	assert_eq(player.current_state, NodeStateMachine.States.SWIMMING)

	# Player exits water area
	player.exit_water(water_area)
	assert_null(player.current_water_area, "Current water area should be cleared on exit")
	assert_false(player.is_swimming, "Player should exit swimming state")


func test_weather_zone_biome_trigger() -> void:
	var wfx = Node3D.new()
	wfx.set_script(WeatherFXScript)
	wfx.name = "WeatherFX"
	wfx.current_biome = ClimateData.BiomeZone.TEMPERATE_PLAINS
	root.add_child(wfx)

	var zone = Area3D.new()
	zone.set_script(WeatherZoneScript)
	zone.biome = ClimateData.BiomeZone.DESERT_DUNES
	zone.set("_weather_fx", wfx)
	root.add_child(zone)

	assert_eq(wfx.current_biome, ClimateData.BiomeZone.TEMPERATE_PLAINS)

	# Trigger body entered with player
	zone._on_body_entered(player)
	assert_eq(wfx.current_biome, ClimateData.BiomeZone.DESERT_DUNES, "WeatherZone should switch WeatherFX biome to Desert Dunes on player entry")


func test_burnable_grass_ignition_and_thermal_updraft() -> void:
	player.enable_stamina = true

	var grass_patch = BURNABLE_GRASS_SCENE.instantiate()
	root.add_child(grass_patch)
	grass_patch.global_position = Vector3(0, 0, 0)

	# Initial state: unignited
	assert_false(grass_patch.is_burning, "Grass should start unignited")
	var updraft_area = grass_patch.find_child("ThermalUpdraftArea", true, false) as Area3D
	assert_not_null(updraft_area, "Updraft Area3D should exist")
	assert_false(updraft_area.monitoring, "Updraft area should be inactive before ignition")

	# Ignite grass
	grass_patch.ignite()
	await wait_process_frames(1) # Area3D monitoring toggles are deferred
	assert_true(grass_patch.is_burning, "Grass should be burning after ignite()")
	assert_true(updraft_area.monitoring, "Updraft area should be active while burning")

	# Position player in paragliding state above burning grass
	player.global_position = Vector3(0, 5.0, 0)
	player.current_state = NodeStateMachine.States.PARAGLIDING
	player.is_paragliding = true
	if player.stamina:
		player.stamina.stamina = 50.0

	var paragliding_node: Paragliding = player.get_node("NodeStateMachine/Paragliding") as Paragliding
	assert_not_null(paragliding_node)

	# Verify paraglider detects thermal updraft
	assert_true(player.is_in_updraft(), "Paraglider should detect thermal updraft above burning grass")

	# Process frame and verify lift
	paragliding_node._physics_process(0.1)
	assert_gt(player.velocity.y, 0.0, "Thermal updraft should boost player upward")
	if player.stamina:
		assert_gte(player.stamina.value, 50.0, "Thermal updraft should replenish stamina")

	# Extinguish fire
	grass_patch.extinguish()
	await wait_process_frames(1) # Area3D monitoring toggles are deferred
	assert_false(grass_patch.is_burning, "Grass should stop burning after extinguish()")
	assert_false(updraft_area.monitoring, "Updraft area should deactivate after extinguish")


func test_fire_spread_to_neighboring_grass() -> void:
	var grass_1 = BURNABLE_GRASS_SCENE.instantiate()
	grass_1.add_to_group("BurnableGrass")
	root.add_child(grass_1)
	grass_1.global_position = Vector3(0, 0, 0)

	var grass_2 = BURNABLE_GRASS_SCENE.instantiate()
	grass_2.add_to_group("BurnableGrass")
	root.add_child(grass_2)
	grass_2.global_position = Vector3(2.5, 0, 0)

	assert_false(grass_1.is_burning)
	assert_false(grass_2.is_burning)

	grass_1.ignite()
	grass_1.spread_to_neighbors()

	assert_true(grass_1.is_burning)
	assert_true(grass_2.is_burning, "Neighboring grass within spread radius should catch fire")

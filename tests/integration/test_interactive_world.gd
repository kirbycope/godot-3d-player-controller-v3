extends GutTest

## Purpose: Integration test suite for interactive world mechanics (Choppable trees, Mineable ores, Water swimming, and Weather zones).

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const TREE_01_SCENE: PackedScene = preload("res://scenes/tree_01.tscn")
const ORE_SMALL_SCENE: PackedScene = preload("res://scenes/ore_small.tscn")

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
	choppable.chops_to_fell = 3

	# Initial state
	assert_false(choppable.is_felled, "Tree should start intact")
	assert_eq(choppable.chops_taken, 0)
	assert_eq(choppable.progress_bar.max_value, 3)
	assert_true(choppable.standing_node.visible, "Standing tree should be visible")
	assert_false(choppable.stump_node.visible, "Stump should be hidden")

	# First chop
	choppable.register_chop()
	assert_eq(choppable.chops_taken, 1)
	assert_eq(choppable.progress_bar.value, 1)
	assert_false(choppable.is_felled)

	# Second chop
	choppable.register_chop()
	assert_eq(choppable.chops_taken, 2)
	assert_eq(choppable.progress_bar.value, 2)
	assert_false(choppable.is_felled)

	# Third chop should fell the tree
	choppable.register_chop()
	assert_true(choppable.is_felled, "Tree should be felled after 3 chops")
	assert_false(choppable.standing_node.visible, "Standing tree should be hidden after felling")
	assert_true(choppable.stump_node.visible, "Stump should be shown after felling")

	# Subsequent chops ignored
	choppable.register_chop()
	assert_eq(choppable.chops_taken, 3)


func test_mineable_ore_depletion() -> void:
	var mineable: Mineable = ORE_SMALL_SCENE.instantiate() as Mineable
	root.add_child(mineable)
	mineable.hits_to_mine = 2

	# Initial state
	assert_false(mineable.is_mined, "Ore should start intact")
	assert_eq(mineable.hits_taken, 0)
	assert_eq(mineable.progress_bar.max_value, 2)
	assert_true(mineable.with_nodes.visible, "Unmined ore nodes should be visible")
	assert_false(mineable.without_nodes.visible, "Depleted ore base should be hidden")

	# First hit
	mineable.register_hit()
	assert_eq(mineable.hits_taken, 1)
	assert_eq(mineable.progress_bar.value, 1)
	assert_false(mineable.is_mined)

	# Second hit depletes ore
	mineable.register_hit()
	assert_true(mineable.is_mined, "Ore should be depleted after 2 hits")
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
	var wfx := WeatherFX.new()
	wfx.name = "WeatherFX"
	wfx.current_biome = ClimateData.BiomeZone.TEMPERATE_PLAINS
	root.add_child(wfx)

	var zone := WeatherZone.new()
	zone.biome = ClimateData.BiomeZone.DESERT_DUNES
	zone.set("_weather_fx", wfx)
	root.add_child(zone)

	assert_eq(wfx.current_biome, ClimateData.BiomeZone.TEMPERATE_PLAINS)

	# Trigger body entered with player
	zone._on_body_entered(player)
	assert_eq(wfx.current_biome, ClimateData.BiomeZone.DESERT_DUNES, "WeatherZone should switch WeatherFX biome to Desert Dunes on player entry")

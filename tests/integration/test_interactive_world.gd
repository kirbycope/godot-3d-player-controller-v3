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


## A tool in [member player]'s hand that can log, or mine.
func _tool(logs: bool) -> Equipment:
	var tool: Equipment = autofree(Equipment.new())
	tool.can_log = logs
	tool.can_mine = not logs
	tool.player = player
	return tool


func test_choppable_tree_logging_and_felling() -> void:
	var choppable: Choppable = TREE_01_SCENE.instantiate() as Choppable
	root.add_child(choppable)
	var axe: Equipment = _tool(true)
	await wait_physics_frames(1)

	# Initial state
	assert_true(choppable is Gatherable, "The tree is the player controller's Gatherable")
	assert_false(choppable.is_spent, "Tree should start intact")
	assert_eq(choppable.hits, 0)
	assert_eq(choppable.progress_bar.max_value, 1.0, "The bar reads the fraction Gatherable.struck reports")
	assert_true(choppable.standing_node.visible, "Standing tree should be visible")
	assert_false(choppable.stump_node.visible, "Stump should be hidden")

	# First chop
	choppable.register_weapon_hit(axe)
	assert_eq(choppable.hits, 1)
	assert_almost_eq(choppable.progress_bar.value, 1.0 / 3.0, 0.001)
	assert_false(choppable.is_spent)

	# Second chop
	choppable.register_weapon_hit(axe)
	assert_eq(choppable.hits, 2)
	assert_almost_eq(choppable.progress_bar.value, 2.0 / 3.0, 0.001)
	assert_false(choppable.is_spent)

	# Third chop should fell the tree
	choppable.register_weapon_hit(axe)
	assert_true(choppable.is_spent, "Tree should be felled after 3 chops")
	assert_true(choppable.visible, "The felled tree stays in sight as its stump")
	assert_false(choppable.standing_node.visible, "Standing tree should be hidden after felling")
	assert_true(choppable.stump_node.visible, "Stump should be shown after felling")
	assert_true(choppable.log_body.visible, "and the log lies beside it")
	assert_eq(player.inventory.count_of(choppable.item), 1, "The felling chop puts the log in the striker's bag")
	await wait_physics_frames(1)
	for shape: CollisionShape3D in choppable.log_body.find_children("*", "CollisionShape3D", false, false):
		assert_false(shape.disabled, "The fallen log collides")
	assert_true((choppable.get_node("CollisionShape3D") as CollisionShape3D).disabled, "The trunk's shape went with the tree")
	var stump_shapes: Array[Node] = choppable.stump_node.find_children("*", "CollisionShape3D", true, false)
	assert_gt(stump_shapes.size(), 0)
	for shape: Node in stump_shapes:
		assert_false((shape as CollisionShape3D).disabled, "The stump stays solid")

	# Subsequent chops ignored
	choppable.register_weapon_hit(axe)
	assert_eq(player.inventory.count_of(choppable.item), 1)


func test_mineable_ore_depletion() -> void:
	var mineable: Mineable = ORE_SMALL_SCENE.instantiate() as Mineable
	root.add_child(mineable)
	var pickaxe: Equipment = _tool(false)
	await wait_physics_frames(1)

	# Initial state
	assert_false(mineable.is_spent, "Ore should start intact")
	assert_eq(mineable.hits, 0)
	assert_eq(mineable.progress_bar.max_value, 1.0)
	assert_true(mineable.with_nodes.visible, "Unmined ore nodes should be visible")
	assert_false(mineable.without_nodes.visible, "Depleted ore base should be hidden")

	# An axe does not mine
	mineable.register_weapon_hit(_tool(true))
	assert_eq(mineable.hits, 0, "The wrong tool does nothing")

	# First hit
	mineable.register_weapon_hit(pickaxe)
	assert_eq(mineable.hits, 1)
	assert_almost_eq(mineable.progress_bar.value, 0.5, 0.001)
	assert_false(mineable.is_spent)

	# Second hit depletes ore
	mineable.register_weapon_hit(pickaxe)
	assert_true(mineable.is_spent, "Ore should be depleted after 2 hits")
	assert_true(mineable.visible, "The bare rock stays in sight")
	assert_false(mineable.with_nodes.visible, "Unmined ore nodes should be hidden")
	assert_true(mineable.without_nodes.visible, "Depleted ore base should be shown")
	assert_eq(player.inventory.count_of(mineable.item), 1, "The ore is in the striker's bag")
	await wait_physics_frames(1)
	assert_false((mineable.get_node("CollisionShape3D") as CollisionShape3D).disabled, "and the bare rock is still solid")

	# Subsequent hits ignored
	mineable.register_weapon_hit(pickaxe)
	assert_eq(player.inventory.count_of(mineable.item), 1)


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

	# is_in_updraft asks the Area3D what it overlaps, and the physics server builds that list on the step
	# after the body moves, so a teleported player is in no overlap list until one has run
	await wait_physics_frames(2)

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

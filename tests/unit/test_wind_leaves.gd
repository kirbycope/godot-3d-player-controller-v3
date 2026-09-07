extends GutTest

const WIND_VFX_SCENE = preload("res://addons/weather_fx/scenes/wind_vfx.tscn")


func test_biome_has_trees_classification() -> void:
	# Forested / Plains biomes should have trees
	assert_true(ClimateData.biome_has_trees(ClimateData.BiomeZone.TEMPERATE_PLAINS), "Temperate plains should have trees")
	assert_true(ClimateData.biome_has_trees(ClimateData.BiomeZone.AUTUMN_HIGHLANDS), "Autumn highlands should have trees")
	assert_true(ClimateData.biome_has_trees(ClimateData.BiomeZone.ANCIENT_FOREST), "Ancient forest should have trees")
	assert_true(ClimateData.biome_has_trees(ClimateData.BiomeZone.SHADOW_WOODS), "Shadow woods should have trees")

	# Barren / Extreme biomes should NOT have trees
	assert_false(ClimateData.biome_has_trees(ClimateData.BiomeZone.DESERT_DUNES), "Desert dunes should not have trees")
	assert_false(ClimateData.biome_has_trees(ClimateData.BiomeZone.ARCTIC_TUNDRA), "Arctic tundra should not have trees")
	assert_false(ClimateData.biome_has_trees(ClimateData.BiomeZone.ALPINE_PEAKS), "Alpine peaks should not have trees")
	assert_false(ClimateData.biome_has_trees(ClimateData.BiomeZone.VOLCANIC_CRATER), "Volcanic crater should not have trees")
	assert_false(ClimateData.biome_has_trees(ClimateData.BiomeZone.DEEP_DESERT), "Deep desert should not have trees")


func test_wind_vfx_leaf_suppression_without_trees() -> void:
	var wind_vfx: WindVFX = WIND_VFX_SCENE.instantiate() as WindVFX
	add_child_autofree(wind_vfx)

	wind_vfx.enabled = true
	wind_vfx.require_nearby_trees = true

	# Without trees present in scene
	wind_vfx._trees_nearby_cached = false
	assert_false(wind_vfx._can_spawn_leaves(), "Wind leaves should be suppressed when no trees are nearby")

	# Spawn a tree nearby
	var tree_node = Node3D.new()
	tree_node.name = "Tree_01"
	tree_node.add_to_group("Tree")
	add_child_autofree(tree_node)
	tree_node.global_position = wind_vfx.global_position + Vector3(5, 0, 5)

	wind_vfx._trees_nearby_cached = wind_vfx._check_nearby_trees()
	assert_true(wind_vfx._can_spawn_leaves(), "Wind leaves should be allowed when trees are nearby in temperate biome")


func test_biome_foliage_and_grass_tint_definitions() -> void:
	# Autumn Highlands should have distinctive orange/amber foliage tint
	var autumn_foliage = ClimateData.get_biome_foliage_tint(ClimateData.BiomeZone.AUTUMN_HIGHLANDS)
	assert_gt(autumn_foliage.r, autumn_foliage.g, "Autumn foliage should be predominantly red/orange")

	# Tropical Rainforest should have lush green foliage tint
	var jungle_foliage = ClimateData.get_biome_foliage_tint(ClimateData.BiomeZone.TROPICAL_RAINFOREST)
	assert_gt(jungle_foliage.g, jungle_foliage.r, "Jungle foliage should be predominantly vibrant green")

	# Desert Dunes should have warm golden/straw tint
	var desert_grass = ClimateData.get_biome_grass_tint(ClimateData.BiomeZone.DESERT_DUNES)
	assert_gt(desert_grass.r, 0.7, "Desert grass should have high red/yellow component")

	# Arctic Tundra should have cold cyan/desaturated tint
	var tundra_foliage = ClimateData.get_biome_foliage_tint(ClimateData.BiomeZone.ARCTIC_TUNDRA)
	assert_gt(tundra_foliage.b, 0.5, "Tundra foliage should have cool blue/cyan component")


const WeatherFXScript: Script = preload("res://addons/weather_fx/scripts/weather_fx.gd")


func test_weather_fx_biome_tint_interpolation() -> void:
	var wfx = Node3D.new()
	wfx.set_script(WeatherFXScript)
	add_child_autofree(wfx)
	wfx.enable_biome_tinting = true
	wfx.current_biome = ClimateData.BiomeZone.AUTUMN_HIGHLANDS

	# Initial tint starts at white and blends toward Autumn orange
	wfx.current_foliage_tint = Color.WHITE
	wfx._update_biome_tinting(0.5)

	assert_ne(wfx.current_foliage_tint, Color.WHITE, "Foliage tint should interpolate away from white toward autumn color")
	assert_gt(wfx.current_foliage_tint.r, wfx.current_foliage_tint.b, "Interpolated tint should lean warm/red")

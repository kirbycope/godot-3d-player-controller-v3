extends GutTest

## Purpose: Integration test suite for BotW/TotK gold-standard wind-driven wildfire physics,
## shader combustion progress, rain dousing, and GrassField thermal updraft generation.

const BurnableGrassScript: Script = preload("res://addons/weather_fx/scripts/burnable_grass.gd")
const GrassFieldScript: Script = preload("res://addons/weather_fx/scripts/grass_field.gd")
const WeatherFXScript: Script = preload("res://addons/weather_fx/scripts/weather_fx.gd")

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	WeatherFX.active_wind_strength = 0.0
	WeatherFX.active_wind_direction = Vector3(1.0, 0.0, 0.0)
	WeatherFX.active_precipitation_strength = 0.0


func after_each() -> void:
	if is_instance_valid(root):
		root.free()
		root = null
	WeatherFX.active_wind_strength = 0.0
	WeatherFX.active_precipitation_strength = 0.0


func test_wind_driven_directional_fire_spread() -> void:
	# Configure strong Eastward wind (+X)
	WeatherFX.active_wind_direction = Vector3(1.0, 0.0, 0.0)
	WeatherFX.active_wind_strength = 6.0

	# Source burning grass at origin
	var source_grass = BurnableGrassScript.new()
	source_grass.add_to_group("BurnableGrass")
	root.add_child(source_grass)
	source_grass.global_position = Vector3(0, 0, 0)
	source_grass._setup_components()

	# Downwind grass (+X) at 6.0m (beyond base 4.5m radius, but within wind-boosted radius ~8.5m)
	var downwind_grass = BurnableGrassScript.new()
	downwind_grass.add_to_group("BurnableGrass")
	root.add_child(downwind_grass)
	downwind_grass.global_position = Vector3(6.0, 0, 0)
	downwind_grass._setup_components()

	# Upwind grass (-X) at 4.0m (within base 4.5m radius, but suppressed by upwind penalty)
	var upwind_grass = BurnableGrassScript.new()
	upwind_grass.add_to_group("BurnableGrass")
	root.add_child(upwind_grass)
	upwind_grass.global_position = Vector3(-4.0, 0, 0)
	upwind_grass._setup_components()

	assert_false(source_grass.is_burning)
	assert_false(downwind_grass.is_burning)
	assert_false(upwind_grass.is_burning)

	# Ignite source and trigger spread
	source_grass.ignite()
	source_grass.spread_to_neighbors()

	assert_true(source_grass.is_burning)
	assert_true(downwind_grass.is_burning, "Downwind grass should ignite due to wind propagation boost")
	assert_false(upwind_grass.is_burning, "Upwind grass should NOT ignite due to opposing wind penalty")


func test_shader_burn_progress_and_charring() -> void:
	var grass = BurnableGrassScript.new()
	root.add_child(grass)
	grass.burn_duration = 10.0
	grass._setup_components()

	assert_eq(grass.current_burn_progress, 0.0)

	grass.ignite()
	assert_true(grass.is_burning)

	# Process 5 seconds (50% burn)
	grass._process(5.0)
	assert_almost_eq(grass.current_burn_progress, 0.5, 0.05, "Burn progress should reach ~0.5 midway")

	var mesh_node: MeshInstance3D = grass.find_child("GrassMesh", true, false) as MeshInstance3D
	assert_not_null(mesh_node)
	assert_not_null(mesh_node.material_override, "Grass mesh should have material_override assigned")

	if mesh_node.material_override is ShaderMaterial:
		var smat: ShaderMaterial = mesh_node.material_override as ShaderMaterial
		var param_val = smat.get_shader_parameter("burn_progress")
		assert_almost_eq(float(param_val), 0.5, 0.05, "Shader burn_progress should mirror script progress")

	# Process remaining duration to burnout
	grass._process(6.0)
	assert_false(grass.is_burning)
	assert_true(grass.is_charred, "Grass should be charred after burnout")
	assert_eq(grass.current_burn_progress, 1.0, "Burn progress should reach 1.0 on burnout")


func test_rain_douses_burning_grass() -> void:
	var grass = BurnableGrassScript.new()
	root.add_child(grass)
	grass._setup_components()

	grass.ignite()
	assert_true(grass.is_burning)

	# Simulate heavy rain
	WeatherFX.active_precipitation_strength = 0.8
	grass._process(0.1)

	assert_false(grass.is_burning, "Rain should automatically extinguish burning grass")


func test_grass_field_wildfire_wind_advance() -> void:
	WeatherFX.active_wind_direction = Vector3(1.0, 0.0, 0.0)
	WeatherFX.active_wind_strength = 5.0

	var field = GrassFieldScript.new()
	field.field_size = Vector2(40.0, 40.0)
	field.instance_count = 50
	root.add_child(field)
	field.regenerate()

	# Ignite wildfire at center
	field.ignite_at(Vector3(0, 0, 0), 3.0, 10.0)
	assert_eq(field._active_fires.size(), 1)

	var fire = field._active_fires[0]
	assert_not_null(fire.updraft_area)
	assert_true(fire.updraft_area.is_in_group("Updraft"))
	assert_true(fire.updraft_area.is_in_group("Thermal"))

	# Rain extinguishes field wildfire
	WeatherFX.active_precipitation_strength = 0.7
	field._process(0.1)
	assert_eq(field._active_fires.size(), 0, "Rain should douse all active field fires")

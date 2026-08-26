extends GutTest

## Tests for GrassField, Grass Wind Shader, and Foliage Sway Shader integration.

const GrassFieldScript = preload("res://addons/weather_fx/scripts/grass_field.gd")

func test_grass_field_instantiation() -> void:
	var grass_field = GrassFieldScript.new()
	grass_field.instance_count = 100
	grass_field.field_size = Vector2(20.0, 20.0)
	add_child_autofree(grass_field)
	
	assert_not_null(grass_field.multimesh, "GrassField should generate a MultiMesh")
	assert_eq(grass_field.multimesh.instance_count, 100, "Instance count should match")
	assert_not_null(grass_field.multimesh.mesh, "MultiMesh should have a mesh assigned")


func test_grass_mesh_generation() -> void:
	var mesh = GrassFieldScript.create_stylized_grass_mesh(0.8, 1.0)
	assert_not_null(mesh, "Grass mesh should be created")
	assert_gt(mesh.get_surface_count(), 0, "Mesh should contain at least 1 surface")
	var arrays = mesh.surface_get_arrays(0)
	assert_not_null(arrays[Mesh.ARRAY_VERTEX], "Mesh should contain vertices")
	assert_not_null(arrays[Mesh.ARRAY_TEX_UV], "Mesh should contain UV coordinates")
	assert_not_null(arrays[Mesh.ARRAY_NORMAL], "Mesh should contain normals")


func test_grass_field_resizing() -> void:
	var grass_field = GrassFieldScript.new()
	add_child_autofree(grass_field)
	
	grass_field.instance_count = 250
	assert_eq(grass_field.multimesh.instance_count, 250, "Instance count should update on property change")
	
	grass_field.instance_count = 0
	assert_eq(grass_field.multimesh.instance_count, 0, "Setting count to 0 should clear multimesh instances")


func test_grass_wind_shader_loaded() -> void:
	var shader: Shader = load("res://materials/grass_wind.gdshader")
	assert_not_null(shader, "grass_wind.gdshader should exist and load without errors")
	
	var mat: ShaderMaterial = load("res://materials/grass_material.tres")
	assert_not_null(mat, "grass_material.tres should exist")
	assert_eq(mat.shader, shader, "grass_material.tres should use grass_wind.gdshader")


func test_foliage_wind_shader_loaded() -> void:
	var shader: Shader = load("res://materials/foliage_wind.gdshader")
	assert_not_null(shader, "foliage_wind.gdshader should exist and load without errors")
	
	var mat: ShaderMaterial = load("res://materials/foliage_material.tres")
	assert_not_null(mat, "foliage_material.tres should exist")
	assert_eq(mat.shader, shader, "foliage_material.tres should use foliage_wind.gdshader")


func test_weather_fx_demo_scene_has_grass() -> void:
	var scene_res: PackedScene = load("res://addons/weather_fx/scenes/demo/demo.tscn")
	assert_not_null(scene_res, "demo.tscn should load")
	var demo_node = scene_res.instantiate()
	assert_not_null(demo_node, "demo.tscn should instantiate")
	add_child_autofree(demo_node)
	
	var grass = demo_node.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(grass.size(), 0, "WeatherFX demo scene should contain MultiMeshInstance3D grass")


func test_addon_grass_field_is_self_contained() -> void:
	var addon_scene: PackedScene = load("res://addons/weather_fx/scenes/grass_field.tscn")
	assert_not_null(addon_scene, "addons/weather_fx/scenes/grass_field.tscn should load")
	var gf = addon_scene.instantiate()
	assert_not_null(gf, "addon grass field should instantiate")
	add_child_autofree(gf)
	assert_not_null(gf.multimesh, "addon grass field should have multimesh")



func test_world_scene_has_grass_fields() -> void:
	var scene_res: PackedScene = load("res://scenes/world.tscn")
	assert_not_null(scene_res, "world.tscn should load")
	var world_node = scene_res.instantiate()
	assert_not_null(world_node, "world.tscn should instantiate")
	add_child_autofree(world_node)
	
	var grass = world_node.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(grass.size(), 0, "World demo scene should contain MultiMeshInstance3D grass")

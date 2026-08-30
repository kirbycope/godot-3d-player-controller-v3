extends GutTest

const PARAGLIDER_SCENE = preload("res://scenes/paraglider.tscn")


func test_paraglider_mesh_surface_materials() -> void:
	var paraglider: Node3D = PARAGLIDER_SCENE.instantiate() as Node3D
	add_child_autofree(paraglider)

	var mesh_instance: MeshInstance3D = paraglider.get_node_or_null("Paraglider2/Paraglider") as MeshInstance3D
	assert_not_null(mesh_instance, "Paraglider mesh instance should exist under Paraglider2/Paraglider")

	var mat_surface_0: Material = mesh_instance.get_surface_override_material(0)
	var mat_surface_1: Material = mesh_instance.get_surface_override_material(1)

	assert_not_null(mat_surface_0, "Surface 0 should have a material override for cloth ruffling")
	assert_not_null(mat_surface_1, "Surface 1 should have a material override for cloth ruffling")

	assert_true(mat_surface_0 is ShaderMaterial, "Surface 0 override should be a ShaderMaterial")
	assert_true(mat_surface_1 is ShaderMaterial, "Surface 1 override should be a ShaderMaterial")

	var shader_mat_0: ShaderMaterial = mat_surface_0 as ShaderMaterial
	var shader_mat_1: ShaderMaterial = mat_surface_1 as ShaderMaterial

	assert_not_null(shader_mat_0.shader, "Surface 0 shader should not be null")
	assert_not_null(shader_mat_1.shader, "Surface 1 shader should not be null")


func test_paraglider_wind_vfx_nodes() -> void:
	var paraglider: Node3D = PARAGLIDER_SCENE.instantiate() as Node3D
	add_child_autofree(paraglider)

	var airflow_streaks: GPUParticles3D = paraglider.get_node_or_null("AirflowStreaks") as GPUParticles3D
	var opening_wind_burst: GPUParticles3D = paraglider.get_node_or_null("OpeningWindBurst") as GPUParticles3D

	assert_not_null(airflow_streaks, "Paraglider should have AirflowStreaks GPUParticles3D node")
	assert_not_null(opening_wind_burst, "Paraglider should have OpeningWindBurst GPUParticles3D node")

	assert_false(airflow_streaks.emitting, "AirflowStreaks should start inactive")
	assert_false(opening_wind_burst.emitting, "OpeningWindBurst should start inactive")
	assert_true(opening_wind_burst.one_shot, "OpeningWindBurst should be configured as one_shot")

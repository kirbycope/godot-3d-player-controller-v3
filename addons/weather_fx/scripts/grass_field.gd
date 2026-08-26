@tool
class_name GrassField
extends MultiMeshInstance3D

## High-performance, wind-reactive grass field populated using MultiMesh.
## Instances sway dynamically in response to WeatherFX global shader uniforms.

@export var instance_count: int = 1000:
	set(val):
		instance_count = max(0, val)
		if is_inside_tree():
			regenerate()

@export var field_size: Vector2 = Vector2(30.0, 30.0):
	set(val):
		field_size = val
		if is_inside_tree():
			regenerate()

@export var min_scale: float = 0.18:
	set(val):
		min_scale = maxf(0.01, val)
		if is_inside_tree():
			regenerate()

@export var max_scale: float = 0.28:
	set(val):
		max_scale = maxf(min_scale, val)
		if is_inside_tree():
			regenerate()

@export var seed_value: int = 12345:
	set(val):
		seed_value = val
		if is_inside_tree():
			regenerate()

@export_group("Tuft Geometry")
@export_range(1, 16) var blades_per_tuft: int = 6:
	set(val):
		blades_per_tuft = clampi(val, 1, 16)
		if is_inside_tree():
			regenerate()

@export_range(2, 6) var blade_segments: int = 4:
	set(val):
		blade_segments = clampi(val, 2, 6)
		if is_inside_tree():
			regenerate()

@export_range(0.01, 0.5, 0.005) var tuft_radius: float = 0.035:
	set(val):
		tuft_radius = maxf(0.005, val)
		if is_inside_tree():
			regenerate()

@export_range(0.05, 3.0, 0.05) var blade_height: float = 0.28:
	set(val):
		blade_height = maxf(0.05, val)
		if is_inside_tree():
			regenerate()

@export_range(0.05, 3.0, 0.05) var blade_width: float = 0.15:
	set(val):
		blade_width = maxf(0.05, val)
		if is_inside_tree():
			regenerate()

const DEFAULT_QUATERNIUS_MESH: Mesh = preload("res://assets/quaternius/nature/Grass_Common_Short_mesh.tres")

@export var custom_mesh: Mesh = null:
	set(val):
		custom_mesh = val
		if is_inside_tree():
			regenerate()

@export_group("Rendering")
@export var cast_grass_shadows: bool = false:
	set(val):
		cast_grass_shadows = val
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_grass_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

@export var custom_grass_material: ShaderMaterial:
	set(val):
		custom_grass_material = val
		if custom_grass_material:
			material_override = custom_grass_material


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_grass_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if multimesh == null or multimesh.instance_count == 0:
		regenerate()


## Generates dense 3D cross-quads for stylized grass blade sampling.
static func create_stylized_grass_mesh(
	height: float = 0.28,
	width: float = 0.15,
	_blades_count: int = 6,
	_segments_per_blade: int = 4,
	_tuft_rad: float = 0.035,
	_curve_strength: float = 0.08
) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w = width * 0.5
	var n = Vector3(0.0, 1.0, 0.0)
	
	# Generate 3 intersecting vertical quads (at 0, 60, and 120 degrees) for volumetric 3D tufts
	for q in range(3):
		var angle = float(q) * (PI / 3.0)
		var dir = Vector3(cos(angle), 0.0, sin(angle))
		
		var v0 = -dir * half_w
		var v1 = dir * half_w
		var v2 = -dir * half_w + Vector3(0.0, height, 0.0)
		var v3 = dir * half_w + Vector3(0.0, height, 0.0)
		
		# Triangle 1
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(v0)
		
		st.set_normal(n)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(v1)
		
		st.set_normal(n)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(v3)
		
		# Triangle 2
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(v0)
		
		st.set_normal(n)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(v3)
		
		st.set_normal(n)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(v2)
	
	return st.commit()




## Rebuilds the MultiMesh instances within field boundaries.
func regenerate() -> void:
	if instance_count <= 0:
		if multimesh:
			multimesh.instance_count = 0
		return
	
	var mesh_to_use: Mesh = custom_mesh
	if mesh_to_use == null:
		mesh_to_use = DEFAULT_QUATERNIUS_MESH
	if mesh_to_use == null:
		mesh_to_use = create_stylized_grass_mesh(
			blade_height,
			blade_width
		)

		
	var mat: Material = custom_grass_material
	if mat == null:
		mat = load("res://addons/weather_fx/materials/grass_material.tres")
	if mat:
		material_override = mat
		if mesh_to_use and mesh_to_use.get_surface_count() > 0:
			mesh_to_use.surface_set_material(0, mat)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_to_use
	mm.instance_count = instance_count
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	var half_x = field_size.x * 0.5
	var half_z = field_size.y * 0.5
	
	for i in range(instance_count):
		var pos_x = rng.randf_range(-half_x, half_x)
		var pos_z = rng.randf_range(-half_z, half_z)
		var rot_y = rng.randf_range(0.0, TAU)
		var scl = rng.randf_range(min_scale, max_scale)
		
		var t = Transform3D()
		t = t.rotated(Vector3.UP, rot_y)
		t = t.scaled(Vector3(scl, scl, scl))
		t.origin = Vector3(pos_x, 0.0, pos_z)
		
		mm.set_instance_transform(i, t)
		
	multimesh = mm

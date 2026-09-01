# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name GrassField
extends MultiMeshInstance3D

## High-performance, wind-reactive grass field populated using MultiMesh.
## Instances sway dynamically in response to WeatherFX global shader uniforms.

enum GrassMeshType {
	COMMON_SHORT,
	COMMON_TALL,
	WISPY_SHORT,
	WISPY_TALL,
	CUSTOM
}

const QUATERNIUS_MESH_PATHS = {
	GrassMeshType.COMMON_SHORT: "res://addons/weather_fx/resources/mesh_grass_common_short.tres",
	GrassMeshType.COMMON_TALL: "res://addons/weather_fx/resources/mesh_grass_common_tall.tres",
	GrassMeshType.WISPY_SHORT: "res://addons/weather_fx/resources/mesh_grass_wispy_short.tres",
	GrassMeshType.WISPY_TALL: "res://addons/weather_fx/resources/mesh_grass_wispy_tall.tres",
}

@export var mesh_type: GrassMeshType = GrassMeshType.COMMON_SHORT:
	set(val):
		mesh_type = val
		if is_inside_tree():
			regenerate()

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

@export var min_scale: float = 0.7:
	set(val):
		min_scale = maxf(0.1, val)
		if is_inside_tree():
			regenerate()

@export var max_scale: float = 1.3:
	set(val):
		max_scale = maxf(min_scale, val)
		if is_inside_tree():
			regenerate()

@export var seed_value: int = 12345:
	set(val):
		seed_value = val
		if is_inside_tree():
			regenerate()

@export var custom_mesh: Mesh = null:
	set(val):
		custom_mesh = val
		if is_inside_tree():
			regenerate()

@export_group("Exclusion Zones")
## Primary circular clearing radius where no grass will spawn (e.g. campfire).
@export_range(0.0, 50.0, 0.1) var exclusion_radius: float = 0.0:
	set(val):
		exclusion_radius = maxf(0.0, val)
		if is_inside_tree():
			regenerate()

## 2D center position (X, Z) in local space of primary exclusion circle.
@export var exclusion_center: Vector2 = Vector2.ZERO:
	set(val):
		exclusion_center = val
		if is_inside_tree():
			regenerate()

## Additional circular exclusion zones formatted as Vector3(center_x, center_z, radius) for ponds, paths, etc.
@export var additional_exclusion_zones: Array = []:
	set(val):
		additional_exclusion_zones = val
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

@export_group("Wildfire Physics")
@export var enable_wildfire: bool = true ## Enables wind-reactive grass fires and thermal updrafts across the field.
@export var fire_spread_speed: float = 1.5 ## Fire front creep speed in m/s, clamped to the BotW 1.2-1.8 band. Wind biases direction, not speed.
@export var max_active_fires: int = 6

## BotW decomp fire front creep speed band (m/s).
const CREEP_SPEED_MIN: float = 1.2
const CREEP_SPEED_MAX: float = 1.8

var _instance_origins: Array[Vector3] = []
var _active_fires: Array[Dictionary] = []


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		if multimesh == null or multimesh.instance_count == 0:
			regenerate()


func _ready() -> void:
	add_to_group("GrassField")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_grass_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if multimesh == null or multimesh.instance_count == 0:
		regenerate()


var _creeper_heads: Array[Dictionary] = []
var _trail_nodes: Array[Node3D] = []


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enable_wildfire:
		return

	var precip: float = WeatherFX.get_precipitation_strength()
	if precip > 0.4:
		extinguish_all_fires()
		return

	# Clean up freed/expired trail nodes
	var n_idx = _trail_nodes.size() - 1
	while n_idx >= 0:
		if not is_instance_valid(_trail_nodes[n_idx]):
			_trail_nodes.remove_at(n_idx)
		n_idx -= 1

	if _creeper_heads.is_empty():
		return

	var wind_dir: Vector3 = WeatherFX.get_wind_direction()
	var wind_strength: float = WeatherFX.get_wind_strength()
	var h_wind = Vector2(wind_dir.x, wind_dir.z)
	var has_wind = h_wind.length_squared() > 0.001
	if has_wind:
		h_wind = h_wind.normalized()

	var h_idx = _creeper_heads.size() - 1
	while h_idx >= 0:
		var head = _creeper_heads[h_idx]
		head.age += delta

		if head.age >= head.max_life or _trail_nodes.size() >= 48:
			_creeper_heads.remove_at(h_idx)
			h_idx -= 1
			continue

		# Update creeping direction with wind bias and organic meandering
		if has_wind:
			var target_heading = h_wind.rotated(head.angle_offset + sin(head.age * 3.5 + head.noise_seed) * 0.35)
			head.heading = head.heading.slerp(target_heading, delta * 3.0).normalized()
		else:
			head.heading = head.heading.rotated(sin(head.age * 2.0 + head.noise_seed) * delta * 0.8).normalized()

		# Advance creeper head
		var move_dist = head.speed * delta
		head.pos += head.heading * move_dist
		head.dist_since_drop += move_dist

		# Check field bounds
		var local_p = to_local(Vector3(head.pos.x, 0.0, head.pos.y))
		if abs(local_p.x) > field_size.x * 0.5 or abs(local_p.z) > field_size.y * 0.5:
			_creeper_heads.remove_at(h_idx)
			h_idx -= 1
			continue

		# Drop new connected FireTrailNode along the path (0.35m spacing for seamless overlap)
		if head.dist_since_drop >= 0.35:
			head.dist_since_drop = 0.0
			var world_p = Vector3(head.pos.x, 0.0, head.pos.y)
			_drop_trail_node(local_p, world_p)

			# Occasional lateral branch (trail split / combining)
			if head.branches_left > 0 and head.age > 0.8 and randf() < (delta * 1.2):
				head.branches_left -= 1
				_spawn_branch_head(head.pos, head.heading, -head.angle_offset)

		h_idx -= 1


func _drop_trail_node(local_pos: Vector3, world_pos: Vector3) -> Node3D:
	var node_scene = null
	if ResourceLoader.exists("res://addons/weather_fx/scenes/fire_trail_node.tscn"):
		node_scene = load("res://addons/weather_fx/scenes/fire_trail_node.tscn") as PackedScene
	elif ResourceLoader.exists("res://addons/weather_fx/scenes/wildfire_patch.tscn"):
		node_scene = load("res://addons/weather_fx/scenes/wildfire_patch.tscn") as PackedScene

	if node_scene:
		var node = node_scene.instantiate() as Node3D
		node.position = local_pos
		add_child(node)
		_trail_nodes.append(node)
		_consume_grass_in_radius(world_pos, 1.2)
		return node
	return null


func _spawn_branch_head(pos_2d: Vector2, parent_heading: Vector2, angle_offset: float) -> void:
	if _creeper_heads.size() >= 8:
		return
	var branch_head = {
		"pos": pos_2d,
		"heading": parent_heading.rotated(angle_offset).normalized(),
		"speed": clampf(fire_spread_speed * randf_range(0.75, 0.95), CREEP_SPEED_MIN, CREEP_SPEED_MAX),
		"age": 0.0,
		"max_life": randf_range(3.5, 5.5),
		"dist_since_drop": 0.0,
		"angle_offset": angle_offset,
		"noise_seed": randf() * 100.0,
		"branches_left": 0
	}
	_creeper_heads.append(branch_head)


## Ignites a trailing, spreading wildfire on this grass field that trails, grows, combines, and burns out.
func ignite_at(world_pos: Vector3, initial_radius: float = 2.0, duration: float = 6.0) -> bool:
	if not enable_wildfire:
		return false

	var local_p = to_local(world_pos)
	var half_x = field_size.x * 0.5 + 2.0
	var half_z = field_size.y * 0.5 + 2.0
	if abs(local_p.x) > half_x or abs(local_p.z) > half_z:
		return false

	# Initial ignition node
	var initial_node = _drop_trail_node(local_p, world_pos)

	# Spawn trailing creeper heads biased downwind
	var wind_dir: Vector3 = WeatherFX.get_wind_direction()
	var h_wind = Vector2(wind_dir.x, wind_dir.z)
	var has_wind = h_wind.length_squared() > 0.001
	if has_wind:
		h_wind = h_wind.normalized()
	else:
		h_wind = Vector2.RIGHT

	var pos_2d = Vector2(world_pos.x, world_pos.z)
	var angle_spreads = [-0.4, 0.0, 0.4] if has_wind else [0.0, 2.1, 4.2]

	for offset_angle in angle_spreads:
		var head_dir = h_wind.rotated(offset_angle).normalized()
		var head = {
			"pos": pos_2d + head_dir * 0.3,
			"heading": head_dir,
			"speed": clampf(fire_spread_speed * randf_range(0.9, 1.1), CREEP_SPEED_MIN, CREEP_SPEED_MAX),
			"age": 0.0,
			"max_life": duration,
			"dist_since_drop": 0.3,
			"angle_offset": offset_angle,
			"noise_seed": randf() * 100.0,
			"branches_left": 2
		}
		_creeper_heads.append(head)

	# Compatibility record for tests
	var fire_record = {
		"origin": world_pos,
		"current_pos": world_pos,
		"radius": initial_radius,
		"age": 0.0,
		"duration": duration,
		"patch_node": initial_node,
		"updraft_area": initial_node.get_node_or_null("ThermalUpdraftArea") if initial_node else null,
		"vfx_node": initial_node
	}
	_active_fires.append(fire_record)
	return true


func _consume_grass_in_radius(world_pos: Vector3, radius: float) -> void:
	if multimesh == null or _instance_origins.is_empty():
		return
	var local_center = to_local(world_pos)
	var count = multimesh.instance_count
	var r_sq = radius * radius
	for idx in range(count):
		if idx < _instance_origins.size():
			var p = _instance_origins[idx]
			var dx = p.x - local_center.x
			var dz = p.z - local_center.z
			if dx * dx + dz * dz <= r_sq:
				var t = multimesh.get_instance_transform(idx)
				t.basis = t.basis.scaled(Vector3(1.0, 0.25, 1.0))
				multimesh.set_instance_transform(idx, t)


## Extinguishes all active wildfire fronts on this field.
func extinguish_all_fires() -> void:
	_creeper_heads.clear()
	_active_fires.clear()
	for node in _trail_nodes:
		if is_instance_valid(node):
			if node.has_method("extinguish"):
				node.extinguish()
			else:
				node.queue_free()
	_trail_nodes.clear()


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		match what:
			NOTIFICATION_EDITOR_PRE_SAVE:
				multimesh = null
			NOTIFICATION_EDITOR_POST_SAVE:
				regenerate()


## Returns the active mesh based on mesh_type or custom_mesh.
func get_active_mesh() -> Mesh:
	if mesh_type == GrassMeshType.CUSTOM and custom_mesh:
		return custom_mesh
	if QUATERNIUS_MESH_PATHS.has(mesh_type):
		var res_path: String = QUATERNIUS_MESH_PATHS[mesh_type]
		var loaded_mesh = load(res_path) as Mesh
		if loaded_mesh:
			return loaded_mesh
	if custom_mesh:
		return custom_mesh
	return load("res://addons/weather_fx/resources/mesh_grass_common_short.tres") as Mesh


## Returns the cached 3D origin points of all grass instances.
func get_instance_origins() -> Array[Vector3]:
	return _instance_origins


## Checks whether a 2D local coordinate (px, pz) falls within any exclusion zone.
func is_point_excluded(px: float, pz: float) -> bool:
	if exclusion_radius > 0.0:
		if Vector2(px - exclusion_center.x, pz - exclusion_center.y).length() < exclusion_radius:
			return true
	for zone in additional_exclusion_zones:
		if zone is Vector3 and zone.z > 0.0:
			if Vector2(px - zone.x, pz - zone.y).length() < zone.z:
				return true
	return false


## Rebuilds the MultiMesh instances within field boundaries.
func regenerate() -> void:
	if instance_count <= 0:
		_instance_origins.clear()
		if multimesh:
			multimesh.instance_count = 0
		return
	
	var mesh_to_use: Mesh = get_active_mesh()
		
	var mat: Material = custom_grass_material
	if mat == null:
		mat = load("res://addons/weather_fx/resources/grass_material.tres")
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
	var max_r = maxf(half_x, half_z)
	var has_exclusions = exclusion_radius > 0.0 or not additional_exclusion_zones.is_empty()
	
	_instance_origins.clear()
	_instance_origins.resize(instance_count)

	for i in range(instance_count):
		var pos_x = 0.0
		var pos_z = 0.0
		if has_exclusions:
			var attempts = 0
			var excluded = true
			while attempts < 40 and excluded:
				pos_x = rng.randf_range(-half_x, half_x)
				pos_z = rng.randf_range(-half_z, half_z)
				excluded = is_point_excluded(pos_x, pos_z)
				attempts += 1
			if excluded:
				var ang = rng.randf_range(0.0, TAU)
				var r = rng.randf_range(exclusion_radius + 0.5, maxf(exclusion_radius + 1.0, max_r))
				pos_x = clampf(exclusion_center.x + cos(ang) * r, -half_x, half_x)
				pos_z = clampf(exclusion_center.y + sin(ang) * r, -half_z, half_z)
		else:
			pos_x = rng.randf_range(-half_x, half_x)
			pos_z = rng.randf_range(-half_z, half_z)

		var rot_y = rng.randf_range(0.0, TAU)
		var scl = rng.randf_range(min_scale, max_scale)
		
		var t = Transform3D()
		t = t.rotated(Vector3.UP, rot_y)
		t = t.scaled(Vector3(scl, scl, scl))
		t.origin = Vector3(pos_x, 0.0, pos_z)
		
		_instance_origins[i] = t.origin
		mm.set_instance_transform(i, t)
		
	multimesh = mm

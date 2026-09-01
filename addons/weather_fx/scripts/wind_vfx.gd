@tool
class_name WindVFX
extends Node3D

## High-level Wind Visual Effects manager for WeatherFX.
## Aligns environmental wind ribbons, air flows, and gust sweeps with global wind physics.
## Automatically disables wind-blown leaf particles in treeless biomes or when no trees are nearby.

@export var enabled: bool = true:
	set(val):
		enabled = val
		if not enabled:
			for p in _airflow_particles:
				if is_instance_valid(p):
					p.emitting = false
			for p in _leaf_particles:
				if is_instance_valid(p):
					p.emitting = false
		_update_visibility()

@export var min_wind_threshold: float = 4.5:
	set(val):
		min_wind_threshold = val

@export var max_wind_reference: float = 12.0:
	set(val):
		max_wind_reference = val

@export var follow_target: Node3D:
	set(val):
		follow_target = val

@export_group("Foliage & Leaves")
@export var enable_wind_leaves: bool = true ## Enable or disable leaf particles in wind.
@export var require_nearby_trees: bool = true ## When true, leaves only blow if trees are physically nearby.
@export var tree_detection_radius: float = 35.0 ## Maximum distance to a tree for leaves to appear in wind.

@export_group("Gust Sweeps")
@export var enable_gust_sweeps: bool = true
@export var gust_interval_min: float = 12.0
@export var gust_interval_max: float = 24.0

var _airflow_particles: Array[GPUParticles3D] = []
var _leaf_particles: Array[GPUParticles3D] = []
var _gust_sweep_scene: PackedScene
var _gust_timer: float = 0.0
var _next_gust_time: float = 8.0
var _tree_check_timer: float = 0.0
var _trees_nearby_cached: bool = false
var _weather_fx_node: Node3D = null


func _ready() -> void:
	_airflow_particles.clear()
	_leaf_particles.clear()
	for child in get_children():
		if child is GPUParticles3D:
			if "leaf" in child.name.to_lower() or "foil" in child.name.to_lower():
				_leaf_particles.append(child)
			else:
				_airflow_particles.append(child)
			child.emitting = false
			child.visible = true

	# Find WeatherFX reference in tree
	_find_weather_fx()

	# Preload gust sweep
	if ResourceLoader.exists("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_WindBlow_1.tscn"):
		_gust_sweep_scene = load("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_WindBlow_1.tscn") as PackedScene

	_next_gust_time = randf_range(gust_interval_min, gust_interval_max)
	visible = enabled


func _find_weather_fx() -> void:
	if is_instance_valid(_weather_fx_node):
		return
	if get_parent() is WeatherFX:
		_weather_fx_node = get_parent() as WeatherFX
	elif is_inside_tree():
		var found = get_tree().root.find_child("WeatherFX", true, false)
		if found is WeatherFX:
			_weather_fx_node = found


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		visible = false
		for p in _airflow_particles:
			if is_instance_valid(p):
				p.emitting = false
		for p in _leaf_particles:
			if is_instance_valid(p):
				p.emitting = false
		return

	var wind_strength: float = WeatherFX.get_wind_strength()
	var is_active = enabled and (wind_strength >= min_wind_threshold)

	if not is_active:
		visible = false
		for p in _airflow_particles:
			if is_instance_valid(p):
				p.emitting = false
		for p in _leaf_particles:
			if is_instance_valid(p):
				p.emitting = false
		return

	visible = true

	# Follow target position if assigned
	if follow_target and is_instance_valid(follow_target):
		global_position = follow_target.global_position

	var wind_dir: Vector3 = WeatherFX.get_wind_direction()
	if wind_dir.length_squared() < 0.001:
		wind_dir = Vector3.RIGHT
	else:
		wind_dir = wind_dir.normalized()

	# Rotate entire wind VFX node so its +X forward axis aligns exactly with wind_dir
	var yaw_angle = atan2(-wind_dir.z, wind_dir.x)
	rotation = Vector3(0.0, yaw_angle, 0.0)

	var wind_factor = clampf((wind_strength - min_wind_threshold) / (max_wind_reference - min_wind_threshold), 0.0, 1.0)

	# Update continuous airflow particle systems (air ribbons, streaks)
	for p in _airflow_particles:
		if is_instance_valid(p):
			p.visible = true
			p.emitting = true
			p.amount_ratio = 0.25 + 0.75 * wind_factor
			p.speed_scale = 0.8 + 1.2 * wind_factor

	# Periodic check for nearby trees (throttled to every 1.0s)
	_tree_check_timer += delta
	if _tree_check_timer >= 1.0:
		_tree_check_timer = 0.0
		_trees_nearby_cached = _check_nearby_trees()

	var allow_leaves: bool = _can_spawn_leaves()

	# Update continuous leaf particle systems
	for p in _leaf_particles:
		if is_instance_valid(p):
			if allow_leaves:
				p.visible = true
				p.emitting = true
				p.amount_ratio = 0.25 + 0.75 * wind_factor
				p.speed_scale = 0.8 + 1.2 * wind_factor
			else:
				p.emitting = false
				p.visible = false

	# Periodic gust sweep wave
	if enable_gust_sweeps and is_active and _gust_sweep_scene:
		_gust_timer += delta
		if _gust_timer >= _next_gust_time:
			_gust_timer = 0.0
			_next_gust_time = randf_range(gust_interval_min / (1.0 + wind_factor), gust_interval_max / (1.0 + wind_factor))
			_spawn_gust_sweep(wind_dir, wind_factor, allow_leaves)


## Determines whether leaves are allowed to appear based on settings, biome, and tree proximity.
func _can_spawn_leaves() -> bool:
	if not enable_wind_leaves:
		return false

	_find_weather_fx()
	if is_instance_valid(_weather_fx_node):
		if not ClimateData.biome_has_trees(_weather_fx_node.current_biome):
			return false

	if require_nearby_trees and not _trees_nearby_cached:
		return false

	return true


## Checks if any trees or foliage nodes are located within tree_detection_radius.
func _check_nearby_trees() -> bool:
	if not is_inside_tree():
		return false

	var tree = get_tree()
	if tree == null:
		return false

	var check_pos: Vector3 = global_position
	if follow_target and is_instance_valid(follow_target):
		check_pos = follow_target.global_position

	# Check group tags
	var candidate_groups: Array[StringName] = [&"Tree", &"Trees", &"Foliage", &"Choppable"]
	for grp in candidate_groups:
		for node in tree.get_nodes_in_group(grp):
			if node is Node3D and (node as Node3D).global_position.distance_to(check_pos) <= tree_detection_radius:
				return true

	# Also check by name heuristic in scene tree
	for node in tree.root.find_children("*Tree*", "Node3D", true, false):
		if node is Node3D and not (node is GPUParticles3D) and (node as Node3D).global_position.distance_to(check_pos) <= tree_detection_radius:
			return true

	return false


func _spawn_gust_sweep(wind_dir: Vector3, wind_factor: float, allow_leaves: bool) -> void:
	if not _gust_sweep_scene:
		return
	var gust = _gust_sweep_scene.instantiate() as Node3D
	if not gust:
		return
	add_child(gust)

	# Place upwind (-X in local space) and let it blow across downwind (+X)
	var offset_x = randf_range(-18.0, -12.0)
	var offset_y = randf_range(1.5, 4.0)
	var offset_z = randf_range(-8.0, 8.0)
	gust.position = Vector3(offset_x, offset_y, offset_z)
	gust.scale = Vector3.ONE * (0.8 + 0.6 * wind_factor)

	# If leaves are not allowed, disable leaf sub-emitters in the gust sweep
	if not allow_leaves:
		for child in gust.find_children("*leaf*", "GPUParticles3D", true, false):
			if child is GPUParticles3D:
				child.emitting = false
				child.visible = false

	# Auto-clean after lifetime
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_gust_timer_timeout.bind(gust))


func _on_gust_timer_timeout(gust: Node3D) -> void:
	if is_instance_valid(gust):
		gust.queue_free()


func _update_visibility() -> void:
	visible = enabled
	if not enabled:
		for p in _airflow_particles:
			if is_instance_valid(p):
				p.emitting = false
		for p in _leaf_particles:
			if is_instance_valid(p):
				p.emitting = false

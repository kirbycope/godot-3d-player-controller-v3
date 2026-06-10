@tool
extends Node3D

@export var clockwise: bool = true
@export var play: bool = true:
	set(value):
		play = value
		if not play:
			_orbit_offset = 0.0
			_restore_initial_positions()
@export var pause_when_editor_unfocused: bool = true
@export_range(0.0, 360.0, 0.1, "suffix:deg/s") var rotation_speed_deg: float = 60.0
@export_range(0.1, 20.0, 0.1, "suffix:m") var orbit_radius: float = 1.5
@export var balloon_group_name: StringName = &"balloon"
@export var balloon_name_prefix: String = "RedBallon"
@export var show_balloon_string: bool = true:
	set(value):
		show_balloon_string = value
		_set_balloons_string_visible(show_balloon_string)

var _balloons: Array[Node3D] = []
var _base_angles: Array[float] = []
var _base_radii: Array[float] = []
var _base_z: Array[float] = []
var _initial_positions: Array[Vector3] = []
var _orbit_offset: float = 0.0
var _orbit_radius_initialized: bool = false


func _enter_tree() -> void:
	set_process(true)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_cache_balloons()
	_capture_initial_orbit()
	_set_child_rigid_bodies_disabled(true)
	_set_balloons_string_visible(show_balloon_string)
	if not play:
		_restore_initial_positions()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_refresh_balloons_if_needed()
	if pause_when_editor_unfocused and Engine.is_editor_hint() and not DisplayServer.window_is_focused():
		return
	if not play:
		return

	var direction := -1.0 if clockwise else 1.0
	_orbit_offset += deg_to_rad(rotation_speed_deg) * direction * delta

	for i in _balloons.size():
		var balloon := _balloons[i]
		if not _is_balloon_valid(balloon):
			continue

		var angle := _base_angles[i] + _orbit_offset
		var radius := orbit_radius
		balloon.position = Vector3(cos(angle) * radius, sin(angle) * radius, _base_z[i])


func _cache_balloons() -> void:
	_balloons.clear()
	for child in get_children():
		if child is Node3D and (child as Node).is_in_group(balloon_group_name):
			_balloons.append(child as Node3D)

	# Fallback when nodes are not yet in group.
	if _balloons.is_empty():
		for child in get_children():
			if child is Node3D and (child as Node).name.begins_with(balloon_name_prefix):
				_balloons.append(child as Node3D)

	_balloons.sort_custom(_sort_balloons_by_name)


func _sort_balloons_by_name(a: Node3D, b: Node3D) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _has_invalid_balloons() -> bool:
	for balloon in _balloons:
		if not _is_balloon_valid(balloon):
			return true
	return false


func _refresh_balloons_if_needed() -> void:
	var should_refresh := _balloons.is_empty()
	# In editor, always refresh if any balloon becomes invalid so level preview updates
	if Engine.is_editor_hint() and _has_invalid_balloons():
		should_refresh = true
	
	if should_refresh:
		_cache_balloons()
		_capture_initial_orbit()
		_set_child_rigid_bodies_disabled(true)
		_set_balloons_string_visible(show_balloon_string)


func _capture_initial_orbit() -> void:
	_base_angles.clear()
	_base_radii.clear()
	_base_z.clear()
	_initial_positions.clear()

	for balloon in _balloons:
		if not _is_balloon_valid(balloon):
			_base_angles.append(0.0)
			_base_radii.append(0.0)
			_base_z.append(0.0)
			_initial_positions.append(Vector3.ZERO)
			continue

		var pos2 := Vector2(balloon.position.x, balloon.position.y)
		_base_angles.append(atan2(pos2.y, pos2.x))
		_base_radii.append(pos2.length())
		_base_z.append(balloon.position.z)
		_initial_positions.append(balloon.position)

	if not _orbit_radius_initialized:
		var radius_sum := 0.0
		var radius_count := 0
		for radius in _base_radii:
			if radius > 0.001:
				radius_sum += radius
				radius_count += 1
		if radius_count > 0:
			orbit_radius = radius_sum / float(radius_count)
		_orbit_radius_initialized = true

	# If all balloons start at origin, build a default visible orbit.
	var has_non_zero_radius := false
	for radius in _base_radii:
		if radius > 0.001:
			has_non_zero_radius = true
			break

	if not has_non_zero_radius:
		var count := _balloons.size()
		if count <= 0:
			return
		for i in count:
			if not _is_balloon_valid(_balloons[i]):
				continue
			var angle := TAU * float(i) / float(count)
			_base_angles[i] = angle
			_base_radii[i] = orbit_radius
			_base_z[i] = 0.0
			var fallback_position := Vector3(cos(angle) * orbit_radius, sin(angle) * orbit_radius, 0.0)
			_balloons[i].position = fallback_position
			_initial_positions[i] = fallback_position


func _is_balloon_valid(balloon) -> bool:
	if balloon == null or not is_instance_valid(balloon):
		return false
	if not (balloon is Node):
		return false
	return not (balloon as Node).is_queued_for_deletion()


func _set_child_rigid_bodies_disabled(disabled: bool) -> void:
	for balloon in _balloons:
		if not _is_balloon_valid(balloon):
			continue
		_set_child_rigid_bodies_disabled_recursive(balloon, disabled)


func _set_child_rigid_bodies_disabled_recursive(node, disabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not (node is Node):
		return

	if node is RigidBody3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED if disabled else Node.PROCESS_MODE_INHERIT
		node.sleeping = disabled
	for child in (node as Node).get_children():
		_set_child_rigid_bodies_disabled_recursive(child, disabled)


func _set_balloons_string_visible(is_visible: bool) -> void:
	for balloon in _balloons:
		if not _is_balloon_valid(balloon):
			continue
		var string_node := (balloon as Node).get_node_or_null("Visuals/String")
		if string_node is Node3D:
			(string_node as Node3D).visible = is_visible


func _restore_initial_positions() -> void:
	for i in _balloons.size():
		var balloon := _balloons[i]
		if not _is_balloon_valid(balloon):
			continue
		if i >= _initial_positions.size():
			continue
		balloon.position = _initial_positions[i]

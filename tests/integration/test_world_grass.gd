extends GutTest

## Purpose: the grass in world.tscn grows on the world's ground and keeps clear of what stands on it.
##
## Every GrassField drops a ray per blade and grows only where the ray meets a collider in the GRASS group,
## so the fields depend on NavigationRegion3D/Ground being in that group. If it ever left, the fields would
## grow nothing and say so only in a warning, which a test run does not fail on; this one does.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	# A probing field starts growing two physics frames after it enters the tree and casts its rays a slice per
	# frame, so wait for every field in the world to be done rather than counting frames
	await wait_until(func() -> bool: return _fields().all(func(f: GrassField) -> bool: return not f.is_growing()), 10.0)


func _fields() -> Array[GrassField]:
	var fields: Array[GrassField] = []
	for node: Node in get_tree().get_nodes_in_group(&"GrassField"):
		if world.is_ancestor_of(node):
			fields.append(node as GrassField)
	return fields


func test_every_field_finds_its_ground() -> void:
	var fields: Array[GrassField] = _fields()
	assert_gt(fields.size(), 0, "The world has grass")
	for field: GrassField in fields:
		assert_gt(field.get_instance_origins().size(), 0, "%s grew on the ground" % field.name)
		assert_eq(field._get_configuration_warnings().size(), 0, "%s found a collider in its ground group" % field.name)


func test_the_silo_stands_in_bare_ground() -> void:
	var silo: Node3D = world.get_node("NavigationRegion3D/Silo") as Node3D
	var axis: Vector2 = Vector2(silo.global_position.x, silo.global_position.z)
	var main: GrassField = world.get_node("NavigationRegion3D/GrassField") as GrassField
	var near_the_wall: int = 0
	var inside: int = 0
	for origin: Vector3 in main.get_instance_origins():
		var at: Vector3 = main.global_transform * origin
		var from_axis: float = Vector2(at.x, at.z).distance_to(axis)
		if from_axis < 1.9: # The silo's radius is 2 m
			inside += 1
		elif from_axis < 3.0:
			near_the_wall += 1
	assert_eq(inside, 0, "No grass grows inside the silo")
	assert_gt(near_the_wall, 0, "while it grows right up to its wall")


func test_the_player_spawns_in_grass_not_a_bald_patch() -> void:
	# The Player is a CharacterBody3D standing on the field when it grows, which the rays look past
	var player: Node3D = world.get_node("PlayerSpawner/1") as Node3D
	var feet: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var main: GrassField = world.get_node("NavigationRegion3D/GrassField") as GrassField
	var underfoot: int = 0
	for origin: Vector3 in main.get_instance_origins():
		var at: Vector3 = main.global_transform * origin
		if Vector2(at.x, at.z).distance_to(feet) < 0.6:
			underfoot += 1
	assert_gt(underfoot, 0, "Grass grows where the Player stood when the field grew")

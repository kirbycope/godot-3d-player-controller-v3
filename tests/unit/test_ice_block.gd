extends GutTest

## Purpose: IceBlock.freeze_at turns the water under a point into a walkable slab with its top at the wave surface,
## gives nothing over dry ground or in the air above the pond, a body dropped on the slab rests on it instead of
## floating, and the slab melts away and frees itself after its lifetime.

const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const ICE_BLOCK_SCENE: PackedScene = preload("res://scenes/ice_block.tscn")

var root: Node3D
var water: Buoyancy


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	_floor(Vector3(0.0, -4.5, 0.0), Vector3(20.0, 1.0, 20.0)) # the pond floor
	_floor(Vector3(30.0, -0.5, 0.0), Vector3(10.0, 1.0, 10.0)) # dry ground beside it
	water = _pond(Vector3.ZERO)
	await wait_physics_frames(1)


func after_each() -> void:
	for block: Node in get_tree().get_nodes_in_group(&"IceBlock"):
		block.free()


func _floor(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = at
	root.add_child(body)


## A 20 x 20 pond like test_buoyancy's: the surface quad at [param at] with the pond shader, the water below it.
func _pond(at: Vector3) -> Buoyancy:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, 20.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	surface.position = at
	root.add_child(surface)
	var pond := Buoyancy.new()
	pond.add_to_group(&"WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20.0, 4.0, 20.0)
	pond.add_child(shape)
	pond.position = at + Vector3(0.0, -2.0, 0.0)
	pond.water_mesh = surface
	pond.body_entered.connect(pond._on_body_entered)
	pond.body_exited.connect(pond._on_body_exited)
	root.add_child(pond)
	return pond


func test_freezing_the_water_under_a_point_makes_a_slab_at_the_surface() -> void:
	var point := Vector3(2.0, -3.0, 1.0) # on the pond floor, where an arrow or the crosshair lands
	assert_eq(IceBlock.find_water(get_tree(), point), water, "The pond is the water under the point")
	var block: IceBlock = IceBlock.freeze_at(root, point)
	assert_not_null(block, "Water freezes")
	assert_true(block.is_inside_tree() and block.is_in_group(&"IceBlock"))
	assert_almost_eq(block.global_position.x, 2.0, 0.001)
	assert_almost_eq(block.global_position.z, 1.0, 0.001)
	var top: float = block.global_position.y + IceBlock.SIZE.y * 0.5
	assert_almost_eq(top, water.get_surface_height(point) + IceBlock.TOP_ABOVE_SURFACE, 0.1, "The slab's top rides just above the wave surface")
	assert_not_null(block.get_node("CollisionShape3D"), "and it is a body to stand on")


func test_dry_ground_and_the_air_over_the_pond_do_not_freeze() -> void:
	assert_null(IceBlock.find_water(get_tree(), Vector3(30.0, 0.0, 0.0)), "Ground beside the pond is not water")
	assert_null(IceBlock.freeze_at(root, Vector3(30.0, 0.0, 0.0)))
	assert_null(IceBlock.freeze_at(root, Vector3(0.0, 2.0, 0.0)), "A point in the air over the pond is not water either")
	assert_null(IceBlock.freeze_at(root, Vector3(11.0, -1.0, 0.0)), "Nor a point past the pond's edge")
	assert_eq(get_tree().get_nodes_in_group(&"IceBlock").size(), 0, "Nothing was made")


func test_a_body_dropped_on_the_slab_rests_on_it_instead_of_floating() -> void:
	IceBlock.freeze_at(root, Vector3(0.0, -3.0, 0.0))
	var ball := RigidBody3D.new()
	ball.mass = 0.2
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.25
	ball.add_child(shape)
	ball.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(ball)
	await wait_seconds(1.5)
	assert_gt(ball.global_position.y, 0.2, "The ball sits on the ice; in the water it would settle a quarter metre under the surface")
	assert_false(water.bodies.has(ball), "It never went into the water")


func test_the_slab_melts_away_and_frees_itself_after_its_lifetime() -> void:
	var block: IceBlock = ICE_BLOCK_SCENE.instantiate()
	block.lifetime = 0.6
	block.melt_seconds = 0.3
	root.add_child(block)
	var melted: Array[int] = [0]
	block.melted.connect(func() -> void: melted[0] += 1)
	await wait_seconds(0.45)
	assert_true(is_instance_valid(block), "Still there while it melts")
	assert_lt(block.scale.x, 1.0, "and shrinking")
	assert_gt(block.scale.x, 0.0)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(block), "Gone after its lifetime")
	assert_eq(melted[0], 1, "It said so once")

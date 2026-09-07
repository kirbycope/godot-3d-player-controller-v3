extends GutTest

## Purpose: the elemental rounds. A fire arrow and an incendiary round light the grass where they land (not in the
## rain) and only when they are the round's authority, the fire arrow's flame burning on where it sticks; an ice
## arrow over water is spent on an ice block at the surface, on ground it sticks like any arrow with its frost at
## the tip, and a copy off the authority freezes nothing.

const FIRE_ARROW_SCENE: PackedScene = preload("res://scenes/fire_arrow.tscn")
const ICE_ARROW_SCENE: PackedScene = preload("res://scenes/ice_arrow.tscn")
const INCENDIARY_SCENE: PackedScene = preload("res://scenes/incendiary_round.tscn")
const GRASS_FIELD_SCENE: PackedScene = preload("res://addons/weather_fx/scenes/grass_field.tscn")
const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const POND_X: float = 40.0 ## The pond sits well clear of the grass.

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	_floor(Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0)) # the ground under the grass
	_floor(Vector3(POND_X, -4.5, 0.0), Vector3(20.0, 1.0, 20.0)) # the pond floor
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


func _pond() -> Buoyancy:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, 20.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	surface.position = Vector3(POND_X, 0.0, 0.0)
	root.add_child(surface)
	var pond := Buoyancy.new()
	pond.add_to_group(&"WATER")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20.0, 4.0, 20.0)
	pond.add_child(shape)
	pond.position = Vector3(POND_X, -2.0, 0.0)
	pond.water_mesh = surface
	root.add_child(pond)
	return pond


func _field() -> GrassField:
	var field: GrassField = GRASS_FIELD_SCENE.instantiate()
	field.field_size = Vector2(20.0, 20.0)
	field.instance_count = 400
	root.add_child(field)
	return field


## Fires [param scene] straight down from [param from]; an [param authority] other than 1 makes it a copy off the authority.
func _shoot(scene: PackedScene, from: Vector3, authority: int = 1) -> Projectile:
	var round: Projectile = scene.instantiate()
	round.set_multiplayer_authority(authority)
	root.add_child(round)
	round.launch(Transform3D(Basis.IDENTITY, from), Vector3.DOWN, 30.0, null)
	return round


func test_a_fire_arrow_lights_the_grass_where_it_lands_and_burns_on_where_it_sticks() -> void:
	var field: GrassField = _field()
	await wait_physics_frames(2)
	var arrow: FireArrow = _shoot(FIRE_ARROW_SCENE, Vector3(0.0, 3.0, 0.0))
	assert_gt(arrow.flame.position.y, 0.4, "In flight the flame rides the tip")
	await wait_physics_frames(20)
	assert_gt(field._burning_cells.size(), 0, "The impact lights the grass around it")
	assert_true(is_instance_valid(arrow) and arrow.has_hit and arrow.freeze, "The arrow sticks where it landed")
	assert_eq(arrow.flame.position, Vector3.ZERO, "and its flame burns at the surface, not buried with the tip")
	assert_true((arrow.flame.get_node("FlameParticles") as GPUParticles3D).emitting, "still alight while it is stuck")


func test_rain_stops_a_fire_arrow_lighting_anything() -> void:
	var field: GrassField = _field()
	await wait_physics_frames(2)
	field._on_weather_changed(ClimateData.WeatherType.RAIN, ClimateData.WeatherType.BLUE_SKY)
	_shoot(FIRE_ARROW_SCENE, Vector3(0.0, 3.0, 0.0))
	await wait_physics_frames(20)
	assert_eq(field._burning_cells.size(), 0, "Wet grass never catches from an arrow")


func test_an_incendiary_round_lights_the_grass_and_is_spent() -> void:
	var field: GrassField = _field()
	await wait_physics_frames(2)
	var round: Projectile = _shoot(INCENDIARY_SCENE, Vector3(0.0, 3.0, 0.0))
	assert_true(round is IncendiaryRound)
	await wait_physics_frames(20)
	assert_gt(field._burning_cells.size(), 0, "The round lights the grass where it lands")
	assert_false(is_instance_valid(round) and round.is_inside_tree(), "A bullet frees itself after hitting")


func test_a_copy_off_the_authority_lights_nothing() -> void:
	var field: GrassField = _field()
	await wait_physics_frames(2)
	var arrow: Projectile = _shoot(FIRE_ARROW_SCENE, Vector3(0.0, 3.0, 0.0), 2)
	_shoot(INCENDIARY_SCENE, Vector3(3.0, 3.0, 0.0), 2)
	await wait_physics_frames(20)
	assert_eq(field._burning_cells.size(), 0, "Only the round's authority decides what a hit leaves behind")
	assert_true(is_instance_valid(arrow) and arrow.has_hit, "The copy still lands and sticks like the authority's")


func test_an_ice_arrow_over_water_is_spent_on_an_ice_block_at_the_surface() -> void:
	var pond: Buoyancy = _pond()
	await wait_physics_frames(2)
	var arrow: IceArrow = _shoot(ICE_ARROW_SCENE, Vector3(POND_X + 1.0, 3.0, -2.0))
	assert_gt(arrow.frost.position.y, 0.4, "In flight the frost rides the tip")
	assert_true(arrow.frost.emitting)
	await wait_physics_frames(30)
	var blocks: Array[Node] = get_tree().get_nodes_in_group(&"IceBlock")
	assert_eq(blocks.size(), 1, "One slab where the arrow landed")
	var block: IceBlock = blocks[0] as IceBlock
	assert_almost_eq(block.global_position.x, POND_X + 1.0, 0.05)
	assert_almost_eq(block.global_position.z, -2.0, 0.05)
	assert_almost_eq(block.global_position.y + IceBlock.SIZE.y * 0.5, pond.get_surface_height(block.global_position) + IceBlock.TOP_ABOVE_SURFACE, 0.1, "at the wave surface")
	assert_false(is_instance_valid(arrow) and arrow.is_inside_tree(), "The arrow is spent instead of sticking in the pond floor")


func test_an_ice_arrow_sticks_in_the_ground_like_any_arrow() -> void:
	_pond()
	await wait_physics_frames(2)
	var arrow: IceArrow = _shoot(ICE_ARROW_SCENE, Vector3(0.0, 3.0, 0.0))
	await wait_physics_frames(20)
	assert_true(is_instance_valid(arrow) and arrow.has_hit and arrow.freeze, "Stuck")
	assert_eq(get_tree().get_nodes_in_group(&"IceBlock").size(), 0, "Ground does not freeze")
	assert_eq(arrow.frost.position, Vector3.ZERO, "The frost sits where the arrow went in")
	assert_true(arrow.frost.emitting, "and keeps drifting while it is stuck")


func test_an_ice_arrow_off_the_authority_freezes_nothing() -> void:
	_pond()
	await wait_physics_frames(2)
	var arrow: Projectile = _shoot(ICE_ARROW_SCENE, Vector3(POND_X, 3.0, 0.0), 2)
	await wait_physics_frames(30)
	assert_eq(get_tree().get_nodes_in_group(&"IceBlock").size(), 0, "Only the authority freezes the water")
	assert_true(is_instance_valid(arrow) and arrow.has_hit and arrow.freeze, "The copy sticks in the pond floor and waits for the authority's despawn")

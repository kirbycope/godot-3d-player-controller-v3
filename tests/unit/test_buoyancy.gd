extends GutTest

## Purpose: The pool's Buoyancy area floats rigid bodies at the wave surface, tilts hulls lifted at offset
## probes, mirrors the pond shader's waves, and the boat rides those waves without leaving its mooring.

const POND_MATERIAL: Material = preload("res://addons/weather_fx/resources/pond_water_material.tres")
const BOAT_SCENE: PackedScene = preload("res://scenes/boat.tscn")

var root: Node3D
var water: Buoyancy


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -4.5
	root.add_child(floor_body)

	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(20.0, 20.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = POND_MATERIAL
	surface.mesh = quad
	root.add_child(surface)

	water = Buoyancy.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20.0, 4.0, 20.0)
	water.add_child(shape)
	water.position.y = -2.0
	water.water_mesh = surface
	water.body_entered.connect(water._on_body_entered)
	water.body_exited.connect(water._on_body_exited)
	root.add_child(water)


func _drop_ball(at: Vector3, radius: float = 0.5) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.mass = 0.2
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = radius
	ball.add_child(shape)
	ball.position = at
	root.add_child(ball)
	return ball


func test_a_light_ball_settles_half_submerged_at_the_surface() -> void:
	var ball := _drop_ball(Vector3(0.0, 1.0, 0.0))
	await wait_seconds(3.0)
	assert_true(water.bodies.has(ball), "The ball is tracked while inside the water")
	assert_almost_eq(ball.global_position.y, -0.25, 0.3, "Lift of twice the weight at full submersion balances a quarter metre under the surface")
	assert_lt(ball.linear_velocity.length(), 0.5, "Drag settles the ball instead of letting it bounce")


func test_leaving_the_water_stops_the_lift() -> void:
	var ball := _drop_ball(Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(10)
	ball.global_position = Vector3(0.0, 6.0, 0.0)
	await wait_physics_frames(3)
	assert_false(water.bodies.has(ball), "Leaving the area removes the body")
	assert_true(ball.can_sleep)
	assert_false(water.is_physics_processing(), "Nothing to float, nothing to process")


func test_wave_offset_mirrors_the_pond_shader() -> void:
	var amplitude: float = POND_MATERIAL.get_shader_parameter("wave_amplitude")
	var wind_speed: float = 0.1 # no WeatherFX in this scene, so the shader's minimum wind applies
	var max_offset: float = amplitude * (0.6 + clampf(wind_speed * 0.1, 0.0, 2.0))
	var samples: Array[float] = []
	for i in 6:
		samples.append(water.get_wave_offset(Vector3.ZERO))
		await wait_seconds(0.2)
	for sample: float in samples:
		assert_lte(absf(sample), max_offset + 0.0001, "Waves never exceed the shader's active amplitude")
	assert_gt(samples.max() - samples.min(), 0.002, "The surface keeps moving over a second")
	assert_almost_eq(water.get_wave_offset(Vector3(9.9, 0.0, 0.0)), 0.0, 0.0001, "Waves are damped to nothing at the pond edge")
	assert_almost_eq(water.get_surface_height(Vector3.ZERO), water.get_wave_offset(Vector3.ZERO), 0.0001, "The surface sits on the water mesh")


func test_an_offset_probe_rolls_the_body() -> void:
	var raft := RigidBody3D.new()
	raft.mass = 1.0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2.0, 0.2, 1.0)
	raft.add_child(shape)
	var probe := Marker3D.new()
	probe.position = Vector3(1.0, 0.0, 0.0)
	probe.add_to_group("BuoyancyProbe")
	raft.add_child(probe)
	raft.position.y = -0.5
	root.add_child(raft)
	await wait_physics_frames(2)
	assert_eq(water.bodies[raft], [probe], "Probe markers replace the origin as lift points")
	await wait_seconds(1.0)
	assert_gt(absf(raft.rotation.z), 0.05, "Lift applied off centre rolls the raft")


func test_the_boat_rides_the_waves_in_place() -> void:
	var boat: AnimatableBody3D = BOAT_SCENE.instantiate()
	boat.water = water
	boat.position = Vector3(2.0, 0.0, 1.0)
	root.add_child(boat)
	var heights: Array[float] = []
	for i in 6:
		await wait_seconds(0.2)
		heights.append(boat.global_position.y)
		assert_almost_eq(boat.global_position.x, 2.0, 0.001, "The boat stays moored")
		assert_almost_eq(boat.global_position.z, 1.0, 0.001)
		assert_lt(absf(boat.rotation.x) + absf(boat.rotation.z), 0.3, "Rocking stays gentle")
	assert_gt(heights.max() - heights.min(), 0.002, "The boat bobs with the waves")

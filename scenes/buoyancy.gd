class_name Buoyancy
extends Area3D
## Floats RigidBody3D bodies that enter this water and reports the wave surface the pond water shader draws.
##
## Bodies are lifted at their "BuoyancyProbe" Marker3D children (or at their origin without any) in
## proportion to how deep each probe sits below the wave surface, so offset probes make hulls roll and
## pitch. Forces have no signal, so they are applied per physics frame while any body is inside.
## [method get_wave_offset] mirrors the vertex waves of pond_water.gdshader so kinematic bodies ride them too.

const WAVE_TIME_ROLLOVER: float = 3600.0 ## Shader TIME wraps at rendering/limits/time/time_rollover_secs.

@export var water_mesh: MeshInstance3D ## Quad drawn with pond_water.gdshader; its height and wave uniforms define the surface.
@export var weather: WeatherFX ## Source of the wind the shader reads from its globals; without it the shader's fallbacks apply.
@export var buoyancy: float = 2.0 ## Lift at full submersion as a multiple of the body's weight; 2 floats a body half submerged.
@export var probe_depth: float = 0.5 ## Metres below the surface at which a probe counts as fully submerged.
@export var drag: float = 8.0 ## Linear damping per unit of submersion, scaled by mass; settles a bob within a few swings.
@export var angular_drag: float = 2.0 ## Angular damping per unit of submersion, scaled by mass.

var bodies: Dictionary[RigidBody3D, Array] = {} ## Floating body -> the nodes it is lifted at.

@onready var _material: ShaderMaterial = water_mesh.get_active_material(0) as ShaderMaterial


func _ready() -> void:
	set_physics_process(false)


## Wave height above the resting surface at [param point], matching pond_water.gdshader's vertex waves.
func get_wave_offset(point: Vector3) -> float:
	# Reading the shader globals back is editor-only, so the wind comes from WeatherFX itself
	var wind: Vector3 = weather.wind_direction if weather else Vector3.RIGHT
	var wind_dir: Vector2 = Vector2(wind.x, wind.z)
	wind_dir = wind_dir.normalized() if wind_dir.length() >= 0.001 else Vector2.RIGHT
	var wind_speed: float = maxf(0.1, weather.current_wind_strength if weather else 0.0)
	var speed: float = _material.get_shader_parameter("wave_speed") * (1.0 + wind_speed * 0.15)
	var amplitude: float = _material.get_shader_parameter("wave_amplitude") * (0.6 + clampf(wind_speed * 0.1, 0.0, 2.0))
	var frequency: float = _material.get_shader_parameter("wave_frequency")
	var time: float = fmod(Time.get_ticks_msec() / 1000.0, WAVE_TIME_ROLLOVER)
	var local: Vector3 = water_mesh.to_local(point)
	var xz: Vector2 = Vector2(local.x, local.z)
	var wave1: float = sin(xz.dot(wind_dir) * frequency + time * speed)
	var wave2: float = cos(xz.dot(Vector2(-wind_dir.y, wind_dir.x)) * frequency * 1.5 + time * speed * 1.3)
	# Waves fade toward the edges so the water stays sealed in the pond
	var size: Vector2 = (water_mesh.mesh as QuadMesh).size
	var edge_mask: float = smoothstep(0.0, 0.35, clampf(1.0 - Vector2(local.x / size.x, local.z / size.y).length() * 2.0, 0.0, 1.0))
	return (wave1 * 0.7 + wave2 * 0.3) * amplitude * edge_mask


## World height of the wave surface at [param point].
func get_surface_height(point: Vector3) -> float:
	return water_mesh.global_position.y + get_wave_offset(point)


func _physics_process(_delta: float) -> void:
	for body: RigidBody3D in bodies:
		var probes: Array = bodies[body]
		var submersion: float = 0.0
		for probe: Node3D in probes:
			var ratio: float = clampf((get_surface_height(probe.global_position) - probe.global_position.y) / probe_depth, 0.0, 1.0)
			submersion += ratio / probes.size()
			body.apply_force(-body.get_gravity() * body.mass * buoyancy * ratio / probes.size(), probe.global_position - body.global_position)
		body.apply_central_force(-body.linear_velocity * drag * submersion * body.mass)
		body.apply_torque(-body.angular_velocity * angular_drag * submersion * body.mass)


## Wired to body_entered in the scene.
func _on_body_entered(body: Node3D) -> void:
	var floating: RigidBody3D = body as RigidBody3D
	if floating == null:
		return
	var probes: Array = floating.get_children().filter(func(child: Node) -> bool: return child.is_in_group("BuoyancyProbe"))
	bodies[floating] = probes if not probes.is_empty() else [floating]
	floating.can_sleep = false
	set_physics_process(true)


## Wired to body_exited in the scene.
func _on_body_exited(body: Node3D) -> void:
	if bodies.erase(body as RigidBody3D):
		body.can_sleep = true
	set_physics_process(not bodies.is_empty())

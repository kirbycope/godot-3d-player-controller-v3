class_name Buoyancy
extends Area3D
## Floats RigidBody3D bodies that enter this water and reports the wave surface the pond water shader draws.
##
## Bodies are lifted at their "BuoyancyProbe" Marker3D children (or at their origin without any) in
## proportion to how deep each probe sits below the wave surface, so offset probes make hulls roll and
## pitch. Forces have no signal, so they are applied per physics frame while any body is inside.
## [method get_wave_offset] mirrors the vertex waves of pond_water.gdshader so kinematic bodies ride them too.
## The water also owns what can be fished out of it: [member fish], picked by the in-game hour and rain.

const WAVE_TIME_ROLLOVER: float = 3600.0 ## Shader TIME wraps at rendering/limits/time/time_rollover_secs.
const WAVE_GRAVITY: float = 9.8 ## Deep-water dispersion in the shader: a wave's angular speed is sqrt(g * k).
## The shader's wave table: angle from the wind (rad), wave number as a multiple of wave_frequency, share of wave_amplitude.
const WAVES: Array[Vector3] = [
	Vector3(0.0, 0.5, 0.30),
	Vector3(0.35, 0.8, 0.22),
	Vector3(-0.45, 1.1, 0.18),
	Vector3(0.9, 1.7, 0.12),
	Vector3(-1.1, 2.3, 0.10),
	Vector3(0.2, 3.2, 0.08),
]

@export var water_mesh: MeshInstance3D ## Quad drawn with pond_water.gdshader; its height and wave uniforms define the surface.
@export var weather: WeatherFX ## Source of the wind the shader reads from its globals; without it the shader's fallbacks apply.
@export var buoyancy: float = 2.0 ## Lift at full submersion as a multiple of the body's weight; 2 floats a body half submerged.
@export var probe_depth: float = 0.5 ## Metres below the surface at which a probe counts as fully submerged; a body with its own `probe_depth` property overrides it.
@export var drag: float = 8.0 ## Linear damping per unit of submersion, scaled by mass; settles a bob within a few swings.
@export var angular_drag: float = 2.0 ## Angular damping per unit of submersion, scaled by mass.
@export_group("Fishing")
@export var fish: Array[Fish] = [] ## What bites here; empty water never bites.
@export var clock: DateAndTime ## In-game clock for the fish tables; without it every table reads noon.
@export var shadows: FishShadows ## Optional shadows swimming in this water.
@export var biome_zone: WeatherZone ## The zone this water lies in; fish list the biomes they live in, and water in no zone holds them all.

var bodies: Dictionary[RigidBody3D, Array] = {} ## Floating body -> the nodes it is lifted at.

@onready var _material: ShaderMaterial = water_mesh.get_active_material(0) as ShaderMaterial


func _ready() -> void:
	set_physics_process(false)


## Wave height above the resting surface at [param point], matching pond_water.gdshader's Gerstner waves.
## The waves move the surface sideways as well as up, so the parameter point whose displaced position
## lands on [param point] is found by a few fixed-point steps before its height is read.
func get_wave_offset(point: Vector3) -> float:
	var local: Vector3 = water_mesh.to_local(point)
	var xz: Vector2 = Vector2(local.x, local.z)
	var parameter: Vector2 = xz
	for i: int in 3:
		var displacement: Vector3 = get_wave_displacement(parameter)
		parameter = xz - Vector2(displacement.x, displacement.z)
	return get_wave_displacement(parameter).y


## Where the wave surface carries the water that rests at mesh-local [param xz]: sideways toward the
## nearest crest and up, summed over the shader's wave table and damped toward the pond edge.
func get_wave_displacement(xz: Vector2) -> Vector3:
	# Reading the shader globals back is editor-only, so the wind comes from WeatherFX itself
	var wind: Vector3 = weather.wind_direction if weather else Vector3.RIGHT
	var wind_dir: Vector2 = Vector2(wind.x, wind.z)
	wind_dir = wind_dir.normalized() if wind_dir.length() >= 0.001 else Vector2.RIGHT
	var wind_speed: float = maxf(0.1, weather.current_wind_strength if weather else 0.0)
	var tempo: float = _wave_parameter("wave_speed", 1.0) * (1.0 + wind_speed * 0.15)
	var amplitude: float = _wave_parameter("wave_amplitude", 0.04) * (0.6 + clampf(wind_speed * 0.1, 0.0, 2.0))
	var frequency: float = _wave_parameter("wave_frequency", 3.5)
	var steepness: float = _wave_parameter("wave_steepness", 0.85)
	var time: float = fmod(Time.get_ticks_msec() / 1000.0, WAVE_TIME_ROLLOVER)
	var displacement: Vector3 = Vector3.ZERO
	for wave: Vector3 in WAVES:
		var direction: Vector2 = wind_dir.rotated(wave.x)
		var k: float = frequency * wave.y
		var a: float = amplitude * wave.z
		var q: float = steepness / (k * a * WAVES.size() + 0.0001)
		var phase: float = k * direction.dot(xz) - sqrt(WAVE_GRAVITY * k) * tempo * time
		displacement += Vector3(q * a * direction.x * cos(phase), a * sin(phase), q * a * direction.y * cos(phase))
	# Waves fade toward the edges so the water stays sealed in the pond
	var size: Vector2 = (water_mesh.mesh as QuadMesh).size
	var edge_mask: float = smoothstep(0.0, 0.35, clampf(1.0 - Vector2(xz.x / size.x, xz.y / size.y).length() * 2.0, 0.0, 1.0))
	return displacement * edge_mask


## A wave uniform of the water material, or the shader's default when the material leaves it unset.
func _wave_parameter(name: String, default: float) -> float:
	var value: Variant = _material.get_shader_parameter(name)
	return value if value != null else default


## World height of the wave surface at [param point].
func get_surface_height(point: Vector3) -> float:
	return water_mesh.global_position.y + get_wave_offset(point)


func _physics_process(_delta: float) -> void:
	for body: RigidBody3D in bodies:
		var probes: Array = bodies[body]
		var own_depth: Variant = body.get("probe_depth")
		var depth_scale: float = own_depth if own_depth != null else probe_depth
		var submersion: float = 0.0
		for probe: Node3D in probes:
			var ratio: float = clampf((get_surface_height(probe.global_position) - probe.global_position.y) / depth_scale, 0.0, 1.0)
			submersion += ratio / probes.size()
			body.apply_force(-body.get_gravity() * body.mass * buoyancy * ratio / probes.size(), probe.global_position - body.global_position)
		body.apply_central_force(-body.linear_velocity * drag * submersion * body.mass)
		body.apply_torque(-body.angular_velocity * angular_drag * submersion * body.mass)


## Wired to body_entered in the scene.
func _on_body_entered(body: Node3D) -> void:
	# Anything burning goes out in the water (the torch, say) before it starts floating
	if body.has_method(&"extinguish"):
		body.call(&"extinguish")
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


func is_raining() -> bool:
	return WeatherFX.get_precipitation_strength() > 0.0


## Weighted pick among the fish available at the current hour, weather and [param lure] (null for a bare hook, which
## junk takes and real fish mostly pass by, see [method Fish.bite_weight]); null when nothing bites. A test hands
## in [param rng] to make the roll repeatable.
func pick_fish(lure: Item = null, rng: RandomNumberGenerator = null) -> Fish:
	var hour: int = clock.get_hour() if clock else 12
	var raining: bool = is_raining()
	var biome: int = biome_zone.biome if biome_zone else -1
	var available: Array[Fish] = fish.filter(func(candidate: Fish) -> bool: return candidate.is_available(hour, raining, lure, biome))
	if available.is_empty():
		return null
	var total: float = 0.0
	for candidate: Fish in available:
		total += candidate.bite_weight(lure)
	var roll: float = (rng.randf() if rng else randf()) * total
	for candidate: Fish in available:
		roll -= candidate.bite_weight(lure)
		if roll <= 0.0:
			return candidate
	return available.back()

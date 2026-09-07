class_name WeatherClouds
extends Node
## Drives the sky's clouds from [WeatherFX], in two layers. The Binbun sky scrolls two layers of noise cloud, and this
## sets its [code]cloud_density[/code], [code]cloud_color[/code] and [code]wind_speed[/code] for the weather and the
## wind; a sky shader runs on every renderer, the web export included, which is what makes it the layer that works
## everywhere. On Forward+ with the Vulkan or Metal driver only, the SunshineClouds2 volumetric clouds sit over it: this loads the [SunshineCloudsGD]
## effect at runtime, puts it in a [Compositor] on the [WorldEnvironment] and starts the [SunshineCloudsDriverGD], the
## way the driver's own Generate Clouds Resource button does; on any other renderer the driver is freed and nothing is
## created, so Compatibility and the web export never touch the compute shaders. Every value eases between targets so
## a change rolls in, and the volumetric coverage and wind ride the same easing as the sky's density and scroll. The
## sky material is copied first, so the asset stays as is. It only processes while the sky is on its way somewhere:
## once every value is within [constant SETTLED] of its target it snaps there, writes once and stops until the next
## change. Purely local: nothing here is replicated.

const SETTLED: float = 0.005 ## How close every channel must be to its target for the easing to stop.
const FORWARD_PLUS: String = "forward_plus" ## The only renderer with the compositor the volumetric clouds need.
const CLOUD_DRIVERS: PackedStringArray = ["vulkan", "metal"] ## Drivers the clouds' compute pipelines build on; on D3D12 (Godot 4.8.dev4) pipeline creation fails and the device is lost, so the clouds stay off there.

@export var weather: WeatherFX
@export var world_environment: WorldEnvironment ## Whose Environment holds the Binbun sky and, on Forward+, the clouds compositor.
@export var transition_seconds: float = 8.0 ## How long a change in the weather takes to roll across the sky.
@export_group("Clear", "clear_")
@export_range(0.0, 5.0) var clear_density: float = 0.5
@export var clear_color: Color = Color(0.92, 0.92, 0.94)
@export_group("Cloudy", "cloudy_")
@export_range(0.0, 5.0) var cloudy_density: float = 1.4
@export var cloudy_color: Color = Color(0.66, 0.68, 0.72)
@export_group("Rain", "rain_")
@export_range(0.0, 5.0) var rain_density: float = 2.0 ## Rain, snow and storms.
@export var rain_color: Color = Color(0.45, 0.47, 0.52)
@export_group("Wind", "wind_")
@export var wind_scroll_scale: float = 0.01 ## Sky scroll per unit of the weather's wind strength.
@export var wind_min_scroll: float = 0.03 ## The clouds never sit dead still.
@export_group("Volumetric", "volumetric_")
@export var volumetric_clouds: SunshineCloudsDriverGD ## The SunshineClouds2 driver; kept on Forward+, freed anywhere else.
@export_file("*.tres") var volumetric_resource: String = "res://resources/clouds/world_clouds.tres" ## The [SunshineCloudsGD] effect, loaded only on Forward+.
@export_range(0.0, 1.0) var volumetric_coverage_min: float = 0.35 ## Cloud coverage at a sky density of zero.
@export_range(0.0, 1.0) var volumetric_coverage_max: float = 0.95 ## Cloud coverage at [member rain_density].
@export var volumetric_wind_scale: float = 20.0 ## Volumetric wind per unit of sky scroll; the driver scales it by its structure speeds.

var target_density: float = 0.5
var target_color: Color = Color(0.92, 0.92, 0.94)
var target_wind: Vector2 = Vector2(0.05, 0.05)
var _density: float = 0.5
var _color: Color = Color(0.92, 0.92, 0.94)
var _wind: Vector2 = Vector2(0.05, 0.05)
var _material: ShaderMaterial ## This node's own copy of the sky material, the one the values are written to.


func _ready() -> void:
	_setup_volumetric_clouds()
	var material: ShaderMaterial = sky_material()
	if material != null:
		# Work on a copy: the sky and its material are shared assets on disk
		var sky: Sky = world_environment.environment.sky.duplicate()
		_material = material.duplicate()
		sky.sky_material = _material
		world_environment.environment.sky = sky
	if _material == null and volumetric_clouds == null:
		set_process(false)
		return
	if weather:
		weather.weather_changed.connect(_on_weather_changed)
		weather.wind_changed.connect(_on_wind_changed)
		apply_weather(weather.active_weather)
		_on_wind_changed(weather.current_wind_strength, weather.wind_direction)
	snap()


func _process(delta: float) -> void:
	if _is_settled():
		snap()
		return
	var weight: float = 1.0 if transition_seconds <= 0.0 else clampf(delta / transition_seconds, 0.0, 1.0)
	_density = lerpf(_density, target_density, weight)
	_color = _color.lerp(target_color, weight)
	_wind = _wind.lerp(target_wind, weight)
	_write()


## The Binbun sky's material, or null when the environment's sky is something else.
func sky_material() -> ShaderMaterial:
	if world_environment == null or world_environment.environment == null or world_environment.environment.sky == null:
		return null
	var material: ShaderMaterial = world_environment.environment.sky.sky_material as ShaderMaterial
	if material == null or material.get_shader_parameter(&"cloud_density") == null:
		return null
	return material


func density_for(weather_type: ClimateData.WeatherType) -> float:
	match weather_type:
		ClimateData.WeatherType.BLUE_SKY:
			return clear_density
		ClimateData.WeatherType.CLOUDY:
			return cloudy_density
		_:
			return rain_density


func color_for(weather_type: ClimateData.WeatherType) -> Color:
	match weather_type:
		ClimateData.WeatherType.BLUE_SKY:
			return clear_color
		ClimateData.WeatherType.CLOUDY:
			return cloudy_color
		_:
			return rain_color


## The volumetric clouds' coverage for a sky [param density]: [member volumetric_coverage_min] at none, up to
## [member volumetric_coverage_max] at [member rain_density].
func coverage_for(density: float) -> float:
	return lerpf(volumetric_coverage_min, volumetric_coverage_max, clampf(density / maxf(rain_density, 0.001), 0.0, 1.0))


## Sets where the sky is heading for [param weather_type]; [method _process] eases it there.
func apply_weather(weather_type: ClimateData.WeatherType) -> void:
	target_density = density_for(weather_type)
	target_color = color_for(weather_type)
	_start_easing()


## Jumps the sky to its targets at once and stops easing.
func snap() -> void:
	_density = target_density
	_color = target_color
	_wind = target_wind
	_write()
	set_process(false)


## The renderer in use; overridden by tests to cover both branches headless.
func _rendering_method() -> String:
	return RenderingServer.get_current_rendering_method()


## The rendering driver in use (vulkan, d3d12, metal, opengl3); overridden by tests.
func _rendering_driver() -> String:
	return RenderingServer.get_current_rendering_driver_name()


## Forward+ on a [constant CLOUD_DRIVERS] driver only: loads the [SunshineCloudsGD] effect, puts it in a [Compositor] on the [WorldEnvironment] and starts
## the driver, mirroring the driver's own build. Anywhere else the driver is freed and nothing is created.
func _setup_volumetric_clouds() -> void:
	if volumetric_clouds == null:
		return
	var effect: SunshineCloudsGD = null
	if _rendering_method() == FORWARD_PLUS and _rendering_driver() in CLOUD_DRIVERS and world_environment != null:
		effect = load(volumetric_resource) as SunshineCloudsGD
	if effect == null:
		volumetric_clouds.queue_free()
		volumetric_clouds = null
		return
	if volumetric_clouds.ambience_sample_environment == null:
		volumetric_clouds.ambience_sample_environment = world_environment.environment
	volumetric_clouds.clouds_resource = effect # The driver's setter puts it on the first WorldEnvironment it finds
	if world_environment.compositor == null:
		world_environment.compositor = Compositor.new()
	var effects: Array[CompositorEffect] = world_environment.compositor.compositor_effects
	if not effects.has(effect):
		effects.append(effect)
		world_environment.compositor.compositor_effects = effects
	volumetric_clouds.update_continuously = true


func _start_easing() -> void:
	set_process(_material != null or volumetric_clouds != null)


func _is_settled() -> bool:
	var gap: Color = target_color - _color
	return absf(target_density - _density) < SETTLED \
		and Vector3(gap.r, gap.g, gap.b).length() < SETTLED \
		and (target_wind - _wind).length() < SETTLED


func _write() -> void:
	if _material != null:
		_material.set_shader_parameter(&"cloud_density", _density)
		_material.set_shader_parameter(&"cloud_color", _color)
		_material.set_shader_parameter(&"wind_speed", _wind)
	if is_instance_valid(volumetric_clouds) and volumetric_clouds.clouds_resource != null:
		volumetric_clouds.clouds_resource.clouds_coverage = coverage_for(_density) # Read by the compute shader every frame
		volumetric_clouds.wind_direction = Vector3(_wind.x, 0.0, _wind.y) * volumetric_wind_scale


func _on_weather_changed(new_weather: ClimateData.WeatherType, _old_weather: ClimateData.WeatherType) -> void:
	apply_weather(new_weather)


## Scrolls the clouds down the wind, faster in a stronger one.
func _on_wind_changed(strength: float, direction: Vector3) -> void:
	var heading: Vector2 = Vector2(direction.x, direction.z)
	if heading.length() < 0.001:
		heading = target_wind.normalized() if target_wind.length() > 0.001 else Vector2.ONE.normalized()
	target_wind = heading.normalized() * maxf(wind_min_scroll, strength * wind_scroll_scale)
	_start_easing()

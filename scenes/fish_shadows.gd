class_name FishShadows
extends Node3D
## Dark shapes wandering just under a water's surface. The fishing rod reads them for bite odds, draws the
## nearest one to the float, bumps it on nibbles and sends it diving on the bite. Wandering runs on Tweens.

@export var water: Buoyancy ## The water the shadows swim in; its quad bounds them.
@export var count: int = 4
@export var speed: float = 0.7 ## Metres per second while wandering.
@export var depth: float = -0.02 ## Height relative to the resting surface; just above it so the dark shape reads through the water shader.

const SHADOW_SCALE: Vector3 = Vector3(0.6, 0.08, 0.3)

var shadows: Array[MeshInstance3D] = []
var interested: MeshInstance3D ## The shadow drawn to the float, if any.
var _tweens: Dictionary[MeshInstance3D, Tween] = {}


func _ready() -> void:
	if water == null:
		return
	for i: int in count:
		_spawn_shadow()


## Distance from [param point] to the closest visible shadow, or INF with none around.
func nearest_distance(point: Vector3) -> float:
	var best: float = INF
	for shadow: MeshInstance3D in shadows:
		if shadow.visible:
			best = minf(best, shadow.global_position.distance_to(point))
	return best


## The nearest shadow takes an interest in the float: it swims up and hovers just beside it.
func attract(point: Vector3) -> void:
	release()
	interested = _nearest(point)
	if interested == null:
		return
	_tweens[interested].kill()
	var beside: Vector3 = Vector3(point.x + 0.45, _surface_y(), point.z + 0.25)
	if interested.global_position.distance_to(beside) > 0.01:
		interested.look_at(beside)
	var tween: Tween = create_tween()
	# A fish darts at a splash far faster than it cruises
	tween.tween_property(interested, "global_position", beside, interested.global_position.distance_to(beside) / (speed * 4.0))
	_tweens[interested] = tween


## The interested shadow darts in to bump the float and backs off.
func nibble(point: Vector3) -> void:
	if interested == null or not interested.visible:
		return
	_tweens[interested].kill()
	var back: Vector3 = interested.global_position
	var tween: Tween = create_tween()
	tween.tween_property(interested, "global_position", Vector3(point.x, back.y, point.z), 0.15)
	tween.tween_property(interested, "global_position", back, 0.35).set_trans(Tween.TRANS_BACK)
	_tweens[interested] = tween


## The interested shadow lunges under the float and vanishes below; it comes back elsewhere later.
func dive(point: Vector3) -> void:
	if interested == null:
		return
	var shadow: MeshInstance3D = interested
	interested = null
	_tweens[shadow].kill()
	var tween: Tween = create_tween()
	tween.tween_property(shadow, "global_position", Vector3(point.x, shadow.global_position.y, point.z), 0.12)
	tween.tween_property(shadow, "scale", SHADOW_SCALE * 0.1, 0.25)
	tween.tween_callback(shadow.hide)
	tween.tween_interval(8.0)
	tween.tween_callback(_respawn.bind(shadow))
	_tweens[shadow] = tween


## Lets the interested shadow wander again.
func release() -> void:
	if interested and interested.visible:
		_wander(interested)
	interested = null


## Every shadow darts off when a fish escapes.
func scatter() -> void:
	for shadow: MeshInstance3D in shadows:
		if shadow.visible:
			_wander(shadow, 4.0)


func _spawn_shadow() -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.05, 0.08, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	shadow.mesh = mesh
	shadow.scale = SHADOW_SCALE
	add_child(shadow)
	shadow.global_position = _random_point()
	shadows.append(shadow)
	_wander(shadow)


func _random_point() -> Vector3:
	var half: Vector2 = (water.water_mesh.mesh as QuadMesh).size * 0.4
	var point: Vector3 = water.water_mesh.to_global(Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y)))
	point.y = _surface_y()
	return point


func _surface_y() -> float:
	return water.water_mesh.global_position.y - depth


func _nearest(point: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for shadow: MeshInstance3D in shadows:
		if shadow.visible and (best == null or shadow.global_position.distance_to(point) < best.global_position.distance_to(point)):
			best = shadow
	return best


## Swims to a random point at [param dash] times the wander speed, then picks another.
func _wander(shadow: MeshInstance3D, dash: float = 1.0) -> void:
	if _tweens.has(shadow):
		_tweens[shadow].kill()
	var target: Vector3 = _random_point()
	if shadow.global_position.distance_to(target) > 0.01:
		shadow.look_at(target)
	var tween: Tween = create_tween()
	tween.tween_property(shadow, "global_position", target, shadow.global_position.distance_to(target) / (speed * dash))
	tween.finished.connect(_wander.bind(shadow))
	_tweens[shadow] = tween


func _respawn(shadow: MeshInstance3D) -> void:
	shadow.scale = SHADOW_SCALE
	shadow.global_position = _random_point()
	shadow.show()
	_wander(shadow)

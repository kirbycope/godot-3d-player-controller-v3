class_name FishShadows
extends Node3D
## Dark shapes wandering just under a water's surface. The fishing rod reads them for bite odds, draws the
## nearest one to the float, bumps it on nibbles and sends it diving on the bite. A Player in the water within
## [member scare_distance] of one sends it fleeing: it darts away, sinks out of sight and comes back elsewhere
## later. Wandering runs on Tweens; the scare is an Area3D on each shadow.

signal scared(shadow: MeshInstance3D) ## A swimmer got too close.
signal shot(shadow: MeshInstance3D) ## A projectile ruined the fish under a shadow.

@export var water: Buoyancy ## The water the shadows swim in; its quad bounds them.
@export var chum: Item ## What a shot fish turns into in the shooter's bag; empty means it just sinks.
@export var count: int = 4
@export var speed: float = 0.7 ## Metres per second while wandering.
@export var depth: float = -0.02 ## Height relative to the resting surface; just above it so the dark shape reads through the water shader.
@export var scare_distance: float = 1.5 ## A Player this close in the water scares the shadow off.
@export var hide_seconds: float = 8.0 ## How long a dived or scared shadow stays gone before it shows up elsewhere.

const SHADOW_SCALE: Vector3 = Vector3(0.6, 0.08, 0.3)

var shadows: Array[MeshInstance3D] = []
var interested: MeshInstance3D ## The shadow drawn to the float, if any.
var _tweens: Dictionary[MeshInstance3D, Tween] = {}


func _ready() -> void:
	if water == null:
		return
	for i: int in count:
		_spawn_shadow()


## A round through a shadow ruins the fish under it: the shadow sinks away and the shooter pockets [member chum].
func register_projectile_hit(projectile: Node3D, point: Vector3, _normal: Vector3) -> void:
	var shadow: MeshInstance3D = _nearest(point)
	if shadow == null or shadow.global_position.distance_to(point) > scare_distance + 0.5:
		return
	if shadow == interested:
		interested = null
	_tweens[shadow].kill()
	var tween: Tween = create_tween()
	tween.tween_property(shadow, "scale", SHADOW_SCALE * 0.1, 0.3)
	tween.tween_callback(shadow.hide)
	tween.tween_interval(hide_seconds)
	tween.tween_callback(_respawn.bind(shadow))
	_tweens[shadow] = tween
	shot.emit(shadow)
	var shooter: Player = projectile.get("shooter") as Player
	if chum and shooter and shooter.inventory:
		shooter.inventory.add_item(chum)
		var card: FishCard = shooter.controls.get_node_or_null(^"FishCard") as FishCard
		if card:
			card.show_item(chum, "Ruined. It will do for bait.")


## Distance from [param point] to the closest visible shadow, or INF with none around.
func nearest_distance(point: Vector3) -> float:
	var best: float = INF
	for shadow: MeshInstance3D in shadows:
		if shadow.visible:
			best = minf(best, shadow.global_position.distance_to(point))
	return best


## The nearest shadow within [param range] takes an interest in the float: it swims up and hovers just beside it.
## A shadow further off stays where it is, so the bite comes from a fish you never saw.
func attract(point: Vector3, range: float = INF) -> void:
	release()
	interested = _nearest(point)
	if interested == null:
		return
	if interested.global_position.distance_to(point) > range:
		interested = null
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
	tween.tween_interval(hide_seconds)
	tween.tween_callback(_respawn.bind(shadow))
	_tweens[shadow] = tween


## Wired to each shadow's ScareArea: a Player in the water sends it fleeing.
func _on_scare_area_body_entered(body: Node3D, shadow: MeshInstance3D) -> void:
	if body is Player and shadow.visible:
		flee(shadow, body.global_position)


## The shadow darts straight away from [param from], sinks out of sight and comes back elsewhere later.
func flee(shadow: MeshInstance3D, from: Vector3) -> void:
	if interested == shadow:
		interested = null
	_tweens[shadow].kill()
	var away: Vector3 = (shadow.global_position - from).slide(Vector3.UP)
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	var target: Vector3 = _clamp_to_water(shadow.global_position + away.normalized() * 3.0)
	if shadow.global_position.distance_to(target) > 0.01:
		shadow.look_at(target)
	var tween: Tween = create_tween()
	tween.tween_property(shadow, "global_position", target, shadow.global_position.distance_to(target) / (speed * 5.0))
	tween.parallel().tween_property(shadow, "scale", SHADOW_SCALE * 0.1, 0.4).set_delay(0.2)
	tween.tween_callback(shadow.hide)
	tween.tween_interval(hide_seconds)
	tween.tween_callback(_respawn.bind(shadow))
	_tweens[shadow] = tween
	scared.emit(shadow)


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
	# The scare volume: a sphere around the shadow, counter-scaled so the flat shadow's scale does not squash it
	var area: Area3D = Area3D.new()
	area.name = "ScareArea"
	area.collision_layer = 1 # On the projectile layer, so a bullet or arrow can find the fish under the shadow
	area.monitorable = true
	area.scale = Vector3.ONE / SHADOW_SCALE
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = scare_distance
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_scare_area_body_entered.bind(shadow))
	shadow.add_child(area)
	add_child(shadow)
	shadow.global_position = _random_point()
	shadows.append(shadow)
	_wander(shadow)


func _random_point() -> Vector3:
	var half: Vector2 = (water.water_mesh.mesh as QuadMesh).size * 0.4
	var point: Vector3 = water.water_mesh.to_global(Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y)))
	point.y = _surface_y()
	return point


## Keeps [param point] inside the water quad, at the surface.
func _clamp_to_water(point: Vector3) -> Vector3:
	var half: Vector2 = (water.water_mesh.mesh as QuadMesh).size * 0.4
	var local: Vector3 = water.water_mesh.to_local(point)
	var clamped: Vector3 = water.water_mesh.to_global(Vector3(clampf(local.x, -half.x, half.x), 0.0, clampf(local.z, -half.y, half.y)))
	clamped.y = _surface_y()
	return clamped


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

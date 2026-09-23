class_name FishShadows
extends Node3D
## Dark shapes wandering just under a water's surface, [member count] instances of [member shadow_scene]. The fishing
## rod reads them for bite odds, draws the nearest one to the float, bumps it on nibbles and sends it diving on the
## bite; the rod sends those moves to every peer ([method attract], [method nibble], [method dive], [method scatter]
## and [method release] are RPCs), and each peer plays them on its own shadows at the float. A Player in the water
## inside a shadow's ScareArea sends it fleeing: it darts away, sinks out of sight and comes back elsewhere later.
## A round or an arrow through its ShootArea ruins the fish: the server, which lands the hit, sinks it on every peer
## and the shooter's own peer pockets [member chum]. Wandering runs on Tweens.

signal scared(shadow: MeshInstance3D) ## A swimmer got too close.
signal shot(shadow: MeshInstance3D) ## A projectile ruined the fish under a shadow.

@export var water: Buoyancy ## The water the shadows swim in; its quad bounds them.
@export var chum: Item ## What a shot fish turns into in the shooter's bag; empty means it just sinks.
@export var shadow_scene: PackedScene = preload("res://scenes/fish_shadow.tscn") ## One shadow: its mesh and material, the ScareArea (how close a swimmer may come) and the ShootArea (the fish a round can hit).
@export var count: int = 4
@export var speed: float = 0.7 ## Metres per second while wandering.
@export var depth: float = -0.02 ## Height relative to the resting surface; just above it so the dark shape reads through the water shader.
@export var hide_seconds: float = 8.0 ## How long a dived or scared shadow stays gone before it shows up elsewhere.

const SHADOW_SCALE: Vector3 = Vector3(0.6, 0.08, 0.3) ## The scale fish_shadow.tscn is saved at, which a sunk shadow grows back to.
const SHOT_REACH: float = 2.0 ## A shadow this close to a shot sinks with it; generous, since every peer's shadows wander on their own.

var shadows: Array[MeshInstance3D] = []
var interested: MeshInstance3D ## The shadow drawn to the float, if any.
var _tweens: Dictionary[MeshInstance3D, Tween] = {}


func _ready() -> void:
	if water == null:
		return
	for i: int in count:
		_spawn_shadow()


## A round through a shadow's ShootArea ruins the fish under it. Only the server (the shadows' authority, which
## lands the rounds) counts the hit, and sends it to every peer through [method _shoot].
func register_projectile_hit(projectile: Node3D, point: Vector3, _normal: Vector3) -> void:
	var shadow: MeshInstance3D = _nearest(point)
	if not is_multiplayer_authority() or shadow == null or shadow.global_position.distance_to(point) > SHOT_REACH:
		return
	var shooter: Node = projectile.get("shooter") as Node
	_shoot.rpc(point, get_path_to(shooter) if is_instance_valid(shooter) else NodePath())


## Every peer sinks its shadow nearest [param point], and the peer whose Player fired (at [param shooter_path],
## relative to this node) pockets [member chum]: a peer's copy of somebody else's Player never gets it.
@rpc("authority", "call_local", "reliable")
func _shoot(point: Vector3, shooter_path: NodePath) -> void:
	var shadow: MeshInstance3D = _nearest(point)
	if shadow and shadow.global_position.distance_to(point) <= SHOT_REACH:
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
	var shooter: Player = get_node_or_null(shooter_path) as Player if not shooter_path.is_empty() else null
	if chum and shooter and shooter.is_multiplayer_authority() and shooter.inventory:
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
@rpc("any_peer", "call_local", "reliable")
func attract(point: Vector3, reach: float = INF) -> void:
	release()
	interested = _nearest(point)
	if interested == null:
		return
	if interested.global_position.distance_to(point) > reach:
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
@rpc("any_peer", "call_local", "reliable")
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
@rpc("any_peer", "call_local", "reliable")
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


## Wired to each shadow's ScareArea as it is instanced: a Player in the water sends it fleeing.
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
@rpc("any_peer", "call_local", "reliable")
func release() -> void:
	if interested and interested.visible:
		_wander(interested)
	interested = null


## Every shadow darts off when a fish escapes.
@rpc("any_peer", "call_local", "reliable")
func scatter() -> void:
	for shadow: MeshInstance3D in shadows:
		if shadow.visible:
			_wander(shadow, 4.0)


## Test seam: parks [param shadow] at [param point] and sends the rest to the far side of the water,
## leaving none of them wandering, so a test can act on a shadow in a known place.
##
## Shadows spawn at [method _random_point] and wander from there, so a test that swims up to
## [code]shadows[0][/code] is really testing wherever the dice put it. Two can land inside each
## other's ScareArea, and then the neighbour's area fires first and the test
## fails having scared a real fish, just not the expected one. Nothing here changes how shadows
## behave in the game; it only removes the randomness from under a test.
func park_shadows_for_test(shadow: MeshInstance3D, point: Vector3) -> void:
	for parked: MeshInstance3D in shadows:
		if _tweens.has(parked):
			_tweens[parked].kill()
	shadow.global_position = _clamp_to_water(point)
	var away: Vector3 = _furthest_water_point_from(shadow.global_position)
	for other: MeshInstance3D in shadows:
		if other != shadow:
			other.global_position = away


## The corner of the water quad furthest from [param point], where a shadow is out of the way.
func _furthest_water_point_from(point: Vector3) -> Vector3:
	var half: Vector2 = (water.water_mesh.mesh as QuadMesh).size * 0.4
	var furthest: Vector3 = point
	var distance: float = -1.0
	for x: float in [-half.x, half.x]:
		for z: float in [-half.y, half.y]:
			var corner: Vector3 = water.water_mesh.to_global(Vector3(x, 0.0, z))
			corner.y = _surface_y()
			if corner.distance_to(point) > distance:
				distance = corner.distance_to(point)
				furthest = corner
	return furthest


## Instances one [member shadow_scene] somewhere in the water and sets it wandering.
func _spawn_shadow() -> void:
	var shadow: MeshInstance3D = shadow_scene.instantiate() as MeshInstance3D
	add_child(shadow)
	shadow.get_node(^"ScareArea").body_entered.connect(_on_scare_area_body_entered.bind(shadow))
	shadow.visibility_changed.connect(_on_shadow_visibility_changed.bind(shadow))
	shadow.global_position = _random_point()
	shadows.append(shadow)
	_wander(shadow)


## Wired to each shadow's visibility_changed as it is instanced: a shadow that has dived, fled or sunk has no fish
## under it to shoot, so its ShootArea lets rounds through until it shows again.
func _on_shadow_visibility_changed(shadow: MeshInstance3D) -> void:
	(shadow.get_node(^"ShootArea/CollisionShape3D") as CollisionShape3D).set_deferred(&"disabled", not shadow.visible)


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

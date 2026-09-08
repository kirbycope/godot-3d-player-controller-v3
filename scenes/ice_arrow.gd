class_name IceArrow
extends Arrow
## A frost arrow: a cold mist sits on the shaft's `Tip` marker, drifting back along the shaft from the head, in
## flight, on the string and where it sticks. Landing over water it is spent on the
## spot and the surface there freezes into an [IceBlock]; on ground it sticks like any arrow. Only the arrow's
## authority freezes the water and is spent; the slab reaches every peer through the [ProjectileSpawner] (or is
## made locally without one), whose despawn then takes the other peers' copies of the arrow.

@onready var tip: Marker3D = $Tip ## The head end of the shaft, where the frost sits.
@onready var frost: GPUParticles3D = $Tip/Frost


## Wired to [signal Projectile.hit] in the scene, before the arrow decides whether to stick, so the copy can be
## spent instead. When it sticks, the arrow's origin snaps to the impact point, so the mist moves there from the
## tip that is now buried in the target. Over water the slab forms where the flight line broke the surface
## ([method surface_entry]), the spot the crosshair was on.
func _on_hit(_collider: Node, point: Vector3, _normal: Vector3) -> void:
	frost.global_position = global_position
	if not is_multiplayer_authority():
		return
	var at: Vector3 = surface_entry(point)
	if IceBlock.find_water(get_tree(), at) == null:
		return
	# Spent on the ice: the authority's copy frees itself instead of sticking; the copies on the other peers stick in
	# the pond floor out of sight until the spawner's despawn takes them, so none frees before that message arrives
	sticks_on_hit = false
	IceBlock.freeze_at(self, at)


## Where the arrow's flight line went into the water on its way down to [param point]. Water stops no projectile
## (a [Buoyancy] area has no hit handler), so an arrow shot into a pond flies on under the surface and lands on the
## pond floor or a wall, metres past the spot the crosshair was on; the slab belongs at the surface. [param point]
## itself when it is not under water or the arrow was not descending.
func surface_entry(point: Vector3) -> Vector3:
	var water: Buoyancy = IceBlock.find_water(get_tree(), point)
	var along: Vector3 = _flight_velocity.normalized()
	if water == null or along.y >= -0.001:
		return point
	var surface: float = water.get_surface_height(point)
	return point + along * ((surface - point.y) / along.y) if point.y < surface else point

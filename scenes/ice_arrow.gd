class_name IceArrow
extends Arrow
## A frost arrow: a cold mist rides its tip in flight and where it sticks. Landing over water it is spent on the
## spot and the surface there freezes into an [IceBlock]; on ground it sticks like any arrow. Only the arrow's
## authority freezes the water and is spent; the slab reaches every peer through the [ProjectileSpawner] (or is
## made locally without one), whose despawn then takes the other peers' copies of the arrow.

@onready var frost: GPUParticles3D = $Frost


## Wired to [signal Projectile.hit] in the scene, before the arrow decides whether to stick, so the copy can be
## spent instead. When it sticks, the arrow's origin snaps to the impact point, so the mist moves there from the
## tip that is now buried in the target.
func _on_hit(_collider: Node, point: Vector3, _normal: Vector3) -> void:
	frost.position = Vector3.ZERO
	if not is_multiplayer_authority() or IceBlock.find_water(get_tree(), point) == null:
		return
	# Spent on the ice: the authority's copy frees itself instead of sticking; the copies on the other peers stick in
	# the pond floor out of sight until the spawner's despawn takes them, so none frees before that message arrives
	sticks_on_hit = false
	IceBlock.freeze_at(self, point)

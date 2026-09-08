class_name IncendiaryRound
extends Projectile
## A rifle round with a faint ember trail that lights the grass where it lands, the way the fire arrow does: the
## round's authority decides, the [ProjectileSpawner] lights it on every peer, and rain still stops it.

@export var ignite_radius: float = 1.5 ## Metres around the impact the grass catches.
@export var burn_duration: float = 6.0 ## Seconds a lit grass field keeps spreading from the impact.


## Wired to [signal Projectile.hit] in the scene.
func _on_hit(_collider: Node, point: Vector3, _normal: Vector3) -> void:
	if is_multiplayer_authority():
		FireArrow.ignite_around(self, point, ignite_radius, burn_duration)

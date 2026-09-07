class_name FireArrow
extends Arrow
## An arrow with a burning head: a small flame (the weather_fx flame at an eighth of its size, its particles in local
## coordinates so they ride the arrow instead of trailing behind it) sits on the shaft's `Tip` marker, rising back
## along the shaft from the head, in flight and on the string, and burns on where the arrow sticks until it frees
## itself. Where it lands it lights the grass around the impact the way a
## torch or a fire spell does ([method Ability.ignite_grass]: GrassField.ignite_at without force, so rain still
## stops it). Only the arrow's authority decides that, and the ignition reaches every peer through the
## [ProjectileSpawner]; without one it lights the local world.

@export var ignite_radius: float = 1.5 ## Metres around the impact the grass catches.
@export var burn_duration: float = 6.0 ## Seconds a lit grass field keeps spreading from the impact.

@onready var tip: Marker3D = $Tip ## The head end of the shaft, where the flame sits.
@onready var flame: Node3D = $Tip/Flame


## Wired to [signal Projectile.hit] in the scene. The arrow's origin snaps to the impact point when it sticks, so
## the flame moves from the tip (buried in the target) to the origin and keeps burning at the surface.
func _on_hit(_collider: Node, point: Vector3, _normal: Vector3) -> void:
	flame.global_position = global_position
	if is_multiplayer_authority():
		ignite_around(self, point, ignite_radius, burn_duration)


## Lights the grass within [param radius] of [param at] on every peer of [param from]'s session, or locally without a spawner.
static func ignite_around(from: Node, at: Vector3, radius: float, duration: float) -> void:
	var spawner: ProjectileSpawner = ProjectileSpawner.find_for(from)
	if spawner:
		spawner.ignite(at, radius, duration)
	else:
		Ability.ignite_grass(from.get_tree(), at, radius, duration)

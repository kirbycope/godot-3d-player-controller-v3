class_name MeleeAbility
extends DamageAbility
## A weapon swing: the moment it lands it hurts everything with a `take_hit` within [member reach] in the arc ahead
## of the caster, no lock-on needed, and applies the [DamageAbility] slow and ticks to each. The casting VFX (a sword
## and its trail) is turned to face the way the caster aims, so the swing crosses what it hits.

const SWING_HEIGHT: float = 1.25 ## Metres above the caster's feet the swing VFX plays; the swing dips below its origin.

@export var reach: float = 2.5 ## Metres from the caster a body must be within.
@export_range(0.0, 360.0) var arc_degrees: float = 150.0 ## Width of the swing, centred on where the caster aims.

var hit_anything: bool = false ## Whether the last [method impact] found a victim; a whiff plays no impact phase.


func _init() -> void:
	target_mode = Target.SELF


## A swing can always start; it lands whether or not anything is there to hit.
func can_cast(_caster: Node3D) -> bool:
	return true


func activate(_caster: Node3D) -> bool:
	return true


## Hits every body in the arc; the impact position is the caster, so nothing here uses [param _target].
func impact(caster: Node3D, _target: Node3D) -> void:
	var victims: Array[Node3D] = find_victims(caster)
	hit_anything = not victims.is_empty()
	for victim: Node3D in victims:
		super.impact(caster, victim)


## Every node with `take_hit` whose collider lies within [member reach] and [member arc_degrees] of the caster,
## the caster itself aside. Only bodies are asked for: zones, water, grass and pickups are areas, and they would
## fill the query before an enemy in reach was returned.
func find_victims(caster: Node3D) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var world: World3D = caster.get_world_3d()
	if world == null:
		return found
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = reach
	query.shape = sphere
	query.transform = Transform3D(Basis(), caster.global_position + Vector3.UP * SWING_HEIGHT)
	query.collide_with_areas = false
	if caster is CollisionObject3D:
		query.exclude = [(caster as CollisionObject3D).get_rid()]
	var forward: Vector3 = forward_of(caster)
	for hit: Dictionary in world.direct_space_state.intersect_shape(query, 64):
		var node: Node = hit["collider"] as Node
		while node and not node.has_method("take_hit"):
			node = node.get_parent()
		if node == null or node == caster or found.has(node):
			continue
		var towards: Vector3 = (node as Node3D).global_position - caster.global_position
		towards.y = 0.0
		if towards.length() > 0.01 and rad_to_deg(forward.angle_to(towards.normalized())) > arc_degrees * 0.5:
			continue
		found.append(node as Node3D)
	return found


## Where the caster aims, flat: a Player's crosshair, an NPC's facing.
static func forward_of(caster: Node3D) -> Vector3:
	var forward: Vector3 = -caster.global_basis.z
	if caster is Player and is_instance_valid((caster as Player).projectile_raycast):
		forward = -(caster as Player).projectile_raycast.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else -caster.global_basis.z


## The swing VFX plays at chest height, turned to face where the caster aims, keeping the scale its scene authored.
func spawn_phase(phase: Phase, at: Vector3, fx_root: Node3D, audio: AudioStreamPlayer3D, target: Node3D, destination: Vector3) -> Node3D:
	var node: Node3D = super.spawn_phase(phase, at, fx_root, audio, target, destination)
	if node == null or phase != Phase.CASTING:
		return node
	var caster: Node3D = fx_root.get_parent() as Node3D # The Player's AbilityFx sits right under it
	if caster:
		node.global_position = at + Vector3.UP * SWING_HEIGHT
		node.global_basis = Basis.looking_at(forward_of(caster), Vector3.UP).scaled(node.scale)
	return node

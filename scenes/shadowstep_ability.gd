class_name ShadowstepAbility
extends Ability
## Shadowstep: the caster appears [member behind_distance] behind its target's back, facing it, rogue style.
## Needs a target (locked on or under the crosshair) within [member cast_range]; refused without one.

@export var behind_distance: float = 1.5 ## Metres behind the target the caster lands.


func _init() -> void:
	target_mode = Target.FOCUS


func can_cast(caster: Node3D) -> bool:
	var target: Node3D = get_target(caster)
	return is_instance_valid(target) and target != caster and caster.global_position.distance_to(target.global_position) <= cast_range


func activate(caster: Node3D) -> bool:
	if not can_cast(caster):
		return false
	var target: Node3D = get_target(caster)
	var up: Vector3 = get_up(caster)
	var destination: Vector3 = get_destination(caster, target)
	var to_target: Vector3 = (target.global_position - destination).slide(up)
	if to_target.length_squared() < 0.001:
		to_target = get_forward(target)
	if caster is Player:
		# The Player's orientation looks down +Z, so it faces the target with its back to where it came from
		(caster as Player).warp_to(Transform3D(Basis.looking_at(-to_target.normalized(), up), destination))
	else:
		caster.global_transform = Transform3D(Basis.looking_at(to_target.normalized(), up), destination)
	return true


## Where the caster lands: behind the target, on the target's level.
func get_destination(caster: Node3D, target: Node3D) -> Vector3:
	var back: Vector3 = (-get_forward(target)).slide(get_up(caster))
	if back.length_squared() < 0.001:
		back = (target.global_position - caster.global_position).slide(get_up(caster))
	return target.global_position + back.normalized() * behind_distance


## The puff plays where the caster appears, not on the target.
func get_impact_position(caster: Node3D) -> Vector3:
	var target: Node3D = get_target(caster)
	return get_destination(caster, target) if is_instance_valid(target) else caster.global_position


## A Player's model looks down its orientation's +Z; everything else looks down -Z as [method Node3D.look_at] leaves it.
static func get_forward(node: Node3D) -> Vector3:
	if node is Player:
		return (node as Player).orientation.basis.z.normalized()
	return -node.global_basis.z.normalized()


static func get_up(node: Node3D) -> Vector3:
	return (node as CharacterBody3D).up_direction if node is CharacterBody3D else Vector3.UP

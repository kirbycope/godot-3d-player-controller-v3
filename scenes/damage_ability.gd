class_name DamageAbility
extends Ability
## Hurts whatever it lands on: anything with a `take_hit(damage, from)` method, Players and enemies alike.

@export var damage: float = 20.0


func _init() -> void:
	target_mode = Target.FOCUS


## Needs something to aim at.
func can_cast(caster: Node3D) -> bool:
	return is_instance_valid(get_target(caster))


func activate(caster: Node3D) -> bool:
	return can_cast(caster)


func impact(caster: Node3D, target: Node3D) -> void:
	if is_instance_valid(target) and target.has_method("take_hit"):
		target.call("take_hit", damage, caster.global_position)

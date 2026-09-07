class_name ChainLightningAbility
extends DamageAbility
## Strikes the target, then jumps from it to the nearest enemy within [member jump_range] that has not been
## hit yet, up to [member max_jumps] times, the damage shrinking by [member jump_damage_scale] each jump. The
## jumps look for Focusable bodies that can take a hit and are not the caster or another Player; each one is
## drawn as an arc by the weather's [LightningFX].

@export var max_jumps: int = 3
@export var jump_range: float = 8.0 ## Metres a jump can reach from the last body hit.
@export var jump_damage_scale: float = 0.7 ## The damage of each jump as a share of the previous one.


func _init() -> void:
	super()
	projectile_speed = 0.0


func impact(caster: Node3D, target: Node3D) -> void:
	super.impact(caster, target)
	if not is_instance_valid(target):
		return
	var lightning: LightningFX = caster.get_tree().get_first_node_in_group(&"LightningFX") as LightningFX
	var hit: Array[Node3D] = [target]
	var last: Node3D = target
	var jump_damage: float = damage
	for jump: int in max_jumps:
		var next: Node3D = next_link(caster, last, hit)
		if next == null:
			return
		jump_damage *= jump_damage_scale
		next.call(&"take_hit", jump_damage, Focus.get_focus_target_position(last))
		if lightning:
			lightning.arc.rpc(Focus.get_focus_target_position(last), Focus.get_focus_target_position(next))
		hit.append(next)
		last = next


## The nearest enemy within reach of [param from] that has not been hit: a Focusable body that takes hits and is
## neither the caster nor a Player.
func next_link(caster: Node3D, from: Node3D, hit: Array[Node3D]) -> Node3D:
	var origin: Vector3 = Focus.get_focus_target_position(from)
	var best: Node3D = null
	var best_distance: float = jump_range
	for candidate: Node in caster.get_tree().get_nodes_in_group(&"Focusable"):
		if not (candidate is Node3D) or candidate == caster or candidate is Player or hit.has(candidate) or not candidate.has_method(&"take_hit"):
			continue
		var distance: float = Focus.get_focus_target_position(candidate).distance_to(origin)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best

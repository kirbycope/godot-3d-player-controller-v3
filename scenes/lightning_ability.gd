class_name LightningAbility
extends DamageAbility
## Calls a bolt down out of the sky onto the target. The bolt is the weather's own ([LightningFX] on the
## WeatherFX node, found through its group), so the spell and the thunderstorm look and sound the same; the
## damage is the ability's, dealt through [DamageAbility], and the strike itself hurts nothing else.


func _init() -> void:
	super()
	projectile_speed = 0.0 # Nothing flies from the hand; the sky does the work


func impact(caster: Node3D, target: Node3D) -> void:
	super.impact(caster, target)
	var at: Vector3 = Focus.get_focus_target_position(target) if is_instance_valid(target) else get_impact_position(caster)
	var lightning: LightningFX = caster.get_tree().get_first_node_in_group(&"LightningFX") as LightningFX
	if lightning:
		lightning.strike_at.rpc(at, 0.0)

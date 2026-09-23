class_name LightningAbility
extends DamageAbility
## Calls a bolt down out of the sky onto the target. The bolt is the weather's own ([LightningFX] on the
## WeatherFX node), so the spell and the thunderstorm look and sound the same; the damage is the ability's, dealt
## through [DamageAbility], and the strike itself hurts nothing else. The bolt reaches every peer through the
## world's [ProjectileSpawner] ([method ProjectileSpawner.strike_lightning]), which a client's cast asks the server
## for; without a spawner it strikes on this peer alone.


func _init() -> void:
	super()
	projectile_speed = 0.0 # Nothing flies from the hand; the sky does the work


func impact(caster: Node3D, target: Node3D) -> void:
	super.impact(caster, target)
	var at: Vector3 = Focus.get_focus_target_position(target) if is_instance_valid(target) else get_impact_position(caster)
	var spawner: ProjectileSpawner = ProjectileSpawner.find_for(caster)
	if spawner:
		spawner.strike_lightning(at, caster)
		return
	var lightning: LightningFX = caster.get_tree().get_first_node_in_group(&"LightningFX") as LightningFX
	if lightning:
		lightning.strike_at(at, 0.0)

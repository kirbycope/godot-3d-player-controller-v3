class_name FreezeAbility
extends Ability
## Freeze: turns the water under the aim point into an [IceBlock] to stand on. The cast is refused when nothing under
## the crosshair (or the locked-on target) is water. The slab is made in the impact phase, which the caster's
## [Abilities] plays on every peer: with a [ProjectileSpawner] the server spawns it for all, without one each peer
## makes its own where the impact landed, so it replicates the way every spell's impact VFX does.


func _init() -> void:
	target_mode = Target.FOCUS


func can_cast(caster: Node3D) -> bool:
	return IceBlock.find_water(caster.get_tree(), get_impact_position(caster)) != null


func activate(caster: Node3D) -> bool:
	return can_cast(caster)


func spawn_phase(phase: Phase, at: Vector3, fx_root: Node3D, audio: AudioStreamPlayer3D, target: Node3D, destination: Vector3) -> Node3D:
	if phase == Phase.IMPACT and fx_root:
		IceBlock.freeze_at(fx_root, at)
	return super(phase, at, fx_root, audio, target, destination)

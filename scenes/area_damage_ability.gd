class_name AreaDamageAbility
extends Ability
## Consecration: a [DamageZone] where the impact lands hurts everything standing in it, the caster aside, for
## [member duration]. Only the casting peer spawns the zone; the hits reach the server as any hit does.

const DAMAGE_ZONE_SCENE: PackedScene = preload("res://scenes/damage_zone.tscn")

@export var radius: float = 4.0 ## Metres around the impact the zone reaches.
@export var duration: float = 8.0 ## Seconds the zone lasts; keep [member fx_lifetime] the same so the VFX matches.
@export var total_damage: float = 64.0 ## Spread over the duration in one-second ticks.


func impact(caster: Node3D, _target: Node3D) -> void:
	var zone: Area3D = DAMAGE_ZONE_SCENE.instantiate()
	zone.set(&"caster", caster)
	zone.set(&"radius", radius)
	zone.set(&"duration", duration)
	zone.set(&"damage_per_tick", total_damage / maxf(1.0, roundf(duration)))
	# The world, never the caster's parent: a spawner's spawn path would try to replicate the zone
	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()
	parent.add_child(zone)
	zone.global_position = get_impact_position(caster)

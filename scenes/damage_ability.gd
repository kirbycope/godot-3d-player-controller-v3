class_name DamageAbility
extends Ability
## Hurts whatever it lands on: anything with a `take_hit(damage, from)` method, Players and enemies alike.
## Optionally keeps hurting it in one-second ticks (Fireball) or slows it through its `slow(factor, seconds)` (Frostbolt).

@export var damage: float = 20.0
@export_group("Over time", "over_time_")
@export var over_time_damage: float = 0.0 ## Extra damage dealt in one-second ticks after the hit; 0 is none.
@export var over_time_duration: float = 0.0 ## Seconds the ticks go on for.
@export_group("Slow", "slow_")
@export_range(0.0, 1.0) var slow_factor: float = 1.0 ## The target moves at this fraction of its speed after the hit; 1 is no slow.
@export var slow_duration: float = 0.0 ## Seconds the slow lasts.


func _init() -> void:
	target_mode = Target.FOCUS


## A Player always fires forward, at whatever the crosshair finds or just ahead; an NPC needs its target.
func can_cast(caster: Node3D) -> bool:
	return caster is Player or is_instance_valid(get_target(caster))


func activate(caster: Node3D) -> bool:
	return can_cast(caster)


func impact(caster: Node3D, target: Node3D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_hit"):
		return
	target.call("take_hit", damage, caster.global_position)
	if slow_factor < 1.0 and slow_duration > 0.0 and target.has_method("slow"):
		target.call("slow", slow_factor, slow_duration)
	if over_time_damage > 0.0 and over_time_duration > 0.0:
		var ticks: int = maxi(1, roundi(over_time_duration))
		_schedule_tick(target, over_time_damage / ticks, ticks)


func _schedule_tick(target: Node3D, amount: float, ticks_left: int) -> void:
	target.get_tree().create_timer(1.0).timeout.connect(_tick.bind(target, amount, ticks_left))


## A tick comes "from" the target itself, so the shove of the first hit never repeats.
func _tick(target: Node3D, amount: float, ticks_left: int) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	target.call("take_hit", amount, target.global_position)
	if ticks_left > 1:
		_schedule_tick(target, amount, ticks_left - 1)

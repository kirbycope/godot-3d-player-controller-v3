class_name DamageZone
extends Area3D
## Consecrated ground: hurts every body standing in it once a second for [member duration], then frees itself.
## [AreaDamageAbility] drops one where its impact lands; the caster is never hurt by its own zone.

var damage_per_tick: float = 8.0
var duration: float = 8.0
var radius: float = 4.0
var caster: Node3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var tick_timer: Timer = $TickTimer


func _ready() -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	collision_shape.shape = sphere
	get_tree().create_timer(duration).timeout.connect(queue_free)


## Wired to the TickTimer's timeout. Damage comes "from" the body itself, so a hit's shove never repeats.
func _on_tick_timer_timeout() -> void:
	for body: Node3D in get_overlapping_bodies():
		if body != caster and body.has_method("take_hit"):
			body.call("take_hit", damage_per_tick, body.global_position)

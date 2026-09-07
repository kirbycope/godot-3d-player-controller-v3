class_name BeachBall
extends RigidBody3D
## A light ball that registers hits on whatever it bumps into; the pool's [Buoyancy] floats it.

var _last_velocity: Vector3 = Vector3.ZERO

@onready var audio_player: AudioStreamPlayer3D = $SFX_Impact


func _on_body_entered(body: Node) -> void:
	var speed_sq: float = maxf(linear_velocity.length_squared(), _last_velocity.length_squared())
	if speed_sq > 0.2:
		audio_player.play()

	if speed_sq > 1.0:
		var node: Node = body
		while node:
			if node.has_method("register_weapon_hit"):
				node.call("register_weapon_hit", self, body)
				break
			elif node.has_method("register_hit"):
				node.call("register_hit", body)
				break
			node = node.get_parent()


## Remembers the speed before a contact so the impact sound reflects it.
func _physics_process(_delta: float) -> void:
	_last_velocity = linear_velocity

class_name BeachBall
extends RigidBody3D
## A light ball that floats in water and registers hits on whatever it bumps into.

@export var buoyancy_force: float = 15.0
@export var fluid_drag: float = 2.0
@export var fluid_angular_drag: float = 2.0

var in_water_area: Area3D = null ## The water [Area3D] the ball is currently inside, set by the world.
var _last_velocity: Vector3 = Vector3.ZERO

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
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


func _physics_process(_delta: float) -> void:
	_last_velocity = linear_velocity
	if not is_instance_valid(in_water_area):
		return

	var radius: float = (collision_shape.shape as SphereShape3D).radius
	var bottom_y: float = global_position.y - radius
	var water_surface_y: float = FollowerNpc.get_water_surface_along_up(in_water_area, Vector3.UP)
	if water_surface_y <= bottom_y:
		return

	var submerged_ratio: float = clampf((water_surface_y - bottom_y) / (radius * 2.0), 0.0, 1.0)
	# Apply buoyancy force
	apply_central_force(Vector3.UP * mass * buoyancy_force * submerged_ratio)
	# Apply drag
	apply_central_force(-linear_velocity * fluid_drag * submerged_ratio)
	apply_torque(-angular_velocity * fluid_angular_drag * submerged_ratio)

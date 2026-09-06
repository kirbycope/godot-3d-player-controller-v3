class_name Choppable
extends Harvestable
## A tree felled after enough chops from the "action" interaction or melee weapon attacks.

@export var standing_node: Node3D ## The intact tree model.
@export var stump_node: Node3D ## The stump model shown after the tree falls.
@export var log_node: Node3D ## The fallen log model shown after the tree falls.
@export var log_body: RigidBody3D ## Optional frozen body unfrozen when the tree falls; overrides [member log_node] handling.

@onready var log_collision_timer: Timer = $LogCollisionTimer ## Polls until the fallen log has tipped clear of the stump.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	# The fallen log must not block the player while the tree still stands
	if log_body:
		log_body.hide()
		_set_collision_shapes_disabled(log_body, true)
	elif log_node:
		log_node.hide()
		_set_collision_shapes_disabled(log_node, true)


## Swaps the standing tree for the stump and fallen log.
func _on_depleted() -> void:
	if standing_node:
		standing_node.hide()
	if stump_node:
		stump_node.show()
	# Remove the standing trunk collision on the root, if any
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	if log_body:
		log_body.show()
		# The log spawns overlapping the stump; temporary exceptions prevent a depenetration launch
		log_body.add_collision_exception_with(self)
		if stump_node:
			for body: Node in stump_node.find_children("*", "PhysicsBody3D", true, false):
				log_body.add_collision_exception_with(body as PhysicsBody3D)
		# Restores the exceptions once the log tips clear of the stump
		log_collision_timer.start()
		# Only the body's own shapes; the model's imported static colliders stay disabled
		for child: Node in log_body.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = false
		log_body.freeze = false
		# Brief grace so the felling swing's knockback doesn't bat the log away
		log_body.set_meta("no_knockback_until", Time.get_ticks_msec() + 1000)
		# Tip the log away from the stump so it does not balance on its cut end
		var up: Vector3 = global_transform.basis.y
		var away: Vector3 = log_body.global_position - global_position
		away = away - away.project(up)
		if away.length_squared() < 0.001:
			away = -global_transform.basis.z
		log_body.angular_velocity = up.cross(away.normalized()) * 2.0
		# Action chops have no weapon knockback; nudge the log away from the player
		if player:
			var push: Vector3 = log_body.global_position - player.global_position
			push = push - push.project(up)
			if push.length_squared() > 0.001:
				log_body.apply_central_impulse(push.normalized() * log_body.mass * 2.0)
	elif log_node:
		log_node.show()
		_set_collision_shapes_disabled(log_node, false)


## Re-enables stump/log collision once the fallen log has tipped clear of the stump.
func _on_log_collision_timer_timeout() -> void:
	if not is_instance_valid(log_body):
		log_collision_timer.stop()
		return
	var stump_bodies: Array[Node] = stump_node.find_children("*", "PhysicsBody3D", true, false) if stump_node else []
	var space_state: PhysicsDirectSpaceState3D = log_body.get_world_3d().direct_space_state
	for child: Node in log_body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape and not (child as CollisionShape3D).disabled:
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = (child as CollisionShape3D).shape
			query.transform = (child as CollisionShape3D).global_transform
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [log_body.get_rid()]
			for result: Dictionary in space_state.intersect_shape(query):
				if result.collider == self or result.collider in stump_bodies:
					# Still resting against the stump; restoring now would shove the log out
					return
	log_collision_timer.stop()
	log_body.remove_collision_exception_with(self)
	for body: Node in stump_bodies:
		log_body.remove_collision_exception_with(body as PhysicsBody3D)


func _set_collision_shapes_disabled(node: Node3D, disabled: bool) -> void:
	for shape: Node in node.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = disabled

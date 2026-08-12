class_name Choppable
extends Node3D
## A tree felled after enough chops from the "action" interaction or melee weapon attacks.

@export var chops_to_fell: int = 3 ## Number of chops before the tree falls.
@export var chop_delay: float = 0.9 ## Seconds after the Logging animation starts before the chop lands.
@export var standing_node: Node3D ## The intact tree model.
@export var stump_node: Node3D ## The stump model shown after the tree falls.
@export var log_node: Node3D ## The fallen log model shown after the tree falls.
@export var log_body: RigidBody3D ## Optional frozen body unfrozen when the tree falls; overrides [member log_node] handling.

var chops_taken: int = 0
var is_felled: bool = false
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt
@onready var progress_bar: ProgressBar3D = $ProgressBar3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.max_value = chops_to_fell
	# The fallen log must not block the player while the tree still stands
	if log_body:
		log_body.hide()
		_set_collision_shapes_disabled(log_body, true)
	elif log_node:
		log_node.hide()
		_set_collision_shapes_disabled(log_node, true)


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player and not is_felled:
		if event.is_action_pressed("action") and not player.is_logging:
			# Make the player_model rotate (horizontally) towards the choppable object
			var target_dir := (global_position - player.global_position)
			target_dir = target_dir - target_dir.project(player.up_direction)
			if target_dir.length_squared() > 0.001:
				target_dir = target_dir.normalized()
				player.orientation.basis = Basis.looking_at(-target_dir, player.up_direction)
			# Travel to "Logging" inside the Shield group of the player's locomotion state machine
			player.travel_locomotion("Shield/Logging")
			# Land the chop once the swing connects
			get_tree().create_timer(chop_delay).timeout.connect(register_chop)


## Called by [HitDetection] when a melee weapon connects with this object.
func register_weapon_hit(equipment: Node = null, hit_node: Node = null) -> void:
	if equipment and "can_log" in equipment and equipment.can_log:
		register_chop()


## Applies one chop of damage; fells the tree once enough chops land.
func register_chop() -> void:
	if is_felled:
		return
	chops_taken += 1
	progress_bar.value = chops_taken
	if chops_taken >= chops_to_fell:
		_fell()


## Swaps the standing tree for the stump and fallen log.
func _fell() -> void:
	is_felled = true
	if standing_node:
		standing_node.hide()
	if stump_node:
		stump_node.show()
	# Remove the standing trunk collision on the root, if any
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
	if log_body:
		log_body.show()
		# The log spawns overlapping the stump; temporary exceptions prevent a depenetration launch
		log_body.add_collision_exception_with(self)
		if stump_node:
			for body in stump_node.find_children("*", "PhysicsBody3D", true, false):
				log_body.add_collision_exception_with(body)
		# Restores itself once the log tips clear of the stump
		_restore_log_collisions()
		# Only the body's own shapes; the model's imported static colliders stay disabled
		for child in log_body.get_children():
			if child is CollisionShape3D:
				child.disabled = false
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
	hide_menu()


## Re-enables stump/log collision once the fallen log has tipped clear of the stump.
func _restore_log_collisions() -> void:
	if log_body == null or not is_instance_valid(log_body):
		return
	if _log_overlaps_stump():
		# Still resting against the stump; retry so restoring doesn't shove the log out
		get_tree().create_timer(0.5).timeout.connect(_restore_log_collisions)
		return
	log_body.remove_collision_exception_with(self)
	if stump_node:
		for body in stump_node.find_children("*", "PhysicsBody3D", true, false):
			log_body.remove_collision_exception_with(body)


func _log_overlaps_stump() -> bool:
	var stump_bodies: Array = []
	if stump_node:
		stump_bodies = stump_node.find_children("*", "PhysicsBody3D", true, false)
	var space_state: PhysicsDirectSpaceState3D = log_body.get_world_3d().direct_space_state
	for child in log_body.get_children():
		if child is CollisionShape3D and child.shape and not child.disabled:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.transform = child.global_transform
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [log_body.get_rid()]
			for result in space_state.intersect_shape(query):
				if result.collider == self or result.collider in stump_bodies:
					return true
	return false


func _set_collision_shapes_disabled(node: Node3D, disabled: bool) -> void:
	if node == null:
		return
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = disabled


func display_menu(_player: Player) -> void:
	if is_felled:
		return
	player = _player
	if action_prompt:
		action_prompt.show()
		action_prompt.update_text()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
	menu_displayed = true


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
	player = null

extends CharacterBody3D
## A training dummy that plays a hit reaction facing whoever struck it.

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")


func _ready() -> void:
	animation_tree.active = true


func register_weapon_hit(equipment: Node = null, hit_node: Node = null) -> void:
	_play_hit_reaction(equipment, hit_node)


func register_hit(hit_node: Node = null) -> void:
	_play_hit_reaction(null, hit_node)


func _play_hit_reaction(source: Node, hit_node: Node = null) -> void:
	var hit_state: String = ""

	if hit_node:
		var bone_name: String = hit_node.name.to_lower()
		if "left" in bone_name:
			hit_state = "ReactionHitOnLeftSide"
		elif "right" in bone_name:
			hit_state = "ReactionHitOnRightSide"

	if hit_state == "" and source:
		var source_name: String = source.name.to_lower()
		if "left" in source_name:
			# Attacking with left hits the character's right side
			hit_state = "ReactionHitOnRightSide"
		elif "right" in source_name:
			# Attacking with right hits the character's left side
			hit_state = "ReactionHitOnLeftSide"

	if hit_state == "":
		var attacker: Node3D = null
		if is_instance_valid(source):
			if source is Node3D:
				attacker = source as Node3D
			elif source.get_parent() is Node3D:
				attacker = source.get_parent() as Node3D
		if attacker == null:
			attacker = get_tree().get_first_node_in_group("Player") as Node3D

		if attacker:
			var to_attacker: Vector3 = global_position.direction_to(attacker.global_position)
			var dot: float = global_transform.basis.x.dot(to_attacker)
			if dot > 0.35:
				hit_state = "ReactionHitOnRightSide"
			elif dot < -0.35:
				hit_state = "ReactionHitOnLeftSide"
			else:
				hit_state = "GettingHit"
		else:
			hit_state = "GettingHit"

	playback.travel(hit_state)

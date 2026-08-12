extends CharacterBody3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

func _ready() -> void:
	animation_tree.active = true

func register_weapon_hit(equipment: Node = null, hit_node: Node = null) -> void:
	_play_hit_reaction(equipment, hit_node)

func register_hit(hit_node: Node = null) -> void:
	_play_hit_reaction(null, hit_node)

func apply_impulse(impulse: Vector3, _impulse_position: Vector3) -> void:
	var right_dir: Vector3 = global_transform.basis.x
	var norm_impulse: Vector3 = impulse.normalized()
	var dot: float = right_dir.dot(norm_impulse)
	
	if dot > 0.35:
		playback.travel("ReactionHitOnLeftSide")
	elif dot < -0.35:
		playback.travel("ReactionHitOnRightSide")
	else:
		playback.travel("GettingHit")

func _play_hit_reaction(source: Node, hit_node: Node = null) -> void:
	var hit_state := ""
	
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
		hit_state = "GettingHit"
		
	playback.travel(hit_state)

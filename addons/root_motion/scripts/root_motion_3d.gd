@icon("res://addons/root_motion/icons/root_motion_3d.svg")
class_name RootMotion
extends Node3D

@export var active = false
@export var debug_logging = true
@export var animation_tree: AnimationTree;

var model: Node3D;
var armature: Node3D;
var skeleton: Skeleton3D;
var animation_player: AnimationPlayer;

func _ready():
	if not Engine.is_editor_hint():
		if (active):
			_debug("Root motion starting")
			add_root_motion()
	pass

func add_root_motion():
	model = get_first_child(get_children()) as Node3D
	if model == null:
		return

	skeleton = _find_skeleton(model)
	if skeleton == null:
		return

	armature = skeleton.get_parent() as Node3D
	if armature == null:
		return

	animation_player = get_first_child(model.find_children("*", "AnimationPlayer", false)) as AnimationPlayer
	if animation_player == null:
		return

	var new_skeleton = skeleton
	if armature.rotation != Vector3.ZERO or armature.scale != Vector3.ONE:
		fix_model()
		new_skeleton = get_first_child(armature.find_children("*", "Skeleton3D", false)) as Skeleton3D
		if new_skeleton == null:
			return

	add_root_bone()

	if _has_root_bone(new_skeleton):
		var base_track_path = model.get_path_to(new_skeleton)
		var root_bone_idx = _get_root_bone_index(new_skeleton)
		var root_bone_path = str(base_track_path, ":", new_skeleton.get_bone_name(root_bone_idx))
		animation_player.root_motion_track = root_bone_path
		if animation_tree != null:
			animation_tree.root_motion_track = root_bone_path

	_debug("Root motion setup complete")
	pass

func get_first_child(arr: Array[Variant]) -> Node:
	if arr.size() > 0:
		return arr[0]
	return null

func _find_skeleton(root: Node3D) -> Skeleton3D:
	var direct_skeleton = get_first_child(root.find_children("*", "Skeleton3D", false)) as Skeleton3D
	if direct_skeleton != null:
		return direct_skeleton

	for child in root.get_children():
		if child is Node3D:
			var nested_skeleton = get_first_child((child as Node3D).find_children("*", "Skeleton3D", false)) as Skeleton3D
			if nested_skeleton != null:
				return nested_skeleton

	return null

func _detect_layout_name(root: Node3D, skeleton_parent: Node3D, sk: Skeleton3D) -> String:
	if skeleton_parent == root:
		return "direct_skeleton"
	if sk.name.contains("GeneralSkeleton"):
		return "retargeted_fbx"
	if skeleton_parent.name.contains("Armature"):
		return "glb_armature"
	return "nested_skeleton"

func _debug(message: String, data: Dictionary = {}) -> void:
	if !debug_logging:
		return

	if data.is_empty():
		print("[RootMotion] ", message)
		return

	print("[RootMotion] ", message, " | ", JSON.stringify(data))

func fix_model():
	#_debug("Normalizing skeleton and animations", {"skeleton": skeleton.name, "animation_count": animation_player.get_animation_list().size()})
	# Create a temp node to resize model
	var skeleton_owner = skeleton.owner
	var new_skeleton = Skeleton3D.new()
	new_skeleton.name = skeleton.name
	add_child(new_skeleton)

	# Copy bones from original skeleton and resize pose
	skeleton.reset_bone_poses()

	new_skeleton.clear_bones();
	for bone_idx in skeleton.get_bone_count():
		var bone_name = skeleton.get_bone_name(bone_idx)
		new_skeleton.add_bone(bone_name)

		var bone_rotation: Basis = Basis(skeleton.get_bone_pose_rotation(bone_idx))
		if (armature.rotation != Vector3.ZERO):
			if bone_idx == 0:
				var angle_x = armature.rotation_degrees.x
				bone_rotation = bone_rotation.rotated(Vector3.RIGHT, deg_to_rad(angle_x))

		var bone_position: Vector3 = skeleton.get_bone_pose_position(bone_idx)
		if (armature.scale != Vector3.ONE):
			bone_position *= 0.01
			if bone_idx == 0:
				bone_position = Vector3(bone_position.x, -bone_position.z, bone_position.y)

		var bone_transform = Transform3D(bone_rotation, bone_position)
		new_skeleton.set_bone_rest(bone_idx, bone_transform)
	#_debug("Copied bone rests to rebuilt skeleton", {"bone_count": new_skeleton.get_bone_count()})

	new_skeleton.reset_bone_poses()

	# Copy skeleton children nodes and resize pose
	var duplicated_child_count = 0
	for skeleton_child in skeleton.get_children():
		var new_skeleton_child = skeleton_child.duplicate()
		new_skeleton.add_child(new_skeleton_child)
		duplicated_child_count += 1

		if (armature.scale != Vector3.ONE):
			if new_skeleton_child is MeshInstance3D:
				var skin: Skin = new_skeleton_child.skin.duplicate(true)
				for bind_idx in range(skin.get_bind_count()):
					var bind_pose = skin.get_bind_pose(bind_idx)
					skin.set_bind_pose(bind_idx, bind_pose * 0.01)
				new_skeleton_child.skin = skin
	#_debug("Duplicated skeleton child nodes", {"children": duplicated_child_count})

	# Reparent bones in the new skeleton
	_reparent_bones(new_skeleton, 0)
	#_debug("Bone hierarchy rebuilt")

	# Resize and rotate all animations keyframes
	for animation_name in animation_player.get_animation_list():
		new_skeleton.reset_bone_poses()
		var animation: Animation = animation_player.get_animation(animation_name)
		#_debug("Processing animation", {"animation": animation_name, "tracks": animation.get_track_count()})
		for track_path_idx in range(animation.get_track_count()):
			var track_type = animation.track_get_type(track_path_idx)
			var track_path = animation.track_get_path(track_path_idx)
			var is_track_path: bool = str(track_path.get_concatenated_names(), ":", track_path.get_concatenated_subnames()).contains("Hips")
			var track_idx = animation.find_track(track_path, track_type)
			for key_index in range(0, animation.track_get_key_count(track_idx), 1):
				if track_type == Animation.TYPE_ROTATION_3D:
					var bone_rotation: Basis = Basis(animation.track_get_key_value(track_idx, key_index))
					if (armature.rotation != Vector3.ZERO):
						if is_track_path:
							var angle_x = armature.rotation_degrees.x
							bone_rotation = bone_rotation.rotated(Vector3.RIGHT, deg_to_rad(angle_x))
					animation.track_set_key_value(track_idx, key_index, bone_rotation)
				if track_type == Animation.TYPE_POSITION_3D:
					var bone_position: Vector3 = animation.track_get_key_value(track_idx, key_index)
					if (armature.scale != Vector3.ONE):
						bone_position *= 0.01
						if is_track_path:
							bone_position = Vector3(bone_position.x, -bone_position.z, bone_position.y)
					animation.track_set_key_value(track_idx, key_index, bone_position)

	# Remove the original skeleton and reparent the new one
	armature.remove_child(skeleton)
	skeleton.owner = null
	new_skeleton.reparent(armature, false)
	if skeleton_owner != null and skeleton_owner.is_ancestor_of(new_skeleton):
		new_skeleton.owner = skeleton_owner
		for new_skeleton_child in new_skeleton.get_children():
			new_skeleton_child.owner = skeleton_owner
	
	# Reset the armature rotation and scale
	if (armature.rotation != Vector3.ZERO):
		armature.rotation = Vector3.ZERO
	
	if (armature.scale != Vector3.ONE):
		armature.scale = Vector3.ONE

	#_debug("Model normalization complete", {"armature_rotation": armature.rotation, "armature_scale": armature.scale})
	pass

func add_root_bone():
	var new_skeleton = get_first_child(armature.find_children("*", "Skeleton3D", false)) as Skeleton3D
	if new_skeleton == null:
		return

	var hip_bone_idx = _get_hip_bone_index(new_skeleton)
	if hip_bone_idx == -1:
		return
	var hip_bone_name = new_skeleton.get_bone_name(hip_bone_idx)

	var root_bone_idx = _get_root_bone_index(new_skeleton)
	if root_bone_idx == -1:
		new_skeleton.add_bone("mixamorig_Root")
		root_bone_idx = new_skeleton.get_bone_count() - 1
		new_skeleton.set_bone_parent(hip_bone_idx, root_bone_idx)
		#_debug("Root bone created", {"root_bone_index": root_bone_idx, "hip_bone_parented": hip_bone_idx, "hip_bone_name": hip_bone_name})
	#else:
		#_debug("Root bone already present, updating animation tracks", {"root_bone_index": root_bone_idx})

	var hip_bone_rest = new_skeleton.get_bone_rest(hip_bone_idx)

	# Update all animations with root bone
	for animation_name in animation_player.get_animation_list():
		# Used to know where add root bone track
		var base_track_path = model.get_path_to(new_skeleton)

		# Define de animation object by animation name
		var animation = animation_player.get_animation(animation_name)

		# Check if animation contains the root bone track
		if _has_root_bone_track(new_skeleton, animation):
			#_debug("Animation already has a root bone track", {"animation": animation_name})
			continue
		
		# Define the root and hips track path name
		var hip_bone_path = str(base_track_path, ":", hip_bone_name)
		var root_bone_path = str(base_track_path, ":", new_skeleton.get_bone_name(root_bone_idx))

		# Add if not exist the root bone position track
		var root_bone_position_track_index = animation.find_track(root_bone_path, Animation.TYPE_POSITION_3D)
		if root_bone_position_track_index == - 1:
			root_bone_position_track_index = animation.add_track(Animation.TYPE_POSITION_3D, 0)
		animation.track_set_path(root_bone_position_track_index, root_bone_path)
		#_debug("Preparing animation root track", {"animation": animation_name, "root_track_index": root_bone_position_track_index})
			
		# Set the X and Z axis to root bone and set Y axis only to hips bone
		var hip_bone_position_track_index = _find_bone_position_track_index(animation, hip_bone_name)
		if hip_bone_position_track_index == - 1:
			#_debug("Hip position track missing, likely in-place clip.", {"animation": animation_name})
			continue
		#var detected_hip_track = animation.track_get_path(hip_bone_position_track_index)
		#_debug("Hip track detected", {"animation": animation_name, "hip_track": str(detected_hip_track.get_concatenated_names(), ":", detected_hip_track.get_concatenated_subnames())})

		var inserted_key_count = 0
		for hip_position_key_index in range(0, animation.track_get_key_count(hip_bone_position_track_index), 1):
			var hip_key_value = animation.track_get_key_value(hip_bone_position_track_index, hip_position_key_index)
			var root_key_value_y = 0
			var hip_key_value_y = hip_key_value.y
			if hip_key_value.y > hip_bone_rest.origin.y:
				var diff = hip_key_value.y - hip_bone_rest.origin.y
				root_key_value_y = diff
				hip_key_value_y -= diff
			var root_bone_position_value = Vector3(hip_key_value.x, root_key_value_y, hip_key_value.z)
			var hip_bone_position_value = Vector3(0, hip_key_value_y, 0)
			animation.track_insert_key(root_bone_position_track_index, animation.track_get_key_time(hip_bone_position_track_index, hip_position_key_index), root_bone_position_value)
			animation.track_set_key_value(hip_bone_position_track_index, hip_position_key_index, hip_bone_position_value)
			inserted_key_count += 1
		#_debug("Animation root track updated", {"animation": animation_name, "keys": inserted_key_count})
	pass

func _has_root_bone_track(sk: Skeleton3D, animation) -> bool:
	var base_track_path = model.get_path_to(sk)
	var root_bone_idx = _get_root_bone_index(sk)
	var root_bone_path = str(base_track_path, ":", sk.get_bone_name(root_bone_idx))
	var root_bone_position_track_index = animation.find_track(root_bone_path, Animation.TYPE_POSITION_3D)
	if root_bone_position_track_index != - 1:
		return true
	return false

func _get_root_bone_index(sk: Skeleton3D) -> int:
	for bone_idx in sk.get_bone_count():
		var bone_name = sk.get_bone_name(bone_idx)
		if bone_name.contains("Root"):
			return bone_idx
	return - 1

func _get_hip_bone_index(sk: Skeleton3D) -> int:
	for bone_idx in sk.get_bone_count():
		var bone_name = sk.get_bone_name(bone_idx)
		if bone_name.contains("Hips"):
			return bone_idx
	return - 1

func _has_root_bone(sk: Skeleton3D) -> bool:
	return _get_root_bone_index(sk) != - 1

func _find_bone_position_track_index(animation: Animation, bone_name: String) -> int:
	for track_idx in range(animation.get_track_count()):
		if animation.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
			continue

		var track_path = animation.track_get_path(track_idx)
		if _track_matches_bone(track_path, bone_name):
			return track_idx

	return -1

func _track_matches_bone(track_path: NodePath, bone_name: String) -> bool:
	var track_path_str = str(track_path.get_concatenated_names(), ":", track_path.get_concatenated_subnames())
	if track_path_str.contains(str(":", bone_name)):
		return true

	if bone_name.contains("mixamorig_"):
		var short_bone_name = bone_name.trim_prefix("mixamorig_")
		if track_path_str.contains(str(":", short_bone_name)):
			return true

	if bone_name.to_lower().contains("hips") and track_path_str.to_lower().contains(":hips"):
		return true

	return false

func _reparent_bones(sk: Skeleton3D, bone_idx: int) -> void:
	var children = skeleton.get_bone_children(bone_idx)
	if children.size() > 0:
		for i in range(children.size()):
			var child_idx = children[i];
			sk.set_bone_parent(child_idx, bone_idx)
			_reparent_bones(sk, child_idx)
	pass

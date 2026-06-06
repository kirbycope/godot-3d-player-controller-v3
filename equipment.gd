extends Node3D

@export var bone_attachment_bone_name: String
@export var position_offset: Vector3:
	set(val):
		position_offset = val
		_update_attachment_offsets()
@export var rotation_offset_degrees: Vector3:
	set(val):
		rotation_offset_degrees = val
		_update_attachment_offsets()

var equipment_instance: Node3D
var menu_displayed: bool = false

@onready var action_prompt: Node3D = $ActionPrompt


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func _update_attachment_offsets() -> void:
	if not is_inside_tree():
		return
	if equipment_instance:
		equipment_instance.position = position_offset
		equipment_instance.rotation = Vector3(
			deg_to_rad(rotation_offset_degrees.x),
			deg_to_rad(rotation_offset_degrees.y),
			deg_to_rad(rotation_offset_degrees.z)
		)


func display_menu(_player: Player) -> void:
	if action_prompt:
		action_prompt.show()
	menu_displayed = true


func equip(player: Player) -> void:
	hide_menu()

	if not bone_attachment_bone_name or not player:
		return

	# 1. Find the Skeleton3D on the player (adjust the node path if needed)
	var skeleton: Skeleton3D = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton") 
	if not skeleton:
		push_error("Skeleton3D not found on player!")
		return

	# 2. Look for and remove any existing attachment on this specific bone
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.bone_name == bone_attachment_bone_name:
			skeleton.remove_child(child)
			child.queue_free() # Clean it up from memory

	# 3. Create a new BoneAttachment3D and configure it
	var new_attachment = BoneAttachment3D.new()
	new_attachment.bone_name = bone_attachment_bone_name
	skeleton.add_child(new_attachment)

	# 4. Duplicate this weapon and add it to the attachment
	equipment_instance = duplicate()
	new_attachment.add_child(equipment_instance)
	_change_collision_layers(equipment_instance)
	_update_attachment_offsets()


func _change_collision_layers(node: Node) -> void:
	if node is CollisionObject3D:
		if node.collision_layer == 1:
			node.collision_layer = 2
	for child in node.get_children():
		_change_collision_layers(child)


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false

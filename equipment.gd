extends Node3D

enum EquipmentType {
	AXE_1H,
	AXE_2H,
	BOW,
	DAGGER,
	STAFF,
	SWORD_1H,
	SWORD_2H,
	SWORD_AND_SHIELD,
}

@export var bone_attachment_bone_name: String
@export var equipment_type: EquipmentType
@export var position_offset: Vector3:
	set(val):
		position_offset = val
		_update_attachment_offsets()
@export var rotation_offset_degrees: Vector3:
	set(val):
		rotation_offset_degrees = val
		_update_attachment_offsets()
@export var scale_offset: Vector3 = Vector3.ONE:
	set(val):
		scale_offset = val
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
		equipment_instance.scale = scale_offset


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
	_disable_collisions(equipment_instance)
	_update_attachment_offsets()

	# 5. Flag the player as having equipped the item
	if equipment_type == EquipmentType.AXE_1H:
		player.equipped_axe_1h = true
	elif equipment_type == EquipmentType.AXE_2H:
		player.equipped_axe_2h = true
	elif equipment_type == EquipmentType.BOW:
		player.equipped_bow = true
	elif equipment_type == EquipmentType.DAGGER:
		player.equipped_dagger = true
	elif equipment_type == EquipmentType.STAFF:
		player.equipped_staff = true
	elif equipment_type == EquipmentType.SWORD_AND_SHIELD:
		player.equipped_shield = true
	elif equipment_type == EquipmentType.SWORD_1H:
		player.equipped_sword_1h = true
	elif equipment_type == EquipmentType.SWORD_2H:
		player.equipped_sword_2h = true


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collisions(child)


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false

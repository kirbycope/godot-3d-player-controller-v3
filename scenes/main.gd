extends Node3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the mouse mode to captured to hide the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var arrow := get_node_or_null("N_Hance_Studio/SK_Bow_Newbie_01/Arrow")
	if arrow is Node:
		_set_collision_shapes_disabled(arrow as Node, true)


func _set_collision_shapes_disabled(node: Node, disabled: bool) -> void:
	if node is CollisionShape3D:
		node.disabled = disabled
	for child in node.get_children():
		if child is Node:
			_set_collision_shapes_disabled(child as Node, disabled)

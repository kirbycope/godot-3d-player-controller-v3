class_name ProgressBar3D
extends Node3D
## Billboarded world-space progress bar. Visible only while progress is between zero and max.

@export var max_value: int = 3

var value: int = 0:
	set(new_value):
		value = new_value
		_update_bar()

@onready var bar_mesh: MeshInstance3D = $BarMesh


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_bar()


func _update_bar() -> void:
	if not is_node_ready():
		return
	var ratio: float = clampf(float(value) / float(maxi(max_value, 1)), 0.0, 1.0)
	bar_mesh.set_instance_shader_parameter("ratio", ratio)
	visible = value > 0 and value < max_value

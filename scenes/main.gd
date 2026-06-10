extends Node3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the mouse mode to captured to hide the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

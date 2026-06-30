extends Node3D

@onready var project_rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get rendering settings from the project settings
	if project_rendering_method in ["forward_plus", "mobile"]:
		# Set the mouse mode to captured to hide the mouse cursor
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Show the Click to Start button
		$ClickToStart.visible = true


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if not $ClickToStart.visible:
		return

	if event is InputEventMouseButton or event is InputEventScreenTouch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$ClickToStart.visible = false

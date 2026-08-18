extends Node3D

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"

var project_rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
@onready var click_to_start: CanvasLayer = $ClickToStart
@onready var loading: Loading = $Loading


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get rendering settings from the project settings
	var requires_input_activation: bool = project_rendering_method not in ["forward_plus", "mobile"]
	loading.start(WORLD_SCENE_PATH, {}, self, not requires_input_activation)
	if not requires_input_activation:
		# Set the mouse mode to captured to hide the mouse cursor
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Show the Click to Start button
		click_to_start.show()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Webfix - Browser requires the user select the app before capturing the mouse and playing audio
	if click_to_start.visible:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			click_to_start.hide()
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			loading.activate()

extends Node3D

@export_file("*.tscn") var single_player_scene: String
@export_file("*.tscn") var multi_player_scene: String

var project_rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")

@onready var click_to_start: CanvasLayer = $ClickToStart
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var loading: Loading = $Loading


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get rendering settings from the project settings
	var requires_input_activation: bool = project_rendering_method not in ["forward_plus", "mobile"]
	# [Webfix] Show the Click to Start button
	if requires_input_activation:
		click_to_start.show()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Webfix - Browser requires the user select the app before capturing the mouse and playing audio
	if click_to_start.visible:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			click_to_start.hide()
			loading.load_scene(single_player_scene)


func single_player() -> void:
	loading.load_scene(single_player_scene)


func multi_player() -> void:
	loading.load_scene(multi_player_scene)

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


## Called when an input event is not handled by the GUI.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.is_pressed() and not event.is_echo():
		if event.button_index == JOY_BUTTON_A:
			if click_to_start.visible:
				click_to_start.hide()
				loading.load_scene(single_player_scene)
				return
			var focused_control = get_viewport().gui_get_focus_owner()
			if focused_control is BaseButton:
				focused_control.emit_signal("pressed")
			elif title_screen and title_screen.has_node("VBoxContainer/Button_SinglePlayer"):
				var single_player_btn = title_screen.get_node("VBoxContainer/Button_SinglePlayer") as Button
				if single_player_btn:
					single_player_btn.emit_signal("pressed")


func single_player() -> void:
	loading.load_scene(single_player_scene)


func multi_player() -> void:
	loading.load_scene(multi_player_scene)

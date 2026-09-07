extends Control
## Runs the GDScript DOOM raycaster on its own for Run Current Scene: the 320x200 screen scales to the window at
## 16:10 with crisp pixels, the addon's controls register the move, look and shoot actions, every input is pushed
## into the screen's viewport, the mouse is captured for turning and Escape lets it go (a click takes it back).
## The [Doom] inside has [member Doom.use_engine] off, so it is the raycaster even where the PureDoom library is built.

const CONTROLS_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/controls.tscn")

@onready var viewport: SubViewport = $ScreenViewport
@onready var doom: Doom = $ScreenViewport/Doom
@onready var screen: TextureRect = $Screen


func _ready() -> void:
	var controls: Node = CONTROLS_SCENE.instantiate() # Registers the addon's input actions in its ready
	controls.set(&"visible", false)
	add_child(controls)
	screen.texture = viewport.get_texture()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	doom.boot()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	viewport.push_input(event) # The screen's own viewport gets no input on its own

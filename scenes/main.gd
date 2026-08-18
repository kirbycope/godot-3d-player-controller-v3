extends Node3D

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"

var project_rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
var steam_enabled: bool = false

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

	# Enable Steam for Forward+
	if project_rendering_method == "forward_plus":
		initialize_steam()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Webfix - Browser requires the user select the app before capturing the mouse and playing audio
	if click_to_start.visible:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			click_to_start.hide()
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			loading.activate()


## Initializing Steam, see `https://godotsteam.com/tutorials/initializing/`
func initialize_steam() -> void:
	var app_id = 480
	var embed_callbacks = true
	var initialize_response: Dictionary = Steam.steamInitEx(app_id, embed_callbacks)
	#print("Did Steam initialize?: %s " % initialize_response) # DEBUGGING
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, disabling Steam functionality: %s" % initialize_response)
		steam_enabled = false
		return
	steam_enabled = true

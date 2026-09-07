class_name RetroComputer
extends StaticBody3D
## A beige desktop computer the Player walks up to and uses: the "action" look-at interaction moves the view to
## its CRT, a [SubViewport] running [Doom], and every input goes to the game until "start" steps away.

## The overlay's plain-text device names, indexed by the player controller's Controls.InputType.
const INPUT_TYPE_NAMES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]

@export var hidden_while_in_use: Array[NodePath] = [] ## HUD layers of the level (the clock and weather, say) to hide while the Player is at the keyboard.

var player: Player ## The Player looking at or using the computer.
var is_in_use: bool = false

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var controls_overlay: PureDoomControlsOverlay = $ControlsOverlay
@onready var screen_camera: Camera3D = $ScreenCamera
@onready var screen: MeshInstance3D = $Screen
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var doom: Doom = $ScreenViewport/Doom


func _ready() -> void:
	set_process_input(false)
	# The CRT reads the viewport at runtime; a ViewportTexture saved in the scene cannot find the viewport while the
	# editor exports the project and logs an invalid path
	(screen.material_override as ShaderMaterial).set_shader_parameter(&"screen_texture", screen_viewport.get_texture())


## Only runs while the Player is at the keyboard: "start" leaves, everything else goes to the game.
func _input(event: InputEvent) -> void:
	# A Player knocked down at the keyboard gets their camera back rather than staying stuck on the screen
	if not is_instance_valid(player) or player.is_ragdolling:
		stop_using()
		return
	# The Controls detect the device in their own _input, which never runs once this one marks the event handled
	player.controls._input(event)
	if event.is_action_pressed("start"):
		stop_using()
	else:
		screen_viewport.push_input(event)
	# Touch input is left for the on-screen buttons, which drive the same actions the game reads
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_viewport().set_input_as_handled()


## Called by [Camera] while the player looks at the computer.
func display_menu(_player: Player) -> void:
	if is_in_use:
		return
	player = _player
	action_prompt.show_for(player, "Use")


## Called by [Camera] when the player looks away from the computer.
func hide_menu() -> void:
	action_prompt.hide_for(player)


## Called by [Camera] when the player presses "action" while looking at the computer.
func equip(_player: Player) -> void:
	if is_in_use or _player.is_riding or _player.is_ragdolling:
		return
	player = _player
	is_in_use = true
	action_prompt.hide_for(player)
	player.is_paused = true
	player.velocity = Vector3.ZERO
	player.rotate_model_to_direction(global_position - player.global_position)
	screen_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The on-screen controls would sit over the monitor; touch players keep them, they have nothing else to press
	player.controls.visible = player.controls.current_input_type == player.controls.InputType.TOUCH
	player.crosshair.hide()
	_set_level_hud_visible(false)
	# The controls card in the black bands beside the monitor, worded for whatever the Player is holding
	_on_input_type_changed(player.controls.current_input_type)
	player.controls.input_type_changed.connect(_on_input_type_changed)
	controls_overlay.show()
	doom.boot()
	set_process_input(true)


## Puts the screen back to the DOS prompt and gives the Player their camera and controls back.
func stop_using() -> void:
	is_in_use = false
	set_process_input(false)
	doom.sleep()
	controls_overlay.hide()
	_set_level_hud_visible(true)
	if not is_instance_valid(player):
		player = null
		return
	if player.controls.input_type_changed.is_connected(_on_input_type_changed):
		player.controls.input_type_changed.disconnect(_on_input_type_changed)
	player.camera.current = true
	player.is_paused = false
	player.controls.show()
	player.crosshair.show()
	var camera: Camera = player.camera as Camera
	if camera and camera.looking_at == self:
		display_menu(player)


func _on_input_type_changed(input_type: int) -> void:
	controls_overlay.input_type = INPUT_TYPE_NAMES[input_type]
	# Picking up a touch screen mid-game brings the on-screen controls back; any other device hides them again
	player.controls.visible = input_type == player.controls.InputType.TOUCH


func _set_level_hud_visible(shown: bool) -> void:
	for path: NodePath in hidden_while_in_use:
		var layer: Node = get_node_or_null(path)
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = shown
		elif layer is CanvasItem:
			(layer as CanvasItem).visible = shown

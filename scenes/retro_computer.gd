class_name RetroComputer
extends StaticBody3D
## A beige desktop computer the Player sits down at: the "action" look-at interaction puts them in the
## chair, starts the typing animation, and moves the view onto the CRT, a [SubViewport] running [Doom].
## Every input goes to the game until "start" gets them up again.
##
## The view stays a camera in the room rather than a full-screen cut, so the monitor reads as an object
## on the desk: the bezel, the keyboard and the Player's own shoulders stay in frame, and their head turns
## down onto the CRT. That is also why [member show_keymap_card] defaults to false, since the full-screen
## key list letterboxes the shot; the game's own HUD stays up instead, re-labelled for DOOM.

## The overlay's plain-text device names, indexed by the player controller's Controls.InputType.
const INPUT_TYPE_NAMES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]

@export var hidden_while_in_use: Array[NodePath] = [] ## HUD layers of the level (the clock and weather, say) to hide while the Player is at the keyboard.

@export_group("Seated view")
@export var seated_camera_position: Vector3 = Vector3(0.46, 1.5, 0.9) ## Where the view settles in third person, in the computer's own space. Over the Player's right shoulder: closer than this and their own upper arm swings across the lens.
@export var seated_camera_target: Vector3 = Vector3(0.0, 1.06, 0.092) ## What it looks at: the middle of the CRT, up on its stand.
@export var seated_camera_fov: float = 36.0 ## Narrow enough for the screen to be readable, wide enough to keep the bezel, the desk and the room around it.
@export var first_person_camera_position: Vector3 = Vector3(0.0, 1.06, 0.40) ## Where the view sits when the Player's camera is in first person: level with the middle of the CRT and on its axis, so the screen is square to the view rather than seen across.
@export var first_person_camera_fov: float = 50.0 ## Frames the whole monitor at that distance, with the room at the sides, since a 4:3 CRT never fills a 16:9 frame.
@export var view_move_time: float = 0.7 ## Seconds the view takes to travel from the Player's own camera into the seat.
@export var show_keymap_card: bool = false ## The full-screen list of keys. Off by default: it fills the edges of the frame and breaks the illusion that the monitor is in the room.

var player: Player ## The Player looking at or using the computer.
var is_in_use: bool = false

var _view_tween: Tween

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var controls_overlay: PureDoomControlsOverlay = $ControlsOverlay
@onready var screen_camera: Camera3D = $ScreenCamera
@onready var screen: MeshInstance3D = $Screen
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var doom: Doom = $ScreenViewport/Doom
@onready var player_seat: Marker3D = $Chair/PlayerSeat


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
	action_prompt.show_for(player.controls, "Use")


## Called by [Camera] when the player looks away from the computer.
func hide_menu() -> void:
	action_prompt.hide_for(player.controls)


## Called by [Camera] when the player presses "action" while looking at the computer.
func equip(_player: Player) -> void:
	if is_in_use or _player.is_riding or _player.is_ragdolling:
		return
	player = _player
	is_in_use = true
	# A previous visit may still be waiting for the lead-out to finish before standing the Player up.
	# Sitting down again cancels it, or it fires mid-session and stands them up at the keyboard.
	if player.locomotion_node_changed.is_connected(_on_player_locomotion_node_changed):
		player.locomotion_node_changed.disconnect(_on_player_locomotion_node_changed)
	action_prompt.hide_for(player.controls)
	_seat_player()
	_begin_seated_view()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.crosshair.hide()
	_set_level_hud_visible(false)
	_show_doom_controls()
	player.controls.input_type_changed.connect(_on_input_type_changed)
	if show_keymap_card:
		_on_input_type_changed(player.controls.current_input_type)
		controls_overlay.show()
	doom.boot()
	set_process_input(true)


## Puts the Player in the chair and starts them typing. The AnimationTree does the rest: [code]is_sitting[/code]
## takes it into Sitting and [code]is_typing_at_keyboard[/code] runs the Sitting -> SittingToTyping ->
## SittingTyping chain, the same way the car's enter animation is driven.
func _seat_player() -> void:
	player.velocity = Vector3.ZERO
	player.warp_to(player_seat.global_transform)
	player.state_machine.travel(player.current_state, NodeStateMachine.States.SITTING)
	player.is_typing_at_keyboard = true
	player.is_paused = true
	# The typing animation holds the head straight ahead, which from this desk means staring past the
	# monitor. The head-only modifier turns it down onto the CRT without disturbing the hands.
	player.set_head_look_at_target(screen)


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
	player.is_typing_at_keyboard = false
	player.is_paused = false
	player.set_head_look_at_target(null)
	_end_seated_view()
	player.controls.reset_labels()
	player.controls.show()
	player.crosshair.show()
	# A Player knocked out of the chair is already in Ragdolling, which travels itself back to Standing
	if player.is_ragdolling:
		return
	# Otherwise let the lead-out play first: the cleared flag runs SittingTyping -> TypingToSitting ->
	# Sitting, and the locomotion path tells us when it has landed there.
	if not player.locomotion_node_changed.is_connected(_on_player_locomotion_node_changed):
		player.locomotion_node_changed.connect(_on_player_locomotion_node_changed)


## Stands the Player up once the typing lead-out has returned the tree to the plain sitting pose.
func _on_player_locomotion_node_changed(state_path: String) -> void:
	if is_in_use:
		return # they sat back down before the lead-out finished
	if state_path != "Sitting":
		return
	player.locomotion_node_changed.disconnect(_on_player_locomotion_node_changed)
	player.state_machine.travel(NodeStateMachine.States.SITTING, NodeStateMachine.States.STANDING)
	var camera: Camera = player.camera as Camera
	if camera and camera.looking_at == self:
		display_menu(player)


## Travels the view from wherever the Player's camera was into the seat, so sitting down is a move
## through the room rather than a cut to a screen.
func _begin_seated_view() -> void:
	var from: Transform3D = player.camera.global_transform if is_instance_valid(player.camera) \
			else screen_camera.global_transform
	# First person means the Player is looking through their own eyes, so give them the screen square on
	# rather than the over-the-shoulder shot, and take the view off their camera to do it.
	var view_camera: Camera = player.camera as Camera
	var first_person: bool = view_camera != null and view_camera.perspective == Camera.Perspective.FIRST_PERSON
	var where: Vector3 = first_person_camera_position if first_person else seated_camera_position
	var to: Transform3D = Transform3D(Basis(), to_global(where)).looking_at(to_global(seated_camera_target), Vector3.UP)
	screen_camera.fov = first_person_camera_fov if first_person else seated_camera_fov
	screen_camera.global_transform = from
	screen_camera.current = true
	if _view_tween and _view_tween.is_valid():
		_view_tween.kill()
	_view_tween = create_tween()
	_view_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_method(_set_view_progress.bind(from, to), 0.0, 1.0, view_move_time)


func _set_view_progress(weight: float, from: Transform3D, to: Transform3D) -> void:
	screen_camera.global_transform = from.interpolate_with(to, weight)


func _end_seated_view() -> void:
	if _view_tween and _view_tween.is_valid():
		_view_tween.kill()
	if is_instance_valid(player.camera):
		player.camera.current = true


## Re-labels the HUD for DOOM rather than for the player controller: at the keyboard the shoulder buttons are
## not Stealth and Focus, they are Fire and Weapons. Every name here comes from the godot_doom_gdextension
## controls resource, so the HUD and the key card never disagree.
##
## The set differs by device because the HUD's key glyphs are fixed (WASD, IJKL, the arrows) while a pad has
## its own buttons. On a keyboard DOOM really does take WASD to move and strafe and the arrows to turn, so
## those are named honestly; its other keys have no glyph on this HUD (Ctrl to fire, Space to use, 1-7 for
## weapons, Tab for the automap, Esc to leave) and only the key card can show them, which is what
## [member show_keymap_card] is for. IJKL are blanked by hand because [method Controls.set_labels] otherwise
## mirrors the d-pad onto them, which would print "Automap" on the I key, where DOOM has nothing.
func _show_doom_controls() -> void:
	var controls: Controls = player.controls
	var labels: Dictionary = {}
	if controls.current_input_type == controls.InputType.KEYBOARD_MOUSE:
		# Only these two render: set_labels mirrors the sticks onto them, and they are the WASD and arrow
		# clusters, the one part of DOOM's keyboard scheme this HUD's fixed glyphs actually match.
		labels = {
			controls.key_s_label: "Move, strafe",
			controls.key_down_label: "Turn",
		}
	else:
		labels = {
			controls.joypad_axis_5_plus_label: "Fire",
			controls.joypad_button_2_label: "Fire",
			controls.joypad_button_0_label: "Use, open",
			controls.joypad_button_1_label: "Menu: pick",
			controls.joypad_button_3_label: "Run (hold)",
			controls.joypad_button_11_label: "Automap",
			controls.joypad_button_12_label: "DOOM menu",
			controls.joypad_button_13_label: "Weapon",
			controls.joypad_button_14_label: "Weapon",
			controls.joypad_button_6_label: "Get Up",
			controls.left_joystick_label: "Move",
			controls.right_joystick_label: "Turn",
		}
	controls.set_labels(labels)
	controls.show()


func _on_input_type_changed(input_type: int) -> void:
	controls_overlay.input_type = INPUT_TYPE_NAMES[input_type]
	# Swapping device re-applies the Controls' defaults, so the seated labels have to be put back
	if is_in_use:
		_show_doom_controls()


func _set_level_hud_visible(shown: bool) -> void:
	for path: NodePath in hidden_while_in_use:
		var layer: Node = get_node_or_null(path)
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = shown
		elif layer is CanvasItem:
			(layer as CanvasItem).visible = shown

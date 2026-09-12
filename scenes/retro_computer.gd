class_name RetroComputer
extends StaticBody3D
## A beige desktop computer the Player sits down at: the "action" look-at interaction puts them in the
## chair, starts the typing animation, and moves the view onto the CRT, a [SubViewport] running [Doom].
## Every input goes to the game until "start" gets them up again.
##
## The view stays a camera in the room rather than a full-screen cut, so the monitor reads as an object
## on the desk: the bezel, the keyboard and the Player's own shoulders stay in frame, and their head turns
## down onto the CRT. While they are seated the Player's own HUD steps aside for DOOM's, which the DOOM addon
## ships as a scene: the same buttons in the same places, saying what DOOM does with them and drawing the keys
## DOOM answers to. It is the HUD rather than a list of keys beside the monitor for the same reason the view
## is a camera in the room - a full-screen card letterboxes the shot and breaks the illusion.

@export var hidden_while_in_use: Array[NodePath] = [] ## HUD layers of the level (the clock and weather, say) to hide while the Player is at the keyboard.

@export_group("Seated view")
@export var seated_camera_position: Vector3 = Vector3(0.46, 1.5, 0.9) ## Where the view settles in third person, in the computer's own space. Over the Player's right shoulder: closer than this and their own upper arm swings across the lens.
@export var seated_camera_target: Vector3 = Vector3(0.0, 1.06, 0.092) ## What it looks at: the middle of the CRT, up on its stand.
@export var seated_camera_fov: float = 36.0 ## Narrow enough for the screen to be readable, wide enough to keep the bezel, the desk and the room around it.
@export var first_person_camera_position: Vector3 = Vector3(0.0, 1.06, 0.40) ## Where the view sits when the Player's camera is in first person: level with the middle of the CRT and on its axis, so the screen is square to the view rather than seen across.
@export var first_person_camera_fov: float = 50.0 ## Frames the whole monitor at that distance, with the room at the sides, since a 4:3 CRT never fills a 16:9 frame.
@export var view_move_time: float = 0.7 ## Seconds the view takes to travel from the Player's own camera into the seat.

var player: Player ## The Player looking at or using the computer.
var is_in_use: bool = false

var _view_tween: Tween

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var doom_controls: PureDoomControls = $DoomControls
@onready var screen_camera: Camera3D = $ScreenCamera
@onready var screen: MeshInstance3D = $Screen
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var doom: Doom = $ScreenViewport/Doom
@onready var player_seat: Marker3D = $Chair/PlayerSeat


func _ready() -> void:
	set_process_input(false)
	# DOOM's HUD is only ever hand-fed events by this node's own _input, because everything that reaches the
	# game has already been marked handled by then. Left listening it would also answer the share button and
	# take screenshots while the Player is walking around the level, which is not its screen to claim.
	doom_controls.set_process_input(false)
	doom_controls.set_process(false)
	# The CRT reads the viewport at runtime; a ViewportTexture saved in the scene cannot find the viewport while the
	# editor exports the project and logs an invalid path
	(screen.material_override as ShaderMaterial).set_shader_parameter(&"screen_texture", screen_viewport.get_texture())


## Only runs while the Player is at the keyboard: "start" leaves, everything else goes to the game.
func _input(event: InputEvent) -> void:
	# A Player knocked down at the keyboard gets their camera back rather than staying stuck on the screen
	if not is_instance_valid(player) or player.is_ragdolling:
		stop_using()
		return
	# The Controls detect the device in their own _input, which never runs once this one marks the event
	# handled. While seated that is DOOM's HUD rather than the Player's, since that is the one on screen.
	doom_controls._input(event)
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
	# DOOM's HUD takes the screen while the Player's steps aside. Both are the same buttons in the same
	# places, so swapping them reads as the words changing rather than as a HUD appearing.
	player.controls.hide()
	doom_controls.current_input_type = player.controls.current_input_type
	doom_controls.show()
	doom_controls.set_process(true)
	# The weapon arms ask the engine what is in hand and what is being carried, and it does not exist until
	# the boot text has finished running. On a platform the PureDoom library is not built for it never
	# arrives at all, the raycaster stands in, and the arms stay quiet because there are no weapons to cycle.
	if not doom.engine_started.is_connected(_on_engine_started):
		doom.engine_started.connect(_on_engine_started)
	doom.boot()
	set_process_input(true)


func _on_engine_started(engine_node: Control) -> void:
	doom_controls.game = engine_node


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
	doom_controls.hide()
	doom_controls.set_process(false)
	doom_controls.game = null
	_set_level_hud_visible(true)
	if not is_instance_valid(player):
		player = null
		return
	# The Player's HUD never saw the events that went to the game, so it is told which device is in hand
	# rather than being left showing whatever was in use when they sat down.
	player.controls.current_input_type = doom_controls.current_input_type
	player.is_typing_at_keyboard = false
	player.is_paused = false
	player.set_head_look_at_target(null)
	_end_seated_view()
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


func _set_level_hud_visible(shown: bool) -> void:
	for path: NodePath in hidden_while_in_use:
		var layer: Node = get_node_or_null(path)
		if layer is CanvasLayer:
			(layer as CanvasLayer).visible = shown
		elif layer is CanvasItem:
			(layer as CanvasItem).visible = shown

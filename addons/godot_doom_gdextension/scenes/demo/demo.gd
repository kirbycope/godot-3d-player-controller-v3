class_name PureDoomDemo
extends Control
## Runs the PureDoom GDExtension full screen with the controls card down each side, the on-screen pad for a
## player with no keyboard, and, when Godot MIDI Player is in the project, DOOM's music through the bundled
## SoundFont. Where the library is not built for the platform the screen says so instead.

const MIDI_PLAYER_SCENE: String = "res://addons/midi/MidiPlayer.tscn" ## Optional: no music without it.
const SOUNDFONT: String = "res://addons/godot_doom_gdextension/assets/gzdoom.sf2"
## The node defaults to this path too, but the libraries in bin/ were built when the addon lived at
## addons/pure_doom, so they still bake in the old one. Setting it here works on every platform.
const WAD: String = "res://addons/godot_doom_gdextension/assets/doom1.wad"
const CARD_INSET: float = 170.0 ## Room down each side of the monitor for the controls card.
## Room for the on-screen pad: the thumb clusters in the bottom corners, the shoulder row across the top and
## the face buttons down the right all reach further in than the card does.
const PAD_INSET_SIDE: float = 190.0
const PAD_INSET_TOP: float = 130.0
const PAD_INSET_BOTTOM: float = 160.0

var engine: Control ## The PureDoom node, null where the library is missing.
var midi_player: Node ## Synthesises the engine's music, null without Godot MIDI Player.
var mouse_captured: bool = false ## Whether the demo is holding the cursor for DOOM's mouse look.
## Whether there is a cursor worth capturing. DOOM turns on relative mouse motion, which a touchscreen has
## none of, and a held pointer makes the browser's emulated mouse events look like a keyboard to the pad.
var uses_mouse: bool = true

@onready var screen: Container = $Screen
@onready var missing: Label = $Missing
@onready var overlay: PureDoomControlsOverlay = $PureDoomControlsOverlay
@onready var virtual_pad: PureDoomVirtualPad = $VirtualPad
@onready var click_to_start: CanvasLayer = $ClickToStart


func _ready() -> void:
	if not ClassDB.class_exists(&"PureDoom"):
		missing.show()
		return
	engine = ClassDB.instantiate(&"PureDoom") as Control
	engine.name = "PureDoom"
	engine.set(&"wad_path", WAD)
	engine.connect(&"exited", _on_engine_exited)
	screen.add_child(engine)
	_start_music()
	uses_mouse = not DisplayServer.is_touchscreen_available()
	# A touch arrives as an emulated mouse click too, and DOOM fires on mouse left, so without this every tap
	# anywhere on screen shoots - including the one that pushes the stick. The engine wants a real mouse's
	# relative motion; it has no use for a phone's invented one.
	Input.emulate_mouse_from_touch = false
	virtual_pad.device_changed.connect(_on_device_changed)
	_on_device_changed(virtual_pad.card_input_type())
	# The browser only grants pointer lock from inside a user gesture, so on web the interstitial waits for
	# a click and captures then. Everywhere else the capture takes hold straight away.
	click_to_start.visible = OS.has_feature("web")
	if uses_mouse:
		capture_mouse()
	engine.call(&"start")


## The card beside the monitor words itself for the device in hand. On a phone it steps aside for the pad,
## whose buttons say what they do themselves, and the monitor pulls in to leave the thumb clusters clear.
func _on_device_changed(card_input_type: String) -> void:
	overlay.input_type = card_input_type
	var touch: bool = card_input_type == "touch"
	overlay.visible = not touch
	screen.offset_left = PAD_INSET_SIDE if touch else CARD_INSET
	screen.offset_right = -screen.offset_left
	screen.offset_top = PAD_INSET_TOP if touch else 0.0
	screen.offset_bottom = -PAD_INSET_BOTTOM if touch else 0.0


## Wires DOOM's 140 Hz MIDI stream into Godot MIDI Player when that addon is present.
func _start_music() -> void:
	if not ResourceLoader.exists(MIDI_PLAYER_SCENE):
		return
	midi_player = (load(MIDI_PLAYER_SCENE) as PackedScene).instantiate()
	midi_player.set(&"soundfont", SOUNDFONT)
	add_child(midi_player)
	_force_stream_playback()
	engine.connect(&"midi_message", Callable(midi_player, &"receive_raw_midi_message"))


## Godot's web export plays an AudioStreamWAV as a sample by default, handing it straight to WebAudio and
## skipping the bus chain and the per-note volume the synthesiser writes every frame, so the music comes out
## silent while DOOM's own sound, an AudioStreamGenerator that cannot be sampled, still plays. The voices want
## stream playback, which is what every other platform gives them anyway.
func _force_stream_playback() -> void:
	for player: AudioStreamPlayer in midi_player.get(&"audio_stream_players"):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		var linked: AudioStreamPlayer = player.get_node(^"Linked") as AudioStreamPlayer
		if linked != null:
			linked.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


## DOOM turns with relative mouse motion, so the cursor is hidden and held in the window while it plays.
func capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Escape gives the cursor back rather than trapping it; DOOM's own menu is on backquote.
func release_mouse() -> void:
	mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if engine == null:
		return
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if click_to_start.visible:
		if pressed:
			click_to_start.hide()
			if uses_mouse:
				capture_mouse()
		return
	if event.is_action_pressed(&"ui_cancel"):
		release_mouse()
	elif pressed and uses_mouse and not mouse_captured:
		capture_mouse()


## DOOM quit itself (its menu's Quit Game, or an error), so say so, free the cursor and stop the music.
func _on_engine_exited(code: int) -> void:
	if is_instance_valid(midi_player):
		midi_player.call(&"stop")
	if is_instance_valid(engine):
		engine.hide()
	missing.text = "DOOM exited with code %d." % code
	missing.show()
	overlay.hide()
	release_mouse()

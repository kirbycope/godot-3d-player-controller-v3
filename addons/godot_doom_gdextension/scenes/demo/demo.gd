class_name PureDoomDemo
extends Control
## Runs the PureDoom GDExtension full screen with the controls card down each side and, when Godot MIDI
## Player is in the project, DOOM's music through the bundled SoundFont. Where the library is not built for
## the platform the screen says so instead.

const MIDI_PLAYER_SCENE: String = "res://addons/midi/MidiPlayer.tscn" ## Optional: no music without it.
const SOUNDFONT: String = "res://addons/godot_doom_gdextension/assets/gzdoom.sf2"
## The node defaults to this path too, but the libraries in bin/ were built when the addon lived at
## addons/pure_doom, so they still bake in the old one. Setting it here works on every platform.
const WAD: String = "res://addons/godot_doom_gdextension/assets/doom1.wad"

var engine: Control ## The PureDoom node, null where the library is missing.
var midi_player: Node ## Synthesises the engine's music, null without Godot MIDI Player.
var mouse_captured: bool = false ## Whether the demo is holding the cursor for DOOM's mouse look.

@onready var screen: Container = $Screen
@onready var missing: Label = $Missing
@onready var overlay: PureDoomControlsOverlay = $PureDoomControlsOverlay
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
	overlay.show()
	# The browser only grants pointer lock from inside a user gesture, so on web the interstitial waits for
	# a click and captures then. Everywhere else the capture takes hold straight away.
	click_to_start.visible = OS.has_feature("web")
	capture_mouse()
	engine.call(&"start")


## Wires DOOM's 140 Hz MIDI stream into Godot MIDI Player when that addon is present.
func _start_music() -> void:
	if not ResourceLoader.exists(MIDI_PLAYER_SCENE):
		return
	midi_player = (load(MIDI_PLAYER_SCENE) as PackedScene).instantiate()
	midi_player.set(&"soundfont", SOUNDFONT)
	add_child(midi_player)
	engine.connect(&"midi_message", Callable(midi_player, &"receive_raw_midi_message"))


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
			capture_mouse()
		return
	if event.is_action_pressed(&"ui_cancel"):
		release_mouse()
	elif pressed and not mouse_captured:
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

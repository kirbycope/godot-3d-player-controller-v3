extends Node3D

@export_file("*.tscn") var single_player_scene: String

@onready var click_to_start: CanvasLayer = $ClickToStart
@onready var title_screen: TitleScreen = $TitleScreen
@onready var lobby_explorer: LobbyExplorer = $LobbyExplorer
@onready var loading: Loading = $Loading


## The layouts this game offers on top of the player controller's own, announced before any settings menu is
## built. GTA ships with the gta addon rather than the player controller, which must not preload across addons.
const EXTRA_CONTROL_SCHEMES: Array[ControlScheme] = [
	preload("res://addons/gta/resources/gta_controls.tres"),
]


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for scheme: ControlScheme in EXTRA_CONTROL_SCHEMES:
		PlayerControls.register_scheme(scheme)
	# [Webfix] Browsers require a user gesture before capturing the mouse and playing audio
	var requires_input_activation: bool = ProjectSettings.get_setting("rendering/renderer/rendering_method") not in ["forward_plus", "mobile"]
	# Two starts on purpose: the desktop and the editor open on the title screen and its buttons; the web export
	# opens on Click to Start and the click goes straight into single player, since there is no Steam there
	click_to_start.visible = requires_input_activation
	title_screen.visible = not requires_input_activation


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if click_to_start.visible and event.is_pressed() and (event is InputEventScreenTouch or event is InputEventMouseButton):
		_dismiss_click_to_start()


## Called when an input event is not handled by the GUI.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.is_pressed() and not event.is_echo():
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			if click_to_start.visible:
				_dismiss_click_to_start()
				return
			var focused_control: Control = get_viewport().gui_get_focus_owner()
			if focused_control is BaseButton:
				(focused_control as BaseButton).pressed.emit()
			else:
				title_screen.default_button().pressed.emit()


## Hides the click-to-start overlay and goes straight into the single-player world: the click is the start of
## the game on the web, not a reveal of the title screen.
func _dismiss_click_to_start() -> void:
	click_to_start.hide()
	single_player()


func single_player() -> void:
	if not single_player_scene.is_empty():
		loading.load_scene(single_player_scene)


## Continue: the world loads as for a new game, and its SaveGame reads the file once the Player is in.
func continue_game() -> void:
	SaveGame.load_requested = true
	single_player()


func multi_player() -> void:
	title_screen.hide()
	lobby_explorer.show()
	lobby_explorer.refresh_lobbies()

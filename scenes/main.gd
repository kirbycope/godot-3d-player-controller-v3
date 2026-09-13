extends Node3D

@export_file("*.tscn") var single_player_scene: String

## Whether the game goes straight into the single-player world instead of showing the title screen. On the web
## the Click to Start overlay still comes first, because a browser lets the game capture the mouse and play
## audio only from inside a user gesture; the click then starts the game rather than revealing the title.
@export var straight_to_single_player: bool = true

@onready var click_to_start: CanvasLayer = $ClickToStart
@onready var title_screen: TitleScreen = $TitleScreen
@onready var lobby_explorer: LobbyExplorer = $LobbyExplorer
@onready var loading: Loading = $Loading


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# [Webfix] Browsers require a user gesture before capturing the mouse and playing audio
	var requires_input_activation: bool = ProjectSettings.get_setting("rendering/renderer/rendering_method") not in ["forward_plus", "mobile"]
	click_to_start.visible = requires_input_activation
	title_screen.visible = not requires_input_activation and not straight_to_single_player
	if straight_to_single_player and not requires_input_activation:
		single_player()


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
				title_screen.button_single_player.pressed.emit()


## Hides the click-to-start overlay and starts the game, or reveals the title screen when that is wanted.
func _dismiss_click_to_start() -> void:
	click_to_start.hide()
	if straight_to_single_player:
		single_player()
		return
	title_screen.show()
	title_screen.button_single_player.grab_focus()


func single_player() -> void:
	if not single_player_scene.is_empty():
		loading.load_scene(single_player_scene)


func multi_player() -> void:
	title_screen.hide()
	lobby_explorer.show()
	lobby_explorer.refresh_lobbies()

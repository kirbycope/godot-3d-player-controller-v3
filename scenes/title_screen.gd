class_name TitleScreen
extends CanvasLayer

signal new_game_pressed ## New Game: a fresh single-player world, nothing loaded.
signal continue_pressed ## Continue: the saved game, loaded once the world is in.
signal multi_player_pressed

@onready var menu_main: VBoxContainer = $VBoxContainer
@onready var menu_single_player: VBoxContainer = $VBoxContainer_SinglePlayer ## The New Game / Continue panel behind Single-Player.
@onready var button_single_player: Button = $VBoxContainer/Button_SinglePlayer
@onready var button_multi_player: Button = $VBoxContainer/Button_MultiPlayer
@onready var button_options: Button = $VBoxContainer/HBoxContainer/Button_Options
@onready var button_quit: Button = $VBoxContainer/HBoxContainer/Button_Quit
@onready var button_new_game: Button = $VBoxContainer_SinglePlayer/Button_NewGame
@onready var button_continue: Button = $VBoxContainer_SinglePlayer/Button_Continue ## Shown while a save exists at the SaveGame's default path.
@onready var button_back: Button = $VBoxContainer_SinglePlayer/Button_Back
@onready var label_version: Label = $Label_Version
@onready var label_copyright: Label = $Label_Copyright


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_continue.visible = SaveGame.has_save_at()
	show_main_menu()
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if not version.is_empty():
		label_version.text = version if version.begins_with("v") else "v" + version
	label_copyright.text = "© Timothy Cope %d" % Time.get_date_dict_from_system().year


## Called when an input event is not handled by the GUI. Backs out of the single-player panel on Cancel (B).
func _unhandled_input(event: InputEvent) -> void:
	if visible and menu_single_player.visible and event.is_action_pressed("ui_cancel"):
		show_main_menu()
		get_viewport().set_input_as_handled()


## The top-level menu: Single-Player, Multi-Player, Options and Quit.
func show_main_menu() -> void:
	menu_single_player.hide()
	menu_main.show()
	button_single_player.grab_focus()


## The panel behind Single-Player: New Game, Continue while a save exists, and Back.
func show_single_player_menu() -> void:
	menu_main.hide()
	menu_single_player.show()
	if button_continue.visible:
		button_continue.grab_focus()
	else:
		button_new_game.grab_focus()


## The button a controller's Accept press should activate while nothing holds focus.
func default_button() -> Button:
	if not menu_single_player.visible:
		return button_single_player
	return button_continue if button_continue.visible else button_new_game


func _on_button_single_player_pressed() -> void:
	show_single_player_menu()


func _on_touch_screen_button_single_player_pressed() -> void:
	_on_button_single_player_pressed()


func _on_button_new_game_pressed() -> void:
	new_game_pressed.emit()


func _on_touch_screen_button_new_game_pressed() -> void:
	_on_button_new_game_pressed()


func _on_button_continue_pressed() -> void:
	continue_pressed.emit()


func _on_touch_screen_button_continue_pressed() -> void:
	_on_button_continue_pressed()


func _on_button_back_pressed() -> void:
	show_main_menu()


func _on_touch_screen_button_back_pressed() -> void:
	_on_button_back_pressed()


func _on_button_multi_player_pressed() -> void:
	multi_player_pressed.emit()


func _on_touch_screen_button_multi_player_pressed() -> void:
	_on_button_multi_player_pressed()


func _on_button_options_pressed() -> void:
	pass # Options screen not implemented yet.


func _on_touch_screen_button_options_pressed() -> void:
	_on_button_options_pressed()


func _on_button_quit_pressed() -> void:
	get_tree().quit()


func _on_touch_screen_button_quit_pressed() -> void:
	_on_button_quit_pressed()

class_name TitleScreen
extends CanvasLayer

signal new_game_pressed ## New Game: a fresh single-player world, nothing loaded.
signal continue_pressed(slot: int, scene_path: String) ## Continue: save number [param slot], loaded into its own level at [param scene_path].
signal multi_player_pressed

@onready var menu_main: VBoxContainer = $VBoxContainer
@onready var menu_single_player: VBoxContainer = $VBoxContainer_SinglePlayer ## The New Game / Continue panel behind Single-Player.
@onready var button_single_player: Button = $VBoxContainer/Button_SinglePlayer
@onready var button_multi_player: Button = $VBoxContainer/Button_MultiPlayer
@onready var button_options: Button = $VBoxContainer/HBoxContainer/Button_Options
@onready var button_quit: Button = $VBoxContainer/HBoxContainer/Button_Quit
@onready var button_new_game: Button = $VBoxContainer_SinglePlayer/Button_NewGame
@onready var button_continue: Button = $VBoxContainer_SinglePlayer/Button_Continue ## Shown while there is a save to continue.
@onready var saves_panel: Panel = $Panel_Saves ## Continue's list of saves, one row each with its preview.
@onready var save_list: VBoxContainer = $Panel_Saves/VBoxContainer/ScrollContainer/SaveList
@onready var button_saves_back: Button = $Panel_Saves/VBoxContainer/Button_SavesBack

const SAVE_SLOT_BUTTON: PackedScene = preload("res://scenes/save_slot_button.tscn")
@onready var button_back: Button = $VBoxContainer_SinglePlayer/Button_Back
@onready var label_version: Label = $Label_Version
@onready var label_copyright: Label = $Label_Copyright
@onready var settings: PlayerMenuLayer = $Settings ## The player controller's settings menu, opened by Options. Its pages are siblings, wired to one another in the scene.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_continue.visible = not SaveGame.list_saves().is_empty()
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
	elif visible and saves_panel.visible and event.is_action_pressed("ui_cancel"):
		show_single_player_menu()
		get_viewport().set_input_as_handled()


## The top-level menu: Single-Player, Multi-Player, Options and Quit.
func show_main_menu() -> void:
	menu_single_player.hide()
	saves_panel.hide()
	menu_main.show()
	button_single_player.grab_focus()


## The panel behind Single-Player: New Game, Continue while a save exists, and Back.
func show_single_player_menu() -> void:
	menu_main.hide()
	saves_panel.hide()
	menu_single_player.show()
	if button_continue.visible:
		button_continue.grab_focus()
	else:
		button_new_game.grab_focus()


## Continue's list: every save, lowest number first, with its preview, level and when it was taken. The panel keeps
## its size and scrolls however many there are.
func show_saves() -> void:
	menu_single_player.hide()
	for row: Node in save_list.get_children():
		save_list.remove_child(row) # out now, not at the end of the frame, so the new rows keep their names and the focus lands on one of them
		row.queue_free()
	for save: Dictionary in SaveGame.list_saves():
		var row: SaveSlotButton = SAVE_SLOT_BUTTON.instantiate()
		row.name = "Save%d" % int(save["slot"])
		save_list.add_child(row)
		row.show_save(save)
		row.chosen.connect(_on_save_chosen)
	saves_panel.show()
	_focus_first_row.call_deferred()


## Deferred from show_saves, so a row added this frame can take the focus. It reads the list when it runs rather than
## holding a row, since a second show_saves in the same frame has replaced the rows by then.
func _focus_first_row() -> void:
	var first: Control = save_list.get_child(0) as Control if save_list.get_child_count() > 0 else button_saves_back
	if first.is_inside_tree():
		first.grab_focus()


func _on_save_chosen(slot: int, scene_path: String) -> void:
	continue_pressed.emit(slot, scene_path)


func _on_button_saves_back_pressed() -> void:
	show_single_player_menu()


## The button a controller's Accept press should activate while nothing holds focus; none while the settings are up.
func default_button() -> Button:
	if saves_panel.visible:
		return save_list.get_child(0) as Button if save_list.get_child_count() > 0 else button_saves_back
	if menu_single_player.visible:
		return button_continue if button_continue.visible else button_new_game
	return button_single_player if menu_main.visible else null


func _on_button_single_player_pressed() -> void:
	show_single_player_menu()


func _on_touch_screen_button_single_player_pressed() -> void:
	_on_button_single_player_pressed()


func _on_button_new_game_pressed() -> void:
	new_game_pressed.emit()


func _on_touch_screen_button_new_game_pressed() -> void:
	_on_button_new_game_pressed()


func _on_button_continue_pressed() -> void:
	show_saves()


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
	menu_main.hide()
	settings.show_menu()


func _on_touch_screen_button_options_pressed() -> void:
	_on_button_options_pressed()


func _on_button_quit_pressed() -> void:
	get_tree().quit()


func _on_touch_screen_button_quit_pressed() -> void:
	_on_button_quit_pressed()


## The settings menu's Back (connected in the scene) closes it and gives the title its menu back, focus on Options.
func _on_settings_back_pressed() -> void:
	settings.hide()
	menu_main.show()
	button_options.grab_focus()

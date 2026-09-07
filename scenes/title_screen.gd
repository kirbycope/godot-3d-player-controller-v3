class_name TitleScreen
extends CanvasLayer

signal single_player_pressed
signal multi_player_pressed

@onready var button_single_player: Button = $VBoxContainer/Button_SinglePlayer
@onready var button_multi_player: Button = $VBoxContainer/Button_MultiPlayer
@onready var button_options: Button = $VBoxContainer/HBoxContainer/Button_Options
@onready var button_quit: Button = $VBoxContainer/HBoxContainer/Button_Quit
@onready var label_version: Label = $Label_Version
@onready var label_copyright: Label = $Label_Copyright


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_single_player.grab_focus()
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if not version.is_empty():
		label_version.text = version if version.begins_with("v") else "v" + version
	label_copyright.text = "© Timothy Cope %d" % Time.get_date_dict_from_system().year


func _on_button_single_player_pressed() -> void:
	single_player_pressed.emit()


func _on_touch_screen_button_single_player_pressed() -> void:
	_on_button_single_player_pressed()


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

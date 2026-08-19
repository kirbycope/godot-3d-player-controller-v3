extends CanvasLayer

signal single_player_pressed
signal multi_player_pressed

@onready var button_single_player: Button = $VBoxContainer/Button_SinglePlayer
@onready var button_multi_player: Button = $VBoxContainer/Button_MultiPlayer
@onready var button_options: Button = $VBoxContainer/HBoxContainer/Button_Options
@onready var button_quit: Button = $VBoxContainer/HBoxContainer/Button_Quit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_single_player.grab_focus()


func _on_button_single_player_pressed() -> void:
	single_player_pressed.emit()


func _on_touch_screen_button_single_player_pressed() -> void:
	_on_button_single_player_pressed()


func _on_button_multi_player_pressed() -> void:
	multi_player_pressed.emit()


func _on_touch_screen_button_multi_player_pressed() -> void:
	_on_button_multi_player_pressed()


func _on_button_options_pressed() -> void:
	pass # Replace with function body.


func _on_touch_screen_button_options_pressed() -> void:
	_on_button_options_pressed()


func _on_button_quit_pressed() -> void:
	get_tree().quit()


func _on_touch_screen_button_quit_pressed() -> void:
	_on_button_quit_pressed()

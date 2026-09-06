class_name PureDoomControlsOverlay
extends CanvasLayer
## Two plain-text columns of DOOM controls, one down each side of the monitor, worded for the input device
## in use. Set [member input_type] from whatever detects the device; the text comes from [member controls].

@export var controls: PureDoomControls ## The card to show; resources/controls.tres by default.
@export var input_type: String = "keyboard": ## "keyboard", "xbox", "nintendo", "playstation" or "touch".
	set(value):
		input_type = value
		if is_node_ready():
			refresh()

@onready var movement: RichTextLabel = $Movement
@onready var actions: RichTextLabel = $Actions


func _ready() -> void:
	refresh()


## Rewrites both columns for the current input type.
func refresh() -> void:
	if controls == null:
		return
	movement.text = column("MOVEMENT", controls.movement)
	actions.text = column("ACTIONS", controls.actions)


## A title then one entry per line that has text for this device: the input in white, what it does beneath.
func column(title: String, lines: Array[PureDoomControl]) -> String:
	var text: String = "[color=white]%s[/color]\n" % title
	for line: PureDoomControl in lines:
		var input: String = line.text_for(input_type)
		if input != "":
			text += "\n[color=white]%s[/color]\n  %s\n" % [input, line.label]
	return text

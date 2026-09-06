class_name PureDoomControl
extends Resource
## One line of the controls card: what a DOOM action is called and the plain-text input for it on each device.
## Leave a device's text empty to drop the line for that device.

@export var label: String = "" ## What it does: "Fire", "Use", "Forward".
@export var keyboard: String = "" ## Keyboard and mouse: "Space", "Left click, Ctrl".
@export var xbox: String = "" ## Xbox pad, also shown on touch: "A", "RT, X".
@export var nintendo: String = "" ## Nintendo pad: "B", "ZR, Y".
@export var playstation: String = "" ## PlayStation pad: "Cross", "R2, Square".


## The text for an input type: "keyboard", "xbox", "nintendo", "playstation" or "touch" (the Xbox text).
func text_for(input_type: String) -> String:
	match input_type:
		"xbox", "touch":
			return xbox
		"nintendo":
			return nintendo
		"playstation":
			return playstation
		_:
			return keyboard

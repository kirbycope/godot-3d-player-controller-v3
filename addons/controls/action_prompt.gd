@tool
class_name ActionPrompt
extends Node3D
## World-space "Press [button] to ..." prompt with one child per input type (KeyboardMouse, Microsoft, Nintendo, Sony).
##
## Hang one on anything the player can walk up to and interact with. It shows only the sub-prompt for the
## device being played on, which it reads off a [Controls] node, and it can name that node's bottom-action
## button after what it does ("Pick Up", "Get In") while it is up.

var _message_begin: String = "Press"
var _message_end: String = "to interact"

@export var message_begin: String = "Press":
	set(value):
		_message_begin = value
		update_text()
	get:
		return _message_begin

@export var message_end: String = "to interact":
	set(value):
		_message_end = value
		update_text()
	get:
		return _message_end

@onready var label_3d_1: Label3D = $KeyboardMouse/Label3D
@onready var label_3d_2: Label3D = $Microsoft/Label3D
@onready var label_3d_3: Label3D = $Nintendo/Label3D
@onready var label_3d_4: Label3D = $Sony/Label3D

@onready var label_3d_2_1: Label3D = $KeyboardMouse/Label3D2
@onready var label_3d_2_2: Label3D = $Microsoft/Label3D2
@onready var label_3d_2_3: Label3D = $Nintendo/Label3D2
@onready var label_3d_2_4: Label3D = $Sony/Label3D2


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()
	update_text()


## Shows only the sub-prompt matching [param controls]' current input type (child names mirror
## [enum Controls.InputType] keys in PascalCase). [param action_label] names the bottom-action button on those
## controls while the prompt is up ("Get In"): the label is kept on the [Controls] node, so every label refresh
## meanwhile re-applies it.
func show_for(controls: Controls, action_label: String = "") -> void:
	if not is_instance_valid(controls):
		return
	# There is no sub-prompt for touch; it borrows the Microsoft art, the way the HUD's own buttons do.
	var input_type: Controls.InputType = controls.current_input_type
	if input_type == Controls.InputType.TOUCH:
		input_type = Controls.InputType.MICROSOFT
	var type_name: String = String(Controls.InputType.keys()[input_type]).to_pascal_case()
	for child: Node3D in get_children():
		child.visible = child.name == type_name
	if action_label != "":
		controls.claim_action_label(action_label, self)
	show()


## Hides the prompt and gives the bottom-action button its label back (unless another prompt has taken it since).
func hide_for(controls: Controls) -> void:
	hide()
	if not is_instance_valid(controls):
		return
	controls.release_action_label(self)


## Hides the prompt and every sub-prompt.
func hide_all() -> void:
	for child: Node3D in get_children():
		child.hide()
	hide()


func update_text() -> void:
	if not is_node_ready():
		return

	label_3d_1.text = message_begin
	label_3d_2.text = message_begin
	label_3d_3.text = message_begin
	label_3d_4.text = message_begin
	label_3d_2_1.text = message_end
	label_3d_2_2.text = message_end
	label_3d_2_3.text = message_end
	label_3d_2_4.text = message_end

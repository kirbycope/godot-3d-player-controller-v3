@tool
extends Node3D

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

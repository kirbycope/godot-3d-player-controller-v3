extends Node3D

@export var message_begin: String = "Press"
@export var message_end: String = "to interact"

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
	update_text()


func update_text() -> void:
	label_3d_1.text = message_begin
	label_3d_2.text = message_begin
	label_3d_3.text = message_begin
	label_3d_4.text = message_begin
	label_3d_2_1.text = message_end
	label_3d_2_2.text = message_end
	label_3d_2_3.text = message_end
	label_3d_2_4.text = message_end

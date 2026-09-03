@tool
extends Node3D
## Spins a ring of balloons around the Z axis by rotating their pivot; the balloons themselves stay upright.

@export var clockwise: bool = true
@export var play: bool = true:
	set(value):
		play = value
		if not play and is_node_ready():
			pivot.rotation.z = 0.0
			for balloon: Node3D in pivot.get_children():
				balloon.rotation.z = 0.0
@export var pause_when_editor_unfocused: bool = true
@export_range(0.0, 360.0, 0.1, "suffix:deg/s") var rotation_speed_deg: float = 60.0
@export var show_balloon_string: bool = true:
	set(value):
		show_balloon_string = value
		if is_node_ready():
			for balloon: RedBalloon in pivot.get_children():
				balloon.balloon_string.visible = value

@onready var pivot: Node3D = $Pivot


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show_balloon_string = show_balloon_string
	play = play


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if pause_when_editor_unfocused and Engine.is_editor_hint() and not DisplayServer.window_is_focused():
		return
	if not play:
		return

	var direction: float = -1.0 if clockwise else 1.0
	pivot.rotate_z(deg_to_rad(rotation_speed_deg) * direction * delta)
	# Counter-rotate the balloons so they orbit without turning upside down
	for balloon: Node3D in pivot.get_children():
		balloon.rotation.z = -pivot.rotation.z

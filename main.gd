extends Node3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	$ClimbingWall/HowToStartClimbing.visible = not $Player.is_climbing
	$ClimbingWall/HowToClimb.visible = $Player.is_climbing


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		$Player.global_position = $"./CSGBox3D3/Marker3D".global_position#Vector3(0.0, 10.0, 4.0)


func _on_area_3d_body_exited(_body: Node3D) -> void:
	pass # Replace with function body.

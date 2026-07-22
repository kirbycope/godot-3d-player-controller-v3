extends Node3D

@onready var player: Player = $Player
@onready var project_rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get rendering settings from the project settings
	if project_rendering_method in ["forward_plus", "mobile"]:
		# Set the mouse mode to captured to hide the mouse cursor
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Show the Click to Start button
		$ClickToStart.visible = true


func _input(event: InputEvent) -> void:
	if $ClickToStart.visible:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			$ClickToStart.hide()


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		# If we're below -40, respawn (teleport to the initial position).
		if player.global_position.y < -40.0:
			player.global_position = Vector3(0.0, 0.0, 0.0)


func _on_warp_area_body_entered(body: Node3D) -> void:
	if body is Player:
		body.global_position = $WarpArea/WarpPointB.global_position


## Called when a body enters the "Pool"
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player:
		# Start swimming (if not already swimming and not in a car/vehicle)
		if not body.is_swimming and not body.is_driving and body.is_driving_in == null and not body.is_entering_vehicle and not body.is_exiting_vehicle:
			body.state_machine.travel(body.current_state, NodeStateMachine.States.SWIMMING)


## Called when a body exits the "Pool"
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is Player:
		# Stop swimming (if currently swimming)
		if body.is_swimming:
			body.is_swimming = false # This will trigger the `stop()` in `swimming.gd`

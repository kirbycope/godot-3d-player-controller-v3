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
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		# If we're below -40, respawn (teleport to the initial position).
		if player.global_position.y < -40.0:
			_warp(player, player.initial_transform)


## Called when a body enters the "Pool"
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player:
		var swimming_player: Player = body as Player
		# Start swimming (if not already swimming and not in a car/vehicle)
		if not swimming_player.is_swimming and not swimming_player.is_driving and swimming_player.is_driving_in == null and not swimming_player.is_entering_vehicle and not swimming_player.is_exiting_vehicle:
			swimming_player.state_machine.travel(swimming_player.current_state, NodeStateMachine.States.SWIMMING)
			return


## Called when a body exits the "Pool"
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body is Player:
		var swimming_player: Player = body as Player
		# Stop swimming (if currently swimming)
		if swimming_player.is_swimming:
			swimming_player.is_swimming = false # This will trigger the `stop()` in `swimming.gd`


func _on_warp_zone_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _on_warp_zone_2_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone2/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _on_warp_zone_3_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone3/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _warp(body: Node3D, target_transform: Transform3D) -> void:
	if body is Player:
		var warp_player: Player = body as Player
		warp_player.global_transform = target_transform
		warp_player.velocity = Vector3.ZERO
		warp_player.up_direction = target_transform.basis.y.normalized()
		warp_player.orientation = Transform3D(warp_player.global_transform.basis, Vector3.ZERO)
		warp_player.player_model.transform = warp_player.initial_player_model_transform
		warp_player.collision_shape.transform = warp_player.initial_collision_shape_transform

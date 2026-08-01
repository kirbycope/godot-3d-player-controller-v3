extends Node3D

@export var little_buddy_count: int = 64
@export var spawn_frame_interval: int = 4

@onready var player: Player = $Player
@onready var first_buddy: Node3D = get_node_or_null("LittleBuddy") as Node3D
@onready var project_rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
var buddy_list: Array[Node3D] = []
var frame_counter: int = 0


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if first_buddy:
		buddy_list.append(first_buddy)

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

	# Spawn LittleBuddy at the specified frame interval until reaching target count.
	if first_buddy and buddy_list.size() < little_buddy_count:
		frame_counter += 1
		if frame_counter >= spawn_frame_interval:
			frame_counter = 0
			var duplicate_buddy = first_buddy.duplicate() as Node3D
			add_child(duplicate_buddy)
			buddy_list.append(duplicate_buddy)

	# If we're below -40, respawn (teleport to the initial position).
	if player and not player.is_driving and not player.is_flying:
		if player.global_position.y < -40.0:
			_warp(player, player.initial_transform)

	# Check if the "CameraRayCast" is colliding with an object that has a "display_menu" method, and if so, call that method
	if player.camera.camera_ray_cast.is_colliding():
		var collider = player.camera.camera_ray_cast.get_collider()
		if collider:
			var target = null
			var current_node = collider
			while current_node:
				if current_node.has_method("display_menu"):
					target = current_node
					break
				current_node = current_node.get_parent()
			
			if target:
				if player.camera.looking_at and player.camera.looking_at != target and player.camera.looking_at.has_method("hide_menu"):
					player.camera.looking_at.hide_menu()
				target.display_menu(player)
				player.camera.looking_at = target
			else:
				if player.camera.looking_at and player.camera.looking_at.has_method("hide_menu"):
					player.camera.looking_at.hide_menu()
				player.camera.looking_at = null
	else:
		if player.camera.looking_at and player.camera.looking_at.has_method("hide_menu"):
			player.camera.looking_at.hide_menu()
		player.camera.looking_at = null


func _on_player_detection_body_entered(_body: Node3D) -> void:
	pass


func _on_player_detection_body_exited(_body: Node3D) -> void:
	pass


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

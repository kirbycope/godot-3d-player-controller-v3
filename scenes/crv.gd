extends VehicleBody3D

@export var max_acceleration_force: float = 1000.0
@export var max_brake_force: float = 500.0
@export var max_reverse_force: float = -500.0

var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var initial_camera_quat: Quaternion = first_person_camera.quaternion

var was_driving: bool = false
var look_angles: Vector2 = Vector2.ZERO
var look_return_timer: float = 0.0
const LOOK_RETURN_DELAY: float = 1.0 # time before returning to center
const MAX_LOOK_YAW: float = 1.0472 # 60 degrees in radians
const MAX_LOOK_PITCH: float = 1.0472 # 60 degrees in radians


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		if event.is_action_pressed("action"):
			if menu_displayed \
			and not player.is_driving:
				player.is_driving_in = self
				var enter_car = $EnterCar
				if enter_car:
					player.global_position = enter_car.global_position
					player.orientation = enter_car.global_transform
					player.orientation.origin = Vector3.ZERO
					player.player_model.global_transform = enter_car.global_transform
					player.velocity = Vector3.ZERO
				player.state_machine.travel(player.current_state, NodeStateMachine.States.DRIVING)
				return

		if player.is_driving and player.is_driving_in == self and first_person_camera.current:
			var player_cam = player.camera as Camera
			if player_cam and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				look_angles.x -= deg_to_rad(event.relative.x * player_cam.mouse_sensitivity)
				look_angles.y -= deg_to_rad(event.relative.y * player_cam.mouse_sensitivity)
				look_angles.x = clampf(look_angles.x, -MAX_LOOK_YAW, MAX_LOOK_YAW)
				look_angles.y = clampf(look_angles.y, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
				look_return_timer = LOOK_RETURN_DELAY


func _process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var is_driving_this_car: bool = player and player.is_driving and player.is_driving_in == self \
		and not player.is_entering_vehicle and not player.is_exiting_vehicle
	
	if is_driving_this_car:
		var player_cam = player.camera as Camera
		var is_first_person: bool = player_cam and player_cam.perspective == Camera.Perspective.FIRST_PERSON
		
		if is_first_person:
			if not first_person_camera.current:
				first_person_camera.current = true
				look_angles = Vector2.ZERO
				first_person_camera.quaternion = initial_camera_quat
		else:
			if first_person_camera.current:
				player.camera.current = true
				
		if first_person_camera.current:
			var joypad_motion_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
			if joypad_motion_input != Vector2.ZERO and player_cam:
				look_angles.x -= deg_to_rad(joypad_motion_input.x * player_cam.joypad_sensitivity * delta)
				look_angles.y -= deg_to_rad(joypad_motion_input.y * player_cam.joypad_sensitivity * delta)
				look_angles.x = clampf(look_angles.x, -MAX_LOOK_YAW, MAX_LOOK_YAW)
				look_angles.y = clampf(look_angles.y, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
				look_return_timer = LOOK_RETURN_DELAY
			elif look_return_timer > 0.0:
				look_return_timer -= delta
			else:
				# SLERP back to center
				look_angles = look_angles.lerp(Vector2.ZERO, delta * 5.0)

			var look_quat = Quaternion.from_euler(Vector3(look_angles.y, look_angles.x, 0.0))
			var target_quat = initial_camera_quat * look_quat
			first_person_camera.quaternion = first_person_camera.quaternion.slerp(target_quat, delta * 15.0)

	elif was_driving: # Player just exited the car
		if player and first_person_camera.current:
			player.camera.current = true
		if player and not menu_displayed and player.is_driving_in != self:
			player = null
			
	was_driving = is_driving_this_car

func display_menu(_player: Player) -> void:
	player = _player
	if action_prompt:
		action_prompt.show()
		action_prompt.update_text()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
	menu_displayed = true


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
	if player and player.is_driving_in == self:
		return
	player = null

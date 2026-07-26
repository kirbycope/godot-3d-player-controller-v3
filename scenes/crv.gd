extends VehicleBody3D

@export var max_acceleration_force: float = 1000.0
@export var max_brake_force: float = 50.0
@export var max_reverse_force: float = -750.0
@export var explosion_impulse_force: float = 1500.0

var menu_displayed: bool = false
var player: Player
var is_on_fire: bool = false
var is_flipped: bool = false
var flipped_timer: float = 0.0
var fire_timer: float = 0.0
var has_exploded: bool = false

@onready var action_prompt: Node3D = $ActionPrompt
@onready var fire: Node3D = $Fire_05
@onready var explosion: Node3D = $VFXGroundExplosion_01
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var initial_camera_quat: Quaternion = first_person_camera.quaternion

var was_driving: bool = false
var look_angles: Vector2 = Vector2.ZERO
var look_return_timer: float = 0.0
const LOOK_RETURN_DELAY: float = 1.0 # time before returning to center
const MAX_LOOK_YAW: float = 1.0472 # 60 degrees in radians
const MAX_LOOK_PITCH: float = 1.0472 # 60 degrees in radians
const FLIPPED_TIME_THRESHOLD: float = 2.0 # seconds on side or top before catching fire
const FLIPPED_DOT_THRESHOLD: float = 0.5 # dot product <= 0.5 means tilted >= 60 degrees
const FLIPPED_VELOCITY_THRESHOLD: float = 2.0 # max linear/angular velocity to be considered settled
const FIRE_BURNTIME_THRESHOLD: float = 5.0 # seconds of burning before exploding


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player:
		if event.is_action_pressed("action"):
			if menu_displayed \
			and not player.is_driving \
			and not is_on_fire \
			and not has_exploded:
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


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var up_dir: Vector3 = -get_gravity().normalized()
	if up_dir == Vector3.ZERO:
		up_dir = Vector3.UP
	
	if not is_on_fire:
		var is_tilted: bool = global_transform.basis.y.dot(up_dir) <= FLIPPED_DOT_THRESHOLD
		var is_settled: bool = linear_velocity.length() < FLIPPED_VELOCITY_THRESHOLD and angular_velocity.length() < FLIPPED_VELOCITY_THRESHOLD
		is_flipped = is_tilted and is_settled
		if is_flipped:
			flipped_timer += delta
			if flipped_timer >= FLIPPED_TIME_THRESHOLD:
				is_on_fire = true
				if fire:
					fire.emitting = true
				hide_menu()
		else:
			flipped_timer = 0.0
	elif fire:
		var fwd: Vector3 = global_transform.basis.z
		if abs(fwd.dot(up_dir)) > 0.99:
			fwd = global_transform.basis.x
		fire.global_transform.basis = Basis.looking_at(fwd, up_dir)
		
		if not has_exploded:
			fire_timer += delta
			if fire_timer >= FIRE_BURNTIME_THRESHOLD:
				has_exploded = true
				if fire:
					fire.emitting = false
				if explosion:
					if explosion.has_method("play"):
						explosion.play()
					else:
						explosion.emitting = true
				apply_impulse(up_dir * explosion_impulse_force)
				hide_menu()


func display_menu(_player: Player) -> void:
	if is_on_fire or has_exploded:
		hide_menu()
		return
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

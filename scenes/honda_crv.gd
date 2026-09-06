extends VehicleBody3D
## Demo car: drivetrain, transmission, damage (flip, burn, explode), engine SFX and first-person look.
##
## The Player's Driving state only passes inputs: it calls [method set_drive_input] every physics
## frame while seated and [method set_driver] with null when the driver gets out.

const MAX_LOOK_YAW: float = 1.0472 # 60 degrees in radians
const MAX_LOOK_PITCH: float = 1.0472 # 60 degrees in radians
const FLIPPED_DOT_THRESHOLD: float = 0.5 # dot product <= 0.5 means tilted >= 60 degrees
const FLIPPED_VELOCITY_THRESHOLD: float = 2.0 # max linear/angular velocity to be considered settled
const DOOR_OPEN_TIME: float = 1.1333 # seconds into the "Entering Car" animation when the door opens
const DOOR_CLOSE_TIME: float = 3.7333 # seconds into the "Entering Car" animation when the door closes
const GEAR_SPEEDS: Array[float] = [8.0, 16.0, 25.0, 36.0, 50.0] # top speed (m/s) of each forward gear
const GEAR_TORQUE_MULTS: Array[float] = [1.2, 1.0, 0.85, 0.7, 0.55] # engine force multiplier per forward gear
const BURNED_MATERIAL: StandardMaterial3D = preload("res://materials/burned.tres")

@export var max_acceleration_force: float = 4500.0
@export var max_brake_force: float = 1800.0
@export var max_reverse_force: float = -2500.0
@export var explosion_impulse_force: float = 6750.0
@export var min_brake_sound_velocity: float = 6.0 ## Minimum speed required to trigger brake screech sound
@export var brake_velocity_threshold: float = 14.0 ## Velocity threshold to switch between sfx_break_short and sfx_break_long
@export var wheels: Array[VehicleWheel3D]

@export_group("GTA Handling & Transmission")
@export var drive_bias_front: float = 0.5 ## AWD torque distribution (0.5 = 50% front / 50% rear)
@export var brake_bias_front: float = 0.65 ## Brake bias (65% front, 35% rear)
@export var handbrake_traction_loss: float = 0.82 ## Rear wheel traction multiplier during handbrake
@export var downforce_coeff: float = 4.0 ## Downforce multiplier
@export var anti_roll_force: float = 12000.0 ## Anti-roll bar force across axles
@export var max_steering_angle: float = 30.0
@export var steering_speed: float = 3.5

@export var current_driver_peer_id: int = 1

var current_gear: int = 1
var current_rpm: float = 0.0 # 0.0 = idle, 1.0 = redline
var has_exploded: bool = false
var initial_spawn_transform: Transform3D
var is_on_fire: bool = false:
	set(value):
		if is_on_fire == value:
			return
		is_on_fire = value
		if is_node_ready():
			_update_fire_state()
var is_flipped: bool = false
var is_engine_started: bool = false
var is_driving_this_car: bool = false ## True from the first drive input until the driver gets out.
var look_angles: Vector2 = Vector2.ZERO
var menu_displayed: bool = false
var player: Player ## The driver, or the Player looking at the action prompt.
var _accelerate: bool = false
var _brake: bool = false
var _handbrake: bool = false
var _steer: float = 0.0
var _revved_current_accel: bool = false

@onready var action_prompt: Node3D = $ActionPrompt
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire: Node3D = $Fire_05
@onready var fire_sfx: AudioStreamPlayer3D = $Fire_05/FireSFX
@onready var explosion: Node3D = $VFXGroundExplosion_01
@onready var explosion_sfx: AudioStreamPlayer3D = $VFXGroundExplosion_01/ExplosionSFX
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var initial_camera_quat: Quaternion = first_person_camera.quaternion
@onready var engine_sfx: Node3D = $EngineSFX ## Container of every looping/rev engine player.
@onready var sfx_car_start: AudioStreamPlayer3D = $SFXCarStart
@onready var sfx_engine_rev: AudioStreamPlayer3D = $EngineSFX/SFXEngineRev
@onready var sfx_engine_slow_down_inside: AudioStreamPlayer3D = $EngineSFX/SFXEngineSlowDownInside
@onready var sfx_engine_slow_down_outside: AudioStreamPlayer3D = $EngineSFX/SFXEngineSlowDownOutside
@onready var sfx_engine_speed_up_inside: AudioStreamPlayer3D = $EngineSFX/SFXEngineSpeedUpInside
@onready var sfx_engine_speed_up_outside: AudioStreamPlayer3D = $EngineSFX/SFXEngineSpeedUpOutside
@onready var sfx_engine_running_inside: AudioStreamPlayer3D = $EngineSFX/SFXEngineRunningInside
@onready var sfx_engine_running_outside: AudioStreamPlayer3D = $EngineSFX/SFXEngineRunningOutside
@onready var sfx_break_short: AudioStreamPlayer3D = $SFXBreakShort
@onready var sfx_break_long: AudioStreamPlayer3D = $SFXBreakLong
@onready var vehicle_synchronizer: MultiplayerSynchronizer = $VehicleSynchronizer
@onready var flipped_timer: Timer = $FlippedTimer ## Runs while flipped and settled; timeout ignites the car.
@onready var fire_timer: Timer = $FireTimer ## Runs while burning; timeout explodes the car.
@onready var screech_timer: Timer = $ScreechTimer ## Minimum gap between brake screech retriggers.
@onready var look_return_timer: Timer = $LookReturnTimer ## Delay before first-person look recenters.
@onready var clutch_timer: Timer = $ClutchTimer ## Brief RPM dip after a gear shift.
@onready var reverse_hold_timer: Timer = $ReverseHoldTimer ## Holds the car still before reverse engages.
@onready var forward_hold_timer: Timer = $ForwardHoldTimer ## Holds the car still before forward engages from reverse.


func _ready() -> void:
	add_to_group("vehicles")
	initial_spawn_transform = global_transform
	set_sfx_volume(PlayerSettingsResource.load_or_create().sfx_volume)
	if is_on_fire:
		_update_fire_state()
	for sfx: Node in engine_sfx.get_children():
		if sfx != sfx_engine_rev and sfx.stream is AudioStreamOggVorbis:
			(sfx.stream as AudioStreamOggVorbis).loop = true


## Sets the current driver and updates multiplayer authority; null when the driver gets out.
func set_driver(driver: Player) -> void:
	if driver:
		player = driver
		current_driver_peer_id = driver.get_multiplayer_authority()
		set_multiplayer_authority(current_driver_peer_id)
		_play_door_sequence()
		return
	if is_driving_this_car and player and player.is_exiting_vehicle:
		_play_door_sequence()
	if player and first_person_camera.current:
		player.camera.current = true
	is_driving_this_car = false
	current_driver_peer_id = 1
	set_multiplayer_authority(1)
	player = null


## Called by the Player's Driving state every physics frame while seated.
func set_drive_input(accelerate: bool, brake_pressed: bool, handbrake: bool, steer: float) -> void:
	if not is_driving_this_car and not is_engine_started:
		sfx_car_start.play()
		is_engine_started = true
	is_driving_this_car = player != null
	_accelerate = accelerate
	_brake = brake_pressed
	_handbrake = handbrake
	_steer = steer


## Returns true if any vehicle wheel is currently touching ground.
func is_any_wheel_on_ground() -> bool:
	for wheel: VehicleWheel3D in wheels:
		if wheel.is_in_contact():
			return true
	return false


## Update volume on all vehicle SFX AudioStreamPlayer3D nodes.
func set_sfx_volume(value: float) -> void:
	var db: float = linear_to_db(value / 100.0) if value > 0.0 else -80.0
	for child: Node in find_children("*", "AudioStreamPlayer3D", true, false):
		(child as AudioStreamPlayer3D).volume_db = db


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or player == null:
		return

	if event.is_action_pressed("action") and menu_displayed and not player.is_driving and not is_on_fire and not has_exploded:
		set_driver(player)
		player.is_driving_in = self
		var enter_car: Node3D = $EnterCar
		player.global_position = enter_car.global_position
		player.orientation = enter_car.global_transform
		player.orientation.origin = Vector3.ZERO
		player.player_model.global_transform = enter_car.global_transform
		player.velocity = Vector3.ZERO
		player.state_machine.travel(player.current_state, NodeStateMachine.States.DRIVING)
		return

	if is_driving_this_car and first_person_camera.current and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var player_cam: Camera = player.camera as Camera
		var motion: InputEventMouseMotion = event
		look_angles.x = clampf(look_angles.x - deg_to_rad(motion.relative.x * player_cam.mouse_sensitivity), -MAX_LOOK_YAW, MAX_LOOK_YAW)
		look_angles.y = clampf(look_angles.y - deg_to_rad(motion.relative.y * player_cam.mouse_sensitivity), -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
		look_return_timer.start()


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_driving_this_car:
		var player_cam: Camera = player.camera as Camera
		if player_cam.perspective == Camera.Perspective.FIRST_PERSON:
			if not first_person_camera.current:
				first_person_camera.current = true
				look_angles = Vector2.ZERO
				first_person_camera.quaternion = initial_camera_quat
		elif first_person_camera.current:
			player.camera.current = true

		if first_person_camera.current:
			var joypad_look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
			if joypad_look != Vector2.ZERO:
				look_angles.x = clampf(look_angles.x - deg_to_rad(joypad_look.x * player_cam.joypad_sensitivity * delta), -MAX_LOOK_YAW, MAX_LOOK_YAW)
				look_angles.y = clampf(look_angles.y - deg_to_rad(joypad_look.y * player_cam.joypad_sensitivity * delta), -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
				look_return_timer.start()
			elif look_return_timer.is_stopped():
				look_angles = look_angles.lerp(Vector2.ZERO, delta * 5.0)
			var target_quat: Quaternion = initial_camera_quat * Quaternion.from_euler(Vector3(look_angles.y, look_angles.x, 0.0))
			first_person_camera.quaternion = first_person_camera.quaternion.slerp(target_quat, delta * 15.0)
	_update_engine_sfx()


## Opens then closes the driver door in sync with the Player's enter/exit animations.
func _play_door_sequence() -> void:
	await get_tree().create_timer(DOOR_OPEN_TIME).timeout
	if not is_instance_valid(animation_player):
		return
	animation_player.play("open")
	await get_tree().create_timer(DOOR_CLOSE_TIME - DOOR_OPEN_TIME).timeout
	if is_instance_valid(animation_player):
		animation_player.play("close")


func _update_fire_state() -> void:
	fire.emitting = is_on_fire
	if is_on_fire:
		if not fire_sfx.playing:
			fire_sfx.play()
		if not has_exploded and is_multiplayer_authority():
			fire_timer.start()
		hide_menu()
	else:
		fire_sfx.stop()
		fire_timer.stop()


func _on_flipped_timer_timeout() -> void:
	is_on_fire = true


func _on_fire_timer_timeout() -> void:
	has_exploded = true
	fire.emitting = false
	fire_sfx.stop()
	explosion.play()
	explosion_sfx.play()
	apply_impulse(-get_gravity().normalized() * explosion_impulse_force)
	_apply_burned_material(self)
	hide_menu()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if is_driving_this_car and not is_on_fire and not has_exploded:
		_apply_drivetrain(delta)
	else:
		steering = 0.0
		engine_force = 0.0
		brake = max_brake_force
		for wheel: VehicleWheel3D in wheels:
			wheel.engine_force = 0.0
			wheel.brake = max_brake_force

	var up_dir: Vector3 = -get_gravity().normalized()
	if up_dir == Vector3.ZERO:
		up_dir = Vector3.UP

	if not is_on_fire:
		var is_tilted: bool = global_transform.basis.y.dot(up_dir) <= FLIPPED_DOT_THRESHOLD
		var is_settled: bool = linear_velocity.length() < FLIPPED_VELOCITY_THRESHOLD and angular_velocity.length() < FLIPPED_VELOCITY_THRESHOLD
		is_flipped = is_tilted and is_settled
		if not is_flipped:
			flipped_timer.stop()
		elif flipped_timer.is_stopped():
			flipped_timer.start()
	else:
		var fwd: Vector3 = global_transform.basis.z
		if absf(fwd.dot(up_dir)) > 0.99:
			fwd = global_transform.basis.x
		fire.global_transform.basis = Basis.looking_at(fwd, up_dir)


## Transmission, RPM, wheel forces, speed-sensitive steering and downforce from the stored drive inputs.
func _apply_drivetrain(delta: float) -> void:
	var speed: float = linear_velocity.length()
	var heading: Vector3 = Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized()
	var forward_speed: float = heading.dot(linear_velocity) if heading != Vector3.ZERO else global_transform.basis.z.dot(linear_velocity)
	var ground_speed: float = Vector2(linear_velocity.x, linear_velocity.z).length()
	var is_grounded: bool = is_any_wheel_on_ground()

	# --- Transmission & Gear State Machine ---
	var target_gear: int = -1
	if forward_speed >= -0.3:
		target_gear = GEAR_SPEEDS.size()
		for g_idx: int in GEAR_SPEEDS.size():
			if speed <= GEAR_SPEEDS[g_idx]:
				target_gear = g_idx + 1
				break
		# Aggressive handbrake downshift: reset gear when handbraking slows the vehicle
		if _handbrake:
			if speed < 10.0:
				target_gear = 1
			elif speed < 18.0:
				target_gear = mini(target_gear, 2)
			elif speed < 28.0:
				target_gear = mini(target_gear, 3)

	if target_gear != current_gear and target_gear > 0 and current_gear > 0:
		if _handbrake:
			clutch_timer.stop() # Instant downshift on handbrake without shift lag
		else:
			clutch_timer.start() # Brief clutch disengagement for shift sound drop
		current_gear = target_gear
	elif target_gear < 0 or current_gear < 0:
		current_gear = target_gear

	# --- Target RPM Calculation ---
	var target_rpm: float = 0.0
	if not is_grounded and not _accelerate:
		target_rpm = 0.1 # Gentle idle hum in mid-air
	elif current_gear > 0:
		var g_idx: int = current_gear - 1
		var min_g_spd: float = 0.0 if g_idx == 0 else GEAR_SPEEDS[g_idx - 1]
		var progress: float = clampf((ground_speed - min_g_spd) / maxf(GEAR_SPEEDS[g_idx] - min_g_spd, 1.0), 0.0, 1.0)
		target_rpm = lerpf(0.35, 1.0, progress) if _accelerate else lerpf(0.1, 0.5, progress)
	elif current_gear == -1: # Reverse
		target_rpm = lerpf(0.3, 0.9, clampf(ground_speed / 12.0, 0.0, 1.0)) if _brake else 0.1

	if (_brake or _handbrake) and _accelerate and speed < 2.5:
		target_rpm = 0.95 # Burnout redline
	if not clutch_timer.is_stopped():
		target_rpm = 0.25 # Clutch dip on gear shift
	current_rpm = lerpf(current_rpm, target_rpm, delta * 12.0)

	# --- Force Calculation ---
	var target_engine_force: float = 0.0
	var target_brake_front: float = 0.0
	var target_brake_rear: float = 0.0
	var rear_slip_multiplier: float = 1.0
	var current_gear_mult: float = GEAR_TORQUE_MULTS[clampi(current_gear - 1, 0, GEAR_TORQUE_MULTS.size() - 1)] if current_gear > 0 else 1.0

	# 1. Acceleration Forward / Braking when in Reverse
	if _accelerate:
		if forward_speed < -0.4:
			# Moving backward in reverse: pressing accelerate smoothly brakes to a stop
			forward_hold_timer.start()
			target_brake_front = max_brake_force * brake_bias_front
			target_brake_rear = max_brake_force * (1.0 - brake_bias_front)
		elif absf(forward_speed) <= 0.4 and not forward_hold_timer.is_stopped() and not _brake:
			# Hold standstill when stopped from reverse
			target_brake_front = max_brake_force
			target_brake_rear = max_brake_force
		else:
			target_engine_force = max_acceleration_force * current_gear_mult
	else:
		forward_hold_timer.stop()

	# 2. Regular Braking Forward / Reversing
	if _brake:
		if forward_speed > 0.4:
			# Moving forward: smoothly brake to a stop and hold before reversing
			reverse_hold_timer.start()
			target_brake_front = max_brake_force * brake_bias_front
			target_brake_rear = max_brake_force * (1.0 - brake_bias_front)
			if not _handbrake and not _accelerate:
				target_engine_force = 0.0
		elif forward_speed < -0.4:
			# Already moving backward: continue reverse unless accelerating
			if _accelerate:
				target_brake_front = max_brake_force
				target_brake_rear = max_brake_force
				target_engine_force = 0.0
			else:
				target_engine_force = max_reverse_force
				target_brake_front = 0.0
				target_brake_rear = 0.0
		elif _accelerate or not reverse_hold_timer.is_stopped():
			# Standstill: rev in place / hold still before reverse engages
			target_brake_front = max_brake_force
			target_brake_rear = max_brake_force
			target_engine_force = 0.0
		else:
			target_engine_force = max_reverse_force
			target_brake_front = 0.0
			target_brake_rear = 0.0
	else:
		reverse_hold_timer.stop()

	# 3. Handbrake (locks rear wheels only, enables progressive drift)
	if _handbrake:
		target_brake_rear = max_brake_force * 1.5
		rear_slip_multiplier = handbrake_traction_loss
		if not _brake and not (_accelerate and forward_speed < -0.4):
			target_brake_front = 0.0
		if _accelerate and forward_speed >= -0.4:
			target_engine_force = max_acceleration_force * current_gear_mult

	# --- Apply Forces to Wheels ---
	for wheel: VehicleWheel3D in wheels:
		if not wheel.has_meta("default_friction"):
			wheel.set_meta("default_friction", wheel.wheel_friction_slip)
		var is_rear: bool = wheel.position.z < 0.0
		wheel.brake = lerpf(wheel.brake, target_brake_rear if is_rear else target_brake_front, delta * 10.0)

		if wheel.use_as_traction:
			if (_brake and forward_speed > 0.4 and not _accelerate) or (_accelerate and forward_speed < -0.4 and not _brake):
				wheel.engine_force = 0.0
			else:
				# Distribute torque according to drive_bias_front
				var wheel_torque_share: float = (1.0 - drive_bias_front) if is_rear else drive_bias_front
				wheel.engine_force = lerpf(wheel.engine_force, target_engine_force * wheel_torque_share * 2.0, delta * 12.0)

		var target_slip: float = float(wheel.get_meta("default_friction")) * (rear_slip_multiplier if is_rear else 1.0)
		wheel.wheel_friction_slip = lerpf(wheel.wheel_friction_slip, target_slip, delta * (12.0 if _handbrake else 25.0))

	# --- Speed-Sensitive Steering ---
	var steer_speed_factor: float = clampf(1.0 - (speed / 35.0) * 0.62, 0.35, 1.0)
	steering = move_toward(steering, _steer * deg_to_rad(max_steering_angle * steer_speed_factor), delta * steering_speed)

	# --- Aerodynamic Downforce Stabilization ---
	if is_grounded:
		apply_central_force(-global_transform.basis.y * clampf(ground_speed * ground_speed * downforce_coeff, 0.0, 4000.0))


func display_menu(_player: Player) -> void:
	if is_on_fire or has_exploded:
		hide_menu()
		return
	player = _player
	if action_prompt:
		action_prompt.update_text()
		action_prompt.show_for(player)
	menu_displayed = true


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
	if player and player.is_driving_in == self:
		return
	player = null


## Replaces every body mesh material with the charred material and hides the glass.
func _apply_burned_material(node: Node) -> void:
	# Skip VFX, particles, prompts
	if node == fire or node == explosion or node is GPUParticles3D or node is CPUParticles3D:
		return
	if node.name.begins_with("VFX") or node.name.begins_with("Fire") or node.name.begins_with("Explosion") or node.name == "ActionPrompt":
		return

	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var node_name: String = node.name.to_lower()
		if "glass" in node_name or "window" in node_name:
			mesh_instance.visible = false
		else:
			var surface_count: int = mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else mesh_instance.get_surface_override_material_count()
			for i: int in surface_count:
				mesh_instance.set_surface_override_material(i, BURNED_MATERIAL)

	for child: Node in node.get_children():
		_apply_burned_material(child)


## Plays the engine and brake SFX that match the stored drive inputs and current RPM.
func _update_engine_sfx() -> void:
	if not is_driving_this_car or is_on_fire or has_exploded:
		for sfx: Node in engine_sfx.get_children():
			(sfx as AudioStreamPlayer3D).stop()
		sfx_break_short.stop()
		sfx_break_long.stop()
		_revved_current_accel = false
		screech_timer.stop()
		return

	if not _accelerate:
		_revved_current_accel = false

	# If start SFX is still playing and player isn't providing inputs yet, let start SFX finish
	if sfx_car_start.playing and not (_accelerate or _brake or _handbrake):
		for sfx: Node in engine_sfx.get_children():
			(sfx as AudioStreamPlayer3D).stop()
		return

	var player_cam: Camera = player.camera as Camera
	var is_first_person: bool = (player_cam and player_cam.perspective == Camera.Perspective.FIRST_PERSON) or first_person_camera.current
	var forward_speed: float = global_transform.basis.z.dot(linear_velocity)
	var lateral_speed: float = absf(global_transform.basis.x.dot(linear_velocity))
	var speed: float = linear_velocity.length()

	# 1. Brake screech / skid SFX (only with wheels on the ground and above the speed threshold)
	var is_screeching: bool = is_any_wheel_on_ground() and speed > min_brake_sound_velocity \
			and (_handbrake or lateral_speed > 2.5 \
			or (_brake and not _accelerate and forward_speed > min_brake_sound_velocity) \
			or (_accelerate and not _brake and forward_speed < -min_brake_sound_velocity))
	if is_screeching:
		if not sfx_break_short.playing and not sfx_break_long.playing and screech_timer.is_stopped():
			screech_timer.start()
			if speed > brake_velocity_threshold or lateral_speed > 4.0:
				sfx_break_long.play()
			else:
				sfx_break_short.play()
	else:
		sfx_break_short.stop()
		sfx_break_long.stop()
		screech_timer.stop()

	# 2. Determine target engine SFX
	var target_sfx: AudioStreamPlayer3D
	if (_brake or _handbrake) and _accelerate and speed < 2.5:
		# Rev engine only during a stationary burnout, once per accelerate press
		if not _revved_current_accel:
			_revved_current_accel = true
			target_sfx = sfx_engine_rev
		elif sfx_engine_rev.playing:
			target_sfx = sfx_engine_rev
		else:
			target_sfx = sfx_engine_running_inside if is_first_person else sfx_engine_running_outside
	elif (_accelerate and forward_speed >= -0.4) or (_brake and not _accelerate and forward_speed < -1.5):
		# Accelerating forward, or actively reversing
		target_sfx = sfx_engine_speed_up_inside if is_first_person else sfx_engine_speed_up_outside
	else:
		# Braking / coasting / idle (off-throttle)
		target_sfx = sfx_engine_running_inside if is_first_person else sfx_engine_running_outside

	# 3. RPM-driven pitch modulation
	var base_pitch: float = lerpf(0.85, 1.6, current_rpm)
	if target_sfx == sfx_engine_speed_up_inside or target_sfx == sfx_engine_speed_up_outside:
		target_sfx.pitch_scale = clampf(base_pitch, 0.85, 1.65)
	elif target_sfx == sfx_engine_rev:
		target_sfx.pitch_scale = 1.0
	elif (_brake or _handbrake) and _accelerate:
		target_sfx.pitch_scale = 1.35
	else:
		target_sfx.pitch_scale = clampf(base_pitch, 0.85, 1.5)

	# 4. Play the target SFX and stop every other engine SFX
	for sfx: Node in engine_sfx.get_children():
		var engine_player: AudioStreamPlayer3D = sfx
		if engine_player == target_sfx:
			if not engine_player.playing:
				engine_player.play()
		else:
			engine_player.stop()

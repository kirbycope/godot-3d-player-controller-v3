extends VehicleBody3D

const LOOK_RETURN_DELAY: float = 1.0 # time before returning to center
const MAX_LOOK_YAW: float = 1.0472 # 60 degrees in radians
const MAX_LOOK_PITCH: float = 1.0472 # 60 degrees in radians
const FLIPPED_DOT_THRESHOLD: float = 0.5 # dot product <= 0.5 means tilted >= 60 degrees
const FLIPPED_VELOCITY_THRESHOLD: float = 2.0 # max linear/angular velocity to be considered settled
const DOOR_OPEN_TIME: float = 1.1333 # seconds into the "Entering Car" animation when the door opens
const DOOR_CLOSE_TIME: float = 3.7333 # seconds into the "Entering Car" animation when the door closes

@export var max_acceleration_force: float = 4500.0
@export var max_brake_force: float = 1800.0
@export var max_reverse_force: float = -2500.0
@export var explosion_impulse_force: float = 6750.0
@export var flipped_time_to_burn: float = 5.0 ## Seconds vehicle must be flipped before catching fire
@export var time_to_explode: float = 10.0 ## Seconds vehicle burns before exploding
@export var min_brake_sound_velocity: float = 6.0 ## Minimum speed required to trigger brake screech sound
@export var brake_velocity_threshold: float = 14.0 ## Velocity threshold to switch between sfx_break_short and sfx_break_long

@export_group("GTA Handling & Transmission")
@export var drive_bias_front: float = 0.5 ## AWD torque distribution (0.5 = 50% front / 50% rear)
@export var brake_bias_front: float = 0.65 ## Brake bias (65% front, 35% rear)
@export var handbrake_traction_loss: float = 0.82 ## Rear wheel traction multiplier during handbrake
@export var downforce_coeff: float = 4.0 ## Downforce multiplier
@export var anti_roll_force: float = 12000.0 ## Anti-roll bar force across axles

var current_gear: int = 1
var current_rpm: float = 0.0 # 0.0 = idle, 1.0 = redline
var clutch_timer: float = 0.0
var fire_timer: float = 0.0
var flipped_timer: float = 0.0
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
var was_entering_vehicle: bool = false
var look_angles: Vector2 = Vector2.ZERO
var look_return_timer: float = 0.0
var menu_displayed: bool = false
var player: Player
var was_driving: bool = false
var _revved_current_accel: bool = false
var _screech_timer: float = 0.0
const SCREECH_RETRIGGER_DELAY: float = 0.8

@onready var action_prompt: Node3D = $ActionPrompt
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire: Node3D = $Fire_05
@onready var fire_sfx: AudioStreamPlayer3D = $Fire_05/FireSFX
@onready var explosion: Node3D = $VFXGroundExplosion_01
@onready var explosion_sfx: AudioStreamPlayer3D = $VFXGroundExplosion_01/ExplosionSFX
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var initial_camera_quat: Quaternion = first_person_camera.quaternion
@onready var sfx_car_start: AudioStreamPlayer3D = $SFXCarStart
@onready var sfx_engine_rev: AudioStreamPlayer3D = $SFXEngineRev
@onready var sfx_engine_slow_down_inside: AudioStreamPlayer3D = $SFXEngineSlowDownInside
@onready var sfx_engine_slow_down_outside: AudioStreamPlayer3D = $SFXEngineSlowDownOutside
@onready var sfx_engine_speed_up_inside: AudioStreamPlayer3D = $SFXEngineSpeedUpInside
@onready var sfx_engine_speed_up_outside: AudioStreamPlayer3D = $SFXEngineSpeedUpOutside
@onready var sfx_engine_running_inside: AudioStreamPlayer3D = $SFXEngineRunningInside
@onready var sfx_engine_running_outside: AudioStreamPlayer3D = $SFXEngineRunningOutside
@onready var sfx_break_short: AudioStreamPlayer3D = $SFXBreakShort
@onready var sfx_break_long: AudioStreamPlayer3D = $SFXBreakLong
@onready var vehicle_synchronizer: MultiplayerSynchronizer = get_node_or_null("VehicleSynchronizer") as MultiplayerSynchronizer

@export var current_driver_peer_id: int = 1


## Sets the current driver and updates multiplayer authority.
func set_driver(p: Player) -> void:
	player = p
	if p:
		current_driver_peer_id = p.get_multiplayer_authority()
		set_multiplayer_authority(current_driver_peer_id)
	else:
		current_driver_peer_id = 1
		set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group("vehicles")
	initial_spawn_transform = global_transform
	var settings_res = PlayerSettingsResource.load_or_create()
	set_sfx_volume(settings_res.sfx_volume)
	if is_on_fire:
		_update_fire_state()
	_configure_engine_loops()


## Returns true if any vehicle wheel is currently touching ground.
func is_any_wheel_on_ground() -> bool:
	for child in get_children():
		if child is VehicleWheel3D and (child as VehicleWheel3D).is_in_contact():
			return true
	return false


func _configure_engine_loops() -> void:
	var looping_players: Array[AudioStreamPlayer3D] = [
		sfx_engine_running_inside,
		sfx_engine_running_outside,
		sfx_engine_speed_up_inside,
		sfx_engine_speed_up_outside,
		sfx_engine_slow_down_inside,
		sfx_engine_slow_down_outside
	]
	for p in looping_players:
		if p and p.stream is AudioStreamOggVorbis:
			(p.stream as AudioStreamOggVorbis).loop = true


## Update volume on all vehicle SFX AudioStreamPlayer3D nodes.
func set_sfx_volume(value: float) -> void:
	var db = linear_to_db(value / 100.0) if value > 0.0 else -80.0
	for child in find_children("*", "AudioStreamPlayer3D", true, false):
		if child is AudioStreamPlayer3D:
			child.volume_db = db


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
				set_driver(player)
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
	
	var is_in_car: bool = player != null and player.is_driving_in == self
	var is_entering: bool = player.is_entering_vehicle if is_in_car else false
	
	if is_in_car:
		if is_entering and not was_entering_vehicle:
			_play_door_sequence()
		if was_entering_vehicle and not is_entering:
			if not is_engine_started:
				if sfx_car_start:
					sfx_car_start.play()
				is_engine_started = true
	was_entering_vehicle = is_entering

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
	_update_engine_sfx(delta)


## Opens then closes the driver door in sync with the player's "Entering Car" animation.
func _play_door_sequence() -> void:
	if animation_player == null:
		return
	await get_tree().create_timer(DOOR_OPEN_TIME).timeout
	if not is_instance_valid(animation_player):
		return
	animation_player.play("open")
	await get_tree().create_timer(DOOR_CLOSE_TIME - DOOR_OPEN_TIME).timeout
	if not is_instance_valid(animation_player):
		return
	animation_player.play("close")


func _update_fire_state() -> void:
	if is_on_fire:
		if fire:
			fire.emitting = true
		if fire_sfx and not fire_sfx.playing:
			fire_sfx.play()
		hide_menu()
	else:
		if fire:
			fire.emitting = false
		if fire_sfx and fire_sfx.playing:
			fire_sfx.stop()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var is_driven: bool = player != null and player.is_driving and player.is_driving_in == self \
		and not player.is_entering_vehicle and not player.is_exiting_vehicle

	if not is_driven or is_on_fire or has_exploded:
		steering = 0.0
		engine_force = 0.0
		brake = max_brake_force
		for child in get_children():
			if child is VehicleWheel3D:
				child.engine_force = 0.0
				child.brake = max_brake_force

	var up_dir: Vector3 = - get_gravity().normalized()
	if up_dir == Vector3.ZERO:
		up_dir = Vector3.UP
	
	if not is_on_fire:
		var is_tilted: bool = global_transform.basis.y.dot(up_dir) <= FLIPPED_DOT_THRESHOLD
		var is_settled: bool = linear_velocity.length() < FLIPPED_VELOCITY_THRESHOLD and angular_velocity.length() < FLIPPED_VELOCITY_THRESHOLD
		is_flipped = is_tilted and is_settled
		if is_flipped:
			flipped_timer += delta
			if flipped_timer >= flipped_time_to_burn:
				is_on_fire = true
		else:
			flipped_timer = 0.0
	elif fire:
		var fwd: Vector3 = global_transform.basis.z
		if abs(fwd.dot(up_dir)) > 0.99:
			fwd = global_transform.basis.x
		fire.global_transform.basis = Basis.looking_at(fwd, up_dir)
		
		if not has_exploded:
			fire_timer += delta
			if fire_timer >= time_to_explode:
				has_exploded = true
				if fire:
					fire.emitting = false
				if fire_sfx:
					fire_sfx.stop()
				if explosion:
					explosion.play()
				if explosion_sfx:
					explosion_sfx.play()
				apply_impulse(up_dir * explosion_impulse_force)
				_apply_burned_material()
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


func _apply_burned_material() -> void:
	var burned_mat := StandardMaterial3D.new()
	burned_mat.albedo_color = Color(0.22, 0.22, 0.23, 1.0)
	burned_mat.clearcoat_enabled = false
	burned_mat.metallic = 0.15
	burned_mat.metallic_specular = 0.2
	burned_mat.roughness = 0.82

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	noise.fractal_octaves = 4

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.25, 0.25, 0.27, 1.0), Color(0.65, 0.65, 0.68, 1.0)])

	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	noise_tex.color_ramp = gradient

	burned_mat.detail_enabled = true
	burned_mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	burned_mat.detail_albedo = noise_tex
	burned_mat.roughness_texture = noise_tex

	_apply_material_recursive(self, burned_mat)



func _apply_material_recursive(node: Node, mat: Material) -> void:
	# Skip VFX, particles, prompts
	if node == fire or node == explosion or node is GPUParticles3D or node is CPUParticles3D:
		return
	if node.name.begins_with("VFX") or node.name.begins_with("Fire") or node.name.begins_with("Explosion") or node.name == "ActionPrompt":
		return

	if node is MeshInstance3D:
		var node_name := node.name.to_lower()
		if "glass" in node_name or "window" in node_name:
			node.visible = false
		else:
			var surf_count := 1
			if node.mesh:
				surf_count = node.mesh.get_surface_count()
			else:
				surf_count = node.get_surface_override_material_count()
			for i in range(surf_count):
				node.set_surface_override_material(i, mat)

	for child in node.get_children():
		_apply_material_recursive(child, mat)



func _update_engine_sfx(delta: float = 0.0) -> void:
	var is_driving_this_car: bool = player and player.is_driving and player.is_driving_in == self \
		and not player.is_entering_vehicle and not player.is_exiting_vehicle

	if not is_driving_this_car or is_on_fire or has_exploded:
		_stop_all_engine_sfx()
		if sfx_break_short and sfx_break_short.playing: sfx_break_short.stop()
		if sfx_break_long and sfx_break_long.playing: sfx_break_long.stop()
		_revved_current_accel = false
		_screech_timer = 0.0
		return

	var accelerate_pressed := false
	var brake_pressed := false
	var handbrake_pressed := false
	if player:
		var driving_state := player.state_machine.get_node_or_null("Driving") as Driving if player.state_machine else null
		if driving_state:
			accelerate_pressed = driving_state.is_accelerate_pressed()
			brake_pressed = driving_state.is_brake_pressed()
			handbrake_pressed = driving_state.is_handbrake_pressed()
		else:
			accelerate_pressed = Input.is_action_pressed("shoot")
			brake_pressed = Input.is_action_pressed("focus")
			handbrake_pressed = Input.is_action_pressed("throw")

	if not accelerate_pressed:
		_revved_current_accel = false

	# If start SFX is still playing and player isn't providing inputs yet, let start SFX finish
	if sfx_car_start and sfx_car_start.playing and not (accelerate_pressed or brake_pressed or handbrake_pressed):
		_stop_all_engine_sfx()
		return

	var player_cam = player.camera as Camera
	var is_first_person: bool = (player_cam and player_cam.perspective == Camera.Perspective.FIRST_PERSON) or first_person_camera.current

	var fwd_heading: Vector3 = global_transform.basis.z
	var forward_speed: float = fwd_heading.dot(linear_velocity)
	var lateral_speed: float = absf(global_transform.basis.x.dot(linear_velocity))
	var speed: float = linear_velocity.length()

	var any_wheel_on_ground: bool = is_any_wheel_on_ground()

	# 1. Brake Screech / Skid SFX (Only if wheels are in contact with ground and speed exceeds threshold!)
	var is_screeching: bool = false
	if any_wheel_on_ground:
		if handbrake_pressed and speed > min_brake_sound_velocity:
			is_screeching = true
		elif lateral_speed > 2.5 and speed > min_brake_sound_velocity:
			is_screeching = true
		elif brake_pressed and not accelerate_pressed and forward_speed > min_brake_sound_velocity:
			is_screeching = true
		elif accelerate_pressed and not brake_pressed and forward_speed < -min_brake_sound_velocity:
			is_screeching = true

	if _screech_timer > 0.0:
		_screech_timer -= delta

	if is_screeching:
		var any_screech_playing: bool = (sfx_break_short and sfx_break_short.playing) or (sfx_break_long and sfx_break_long.playing)
		if not any_screech_playing and _screech_timer <= 0.0:
			_screech_timer = SCREECH_RETRIGGER_DELAY
			if speed > brake_velocity_threshold or lateral_speed > 4.0:
				if sfx_break_long: sfx_break_long.play()
			else:
				if sfx_break_short: sfx_break_short.play()
	else:
		if sfx_break_short and sfx_break_short.playing: sfx_break_short.stop()
		if sfx_break_long and sfx_break_long.playing: sfx_break_long.stop()
		_screech_timer = 0.0

	# 2. Determine target Engine SFX
	var target_sfx: AudioStreamPlayer3D = null

	# Rev Engine: ONLY during stationary burnout
	if (brake_pressed or handbrake_pressed) and accelerate_pressed and speed < 2.5:
		if not _revved_current_accel:
			_revved_current_accel = true
			target_sfx = sfx_engine_rev
		elif sfx_engine_rev and sfx_engine_rev.playing:
			target_sfx = sfx_engine_rev
		else:
			target_sfx = sfx_engine_running_inside if is_first_person else sfx_engine_running_outside
	# Accelerating forward (on-throttle while moving forward or standstill)
	elif accelerate_pressed and forward_speed >= -0.4:
		target_sfx = sfx_engine_speed_up_inside if is_first_person else sfx_engine_speed_up_outside
	# Reversing (actively rolling backward with reverse throttle)
	elif brake_pressed and not accelerate_pressed and forward_speed < -1.5:
		target_sfx = sfx_engine_speed_up_inside if is_first_person else sfx_engine_speed_up_outside
	# Braking / Coasting / Normal stopping / Idle (Off-throttle)
	else:
		target_sfx = sfx_engine_running_inside if is_first_person else sfx_engine_running_outside

	# 3. Dynamic RPM-Driven Continuous Pitch Modulation
	var base_pitch: float = lerp(0.85, 1.6, current_rpm)
	if target_sfx:
		if target_sfx == sfx_engine_speed_up_inside or target_sfx == sfx_engine_speed_up_outside:
			target_sfx.pitch_scale = clampf(base_pitch, 0.85, 1.65)
		elif target_sfx == sfx_engine_slow_down_inside or target_sfx == sfx_engine_slow_down_outside:
			target_sfx.pitch_scale = clampf(lerp(0.8, 1.25, current_rpm), 0.75, 1.3)
		elif target_sfx == sfx_engine_running_inside or target_sfx == sfx_engine_running_outside:
			if (brake_pressed or handbrake_pressed) and accelerate_pressed:
				target_sfx.pitch_scale = 1.35
			else:
				target_sfx.pitch_scale = clampf(base_pitch, 0.85, 1.5)
		elif target_sfx == sfx_engine_rev:
			target_sfx.pitch_scale = 1.0

	# 4. Play target SFX and stop all other engine SFX
	var engine_sfx_list: Array[AudioStreamPlayer3D] = [
		sfx_engine_rev,
		sfx_engine_running_inside,
		sfx_engine_running_outside,
		sfx_engine_speed_up_inside,
		sfx_engine_speed_up_outside,
		sfx_engine_slow_down_inside,
		sfx_engine_slow_down_outside
	]

	for sfx in engine_sfx_list:
		if sfx == target_sfx:
			if sfx and not sfx.playing:
				sfx.play()
		else:
			if sfx and sfx.playing:
				sfx.stop()


func _stop_all_engine_sfx() -> void:
	var engine_sfx_list: Array[AudioStreamPlayer3D] = [
		sfx_engine_rev,
		sfx_engine_running_inside,
		sfx_engine_running_outside,
		sfx_engine_speed_up_inside,
		sfx_engine_speed_up_outside,
		sfx_engine_slow_down_inside,
		sfx_engine_slow_down_outside
	]
	for sfx in engine_sfx_list:
		if sfx and sfx.playing:
			sfx.stop()

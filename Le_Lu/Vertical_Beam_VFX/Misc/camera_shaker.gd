extends Camera3D

@export var shake_duration := 4.0
@export var max_shake_intensity := 0.15
@export var shake_speed := 15.0
@export var rotation_multiplier := 5.0
@export var reset_duration := 0.5  # Duration for smooth reset

var current_shake_intensity := 0.0
var rng := RandomNumberGenerator.new()
var original_position: Vector3
var original_rotation: Vector3
var active_tween: Tween

func _ready():
	original_position = position
	original_rotation = rotation
	rng.randomize()
	#start_shake()

func start_shake():
	# Clear any existing tween
	if active_tween:
		active_tween.kill()
	
	current_shake_intensity = max_shake_intensity
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_method(set_current_shake_intensity, max_shake_intensity, 0.0, shake_duration)
	active_tween.tween_callback(initiate_smooth_reset)
	set_process(true)

func _process(delta):
	if current_shake_intensity > 0:
		var time = Time.get_ticks_usec() * 0.000001 * shake_speed
		var offset = Vector3(
			noise(time, 0) * current_shake_intensity,
			noise(time, 1) * current_shake_intensity,
			noise(time, 2) * current_shake_intensity
		)
		
		position = original_position + offset
		rotation = original_rotation + Vector3(
			offset.z * rotation_multiplier * 0.0174533,
			offset.x * rotation_multiplier * 0.0174533,
			offset.y * rotation_multiplier * 0.0174533
		)

func initiate_smooth_reset():
	set_process(false)
	if active_tween:
		active_tween.kill()
	
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_QUAD)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "position", original_position, reset_duration)
	active_tween.parallel().tween_property(self, "rotation", original_rotation, reset_duration)
	active_tween.tween_callback(cleanup)

func cleanup():
	if active_tween:
		active_tween.kill()
	active_tween = null

func set_current_shake_intensity(intensity: float):
	current_shake_intensity = intensity

func noise(t: float, offset: float) -> float:
	return rng.randf_range(-1.0, 1.0) * sin(t * 2.0 + offset * 100.0)

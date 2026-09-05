@tool
extends GPUParticles3D
class_name SimpleDistanceParticles

@export_category("Distance Control")
@export var enabled: bool = true
@export var full_distance: float = 5.0  # Distance for full particles
@export var min_ratio: float = 0.1
@export var max_ratio: float = 1.0

var _last_position: Vector3
var _current_distance: float = 0.0

func _ready() -> void:
	_last_position = global_position
	if Engine.is_editor_hint():
		set_process(true)

func _process(delta: float) -> void:
	if !enabled:
		return
	
	var current_pos = global_position
	var distance_moved = current_pos.distance_to(_last_position)
	_last_position = current_pos
	
	# Accumulate distance with decay
	_current_distance = lerp(_current_distance, 0.0, delta * 2.0)
	_current_distance += distance_moved
	
	# Calculate ratio based on accumulated distance
	var distance_factor = clamp(_current_distance / full_distance, 0.0, 1.0)
	amount_ratio = lerp(min_ratio, max_ratio, distance_factor)

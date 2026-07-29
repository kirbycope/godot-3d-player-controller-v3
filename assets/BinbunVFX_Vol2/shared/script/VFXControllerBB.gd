@tool
extends Node3D
class_name VFXControllerBB

var materials : Array[ShaderMaterial]:
	get():
		if !materials.is_empty():
			return materials
		
		var result : Array[ShaderMaterial]
		for c in get_children():
			if c is GPUParticles3D || c is MeshInstance3D:
				if c.material_override:
					result.append(c.material_override)
		if !Engine.is_editor_hint():
			materials = result
		return result

var particles : Array[GPUParticles3D]:
	get():
		if !particles.is_empty():
			return particles
		
		var result : Array[GPUParticles3D]
		for c in get_children():
			if c is GPUParticles3D:
				result.append(c)
		if !Engine.is_editor_hint():
			particles = result
		return result

var anim : AnimationPlayer:
	get():
		if has_node("AnimationPlayer"):
			if !Engine.is_editor_hint() && anim:
				return anim
			return $AnimationPlayer
		else:
			return null

@export var one_shot : bool = false
@export var autoplay : bool = false

@export_range(0.0, 8.0, 0.01) var speed_scale : float = 1.0:
	set(v):
		speed_scale = v
		for p in particles:
			p.speed_scale = speed_scale
		anim.speed_scale = speed_scale

@export var emitting : bool = false:
	set(v):
		if emitting == v:
			return
		emitting = v
		if emitting:
			play()
		else:
			stop()

@export_tool_button("Play", "Play") var play_button = func(): 
	play()
@export_tool_button("Stop", "Stop") var stop_button = func(): 
	stop()

signal finished
signal stopped

func _ready() -> void:
	if autoplay or emitting:
		play()
	else:
		stop()

func _enter_tree() -> void:
	if Engine.is_editor_hint() and autoplay:
		play()

func play() -> void:
	emitting = true
	if not anim: return
	if one_shot and anim.has_animation("main"):
		anim.get_animation("main").loop_mode = Animation.LOOP_NONE
	anim.play("main")
	anim.seek(0.0)
	
	await anim.animation_finished
	finished.emit()
	
	if !one_shot:
		if emitting:
			anim.advance(0.0)
			play()
	else:
		stop()

func stop() -> void:
	emitting = false
	if anim:
		if anim.has_animation("stop"):
			anim.play("stop")
		anim.stop()
	for p in particles:
		p.emitting = false
	stopped.emit()

func _restart_particles() -> void:
	print("AA")
	for p in particles:
		p.restart()

func _set_shader_param(key : String, value : Variant) -> void:
	var mats : Array[ShaderMaterial] = materials
	for m in mats:
		m.set_shader_parameter(key, value)

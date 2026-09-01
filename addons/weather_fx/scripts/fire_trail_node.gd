# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

class_name FireTrailNode
extends Node3D

## A dynamic trailing wildfire node that spawns as a small flame,
## GROWS into burning ground flames, COMBINES with neighboring trail nodes,
## and BURNS OUT cleanly into rising smoke.

@export var grow_time: float = 0.8
@export var peak_time: float = 2.8
@export var decay_time: float = 1.4
@export var max_flame_scale: float = 1.3

var _age: float = 0.0
var _is_extinguished: bool = false
var _is_burning_out: bool = false

var _flame_vfx: GPUParticles3D = null
var _light: OmniLight3D = null
var _updraft_area: Area3D = null
var _audio: AudioStreamPlayer3D = null


func _ready() -> void:
	add_to_group("Wildfire")
	add_to_group("Fire")

	_flame_vfx = get_node_or_null("FlameVFX") as GPUParticles3D
	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_updraft_area = get_node_or_null("ThermalUpdraftArea") as Area3D
	_audio = get_node_or_null("AudioCrackle") as AudioStreamPlayer3D

	if is_instance_valid(_updraft_area):
		_updraft_area.add_to_group("Updraft")
		_updraft_area.add_to_group("Thermal")

	# Start small
	_apply_scale_intensity(0.2)


func _process(delta: float) -> void:
	if _is_extinguished:
		return

	# Rain extinguishes fire
	if WeatherFX.get_precipitation_strength() > 0.4:
		extinguish()
		return

	_age += delta
	var total_active = grow_time + peak_time
	var full_duration = total_active + decay_time

	if _age < grow_time:
		# PHASE 1: GROWING (0.2 -> 1.0)
		var progress = clampf(_age / grow_time, 0.0, 1.0)
		var intensity = ease(progress, 0.5)
		_apply_scale_intensity(intensity)
	elif _age < total_active:
		# PHASE 2: PEAK ROARING & COMBINING (with subtle flame flicker)
		var flicker = 1.0 + sin(_age * 8.0 + position.x * 3.0) * 0.06
		_apply_scale_intensity(flicker)
	elif _age < full_duration:
		# PHASE 3: BURNING OUT (1.0 -> 0.0)
		var decay_progress = clampf((_age - total_active) / decay_time, 0.0, 1.0)
		var intensity = (1.0 - decay_progress)
		_apply_scale_intensity(intensity)
	else:
		_burn_out()


func _apply_scale_intensity(intensity: float) -> void:
	var s = clampf(intensity, 0.0, 1.2) * max_flame_scale

	if is_instance_valid(_flame_vfx):
		_flame_vfx.scale = Vector3(s, s * 1.1, s)

	if is_instance_valid(_light):
		_light.light_energy = 1.8 * intensity
		_light.omni_range = 4.5 * maxf(0.2, intensity)


func _burn_out() -> void:
	if _is_burning_out or _is_extinguished:
		return
	_is_burning_out = true
	_is_extinguished = true

	if is_instance_valid(_updraft_area):
		_updraft_area.monitoring = false
		_updraft_area.monitorable = false

	if is_instance_valid(_flame_vfx):
		_flame_vfx.emitting = false

	if is_instance_valid(_light):
		_light.visible = false

	if is_instance_valid(_audio) and _audio.playing:
		_audio.stop()

	# Free after particle dissipation
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(queue_free)


func extinguish() -> void:
	_burn_out()

# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

class_name GroundWildfireSegment
extends Node3D

## A dense, connected ground flame segment that forms part of a continuous spreading wildfire front.
## Features ground-crawling flame trails, terrain wave flames, rising embers, and thermal updrafts.

@export var burn_duration: float = 6.0 ## Seconds this flame segment burns before turning to ash.
@export var flame_scale: float = 1.0

var _age: float = 0.0
var _is_extinguished: bool = false

var _flame_trail: Node3D = null
var _flame_area: Node3D = null
var _sparks: GPUParticles3D = null
var _smoke: GPUParticles3D = null
var _light: OmniLight3D = null
var _updraft_area: Area3D = null
var _audio: AudioStreamPlayer3D = null


func _ready() -> void:
	add_to_group("Wildfire")
	add_to_group("Fire")

	_flame_trail = get_node_or_null("Fire_Trail") as Node3D
	_flame_area = get_node_or_null("Fire_Area") as Node3D
	_sparks = get_node_or_null("Sparks") as GPUParticles3D
	_smoke = get_node_or_null("Smoke") as GPUParticles3D
	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_updraft_area = get_node_or_null("ThermalUpdraftArea") as Area3D
	_audio = get_node_or_null("AudioCrackle") as AudioStreamPlayer3D

	if is_instance_valid(_updraft_area):
		_updraft_area.add_to_group("Updraft")
		_updraft_area.add_to_group("Thermal")

	_start_particles()


func _start_particles() -> void:
	for p in find_children("*", "GPUParticles3D", true, false):
		if p is GPUParticles3D:
			p.emitting = true
			p.visible = true


func _process(delta: float) -> void:
	if _is_extinguished:
		return

	# Rain extinguishes fire
	if WeatherFX.get_precipitation_strength() > 0.4:
		extinguish()
		return

	_age += delta

	# Fade out near end of life
	if _age >= burn_duration * 0.8 and is_instance_valid(_light):
		var fade_ratio = 1.0 - clampf((_age - burn_duration * 0.8) / (burn_duration * 0.2), 0.0, 1.0)
		_light.light_energy = 2.0 * fade_ratio

	if _age >= burn_duration:
		_burn_out()


func _burn_out() -> void:
	if _is_extinguished:
		return
	_is_extinguished = true

	if is_instance_valid(_updraft_area):
		_updraft_area.monitoring = false
		_updraft_area.monitorable = false

	for p in find_children("*", "GPUParticles3D", true, false):
		if p is GPUParticles3D:
			p.emitting = false

	for m in find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and m.name != "AshDecal":
			m.visible = false

	if is_instance_valid(_audio) and _audio.playing:
		_audio.stop()

	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(queue_free)


func extinguish() -> void:
	_burn_out()

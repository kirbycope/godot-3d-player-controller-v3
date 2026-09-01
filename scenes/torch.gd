# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

class_name Torch
extends RigidBody3D

## A physics-driven throwable flaming torch that ignites grass fields upon impact.
## Can be picked up with Ultrahand / HeldObject and thrown across the environment.
## Flame VFX is kept upright in world space (+Y up) regardless of torch rotation.

@export var is_lit: bool = true:
	set(val):
		is_lit = val
		_update_flame_state()

@export var ignite_on_impact: bool = true
@export var impact_cooldown: float = 0.5 ## Minimum seconds between impact ignitions.
@export var flame_light_energy: float = 2.0

var _last_ignite_time: float = -10.0
var _fire_vfx: Node3D = null
var _omni_light: OmniLight3D = null
var _audio_loop: AudioStreamPlayer3D = null
var _impact_audio: AudioStreamPlayer3D = null
var _has_landed_initial_drop: bool = false


func _ready() -> void:
	add_to_group("Torch")
	add_to_group("Fire")
	add_to_group("Throwable")

	# Physics contact monitoring for impact detection
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

	_setup_components()
	_update_flame_state()

	# Detach flame from parent rotation so it always burns strictly upwards in world space
	if is_instance_valid(_fire_vfx):
		_fire_vfx.top_level = true
		for p in _fire_vfx.find_children("*", "GPUParticles3D", true, false):
			if p is GPUParticles3D:
				p.local_coords = false

	if is_instance_valid(_omni_light):
		_omni_light.top_level = true


func _process(_delta: float) -> void:
	# Keep flame and light attached to torch head, always aligned with world UP (+Y)
	var head_world_pos: Vector3 = to_global(Vector3(0.0, 0.52, 0.0))

	if is_instance_valid(_fire_vfx):
		_fire_vfx.global_position = head_world_pos
		_fire_vfx.global_basis = Basis().scaled(Vector3(0.7, 0.7, 0.7)) # Upright in world space

	if is_instance_valid(_omni_light):
		_omni_light.global_position = head_world_pos + Vector3(0.0, 0.1, 0.0)


func _setup_components() -> void:
	_fire_vfx = get_node_or_null("FireVFX") as Node3D
	_omni_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_audio_loop = get_node_or_null("AudioLoop") as AudioStreamPlayer3D
	_impact_audio = get_node_or_null("ImpactAudio") as AudioStreamPlayer3D


func _update_flame_state() -> void:
	if is_instance_valid(_fire_vfx):
		_fire_vfx.visible = is_lit
		for p in _fire_vfx.find_children("*", "GPUParticles3D", true, false):
			if p is GPUParticles3D:
				p.emitting = is_lit
				p.visible = is_lit

	if is_instance_valid(_omni_light):
		_omni_light.visible = is_lit
		_omni_light.light_energy = flame_light_energy if is_lit else 0.0

	if is_instance_valid(_audio_loop):
		if is_lit and not _audio_loop.playing:
			_audio_loop.play()
		elif not is_lit and _audio_loop.playing:
			_audio_loop.stop()


func _on_body_entered(_body: Node) -> void:
	if not is_lit or not ignite_on_impact:
		return

	var current_time = Time.get_ticks_msec() * 0.001
	if current_time - _last_ignite_time < impact_cooldown:
		return

	_last_ignite_time = current_time

	# Play impact sound
	if is_instance_valid(_impact_audio) and not _impact_audio.playing:
		_impact_audio.play()

	_ignite_surrounding_grass()


## Ignites the ground grass field and any burnable entities at the torch's current position.
func _ignite_surrounding_grass() -> void:
	var contact_pos: Vector3 = global_position
	var tree = get_tree()
	if tree == null:
		return

	# 1. Ignite MultiMesh GrassFields
	tree.call_group("GrassField", "ignite_at", contact_pos, 3.5, 18.0)

	# 2. Ignite individual BurnableGrass nodes if nearby
	for node in tree.get_nodes_in_group("BurnableGrass"):
		if node is Node3D and node.has_method("ignite"):
			var dist = (node.global_position - contact_pos).length()
			if dist <= 4.5:
				node.call("ignite")


## Extinguishes the torch (e.g. when submerged in water).
func extinguish() -> void:
	is_lit = false


## Relights the torch.
func relight() -> void:
	is_lit = true

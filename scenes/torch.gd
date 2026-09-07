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
@export var flame_light_energy: float = 2.0

@onready var fire_vfx: Node3D = $FireVFX
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var audio_loop: AudioStreamPlayer3D = $AudioLoop
@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio
@onready var impact_cooldown_timer: Timer = $ImpactCooldownTimer ## Running while impact ignitions are suppressed.


func _ready() -> void:
	_update_flame_state()

	# Detach flame from parent rotation so it always burns strictly upwards in world space
	fire_vfx.top_level = true
	for particles: Node in fire_vfx.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).local_coords = false
	omni_light.top_level = true


func _process(_delta: float) -> void:
	# Keep flame and light attached to torch head, always aligned with world UP (+Y)
	var head_world_pos: Vector3 = to_global(Vector3(0.0, 0.52, 0.0))
	fire_vfx.global_position = head_world_pos
	fire_vfx.global_basis = Basis().scaled(Vector3(0.7, 0.7, 0.7)) # Upright in world space
	omni_light.global_position = head_world_pos + Vector3(0.0, 0.1, 0.0)


func _update_flame_state() -> void:
	if not is_node_ready():
		return
	fire_vfx.visible = is_lit
	for particles: Node in fire_vfx.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).emitting = is_lit
		(particles as GPUParticles3D).visible = is_lit
	omni_light.visible = is_lit
	omni_light.light_energy = flame_light_energy if is_lit else 0.0
	if is_lit and not audio_loop.playing:
		audio_loop.play()
	elif not is_lit and audio_loop.playing:
		audio_loop.stop()


## Ignites the ground grass field and any burnable entities at the torch's position.
func _on_body_entered(_body: Node) -> void:
	if not is_lit or not ignite_on_impact or not impact_cooldown_timer.is_stopped():
		return
	impact_cooldown_timer.start()

	if not impact_audio.playing:
		impact_audio.play()

	var contact_pos: Vector3 = global_position
	# 1. Ignite MultiMesh GrassFields
	get_tree().call_group("GrassField", "ignite_at", contact_pos, 3.5, 18.0)
	# 2. Ignite individual BurnableGrass nodes if nearby
	for node: Node in get_tree().get_nodes_in_group("BurnableGrass"):
		if node is Node3D and node.has_method("ignite") and (node as Node3D).global_position.distance_to(contact_pos) <= 4.5:
			node.call("ignite")


## Extinguishes the torch (e.g. when submerged in water).
func extinguish() -> void:
	is_lit = false


## Relights the torch.
func relight() -> void:
	is_lit = true

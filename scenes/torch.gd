# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

class_name Torch
extends RigidBody3D

## A physics-driven throwable flaming torch that ignites grass fields upon impact.
## Can be picked up with Ultrahand / HeldObject and thrown across the environment.
## Flame VFX is kept upright in world space (+Y up) regardless of torch rotation: the flame and its light are top
## level in the scene, and RemoteTransform3D anchors carry only their position (FlameAnchor at the torch head moves
## the flame, and LightAnchor on the upright flame moves the light 10 cm above it).

@export var is_lit: bool = true:
	set(val):
		is_lit = val
		_update_flame_state()

@export var ignite_on_impact: bool = true
@export var ignite_radius: float = 3.5 ## Metres around the impact the grass catches and anything burnable lights.
@export var burn_duration: float = 18.0 ## Seconds a lit grass field keeps spreading from the impact.
@export var flame_light_energy: float = 2.0

@onready var fire_vfx: Node3D = $FireVFX
@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var audio_loop: AudioStreamPlayer3D = $AudioLoop
@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio
@onready var impact_cooldown_timer: Timer = $ImpactCooldownTimer ## Running while impact ignitions are suppressed.


func _ready() -> void:
	_update_flame_state()


## Leaving the tree stops the crackle (a pickup reparents the torch onto the Player's spring arm, a drop puts it
## back): re-entering brings it back only while the torch is lit. The scene leaves the loop's autoplay off for the
## same reason: an autoplaying loop restarts on every re-entry, lit or not.
func _enter_tree() -> void:
	if is_node_ready():
		_update_flame_state.call_deferred() # once the audio child is back in the tree too


func _update_flame_state() -> void:
	if not is_node_ready():
		return
	fire_vfx.visible = is_lit
	for particles: Node in fire_vfx.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).emitting = is_lit
		(particles as GPUParticles3D).visible = is_lit
	omni_light.visible = is_lit
	omni_light.light_energy = flame_light_energy if is_lit else 0.0
	if is_lit:
		if not audio_loop.playing:
			audio_loop.play()
	else:
		audio_loop.stop()


## Ignites the grass and anything burnable within [member ignite_radius] of the torch's position, the way a fire
## arrow does where it lands ([method FireArrow.ignite_around]: on every peer through the ProjectileSpawner).
func _on_body_entered(_body: Node) -> void:
	if not is_lit or not ignite_on_impact or not impact_cooldown_timer.is_stopped():
		return
	impact_cooldown_timer.start()

	if not impact_audio.playing:
		impact_audio.play()

	FireArrow.ignite_around(self, global_position, ignite_radius, burn_duration)


## Extinguishes the torch (e.g. when submerged in water).
func extinguish() -> void:
	is_lit = false


## Relights the torch.
func relight() -> void:
	is_lit = true

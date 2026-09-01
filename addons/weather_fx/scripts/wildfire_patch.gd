# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

class_name WildfirePatch
extends Node3D

## A stationary ground fire patch that burns on grass, generates a vertical thermal updraft,
## and organically propagates fire to neighboring grass spots biased by active wind direction (BotW style).

@export var burn_duration: float = 7.0 ## Total seconds this patch stays burning before turning to ash.
@export var spread_interval: float = 0.65 ## Seconds between fire propagation attempts.
@export var max_spread_children: int = 4 ## Maximum new patches this single patch can spawn.
@export var spread_radius: float = 1.8 ## Base propagation radius in meters.
@export var updraft_height: float = 22.0 ## Height of vertical thermal updraft cylinder for paragliding.
@export var updraft_radius: float = 3.5 ## Radius of thermal updraft cylinder.

var _age: float = 0.0
var _spread_timer: float = 0.0
var _spreads_spawned: int = 0
var _is_extinguished: bool = false

var _flame_vfx: Node3D = null
var _sparks_vfx: GPUParticles3D = null
var _smoke_vfx: GPUParticles3D = null
var _omni_light: OmniLight3D = null
var _updraft_area: Area3D = null
var _audio: AudioStreamPlayer3D = null


func _ready() -> void:
	add_to_group("Wildfire")
	add_to_group("Fire")

	_setup_components()
	_update_wind_drift()


func _setup_components() -> void:
	_flame_vfx = get_node_or_null("FlameVFX") as Node3D
	_sparks_vfx = get_node_or_null("Sparks") as GPUParticles3D
	_smoke_vfx = get_node_or_null("Smoke") as GPUParticles3D
	_omni_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_updraft_area = get_node_or_null("ThermalUpdraftArea") as Area3D
	_audio = get_node_or_null("AudioCrackle") as AudioStreamPlayer3D

	if is_instance_valid(_updraft_area):
		_updraft_area.add_to_group("Updraft")
		_updraft_area.add_to_group("Thermal")


func _process(delta: float) -> void:
	if _is_extinguished:
		return

	# Douse fire if it starts raining or storming
	if WeatherFX.get_precipitation_strength() > 0.4:
		extinguish()
		return

	_age += delta
	_spread_timer += delta

	# Periodic propagation to neighbor grass spots along wind vector
	if _spread_timer >= spread_interval and _spreads_spawned < max_spread_children and _age < (burn_duration * 0.75):
		_spread_timer = 0.0
		_try_spread_fire()

	# Burn-out transition
	if _age >= burn_duration:
		_burn_out()


## Spreads fire to an adjacent ground spot biased downwind.
func _try_spread_fire() -> void:
	var tree = get_tree()
	if tree == null:
		return

	var grass_fields = tree.get_nodes_in_group("GrassField")
	if grass_fields.is_empty():
		return

	var wind_dir: Vector3 = WeatherFX.get_wind_direction()
	var wind_strength: float = WeatherFX.get_wind_strength()
	var h_wind = Vector2(wind_dir.x, wind_dir.z)
	var has_wind = h_wind.length_squared() > 0.001
	if has_wind:
		h_wind = h_wind.normalized()

	# Pick a random angle biased toward downwind
	var base_angle = randf() * TAU
	if has_wind:
		var wind_angle = atan2(h_wind.y, h_wind.x)
		# 75% chance to spread in the downwind half-circle (-PI/2 to +PI/2 from wind direction)
		if randf() < 0.75:
			base_angle = wind_angle + randf_range(-PI * 0.35, PI * 0.35)

	var dir_2d = Vector2(cos(base_angle), sin(base_angle))
	var wind_dot = dir_2d.dot(h_wind) if has_wind else 0.0

	# Downwind fires travel further; upwind fires stay close
	var distance_factor = 1.0 + maxf(0.0, wind_dot) * minf(wind_strength * 0.4, 1.8) - maxf(0.0, -wind_dot) * 0.4
	var dist = spread_radius * randf_range(0.8, 1.3) * distance_factor

	var spawn_pos = global_position + Vector3(dir_2d.x * dist, 0.0, dir_2d.y * dist)

	# Check minimum distance to any existing fire patch to avoid dense stacking
	for existing in tree.get_nodes_in_group("Wildfire"):
		if existing is Node3D and existing != self:
			if (existing.global_position - spawn_pos).length() < 1.4:
				return # Too close to existing patch

	# Ignite the grass field at this new position
	for field in grass_fields:
		if field.has_method("ignite_at"):
			if field.ignite_at(spawn_pos, 2.0, randf_range(6.0, 9.0)):
				_spreads_spawned += 1
				break


func _update_wind_drift() -> void:
	var wind_dir: Vector3 = WeatherFX.get_wind_direction()
	var wind_strength: float = WeatherFX.get_wind_strength()
	# Apply subtle wind drift to smoke particles
	if is_instance_valid(_smoke_vfx) and _smoke_vfx.process_material is ParticleProcessMaterial:
		var pmat = _smoke_vfx.process_material as ParticleProcessMaterial
		pmat.gravity = Vector3(wind_dir.x * wind_strength * 0.3, 3.5, wind_dir.z * wind_strength * 0.3)


## Smoothly burns out the fire patch.
func _burn_out() -> void:
	if _is_extinguished:
		return
	_is_extinguished = true

	if is_instance_valid(_updraft_area):
		_updraft_area.monitoring = false
		_updraft_area.monitorable = false

	if is_instance_valid(_flame_vfx):
		for p in _flame_vfx.find_children("*", "GPUParticles3D", true, false):
			if p is GPUParticles3D:
				p.emitting = false
		for m in _flame_vfx.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D:
				m.visible = false

	if is_instance_valid(_sparks_vfx):
		_sparks_vfx.emitting = false
	if is_instance_valid(_smoke_vfx):
		_smoke_vfx.emitting = false

	if is_instance_valid(_omni_light):
		var tween = create_tween()
		tween.tween_property(_omni_light, "light_energy", 0.0, 1.0)

	if is_instance_valid(_audio) and _audio.playing:
		_audio.stop()

	# Allow remaining smoke/sparks to finish dissipating before free
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(queue_free)


## Instantly extinguishes the fire (e.g. rain).
func extinguish() -> void:
	_burn_out()

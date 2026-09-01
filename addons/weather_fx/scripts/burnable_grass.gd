# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name BurnableGrass
extends Node3D

## Interactive, wind-reactive burnable grass patch for WeatherFX and Player Controller.
## When ignited, it catches fire, burns dynamically with glowing combustion embers,
## spreads downwind following BotW/TotK gold-standard fire propagation physics,
## and generates a powerful vertical thermal updraft that launches paragliders skyward.

signal ignited()
signal extinguished()
signal burned_out()

@export_group("Fire & Burning State")
@export var is_burning: bool = false:
	set(val):
		if is_burning != val:
			is_burning = val
			if is_inside_tree():
				_update_burn_state()

@export var auto_ignite: bool = false ## If true, ignites immediately on ready (useful for testing updrafts).
@export var burn_duration: float = 20.0 ## Time in seconds before burning out (0.0 = burns indefinitely).
@export var is_charred: bool = false ## State after fire consumes the grass into ash.
@export var current_burn_progress: float = 0.0 ## 0.0 (healthy) -> 0.5 (burning) -> 1.0 (charred ash).

@export_group("Thermal Updraft")
@export var enable_thermal_updraft: bool = true ## Creates a vertical lift column for paragliding when burning.
@export var updraft_height: float = 20.0 ## Height of the thermal lift column in meters.
@export var updraft_radius: float = 4.5 ## Radius of the thermal lift column in meters.

@export_group("Wind-Driven Fire Propagation")
@export var enable_fire_spread: bool = true ## Propagates fire to neighboring grass along the wind vector.
@export var spread_radius: float = 4.5 ## Base isotropic spread radius in meters.
@export var spread_interval: float = 2.5 ## Interval between fire spread propagation checks.
@export var wind_spread_multiplier: float = 0.35 ## Speed and range boost along the active wind vector.
@export var rain_extinguish_enabled: bool = true ## Automatically douses fire during rain or storm.

@export_group("Interaction & Visuals")
@export var enable_interaction: bool = true
@export var grass_scale: Vector3 = Vector3.ONE
@export var custom_grass_material: Material = null:
	set(val):
		custom_grass_material = val
		if is_instance_valid(_grass_mesh):
			_grass_mesh.material_override = custom_grass_material

# Internal nodes
var _fire_vfx_instance: Node3D = null
var _updraft_vfx_instance: Node3D = null
var _updraft_area: Area3D = null
var _action_prompt: Node3D = null
var _grass_mesh: MeshInstance3D = null
var _audio_player: AudioStreamPlayer3D = null
var _burn_timer: float = 0.0
var _spread_timer: float = 0.0
var _player_nearby: bool = false


func _ready() -> void:
	_setup_components()
	if auto_ignite and not Engine.is_editor_hint():
		ignite()
	else:
		_update_burn_state()


func _setup_components() -> void:
	# 1. Grass Mesh Clump
	if not has_node("GrassMesh"):
		_grass_mesh = MeshInstance3D.new()
		_grass_mesh.name = "GrassMesh"
		if ResourceLoader.exists("res://addons/weather_fx/resources/mesh_grass_common_tall.tres"):
			_grass_mesh.mesh = load("res://addons/weather_fx/resources/mesh_grass_common_tall.tres") as Mesh
		elif ResourceLoader.exists("res://addons/weather_fx/resources/mesh_grass_wispy_tall.tres"):
			_grass_mesh.mesh = load("res://addons/weather_fx/resources/mesh_grass_wispy_tall.tres") as Mesh
		
		if custom_grass_material != null:
			_grass_mesh.material_override = custom_grass_material.duplicate()
		elif ResourceLoader.exists("res://addons/weather_fx/resources/grass_material.tres"):
			var base_mat = load("res://addons/weather_fx/resources/grass_material.tres") as Material
			if base_mat:
				_grass_mesh.material_override = base_mat.duplicate()

		_grass_mesh.scale = grass_scale * 1.5
		add_child(_grass_mesh)
	else:
		_grass_mesh = get_node("GrassMesh") as MeshInstance3D
		if _grass_mesh.material_override == null:
			if custom_grass_material != null:
				_grass_mesh.material_override = custom_grass_material.duplicate()
			elif ResourceLoader.exists("res://addons/weather_fx/resources/grass_material.tres"):
				var base_mat = load("res://addons/weather_fx/resources/grass_material.tres") as Material
				if base_mat:
					_grass_mesh.material_override = base_mat.duplicate()
		else:
			_grass_mesh.material_override = _grass_mesh.material_override.duplicate()

	# 2. Fire VFX Instance
	if not has_node("FireVFX"):
		var fire_scene: PackedScene = null
		if ResourceLoader.exists("res://assets/BinbunVFX/fire_effects/effects/Fire/fire_05.tscn"):
			fire_scene = load("res://assets/BinbunVFX/fire_effects/effects/Fire/fire_05.tscn") as PackedScene
		elif ResourceLoader.exists("res://assets/BinbunVFX/fire_effects/effects/Fire/fire_area_01.tscn"):
			fire_scene = load("res://assets/BinbunVFX/fire_effects/effects/Fire/fire_area_01.tscn") as PackedScene

		if fire_scene:
			_fire_vfx_instance = fire_scene.instantiate() as Node3D
			_fire_vfx_instance.name = "FireVFX"
			_fire_vfx_instance.scale = Vector3.ONE * 1.2
			add_child(_fire_vfx_instance)
	else:
		_fire_vfx_instance = get_node("FireVFX") as Node3D

	# 3. Updraft VFX Instance
	if not has_node("UpdraftVFX"):
		var updraft_scene: PackedScene = null
		if ResourceLoader.exists("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_AirFlowUP_strong.tscn"):
			updraft_scene = load("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_AirFlowUP_strong.tscn") as PackedScene
		elif ResourceLoader.exists("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_AirFlowUP.tscn"):
			updraft_scene = load("res://addons/weather_fx/assets/vfx/wind/Scenes/VFX_AirFlowUP.tscn") as PackedScene

		if updraft_scene:
			_updraft_vfx_instance = updraft_scene.instantiate() as Node3D
			_updraft_vfx_instance.name = "UpdraftVFX"
			_updraft_vfx_instance.scale = Vector3(updraft_radius * 0.4, updraft_height * 0.1, updraft_radius * 0.4)
			add_child(_updraft_vfx_instance)
	else:
		_updraft_vfx_instance = get_node("UpdraftVFX") as Node3D

	# 4. Thermal Updraft Area3D
	if not has_node("ThermalUpdraftArea"):
		_updraft_area = Area3D.new()
		_updraft_area.name = "ThermalUpdraftArea"
		_updraft_area.add_to_group("Updraft")
		_updraft_area.add_to_group("Thermal")
		_updraft_area.position = Vector3(0.0, updraft_height * 0.5, 0.0)

		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cyl = CylinderShape3D.new()
		cyl.height = updraft_height
		cyl.radius = updraft_radius
		col.shape = cyl
		_updraft_area.add_child(col)
		add_child(_updraft_area)
	else:
		_updraft_area = get_node("ThermalUpdraftArea") as Area3D

	# 5. Hitbox / Interaction Area
	if not has_node("HitboxArea"):
		var hitbox = Area3D.new()
		hitbox.name = "HitboxArea"
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(5.0, 3.0, 5.0)
		col.shape = box
		col.position = Vector3(0, 1.5, 0)
		hitbox.add_child(col)
		hitbox.body_entered.connect(_on_body_entered)
		hitbox.body_exited.connect(_on_body_exited)
		hitbox.area_entered.connect(_on_area_entered)
		add_child(hitbox)
	else:
		var hitbox = get_node("HitboxArea") as Area3D
		if is_instance_valid(hitbox):
			if not hitbox.body_entered.is_connected(_on_body_entered):
				hitbox.body_entered.connect(_on_body_entered)
			if not hitbox.body_exited.is_connected(_on_body_exited):
				hitbox.body_exited.connect(_on_body_exited)
			if not hitbox.area_entered.is_connected(_on_area_entered):
				hitbox.area_entered.connect(_on_area_entered)

	# 6. Action Prompt
	if not has_node("ActionPrompt"):
		if ResourceLoader.exists("res://scenes/action_prompt.tscn"):
			var prompt_scene = load("res://scenes/action_prompt.tscn") as PackedScene
			if prompt_scene:
				_action_prompt = prompt_scene.instantiate() as Node3D
				_action_prompt.name = "ActionPrompt"
				_action_prompt.position = Vector3(0.0, 2.0, 0.0)
				_action_prompt.set("message_begin", "Press")
				_action_prompt.set("message_end", "to ignite grass")
				_action_prompt.hide()
				add_child(_action_prompt)
	else:
		_action_prompt = get_node("ActionPrompt") as Node3D

	# 7. Audio Player
	if not has_node("FireAudio"):
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "FireAudio"
		_audio_player.unit_size = 8.0
		_audio_player.max_distance = 25.0
		if ResourceLoader.exists("res://addons/weather_fx/assets/audio/gravitysound/Weather Sound Pack/Wind/heavy wind.ogg"):
			_audio_player.stream = load("res://addons/weather_fx/assets/audio/gravitysound/Weather Sound Pack/Wind/heavy wind.ogg") as AudioStream
		add_child(_audio_player)
	else:
		_audio_player = get_node("FireAudio") as AudioStreamPlayer3D


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Douse fire if it starts raining/storming
	if rain_extinguish_enabled and is_burning:
		var precip = WeatherFX.get_precipitation_strength()
		if precip > 0.4:
			extinguish()
			return

	if is_burning:
		if burn_duration > 0.0:
			_burn_timer += delta
			current_burn_progress = clampf(_burn_timer / burn_duration, 0.0, 1.0)
			if _burn_timer >= burn_duration:
				burn_out()
				return
		else:
			current_burn_progress = 0.5

		_update_shader_burn_progress()

		if enable_fire_spread:
			_spread_timer += delta
			if _spread_timer >= spread_interval:
				_spread_timer = 0.0
				spread_to_neighbors()
	elif is_charred:
		current_burn_progress = 1.0
		_update_shader_burn_progress()
	else:
		current_burn_progress = 0.0
		_update_shader_burn_progress()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_interaction or not _player_nearby or is_charred:
		return

	if event.is_action_pressed("action") and not event.is_echo():
		if not is_burning:
			ignite()
		else:
			extinguish()
		get_viewport().set_input_as_handled()


## Ignites this grass patch into roaring fire and activates thermal updraft.
func ignite() -> void:
	if is_burning or is_charred:
		return
	is_burning = true
	_burn_timer = 0.0
	_spread_timer = 0.0
	current_burn_progress = 0.1
	_update_burn_state()
	emit_signal("ignited")


## Extinguishes the fire safely.
func extinguish() -> void:
	if not is_burning:
		return
	is_burning = false
	current_burn_progress = 0.0
	_update_burn_state()
	emit_signal("extinguished")


## Triggered when grass has burned for full duration into charred ash.
func burn_out() -> void:
	is_burning = false
	is_charred = true
	current_burn_progress = 1.0
	_update_burn_state()
	emit_signal("burned_out")


## Propagates fire to neighboring BurnableGrass patches along the active wind vector.
## Follows BotW/TotK gold-standard directional wildfire propagation physics.
func spread_to_neighbors() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if tree == null:
		return

	var wind_dir = WeatherFX.get_wind_direction()
	var wind_strength = WeatherFX.get_wind_strength()
	var h_wind = Vector2(wind_dir.x, wind_dir.z)
	var has_wind = h_wind.length_squared() > 0.001
	if has_wind:
		h_wind = h_wind.normalized()

	for node in tree.get_nodes_in_group("BurnableGrass"):
		if node is BurnableGrass and node != self and not node.is_burning and not node.is_charred:
			var delta_pos: Vector3 = node.global_position - global_position
			var h_delta = Vector2(delta_pos.x, delta_pos.z)
			var dist = h_delta.length()
			if dist < 0.001:
				continue

			var h_dir = h_delta / dist
			var wind_align = h_dir.dot(h_wind) if has_wind else 0.0

			# BotW decomp standard: downwind fire propagation boost, upwind suppression
			var wind_boost = maxf(0.0, wind_align) * minf(wind_strength * wind_spread_multiplier, 2.5)
			var upwind_penalty = maxf(0.0, -wind_align) * 0.50
			var effective_spread_radius = spread_radius * (1.0 + wind_boost - upwind_penalty)

			if dist <= effective_spread_radius:
				node.ignite()


func _update_shader_burn_progress() -> void:
	if is_instance_valid(_grass_mesh) and _grass_mesh.material_override is ShaderMaterial:
		var smat: ShaderMaterial = _grass_mesh.material_override as ShaderMaterial
		smat.set_shader_parameter("burn_progress", current_burn_progress)


func _update_burn_state() -> void:
	# Fire VFX
	if is_instance_valid(_fire_vfx_instance):
		_fire_vfx_instance.visible = is_burning
		if _fire_vfx_instance.has_method("play") and _fire_vfx_instance.has_method("stop"):
			if is_burning:
				_fire_vfx_instance.call("play")
			else:
				_fire_vfx_instance.call("stop")
		if "emitting" in _fire_vfx_instance:
			_fire_vfx_instance.set("emitting", is_burning)
		for p in _fire_vfx_instance.find_children("*", "GPUParticles3D", true, false):
			if p is GPUParticles3D:
				p.emitting = is_burning
				p.visible = is_burning
		for m in _fire_vfx_instance.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and m.is_in_group("effect_mesh"):
				m.visible = is_burning

	# Updraft VFX & Area
	if is_instance_valid(_updraft_vfx_instance):
		_updraft_vfx_instance.visible = is_burning and enable_thermal_updraft
		for p in _updraft_vfx_instance.find_children("*", "GPUParticles3D", true, false):
			if p is GPUParticles3D:
				p.emitting = is_burning and enable_thermal_updraft

	if is_instance_valid(_updraft_area):
		_updraft_area.monitoring = is_burning and enable_thermal_updraft
		_updraft_area.monitorable = is_burning and enable_thermal_updraft

	# Audio
	if is_instance_valid(_audio_player):
		if is_burning and not _audio_player.playing:
			_audio_player.play()
		elif not is_burning and _audio_player.playing:
			_audio_player.stop()

	# Action Prompt Text
	if is_instance_valid(_action_prompt):
		if is_charred:
			_action_prompt.hide()
		elif is_burning:
			_action_prompt.set("message_end", "to extinguish fire")
		else:
			_action_prompt.set("message_end", "to ignite grass")

	# Grass visual state & material charring
	if is_instance_valid(_grass_mesh):
		if is_charred:
			_grass_mesh.scale = grass_scale * 0.6
		else:
			_grass_mesh.scale = grass_scale * 1.5

	_update_shader_burn_progress()


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_nearby = true
		if enable_interaction and is_instance_valid(_action_prompt) and not is_charred:
			_action_prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_nearby = false
		if is_instance_valid(_action_prompt):
			_action_prompt.hide()


func _on_area_entered(area: Area3D) -> void:
	if area == _updraft_area or area.get_parent() == self:
		return
	if area.name.begins_with("HitboxArea") or area.name.begins_with("ThermalUpdraftArea"):
		return
	var a_name = area.name.to_lower()
	if area.is_in_group("Fire") or "fire" in a_name or "flame" in a_name or "explosion" in a_name:
		ignite()

class_name Bobber
extends Projectile
## A fishing float: flies on the rod's cast, floats on [Buoyancy] water and dips on nibbles and bites.
##
## Spawned through the ProjectileSpawner, so every peer simulates its own copy from the same launch
## and sees the line, the dips and the catch, and hears the rod's sounds at the float (each [method splash] names
## one). The line runs from the caster's rod tip when that peer has the rod, or from their left hand otherwise, and a
## hooked fish spins that rod's reel on every peer. It never sweeps for hits. Its lift saturates within a few
## centimetres ([member probe_depth]) and its centre of mass sits below the probe, so it rights itself after the
## tumble of the cast and rides on the surface. A caster who leaves takes their float with them.
##
## The moves are RPCs any peer may call, but the float answers only the server and the caster's own peer
## ([method _from_owner]); nothing in them names a file: the catch is an index into the water's fish list and the
## sound an index into the caster's rod's own streams, resolved on every peer from its own copies.

signal landed_in_water(water: Area3D) ## Emitted once when the float first enters a "WATER" area.
signal landed_dry ## Emitted when the float touches something before reaching water.

@export var probe_depth: float = 0.08 ## Read by [Buoyancy]: depth at which the float's lift is at full strength.

var in_water: bool = false
var water: Area3D ## The "WATER" area the float landed in, on this peer; the catch is one of its fish.

@onready var float_mesh: Node3D = $Float ## Holds both halves of the float so plunges move them together.
@onready var line: MeshInstance3D = $Line ## Top-level, so its vertices are world space.
@onready var splash_particles: GPUParticles3D = $SplashParticles
@onready var ring: MeshInstance3D = $Ring ## Top-level expanding ripple ring.
@onready var bait_icon: Sprite3D = $BaitIcon ## The bait's icon, floated off the hook when the bite takes it.
@onready var audio: AudioStreamPlayer3D = $Audio ## Plays the rod's sounds at the float, on every peer.


func _init() -> void:
	is_template = false
	lifetime = 600.0


func _ready() -> void:
	line.mesh = ImmediateMesh.new()
	super()


## Also ties the float to its caster: when they leave, the server takes it in (see [method retract]).
func launch(origin: Transform3D, direction: Vector3, speed: float, from_shooter: Node3D, from_weapon: Equipment = null) -> void:
	super(origin, direction, speed, from_shooter, from_weapon)
	if is_instance_valid(shooter):
		shooter.tree_exiting.connect(retract, CONNECT_ONE_SHOT)


## Draws the line from the caster to the float; only flies, no swept hits.
func _physics_process(_delta: float) -> void:
	var mesh: ImmediateMesh = line.mesh
	mesh.clear_surfaces()
	if not is_instance_valid(shooter):
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(_line_anchor())
	mesh.surface_add_vertex(global_position)
	mesh.surface_end()


## The caster's rod tip on the peer that has the rod, else their left hand.
func _line_anchor() -> Vector3:
	var player: Player = shooter as Player
	if player == null:
		return shooter.global_position
	var rod: FishingRod = _rod()
	if rod:
		return rod.get_rod_tip()
	var skeleton: Skeleton3D = player.skeleton
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin


## The caster's rod on this peer, or null when their copy here has none out.
func _rod() -> FishingRod:
	var player: Player = shooter as Player
	if not is_instance_valid(player) or player.inventory == null:
		return null
	return player.inventory.get_equipment_by_type(Equipment.EquipmentType.FISHING_ROD) as FishingRod


## Wired to body_entered: ground before water means a bad cast. The caster's own body never counts.
func _on_body_entered(body: Node) -> void:
	if not in_water and body != shooter:
		landed_dry.emit()


## Wired to the WaterSensor's area_entered.
func _on_water_sensor_area_entered(area: Area3D) -> void:
	if in_water or not area.is_in_group("WATER"):
		return
	in_water = true
	water = area
	landed_in_water.emit(area)


## True when the RPC being run came from the server, the caster's own peer, or this peer itself (a local call, a
## call_local's own leg): the only peers allowed to move this float.
func _from_owner() -> bool:
	var sender: int = multiplayer.get_remote_sender_id() if is_inside_tree() else 0 # out of the tree there is no API and no remote caller
	return sender == 0 or sender == 1 or (is_instance_valid(shooter) and sender == shooter.get_multiplayer_authority())


## Dips the float [param depth] metres and lets it bob back over [param duration] seconds, on every peer.
@rpc("any_peer", "call_local", "reliable")
func plunge(depth: float, duration: float) -> void:
	if not _from_owner():
		return
	var tween: Tween = create_tween()
	tween.tween_property(float_mesh, "position:y", -depth, duration * 0.3)
	tween.tween_property(float_mesh, "position:y", 0.0, duration * 0.7).set_trans(Tween.TRANS_BOUNCE)


## Droplets and an expanding ring at the float, on every peer; [param strength] sizes both. The rod's sound for the
## moment ([param sound], one of [enum FishingRod.Sound], read off this peer's copy of the caster's rod) plays at the
## float with them; NONE, or a peer whose copy of the caster has no rod out, is a silent splash.
@rpc("any_peer", "call_local", "reliable")
func splash(strength: float, sound: int = FishingRod.Sound.NONE) -> void:
	if not _from_owner():
		return
	var rod: FishingRod = _rod()
	var stream: AudioStream = rod.sound_stream(sound) if rod else null
	if stream:
		audio.stream = stream
		audio.play()
	splash_particles.amount_ratio = clampf(strength, 0.2, 1.0)
	splash_particles.restart()
	ring.global_transform = Transform3D(Basis().scaled(Vector3(0.3, 1.0, 0.3)), global_position + Vector3.UP * 0.02)
	ring.transparency = 0.2
	ring.show()
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(0.8 + strength, 1.0, 0.8 + strength), 0.6)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.6)
	tween.tween_callback(ring.hide)


## The bite took the bait: its icon (at [param icon_path], tinted [param tint]) rises off the float and fades, on
## every peer, so the loss is seen and not only read in the rod's details. An empty path shows nothing.
@rpc("any_peer", "call_local", "reliable")
func show_bait_taken(icon_path: String, tint: Color) -> void:
	if not _from_owner() or icon_path.is_empty() or not icon_path.begins_with("res://"):
		return
	bait_icon.texture = load(icon_path)
	bait_icon.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	bait_icon.position = Vector3(0.0, 0.15, 0.0)
	bait_icon.show()
	var tween: Tween = create_tween()
	tween.tween_property(bait_icon, "position:y", 0.9, 1.0).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bait_icon, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.tween_callback(bait_icon.hide)


## A hooked fish drags the float about for [param duration] seconds and spins the caster's reel, on every peer.
@rpc("any_peer", "call_local", "reliable")
func thrash(duration: float) -> void:
	if not _from_owner():
		return
	var rod: FishingRod = _rod()
	if rod and rod.animation_player.has_animation(FishingRod.REEL_ANIMATION):
		rod.animation_player.play(FishingRod.REEL_ANIMATION)
	var tween: Tween = create_tween().set_loops(maxi(1, int(duration / 0.15)))
	tween.tween_callback(_thrash_step)
	tween.tween_interval(0.15)
	tween.finished.connect(func() -> void: create_tween().tween_property(float_mesh, "position", Vector3.ZERO, 0.2))


func _thrash_step() -> void:
	create_tween().tween_property(float_mesh, "position", Vector3(randf_range(-0.08, 0.08), randf_range(-0.28, -0.08), randf_range(-0.08, 0.08)), 0.14)


## Arcs the catch, fish number [param species] of the water the float sits in, from the float into the caster's
## hands on every peer; a number the water has no fish for shows nothing.
@rpc("any_peer", "call_local", "reliable")
func present_catch(species: int, length_cm: float) -> void:
	if not _from_owner() or not is_instance_valid(shooter):
		return
	var fish: Fish = fish_at(species)
	if fish == null:
		return
	var model: Node3D = fish.get_model_scene().instantiate()
	get_parent().add_child(model)
	var from: Vector3 = global_position
	model.global_position = from
	fish.dress_model(model, length_cm)
	var target: Vector3 = shooter.global_position + Vector3.UP * 1.3
	var tween: Tween = model.create_tween()
	tween.tween_method(func(t: float) -> void: model.global_position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 1.5, 0.0, 1.0, 0.7)
	tween.tween_interval(1.5)
	tween.tween_callback(model.queue_free)


## Stops the caster's reel and frees the float on the server, which despawns it everywhere. The caster's rod calls it
## when the line comes in; the caster leaving calls it too, so their float never waits out its lifetime.
@rpc("any_peer", "call_local", "reliable")
func retract() -> void:
	if not _from_owner():
		return
	var rod: FishingRod = _rod()
	if rod:
		rod.animation_player.stop()
	if is_inside_tree() and multiplayer.is_server():
		queue_free()


## Fish number [param species] of the water the float landed in, or null: the list every peer's copy of the water
## carries, so a catch names a number and never a file.
func fish_at(species: int) -> Fish:
	var pool: Buoyancy = water as Buoyancy
	if pool == null or species < 0 or species >= pool.fish.size():
		return null
	return pool.fish[species]

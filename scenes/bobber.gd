class_name Bobber
extends Projectile
## A fishing float: flies on the rod's cast, floats on [Buoyancy] water and dips on nibbles and bites.
##
## Spawned through the ProjectileSpawner, so every peer simulates its own copy from the same launch
## and sees the line, the dips and the catch. The line runs from the caster's rod tip when that peer
## has the rod, or from their left hand otherwise (equipment is not replicated). It never sweeps for
## hits. Its lift saturates within a few centimetres ([member probe_depth]) and its centre of mass sits below
## the probe, so it rights itself after the tumble of the cast and rides on the surface.

signal landed_in_water(water: Area3D) ## Emitted once when the float first enters a "WATER" area.
signal landed_dry ## Emitted when the float touches something before reaching water.

@export var fish_scene: PackedScene ## Placeholder catch model for any [Fish] without one of its own.
@export var probe_depth: float = 0.08 ## Read by [Buoyancy]: depth at which the float's lift is at full strength.

var in_water: bool = false

@onready var float_mesh: Node3D = $Float ## Holds both halves of the float so plunges move them together.
@onready var line: MeshInstance3D = $Line ## Top-level, so its vertices are world space.
@onready var splash_particles: GPUParticles3D = $SplashParticles
@onready var ring: MeshInstance3D = $Ring ## Top-level expanding ripple ring.


func _init() -> void:
	is_template = false
	lifetime = 600.0


func _ready() -> void:
	line.mesh = ImmediateMesh.new()
	super()


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
	var rod: FishingRod = player.inventory.get_equipment_by_type(Equipment.EquipmentType.FISHING_ROD) as FishingRod
	if rod:
		return rod.get_rod_tip()
	var skeleton: Skeleton3D = player.skeleton
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin


## Wired to body_entered: ground before water means a bad cast. The caster's own body never counts.
func _on_body_entered(body: Node) -> void:
	if not in_water and body != shooter:
		landed_dry.emit()


## Wired to the WaterSensor's area_entered.
func _on_water_sensor_area_entered(area: Area3D) -> void:
	if in_water or not area.is_in_group("WATER"):
		return
	in_water = true
	landed_in_water.emit(area)


## Dips the float [param depth] metres and lets it bob back over [param duration] seconds, on every peer.
@rpc("any_peer", "call_local", "reliable")
func plunge(depth: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(float_mesh, "position:y", -depth, duration * 0.3)
	tween.tween_property(float_mesh, "position:y", 0.0, duration * 0.7).set_trans(Tween.TRANS_BOUNCE)


## Droplets and an expanding ring at the float, on every peer; [param strength] sizes both.
@rpc("any_peer", "call_local", "reliable")
func splash(strength: float) -> void:
	splash_particles.amount_ratio = clampf(strength, 0.2, 1.0)
	splash_particles.restart()
	ring.global_transform = Transform3D(Basis().scaled(Vector3(0.3, 1.0, 0.3)), global_position + Vector3.UP * 0.02)
	ring.transparency = 0.2
	ring.show()
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(0.8 + strength, 1.0, 0.8 + strength), 0.6)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.6)
	tween.tween_callback(ring.hide)


## A hooked fish drags the float about for [param duration] seconds, on every peer.
@rpc("any_peer", "call_local", "reliable")
func thrash(duration: float) -> void:
	var tween: Tween = create_tween().set_loops(maxi(1, int(duration / 0.15)))
	tween.tween_callback(_thrash_step)
	tween.tween_interval(0.15)
	tween.finished.connect(func() -> void: create_tween().tween_property(float_mesh, "position", Vector3.ZERO, 0.2))


func _thrash_step() -> void:
	create_tween().tween_property(float_mesh, "position", Vector3(randf_range(-0.08, 0.08), randf_range(-0.28, -0.08), randf_range(-0.08, 0.08)), 0.14)


## Arcs the catch from the float into the caster's hands on every peer; an empty path shows nothing.
@rpc("any_peer", "call_local", "reliable")
func present_catch(fish_path: String, length_cm: float) -> void:
	if fish_path.is_empty() or not is_instance_valid(shooter):
		return
	var fish: Fish = load(fish_path)
	var scene: PackedScene = fish.get_model_scene() if fish.get_model_scene() else fish_scene
	var model: Node3D = scene.instantiate()
	get_parent().add_child(model)
	var from: Vector3 = global_position
	model.global_position = from
	fish.dress_model(model, length_cm)
	var target: Vector3 = shooter.global_position + Vector3.UP * 1.3
	var tween: Tween = model.create_tween()
	tween.tween_method(func(t: float) -> void: model.global_position = from.lerp(target, t) + Vector3.UP * sin(t * PI) * 1.5, 0.0, 1.0, 0.7)
	tween.tween_interval(1.5)
	tween.tween_callback(model.queue_free)


## Frees the float on the server, which despawns it everywhere.
@rpc("any_peer", "call_local", "reliable")
func retract() -> void:
	if multiplayer.is_server():
		queue_free()

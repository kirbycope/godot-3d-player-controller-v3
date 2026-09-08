class_name IceBlock
extends StaticBody3D
## A slab of ice frozen out of a pond: a walkable body the Player and floating props rest on. It sits with its top
## just above the wave surface and reaches deep enough below it that a swimmer's ledge ray (cast a little under
## the surface) meets its flank, so it is climbed out onto as the pool's rim is. It melts after [member lifetime]
## seconds (shrinking away over the last [member melt_seconds]) and frees itself. [method freeze_at] makes one on any "WATER" area ([Buoyancy]) under a
## point, through the world's [ProjectileSpawner] so every peer gets it, or locally without one.

signal melted ## Emitted when the slab has melted away, just before it frees itself.

const SCENE_PATH: String = "res://scenes/ice_block.tscn"
const SIZE: Vector3 = Vector3(2.0, 0.6, 2.0) ## The slab, as the scene's box and mesh are sized; half a metre of it is under water.
const TOP_ABOVE_SURFACE: float = 0.1 ## The top of the slab floats this far above the resting wave surface.
const OVER_WATER_MARGIN: float = 0.5 ## A point this far above the surface still counts as over the water (an arrow in the surface).

@export var lifetime: float = 20.0 ## Seconds until the slab has melted away.
@export var melt_seconds: float = 2.0 ## The slab shrinks away over these last seconds of its lifetime.

@onready var melt_timer: Timer = $MeltTimer


func _ready() -> void:
	add_to_group(&"IceBlock")
	melt_timer.start(maxf(lifetime - melt_seconds, 0.01))


## Wired to MeltTimer.timeout in the scene: the slab shrinks away, then frees itself.
func _on_melt_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, melt_seconds)
	tween.tween_callback(_melt_away)


func _melt_away() -> void:
	melted.emit()
	queue_free()


## The "WATER" area ([Buoyancy]) whose surface lies over [param position]: the point is within its water mesh's
## footprint and no higher than [constant OVER_WATER_MARGIN] above the wave surface; null over ground or in the air.
static func find_water(tree: SceneTree, position: Vector3) -> Buoyancy:
	for node: Node in tree.get_nodes_in_group(&"WATER"):
		var water: Buoyancy = node as Buoyancy
		if water == null or water.water_mesh == null or water.water_mesh.mesh == null:
			continue
		var size: Variant = water.water_mesh.mesh.get(&"size") # QuadMesh and PlaneMesh both have one
		if not size is Vector2:
			continue
		var local: Vector3 = water.water_mesh.to_local(position)
		var half: Vector2 = (size as Vector2) * 0.5
		if absf(local.x) <= half.x and absf(local.z) <= half.y and position.y <= water.get_surface_height(position) + OVER_WATER_MARGIN:
			return water
	return null


## Freezes the water under [param position] into a slab with its top at the wave surface; null when the point is
## not over water. [param from] is the node asking (the arrow, the caster's VFX root): its session's
## [ProjectileSpawner] spawns the slab on every peer (the server's copy comes back, a client's arrives through the
## spawner, so a client gets null), or without a spawner the slab is added to the current scene.
static func freeze_at(from: Node, position: Vector3) -> IceBlock:
	if from == null or not from.is_inside_tree():
		return null
	var water: Buoyancy = find_water(from.get_tree(), position)
	if water == null:
		return null
	var at: Vector3 = Vector3(position.x, water.get_surface_height(position) + TOP_ABOVE_SURFACE - SIZE.y * 0.5, position.z)
	var spawner: ProjectileSpawner = ProjectileSpawner.find_for(from)
	if spawner:
		return spawner.place(load(SCENE_PATH) as PackedScene, at) as IceBlock if spawner.multiplayer.is_server() else null
	var block: IceBlock = (load(SCENE_PATH) as PackedScene).instantiate() as IceBlock
	var parent: Node = from.get_tree().current_scene if from.get_tree().current_scene else from.get_tree().root
	parent.add_child(block)
	block.global_position = at
	return block

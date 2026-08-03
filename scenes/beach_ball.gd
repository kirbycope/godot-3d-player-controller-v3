extends RigidBody3D

@export var buoyancy_force: float = 15.0
@export var fluid_drag: float = 2.0
@export var fluid_angular_drag: float = 2.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _physics_process(delta: float) -> void:
	var water_surface_y := _get_water_surface_y()
	if is_nan(water_surface_y):
		return
	
	var radius: float = 0.5
	if collision_shape and collision_shape.shape is SphereShape3D:
		radius = (collision_shape.shape as SphereShape3D).radius
		
	var ball_y := global_position.y
	var bottom_y := ball_y - radius
	
	if water_surface_y > bottom_y:
		var depth := water_surface_y - bottom_y
		var submerged_ratio := clampf(depth / (radius * 2.0), 0.0, 1.0)
		
		# Apply buoyancy force
		var b_force = Vector3.UP * mass * buoyancy_force * submerged_ratio
		apply_central_force(b_force)
		
		# Apply drag
		apply_central_force(-linear_velocity * fluid_drag * submerged_ratio)
		apply_torque(-angular_velocity * fluid_angular_drag * submerged_ratio)

func _get_water_surface_y() -> float:
	var tree := get_tree()
	if not tree:
		return NAN
		
	var has_surface := false
	var highest_surface_y := 0.0
	
	var water_nodes := tree.get_nodes_in_group("WATER")
	for node in water_nodes:
		var water_area := node as Area3D
		if not water_area:
			continue
			
		var overlapping := water_area.overlaps_body(self)
		if not overlapping:
			continue
			
		var water_collision := water_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not water_collision:
			continue
			
		var box_shape := water_collision.shape as BoxShape3D
		if not box_shape:
			continue
			
		var up_in_local: Vector3 = water_collision.global_basis.inverse() * Vector3.UP
		var half_size: Vector3 = box_shape.size * 0.5
		var half_extent_along_up: float = abs(up_in_local.x) * half_size.x \
			+ abs(up_in_local.y) * half_size.y \
			+ abs(up_in_local.z) * half_size.z

		var local_surface: Vector3 = up_in_local.normalized() * half_extent_along_up
		var world_surface: Vector3 = water_collision.to_global(local_surface)
		var surface_y: float = world_surface.y
		
		if not has_surface or surface_y > highest_surface_y:
			has_surface = true
			highest_surface_y = surface_y
			
	if not has_surface:
		return NAN
		
	return highest_surface_y


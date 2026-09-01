extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var torch = world.get_node_or_null("Torch") as RigidBody3D
	var grass_field = world.get_node_or_null("NavigationRegion3D/GrassField") as GrassField

	if torch:
		torch.body_entered.connect(func(body):
			print(">>> TORCH HIT BODY: ", body.name, " (", body.get_class(), ") at pos: ", torch.global_position)
		)

	for i in range(180):
		await physics_frame
		if torch and i % 30 == 0:
			print("Frame ", i, " pos: ", torch.global_position, " lin_vel: ", torch.linear_velocity)

	if grass_field:
		print("GrassField active fires: ", grass_field._active_fires.size())

	quit()

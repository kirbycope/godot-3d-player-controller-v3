extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var torch = world.get_node_or_null("Torch") as RigidBody3D
	var player = world.get_node_or_null("Player")
	var grass_field = world.get_node_or_null("NavigationRegion3D/GrassField") as GrassField

	if player:
		player.rotation_degrees.y = 180.0
		var cam_pivot = player.get_node_or_null("CameraPivot")
		if cam_pivot:
			cam_pivot.rotation_degrees.y = 180.0

	# Process 80 frames for torch to drop, impact ground, and ignite GrassField
	for i in range(80):
		await process_frame

	print("After drop Torch pos: ", torch.global_position if torch else "null")
	if grass_field:
		print("GrassField active fires: ", grass_field._active_fires.size())

	var img = root.get_viewport().get_texture().get_image()
	if img:
		var artifact_path = "C:/Users/kirby/.gemini/antigravity-ide/brain/53182c61-5a60-4686-bfdd-96073f866f45/screenshot_grass.png"
		img.save_png(artifact_path)
		img.save_png("res://screenshot_grass.png")

	quit()

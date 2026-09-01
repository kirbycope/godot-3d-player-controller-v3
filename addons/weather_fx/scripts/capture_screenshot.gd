extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var player = world.get_node_or_null("Player")
	if player:
		player.rotation_degrees.y = 180.0
		var cam_pivot = player.get_node_or_null("CameraPivot")
		if cam_pivot:
			cam_pivot.rotation_degrees.y = 180.0

	var wfx = world.get_node_or_null("WeatherFX")
	if wfx and wfx.has_method("set_weather"):
		wfx.set_weather(0)

	WeatherFX.active_precipitation_strength = 0.0
	WeatherFX.active_wind_direction = Vector3(1.0, 0.0, 0.0)
	WeatherFX.active_wind_strength = 3.5

	# Tip torch at 60 degree tilt to visually test that flame burns straight UP in world space
	var torch = world.get_node_or_null("Torch")
	if torch:
		torch.rotation_degrees.z = 60.0

	# Process 90 physics frames
	for i in range(90):
		await physics_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		var artifact_path = "C:/Users/kirby/.gemini/antigravity-ide/brain/53182c61-5a60-4686-bfdd-96073f866f45/screenshot_grass.png"
		img.save_png(artifact_path)
		img.save_png("res://screenshot_grass.png")

	quit()

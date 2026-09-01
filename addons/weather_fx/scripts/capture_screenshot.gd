extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var player = world.get_node_or_null("Player")
	if player:
		# Elevate player to Y=6.0 in air
		player.global_position = Vector3(0.0, 6.0, 0.0)
		player.rotation_degrees.y = 180.0
		var cam_pivot = player.get_node_or_null("CameraPivot")
		if cam_pivot:
			cam_pivot.rotation_degrees.y = 180.0

	var wfx = world.get_node_or_null("WeatherFX")
	if wfx:
		wfx.set_weather(1) # RAIN
		wfx.apply_weather_effects(1)

	# Process 60 physics frames in rain
	for i in range(60):
		await physics_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		var artifact_path = "C:/Users/kirby/.gemini/antigravity-ide/brain/53182c61-5a60-4686-bfdd-96073f866f45/screenshot_grass.png"
		img.save_png(artifact_path)
		img.save_png("res://screenshot_grass.png")

	quit()

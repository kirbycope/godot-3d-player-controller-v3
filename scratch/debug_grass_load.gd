extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var grass_active = world.get_node("BurnableGrass_Active")
	print("Initial grass_active is_burning: ", grass_active.is_burning)
	print("Initial grass_active auto_ignite: ", grass_active.auto_ignite)
	print("Initial WeatherFX precip: ", WeatherFX.get_precipitation_strength())
	print("Initial WeatherFX wind: ", WeatherFX.get_wind_strength(), " dir: ", WeatherFX.get_wind_direction())

	for i in range(10):
		await process_frame
		print("Frame ", i, " is_burning: ", grass_active.is_burning, " is_charred: ", grass_active.is_charred, " precip: ", WeatherFX.get_precipitation_strength())

	quit()

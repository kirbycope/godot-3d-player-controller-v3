extends SceneTree

func _init() -> void:
	var script = load("res://addons/weather_fx/scripts/burnable_grass.gd")
	var grass = script.new()
	root.add_child(grass)
	print("Step 1: setup")
	grass._setup_components()
	print("Step 2: ignite")
	grass.ignite()
	print("Step 3: process")
	grass._process(0.1)
	print("Step 4: extinguish")
	grass.extinguish()
	quit()

extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var active = world.get_node("BurnableGrass_Active")
	var trail1 = world.get_node("BurnableGrass_Trail1")
	var trail2 = world.get_node("BurnableGrass_Trail2")
	var spawn = world.get_node("BurnableGrass_SpawnInteractable")

	print("Mesh active mat: ", active.get_node("GrassMesh").material_override)
	print("Mesh trail1 mat: ", trail1.get_node("GrassMesh").material_override)
	print("Are mats identical? ", active.get_node("GrassMesh").material_override == trail1.get_node("GrassMesh").material_override)

	quit()

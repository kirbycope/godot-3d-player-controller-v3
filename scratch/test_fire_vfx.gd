extends SceneTree

func _init() -> void:
	var world_scene = load("res://scenes/world.tscn") as PackedScene
	var world = world_scene.instantiate()
	root.add_child(world)

	var active = world.get_node("BurnableGrass_Active")
	var fire_vfx = active.get_node_or_null("FireVFX")
	print("active is_burning: ", active.is_burning)
	print("fire_vfx valid: ", is_instance_valid(fire_vfx))
	if fire_vfx:
		print("fire_vfx visible: ", fire_vfx.visible)
		print("fire_vfx children count: ", fire_vfx.get_child_count())
		for c in fire_vfx.find_children("*", "", true, false):
			if c is GPUParticles3D:
				print("  GPUParticle ", c.name, " emitting: ", c.emitting, " visible: ", c.visible)
			elif c is MeshInstance3D:
				print("  MeshInstance3D ", c.name, " visible: ", c.visible)

	quit()

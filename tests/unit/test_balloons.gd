extends GutTest

## Purpose: Plushies ride inside their balloons while the circle spins and only start simulating once popped.

const CIRCLE_SCENE: PackedScene = preload("res://scenes/ballon_circle.tscn")


func test_plushies_stay_inside_orbiting_balloons() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	add_child_autofree(circle)
	await wait_physics_frames(10)
	for balloon: RedBalloon in circle.get_node("Pivot").get_children():
		assert_eq(balloon.godot_plush.process_mode, Node.PROCESS_MODE_DISABLED, "%s plush must not simulate while carried" % balloon.name)
		assert_lt(balloon.godot_plush.global_position.distance_to(balloon.global_position), 0.5, "%s plush should ride with its balloon" % balloon.name)


func test_popping_releases_the_plush() -> void:
	var circle: Node3D = CIRCLE_SCENE.instantiate()
	add_child_autofree(circle)
	await wait_physics_frames(1)
	var balloon: RedBalloon = circle.get_node("Pivot/RedBallon")
	var plush: RigidBody3D = balloon.godot_plush
	var arrow: RigidBody3D = RigidBody3D.new()
	arrow.name = "Arrow"
	add_child_autofree(arrow)
	balloon._on_hit_detection_body_entered(arrow)
	await wait_physics_frames(1)
	assert_true(is_instance_valid(plush) and plush.is_inside_tree(), "Plush survives the pop")
	assert_eq(plush.process_mode, Node.PROCESS_MODE_INHERIT, "Popping re-enables the plush")
	assert_false(plush.freeze, "Popping unfreezes the plush")
	assert_ne(plush.get_parent(), balloon, "Plush is reparented out of the balloon")
	plush.queue_free()

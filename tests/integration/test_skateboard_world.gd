extends GutTest

## Purpose: The skateboard in the world can be picked up: looking at it shows its Action prompt, because it
## carries an Area3D for the camera's interaction ray to hit.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")


func test_looking_at_the_skateboard_shows_its_prompt() -> void:
	var world: Node = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var player: Player = world.get_node("Players/1")
	var board: Node3D = world.get_node("Skateboard")
	assert_true(board.get_node_or_null("Area3D") is Area3D, "The board has a volume the interaction ray can hit")
	player.warp_to(Transform3D(Basis(), board.global_position + Vector3(0.0, 0.0, 1.8)))
	await wait_physics_frames(2)
	var mount: Node3D = player.camera_mount
	var to: Vector3 = board.global_position - mount.global_position
	mount.rotation.y = atan2(-to.x, -to.z)
	mount.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait_physics_frames(3)
	assert_eq(player.camera.looking_at, board, "The camera resolves the board under the crosshair")
	assert_true(board.action_prompt.visible, "And the board shows its Action prompt")

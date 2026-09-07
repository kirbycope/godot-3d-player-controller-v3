extends GutTest
## Sitting in the boat in world.tscn: from the water beside it the camera ray reaches the hull through the pool's
## water area, the prompt shows, and Action seats the Player.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node
var player: Player
var boat: Node3D


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)
	player = world.get_node("Players/1")
	boat = world.get_node("Boat")


func _look_at_the_boat_from_the_water() -> void:
	player.warp_to(Transform3D(Basis(), boat.global_position + Vector3(1.4, 0.3, 0.0)))
	await wait_physics_frames(20) # Into the water, and swimming
	var mount: Node3D = player.camera_mount
	var to: Vector3 = boat.global_position + Vector3(0.0, 0.2, 0.0) - mount.global_position
	mount.rotation.y = atan2(-to.x, -to.z)
	mount.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait_physics_frames(5)


func test_the_camera_ray_reaches_the_boat_through_the_water() -> void:
	await _look_at_the_boat_from_the_water()
	assert_true(player.is_swimming, "Beside the boat the Player is in the pool")
	assert_eq(player.camera.looking_at, boat, "The water area does not block the interaction ray")
	assert_true(boat.action_prompt.visible, "The boat shows its prompt")


func test_action_seats_the_player_in_the_boat() -> void:
	await _look_at_the_boat_from_the_water()
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(2)
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	Input.parse_input_event(release)
	await wait_physics_frames(3)
	assert_true(player.is_sitting, "Action sits the Player down")
	assert_true(boat._seated)
	assert_lt(player.global_position.distance_to(boat.seat_01.global_position), 0.2, "Pinned to the seat")
	assert_false(boat.action_prompt.visible, "The prompt is gone once seated")

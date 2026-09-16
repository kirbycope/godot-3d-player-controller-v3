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
	await _aim_at_the_boat()


## Aim the camera at the boat and wait until the interaction ray actually reports it.
##
## The Player is swimming here, so they drift from one frame to the next and an aim computed once
## is stale by the time a test acts on it. That made this suite fail roughly one run in three,
## locally as well as on CI, with the Player two metres from the seat because the Action they
## pressed never had the boat as its target. Re-aiming until the ray agrees removes the guess.
func _aim_at_the_boat() -> void:
	var mount: Node3D = player.camera_mount
	for _attempt: int in 40:
		var to: Vector3 = boat.global_position + Vector3(0.0, 0.2, 0.0) - mount.global_position
		mount.rotation.y = atan2(-to.x, -to.z)
		mount.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		await wait_physics_frames(1)
		if player.camera.looking_at == boat:
			return


func test_the_camera_ray_reaches_the_boat_through_the_water() -> void:
	await _look_at_the_boat_from_the_water()
	assert_true(player.is_swimming, "Beside the boat the Player is in the pool")
	assert_eq(player.camera.looking_at, boat, "The water area does not block the interaction ray")
	assert_true(boat.action_prompt.visible, "The boat shows its prompt")


func test_action_seats_the_player_in_the_boat() -> void:
	await _look_at_the_boat_from_the_water()
	assert_eq(player.camera.looking_at, boat, "Action needs the boat under the ray to seat anyone")
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
	# A parsed input event is delivered on a process frame, and a loaded machine can run several
	# physics ticks between two of them, so a fixed physics frame count is not a wait for the press
	# to have been seen at all. This still fails below if the Player never sits.
	await wait_until(func() -> bool: return player.is_sitting, 1.0)
	assert_true(player.is_sitting, "Action sits the Player down")
	assert_true(boat._seated)
	assert_lt(player.global_position.distance_to(boat.seat_01.global_position), 0.2, "Pinned to the seat")
	assert_false(boat.action_prompt.visible, "The prompt is gone once seated")

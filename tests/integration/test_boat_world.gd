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
		# Boat._input gates on its prompt being up, not on the ray, and the prompt only appears once
		# the Camera has called display_menu, which is a frame or more behind looking_at. Waiting on
		# the weaker of the two conditions is what let the press arrive too early to count.
		if player.camera.looking_at == boat and boat.action_prompt.visible:
			return


func test_the_camera_ray_reaches_the_boat_through_the_water() -> void:
	await _look_at_the_boat_from_the_water()
	assert_true(player.is_swimming, "Beside the boat the Player is in the pool")
	assert_eq(player.camera.looking_at, boat, "The water area does not block the interaction ray")
	assert_true(boat.action_prompt.visible, "The boat shows its prompt")


## Send one Action press, the way the keyboard would.
func _press_action() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	Input.parse_input_event(release)


func test_action_seats_the_player_in_the_boat() -> void:
	await _look_at_the_boat_from_the_water()
	assert_eq(player.camera.looking_at, boat, "Action needs the boat under the ray to seat anyone")
	assert_true(boat.action_prompt.visible, "and Boat._input gates on the prompt, so that has to be up too")
	# Pressing once into that window is still a race. A parsed event is delivered on a process frame,
	# a loaded machine can run several physics ticks between two of them, and the Player is swimming
	# the whole time, so by the time the event arrives they may have drifted far enough for the
	# Camera to call hide_menu and take the prompt down again. Re-aim and press until it takes.
	# Boat._input ignores a press while the Player is already sitting, so a repeat cannot un-seat.
	for _attempt: int in 20:
		await _aim_at_the_boat()
		_press_action()
		await wait_physics_frames(3)
		if player.is_sitting:
			break

	assert_true(player.is_sitting, "Action sits the Player down")
	assert_true(boat._seated)
	assert_lt(player.global_position.distance_to(boat.seat_01.global_position), 0.2, "Pinned to the seat")
	assert_false(boat.action_prompt.visible, "The prompt is gone once seated")

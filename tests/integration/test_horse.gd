extends GutTest

## Purpose: the horse is a rideable on the Riding contract: the prompt reads Mount in range, Action mounts the
## Player onto the seat with hands off weapons, the move input walks and gallops the horse with the rider along,
## Action again gets off beside it, and the AnimationTree's blend space and jump chain follow the pace.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const HORSE_SCENE: PackedScene = preload("res://scenes/horse.tscn")

var root: Node3D
var player: Player
var horse: Horse
var sender


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(200.0, 1.0, 200.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	horse = HORSE_SCENE.instantiate()
	root.add_child(horse)
	horse.global_position = Vector3(0.0, 0.05, 0.0)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.global_position = Vector3(3.0, 0.1, 0.0)
	player.controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	await wait_physics_frames(12) # the horse settles onto the floor


func after_each() -> void:
	sender.release_all()
	sender.clear()


func _ride(motion: Vector2, frames: int) -> void:
	for i: int in frames:
		player.player_input.motion = motion
		await get_tree().physics_frame
	player.player_input.motion = Vector2.ZERO


func test_the_model_carries_the_clips_the_tree_uses_and_none_is_root_motion() -> void:
	for clip: StringName in ["idle", "walk", "run", "Walk_Backwards", "Walk_Left", "Walk_Right", "Run_Left", "Run_Right", "JumpStart", "JumpLoop", "JumpEnd"]:
		assert_true(horse.animation_player.has_animation(clip), "The FBX has a %s clip" % clip)
	for cycle: StringName in ["idle", "walk", "run", "Walk_Backwards", "Walk_Left", "Walk_Right", "Run_Left", "Run_Right", "JumpLoop"]:
		assert_eq(horse.animation_player.get_animation(cycle).loop_mode, Animation.LOOP_LINEAR, "%s cycles, from the import settings" % cycle)
	for one_shot: StringName in ["JumpStart", "JumpEnd"]:
		assert_eq(horse.animation_player.get_animation(one_shot).loop_mode, Animation.LOOP_NONE, "%s plays once" % one_shot)
	var walk: Animation = horse.animation_player.get_animation("walk")
	for t: int in walk.get_track_count():
		if walk.track_get_type(t) == Animation.TYPE_POSITION_3D and walk.track_get_key_count(t) > 1:
			var first: Vector3 = walk.track_get_key_value(t, 0)
			var last: Vector3 = walk.track_get_key_value(t, walk.track_get_key_count(t) - 1)
			assert_lt(first.distance_to(last), 0.05, "%s stays put over the walk: the clips are in place, not root motion" % walk.track_get_path(t))


func test_a_riderless_horse_idles_in_the_locomotion_blend_space() -> void:
	assert_true(horse.animation_tree.active, "The tree drives the model")
	assert_eq(horse.playback.get_current_node(), &"Locomotion")
	assert_almost_eq(horse.animation_tree.get(Horse.BLEND_PATH) as Vector2, Vector2.ZERO, Vector2.ONE * 0.01, "Standing still is the blend space origin, the idle")


func test_walking_up_and_pressing_action_mounts() -> void:
	player.warp_to(Transform3D(Basis(), horse.global_position + Vector3(1.5, 0.1, 0.0)))
	await wait_physics_frames(3)
	assert_true(horse.action_prompt.visible, "In range the prompt is up")
	assert_eq(player.controls.joypad_button_0_label.text, "Mount")
	sender.action_down("action")
	await wait_physics_frames(2)
	sender.action_up("action")
	await wait_physics_frames(2)
	assert_eq(player.current_state, NodeStateMachine.States.RIDING, "Action mounts")
	assert_eq(player.riding, horse)
	assert_true(player.riding_blocks_hands(), "Both hands on the reins")
	assert_true(player.collision_shape.disabled, "The rider sits inside the horse's body")
	assert_lt(player.global_position.distance_to(horse.seat.global_position), 0.1, "On the seat")
	assert_eq(player.get_parent(), root, "Still where it was in the tree; the state pins it to the seat instead of reparenting")
	assert_eq(player.current_locomotion_node, horse.rider_animation)
	assert_false(horse.action_prompt.visible)


func test_the_move_input_rides_the_horse_and_the_blend_space_follows_the_pace() -> void:
	player.mount(horse)
	await wait_physics_frames(2)
	var start: Vector3 = horse.global_position
	await _ride(Vector2(0.0, 1.0), 60)
	assert_gt(horse.global_position.distance_to(start), 1.5, "Forward walks the horse")
	var blend: Vector2 = horse.animation_tree.get(Horse.BLEND_PATH)
	assert_almost_eq(blend.y, 0.5, 0.1, "At a walk the blend space sits on the walk cycle")
	assert_lt(player.global_position.distance_to(horse.seat.global_position), 0.1, "The rider stays on the seat")
	sender.action_down(horse.keyboard_sprint_action)
	await _ride(Vector2(0.0, 1.0), 90)
	sender.action_up(horse.keyboard_sprint_action)
	assert_gt(horse.speed, horse.walk_speed + 0.5, "Sprint gallops")
	blend = horse.animation_tree.get(Horse.BLEND_PATH)
	assert_almost_eq(blend.y, 1.0, 0.1, "A gallop is the top of the blend space")
	var heading: Vector3 = horse.global_basis.z
	var camera_heading: Vector3 = -player.camera.global_basis.z
	await _ride(Vector2(1.0, 1.0), 30)
	assert_lt(horse.global_basis.z.dot(heading), 0.95, "Right turns the horse")
	assert_almost_eq(player.global_basis.z.dot(horse.global_basis.z), 1.0, 0.01, "And the rider turns with it, the same frame")
	assert_lt((-player.camera.global_basis.z).dot(camera_heading), 0.95, "The rider's camera turns with the horse too")
	blend = horse.animation_tree.get(Horse.BLEND_PATH)
	assert_gt(blend.x, 0.5, "And leans the blend space to the right cycles")
	await _ride(Vector2(0.0, -1.0), 150)
	assert_lt(horse.speed, -0.2, "Back backs up")
	blend = horse.animation_tree.get(Horse.BLEND_PATH)
	assert_lt(blend.y, -0.2, "Backing up is below the origin, the backwards cycle")
	assert_eq(horse.playback.get_current_node(), &"Locomotion", "All of it inside Locomotion")


func test_jump_runs_the_start_loop_end_chain_and_lands_back_in_locomotion() -> void:
	player.mount(horse)
	await wait_physics_frames(2)
	sender.action_down(horse.keyboard_jump_action)
	await wait_physics_frames(2)
	sender.action_up(horse.keyboard_jump_action)
	assert_true(horse.is_jumping, "Jump sets the flag the tree reads")
	assert_gt(horse.velocity.y, 0.0, "And the horse leaves the ground")
	await wait_physics_frames(4)
	assert_true(horse.playback.get_current_node() in [&"JumpStart", &"JumpLoop"], "The tree is in the jump chain")
	var landed: bool = false
	for i: int in 180:
		await get_tree().physics_frame
		if horse.is_on_floor() and horse.playback.get_current_node() == &"Locomotion":
			landed = true
			break
	assert_true(landed, "Landing takes JumpLoop to JumpEnd and back to Locomotion")
	assert_false(horse.is_jumping, "The flag is off on the ground")


func test_the_riders_camera_still_looks_around_while_riding() -> void:
	player.mount(horse)
	await wait_physics_frames(2)
	var mount_rotation: Vector3 = player.camera_mount.rotation
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(120.0, 0.0)
	Input.parse_input_event(look)
	await wait_physics_frames(2)
	assert_ne(player.camera_mount.rotation.y, mount_rotation.y, "Mouse motion turns the camera mount on horseback; the horse brings no camera of its own")
	assert_true(player.camera.current, "The Player's camera is the view")


func test_action_gets_off_beside_the_horse() -> void:
	player.mount(horse)
	await wait_physics_frames(2)
	sender.action_down("action")
	await wait_physics_frames(2)
	sender.action_up("action")
	await wait_physics_frames(2)
	assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Action dismounts")
	assert_null(player.riding)
	assert_almost_eq(player.global_basis.y, Vector3.UP, Vector3.ONE * 0.01, "Upright")
	assert_false(player.collision_shape.disabled)
	assert_lt(player.global_position.distance_to(horse.dismount_point.global_position), 0.75, "Beside the horse, give or take the settle onto the ground")
	assert_true(player.camera.current)
	assert_eq(horse.speed, 0.0)

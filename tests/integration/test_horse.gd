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
	await _ride(Vector2(0.0, 1.0), 120) # long enough to turn right around first
	assert_gt(horse.global_position.distance_to(start), 1.5, "Forward walks the horse")
	assert_gt(horse.global_basis.z.dot((-player.camera.global_basis.z).slide(Vector3.UP).normalized()), 0.95, "Forward is the camera's forward, like the Player on foot")
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
	var camera_right_forward: Vector3 = camera_heading.slide(Vector3.UP).normalized().rotated(Vector3.UP, -PI / 4.0)
	assert_gt(horse.global_basis.z.dot(camera_right_forward), 0.99, "The body faces where the input points within half a second, like the Player model")
	blend = horse.animation_tree.get(Horse.BLEND_PATH)
	assert_almost_eq(blend.x, 0.0, 0.001, "No turning cycles: the blend space stays up the middle")
	assert_almost_eq((-player.global_basis.z).dot(horse.global_basis.z), 1.0, 0.01, "And the rider's body turns with it the same frame, its -Z (Godot's forward) on the heading")
	assert_almost_eq(player.player_model.global_basis.z.dot(horse.global_basis.z), 1.0, 0.01, "The rider faces the way the horse walks, not the tail")
	assert_gt((-player.camera.global_basis.z).dot(camera_heading), 0.99, "While their camera keeps its view, as on foot")
	await _ride(Vector2(0.0, -1.0), 150)
	assert_lt(horse.global_basis.z.dot((-player.camera.global_basis.z).slide(Vector3.UP).normalized()), -0.9, "Back turns the horse around toward the camera and walks it, like the Player")
	assert_gt(horse.speed, 0.5, "Walking, never backing up")
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


func test_mounting_jumping_and_dismounting_play_the_idle_horse_calls() -> void:
	const IDLE_DIR: String = "res://assets/tommusic/fantasy_sfx/OGG Files/SFX/Horse/Idle/"
	var mount_audio: AudioStreamPlayer3D = horse.get_node("MountAudio")
	var jump_audio: AudioStreamPlayer3D = horse.get_node("JumpAudio")
	var dismount_audio: AudioStreamPlayer3D = horse.get_node("DismountAudio")
	assert_eq(mount_audio.stream.resource_path, IDLE_DIR + "Idle Horse 1.ogg", "Getting on is Idle Horse 1")
	assert_eq(jump_audio.stream.resource_path, IDLE_DIR + "Idle Horse 2.ogg", "A jump is Idle Horse 2")
	assert_eq(dismount_audio.stream.resource_path, IDLE_DIR + "Idle Horse 2.ogg", "and so is getting off")
	for audio: AudioStreamPlayer3D in [mount_audio, jump_audio, dismount_audio]:
		assert_false(audio.playing, audio.name + " is quiet with nobody on")
	watch_signals(horse)
	player.mount(horse)
	await wait_physics_frames(2)
	assert_signal_emitted(horse, "mounted")
	assert_true(mount_audio.playing, "Mounting plays through the scene-wired MountAudio")
	sender.action_down(horse.keyboard_jump_action)
	await wait_physics_frames(1)
	sender.action_up(horse.keyboard_jump_action)
	assert_signal_emitted(horse, "jumped")
	assert_true(jump_audio.playing, "The hop plays JumpAudio")
	assert_false(dismount_audio.playing, "Nobody got off yet")
	await wait_physics_frames(2)
	sender.action_down("action")
	await wait_physics_frames(2)
	sender.action_up("action")
	await wait_physics_frames(2)
	assert_signal_emitted(horse, "dismounted")
	assert_true(dismount_audio.playing, "Getting off plays DismountAudio")


# --- Summon -------------------------------------------------------------------------------------------------------

func _whistle() -> void:
	sender.action_down("whistle")
	await wait_physics_frames(2)
	sender.action_up("whistle")
	await wait_physics_frames(1)


## What the world does with the whistle: Horse.summon_nearest picks the horse in earshot.
func _answer_whistles() -> void:
	player.whistled.connect(func(whistler: Player) -> void: Horse.summon_nearest(whistler))


func _wait_for_summon_state(state: Horse.SummonState, frames: int) -> void:
	for i: int in frames:
		if horse.summon_state == state:
			return
		await get_tree().physics_frame


func test_a_whistle_in_range_brings_the_horse_to_the_player_and_it_calls_out_on_arriving() -> void:
	const IDLE_3: String = "res://assets/tommusic/fantasy_sfx/OGG Files/SFX/Horse/Idle/Idle Horse 3.ogg"
	var summon_audio: AudioStreamPlayer3D = horse.get_node("SummonAudio")
	assert_eq(summon_audio.stream.resource_path, IDLE_3, "Arriving is Idle Horse 3")
	assert_false(summon_audio.playing)
	_answer_whistles()
	player.warp_to(Transform3D(Basis(), Vector3(20.0, 0.1, 0.0)))
	await wait_physics_frames(3)
	watch_signals(horse)
	await _whistle()
	assert_eq(horse.summon_state, Horse.SummonState.COMING, "A whistle within summon_range starts the summon")
	assert_eq(horse.summoner, player)
	await wait_physics_frames(60)
	assert_gt(horse.speed, horse.walk_speed, "It gallops while far off")
	assert_gt((horse.animation_tree.get(Horse.BLEND_PATH) as Vector2).y, 0.5, "in the run cycle of the blend space")
	assert_eq(horse.playback.get_current_node(), &"Locomotion")
	await _wait_for_summon_state(Horse.SummonState.ARRIVED, 600)
	assert_eq(horse.summon_state, Horse.SummonState.ARRIVED, "It arrives")
	assert_signal_emitted(horse, "arrived")
	assert_true(summon_audio.playing, "and plays through the scene-wired SummonAudio")
	var to_player: Vector3 = (player.global_position - horse.global_position).slide(Vector3.UP)
	assert_lt(to_player.length(), horse.arrive_distance + 0.1, "stopping at arrive_distance")
	assert_gt(to_player.length(), 1.0, "beside the Player, not on top of them")
	await wait_physics_frames(30)
	to_player = (player.global_position - horse.global_position).slide(Vector3.UP)
	assert_gt(horse.global_basis.z.dot(to_player.normalized()), 0.95, "facing them")
	assert_eq(horse.speed, 0.0, "and standing")
	assert_almost_eq((horse.animation_tree.get(Horse.BLEND_PATH) as Vector2).y, 0.0, 0.05, "back in the idle")


func test_a_whistle_out_of_range_is_not_heard() -> void:
	_answer_whistles()
	player.warp_to(Transform3D(Basis(), Vector3(horse.summon_range + 10.0, 0.1, 0.0)))
	await wait_physics_frames(3)
	var start: Vector3 = horse.global_position
	await _whistle()
	await wait_physics_frames(30)
	assert_eq(horse.summon_state, Horse.SummonState.IDLE, "Beyond summon_range the horse does not hear it")
	assert_null(horse.summoner)
	assert_lt(horse.global_position.distance_to(start), 0.05, "and stays put")
	assert_eq(horse.speed, 0.0)
	assert_false((horse.get_node("SummonAudio") as AudioStreamPlayer3D).playing)


func test_mounting_cancels_the_summon() -> void:
	player.warp_to(Transform3D(Basis(), Vector3(20.0, 0.1, 0.0)))
	await wait_physics_frames(3)
	horse.summon(player)
	await wait_physics_frames(30)
	assert_eq(horse.summon_state, Horse.SummonState.COMING)
	assert_gt(horse.speed, 0.0, "On its way")
	player.mount(horse)
	await wait_physics_frames(2)
	assert_eq(horse.summon_state, Horse.SummonState.IDLE, "Getting on ends the summon")
	assert_null(horse.summoner)
	assert_eq(player.riding, horse)
	await wait_physics_frames(60)
	assert_eq(horse.speed, 0.0, "and the horse stands under the rider instead of walking on")
	horse.summon(player)
	assert_eq(horse.summon_state, Horse.SummonState.IDLE, "A ridden horse ignores whistles")


func test_a_second_whistle_while_coming_does_not_restart_it_but_another_player_retargets_it() -> void:
	_answer_whistles()
	player.warp_to(Transform3D(Basis(), Vector3(20.0, 0.1, 0.0)))
	await wait_physics_frames(3)
	await _whistle()
	await wait_physics_frames(30)
	var speed_before: float = horse.speed
	assert_gt(speed_before, 0.0)
	await _whistle()
	assert_eq(horse.summon_state, Horse.SummonState.COMING, "Still coming")
	assert_eq(horse.summoner, player)
	assert_gte(horse.speed, speed_before, "without slowing down or starting over")
	var other: Player = PLAYER_SCENE.instantiate()
	root.add_child(other)
	other.global_position = Vector3(0.0, 0.1, 20.0)
	await wait_physics_frames(2)
	horse.summon(other)
	assert_eq(horse.summoner, other, "A different Player's whistle retargets the horse")
	assert_eq(horse.summon_state, Horse.SummonState.COMING)
	await wait_physics_frames(60)
	var to_other: Vector3 = (other.global_position - horse.global_position).slide(Vector3.UP).normalized()
	assert_gt(horse.global_basis.z.dot(to_other), 0.9, "and it turns to head for them")

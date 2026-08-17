extends GutTest

const DUCK_SCENE: PackedScene = preload("res://scenes/duck.tscn")


func test_falling_below_world_respawns_giant_duck() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	duck.position = Vector3(3.0, 5.0, 4.0)
	add_child_autofree(duck)
	await wait_physics_frames(1)

	duck.global_position.y = -41.0
	await wait_physics_frames(1)

	assert_almost_eq(duck.global_position.x, 3.0, 0.01)
	assert_almost_eq(duck.global_position.y, 5.0, 0.01)
	assert_almost_eq(duck.global_position.z, 4.0, 0.01)
	assert_eq(duck.scale, Vector3.ONE)
	assert_eq(duck.idle_model.scale, Vector3.ONE * 10.0)
	assert_eq(duck.walk_model.scale, Vector3.ONE * 10.0)
	assert_eq(duck.eat_model.scale, Vector3.ONE * 10.0)
	assert_eq(duck.move_speed, 4.0)
	assert_eq(duck.follow_distance, 4.0)
	assert_eq(duck.max_follow_distance, 100.0)
	assert_true(duck.knife.visible)
	assert_true(duck.knife_idle.visible)
	assert_true(duck.knife_walk.visible)
	assert_true(duck.knife_eat.visible)
	assert_eq(duck.audio_stream_player_3d.pitch_scale, 0.5)
	assert_eq(duck.audio_stream_player_3d.bus, &"GiantDuck")
	var giant_bus_index: int = AudioServer.get_bus_index(&"GiantDuck")
	assert_eq(AudioServer.get_bus_effect_count(giant_bus_index), 2)
	assert_true(AudioServer.get_bus_effect(giant_bus_index, 0) is AudioEffectReverb)
	assert_true(AudioServer.get_bus_effect(giant_bus_index, 1) is AudioEffectDelay)
	assert_true(duck.audio_stream_player_3d.playing)


func test_walk_animation_resumes_after_pause() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)
	await wait_physics_frames(1)

	duck.animation_player_walk.play(&"FBXExportClip_0_001")
	duck.animation_player_walk.pause()
	duck.call("_play_walk_animation")

	assert_true(duck.animation_player_walk.is_playing())
	assert_eq(duck.animation_player_walk.current_animation, &"FBXExportClip_0_001")
	assert_true(duck.walk_model.visible)
	assert_false(duck.idle_model.visible)
	assert_false(duck.eat_model.visible)


func test_state_model_visibilities_and_giant_attack() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)
	await wait_physics_frames(1)

	# Idle state
	duck.call("_stop_moving")
	assert_true(duck.idle_model.visible)
	assert_false(duck.walk_model.visible)
	assert_false(duck.eat_model.visible)
	assert_true(duck.animation_player_idle.is_playing())

	# Walking state
	duck.call("_play_walk_animation")
	assert_false(duck.idle_model.visible)
	assert_true(duck.walk_model.visible)
	assert_false(duck.eat_model.visible)
	assert_true(duck.animation_player_walk.is_playing())

	# Giant attack eating state
	duck.audio_stream_player_3d.stop()
	duck.call("_play_eating_animation")
	assert_false(duck.idle_model.visible)
	assert_false(duck.walk_model.visible)
	assert_true(duck.eat_model.visible)
	assert_true(duck.animation_player_eat.is_playing())
	assert_true(duck.audio_stream_player_3d.playing)



func test_impulse_collision_plays_quack() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)
	await wait_physics_frames(1)

	duck.apply_impulse(Vector3(3.0, 0.0, 0.0))

	assert_true(duck.audio_stream_player_3d.playing)


func test_registered_physics_hit_plays_quack() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)
	await wait_physics_frames(1)

	duck.register_hit()

	assert_true(duck.audio_stream_player_3d.playing)


func test_player_crossing_detection_range_plays_quack() -> void:
	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)
	await wait_physics_frames(1)

	duck.call("_update_player_range", duck.max_follow_distance + 1.0)
	assert_false(duck.audio_stream_player_3d.playing)

	duck.call("_update_player_range", duck.max_follow_distance - 1.0)
	assert_true(duck.audio_stream_player_3d.playing)

	duck.audio_stream_player_3d.stop()
	duck.call("_update_player_range", duck.max_follow_distance + 1.0)
	assert_true(duck.audio_stream_player_3d.playing)


func test_rigid_body_collision_plays_quack() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(10.0, 1.0, 10.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	add_child_autofree(floor_body)

	var duck: CharacterBody3D = DUCK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(duck)

	var impact_body: RigidBody3D = RigidBody3D.new()
	var impact_collision: CollisionShape3D = CollisionShape3D.new()
	var impact_shape: SphereShape3D = SphereShape3D.new()
	impact_shape.radius = 0.5
	impact_collision.shape = impact_shape
	impact_body.add_child(impact_collision)
	impact_body.position = Vector3(-3.0, 0.3, 0.0)
	impact_body.gravity_scale = 0.0
	add_child_autofree(impact_body)
	await wait_physics_frames(1)

	impact_body.linear_velocity = Vector3(8.0, 0.0, 0.0)
	var quack_played: bool = false
	for frame: int in range(60):
		await wait_physics_frames(1)
		if duck.audio_stream_player_3d.playing:
			quack_played = true
			break

	assert_true(quack_played)
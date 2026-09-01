extends GutTest

const CRV_SCENE = preload("res://scenes/honda_crv.tscn")
const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")


func test_vehicle_synchronizer_exists() -> void:
	var crv = CRV_SCENE.instantiate()
	add_child_autofree(crv)

	assert_not_null(crv.vehicle_synchronizer, "HondaCRV should have a VehicleSynchronizer node")
	assert_true(crv.vehicle_synchronizer is MultiplayerSynchronizer, "VehicleSynchronizer must be a MultiplayerSynchronizer")
	assert_not_null(crv.vehicle_synchronizer.replication_config, "VehicleSynchronizer must have SceneReplicationConfig")


func test_vehicle_synchronizer_tracks_properties() -> void:
	var crv = CRV_SCENE.instantiate()
	add_child_autofree(crv)

	var config: SceneReplicationConfig = crv.vehicle_synchronizer.replication_config
	assert_not_null(config, "Config should not be null")

	var props: Array[NodePath] = config.get_properties()
	assert_true(props.has(NodePath(".:position")), "Should track position")
	assert_true(props.has(NodePath(".:rotation")), "Should track rotation")
	assert_true(props.has(NodePath(".:steering")), "Should track steering")
	assert_true(props.has(NodePath(".:engine_force")), "Should track engine_force")
	assert_true(props.has(NodePath(".:brake")), "Should track brake")
	assert_true(props.has(NodePath(".:linear_velocity")), "Should track linear_velocity")
	assert_true(props.has(NodePath(".:angular_velocity")), "Should track angular_velocity")
	assert_true(props.has(NodePath(".:is_on_fire")), "Should track is_on_fire")
	assert_true(props.has(NodePath(".:has_exploded")), "Should track has_exploded")
	assert_true(props.has(NodePath(".:is_engine_started")), "Should track is_engine_started")
	assert_true(props.has(NodePath(".:current_driver_peer_id")), "Should track current_driver_peer_id")


func test_driver_authority_handover() -> void:
	var crv = CRV_SCENE.instantiate()
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(crv)
	add_child_autofree(player)

	# Simulate remote peer 42
	player.set_multiplayer_authority(42)

	# Enter car
	crv.set_driver(player)
	assert_eq(crv.current_driver_peer_id, 42, "current_driver_peer_id should match driver's authority")
	assert_eq(crv.get_multiplayer_authority(), 42, "Vehicle authority should transfer to driver")

	# Exit car
	crv.set_driver(null)
	assert_eq(crv.current_driver_peer_id, 1, "current_driver_peer_id should revert to host (1)")
	assert_eq(crv.get_multiplayer_authority(), 1, "Vehicle authority should revert to host (1)")

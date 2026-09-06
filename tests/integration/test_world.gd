extends GutTest

## Purpose: World wiring — pool signals set NPC water areas, driving powers the radio, warp zones teleport the player.

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var world: Node3D


func before_each() -> void:
	world = WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	await wait_physics_frames(2)


func test_pool_sets_follower_npc_water_area() -> void:
	var buddy: FollowerNpc = world.get_node("LittleBuddy") as FollowerNpc
	var pool: Area3D = world.get_node("Pool/WaterArea3D") as Area3D
	assert_not_null(buddy)
	assert_null(buddy.in_water_area)

	buddy.global_position = pool.global_position
	await wait_physics_frames(2)
	assert_eq(buddy.in_water_area, pool, "Entering the pool should set in_water_area")
	assert_true(buddy.is_swimming, "An NPC below the pool surface should be swimming")

	buddy.global_position = Vector3(0.0, 50.0, 0.0)
	await wait_physics_frames(2)
	assert_null(buddy.in_water_area, "Leaving the pool should clear in_water_area")


func test_driving_state_powers_radio_and_radial_menu() -> void:
	var player: Player = world.get_node("Player") as Player
	var radio: RadiOtPlayer3D = world.get_node("Player/RadiOtPlayer3D") as RadiOtPlayer3D
	assert_false(radio.is_power_on())

	player.current_state = NodeStateMachine.States.DRIVING
	assert_true(radio.is_power_on(), "Radio should power on when the player starts driving")
	assert_true(player.radial_menu.custom_item_provider.is_valid())

	player.current_state = NodeStateMachine.States.STANDING
	assert_false(radio.is_power_on(), "Radio should power off when the player stops driving")
	assert_false(player.radial_menu.custom_item_provider.is_valid())


func test_warp_zone_and_warp_to() -> void:
	var player: Player = world.get_node("Player") as Player
	var marker: Marker3D = world.get_node("WarpZone2/Marker3D") as Marker3D
	player.velocity = Vector3(1.0, 2.0, 3.0)

	world._on_warp_zone_body_entered(player, NodePath("WarpZone2/Marker3D"))
	assert_eq(player.global_position, marker.global_position)
	assert_eq(player.velocity, Vector3.ZERO)

	player.warp_to(Transform3D(Basis(), Vector3(5.0, 6.0, 7.0)))
	assert_eq(player.global_position, Vector3(5.0, 6.0, 7.0))
	assert_eq(player.up_direction, Vector3.UP)

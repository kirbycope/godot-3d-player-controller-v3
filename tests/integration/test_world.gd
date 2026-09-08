extends GutTest

## Purpose: World wiring: pool signals set NPC water areas, driving powers the radio, warp zones teleport the
## player, and the QA kit is in the spawned player's inventory.

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


func test_the_spawned_player_carries_the_qa_kit() -> void:
	var player: Player = world.get_node("Players/1") as Player
	var kit: Dictionary[Item, int] = world.STARTING_ITEMS
	assert_eq(kit.size(), 10, "Worms, rifle clips, an incendiary clip, a pistol magazine, arrows, fire arrows, ice arrows, rocks, apples and a dagger")
	for item: Item in kit:
		if item.category == Item.Category.EQUIPMENT:
			continue
		assert_eq(player.inventory.count_of(item), kit[item], "%d x %s on spawn" % [kit[item], item.get_display_name()])
	assert_eq(player.inventory.count_of(load("res://resources/lures/worm.tres")), 10)
	assert_eq(player.inventory.count_of(load("res://resources/items/arrow.tres")), 20)
	var rock: Item = load("res://resources/items/rock.tres")
	var apple: Item = load("res://resources/items/apple.tres")
	assert_true(rock.throwable and rock.throw_damage > 0.0, "The rock is the throwable that hurts")
	assert_true(apple.throwable and apple.consumable, "The apple is the throwable food")
	for ammo: Item in kit:
		if ammo is AmmoItem or ammo is Lure:
			assert_false(ammo.throwable, "%s is not thrown by hand" % ammo.get_display_name())
	var daggers: Array[Equipment] = player.inventory.get_all_weapons().filter(func(weapon: Equipment) -> bool: return weapon.scene_file_path == "res://scenes/dagger.tscn")
	assert_eq(daggers.size(), 1, "One dagger from its scene is in the backpack")
	assert_true(daggers[0].is_throwable, "and it is the throwable equipment")
	assert_true(player.inventory.is_unarmed(), "stowed, so the player spawns unarmed")
	player.inventory.remove_item(kit.keys()[0], 3)
	world._grant_starting_items(player)
	assert_eq(player.inventory.count_of(kit.keys()[0]), kit[kit.keys()[0]], "Granting again tops up rather than stacking on")
	assert_eq(player.inventory.get_all_weapons().size(), 1, "and hands out no second dagger")


func test_driving_state_powers_radio_and_radial_menu() -> void:
	var player: Player = world.get_node("Players/1") as Player
	var radio: RadiOtPlayer3D = world.get_node("Players/1/RadiOtPlayer3D") as RadiOtPlayer3D
	assert_false(radio.is_power_on())

	player.riding = world.get_node("HondaCRV")
	player.current_state = NodeStateMachine.States.RIDING
	assert_true(radio.is_power_on(), "Radio should power on when the player starts driving")
	assert_true(player.radial_menu.custom_item_provider.is_valid())

	player.current_state = NodeStateMachine.States.STANDING
	player.riding = null
	assert_false(radio.is_power_on(), "Radio should power off when the player stops driving")
	assert_false(player.radial_menu.custom_item_provider.is_valid())


func test_warp_zone_and_warp_to() -> void:
	var player: Player = world.get_node("Players/1") as Player
	var marker: Marker3D = world.get_node("WarpZone2/Marker3D") as Marker3D
	player.velocity = Vector3(1.0, 2.0, 3.0)

	world._on_warp_zone_body_entered(player, NodePath("WarpZone2/Marker3D"))
	assert_eq(player.global_position, marker.global_position)
	assert_eq(player.velocity, Vector3.ZERO)

	player.warp_to(Transform3D(Basis(), Vector3(5.0, 6.0, 7.0)))
	assert_eq(player.global_position, Vector3(5.0, 6.0, 7.0))
	assert_eq(player.up_direction, Vector3.UP)


func test_hud_temperature_gauge_stays_square() -> void:
	var gauge: Control = world.get_node("HUD/BottomRight/TemperatureGaugeDisplay")
	await wait_physics_frames(2)
	assert_eq(gauge.size, Vector2(36.0, 36.0), "The gauge dial is 36x36; a stretched height means an unpinned offset_bottom")


func test_the_world_plays_the_weather_fx_ambience() -> void:
	var sounds: Node3D = world.get_node_or_null("BackGroundSounds")
	assert_not_null(sounds, "world.tscn instances the addon's bgs.tscn (left in the addon)")
	var audio: WeatherAudio = world.get_node("WeatherFX/WeatherAudio")
	assert_eq(audio.bgs_day_clear, sounds.get_node("BGS_Day_Clear"), "and points WeatherAudio's slots at its players")
	assert_eq(audio.bgs_night_storm, sounds.get_node("BGS_Night_Storm"))
	var target: Node = audio.get_target_bgs_player()
	assert_not_null(target, "One of them matches the weather and the hour")
	assert_true(bool(target.get("playing")), "and is playing")

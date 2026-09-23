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
	var player: Player = world.get_node("PlayerSpawner/1") as Player
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
	var player: Player = world.get_node("PlayerSpawner/1") as Player
	var radio: RadiOtPlayer3D = world.get_node("HondaCRV/RadiOtPlayer3D") as RadiOtPlayer3D
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
	var player: Player = world.get_node("PlayerSpawner/1") as Player
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


func test_the_hosts_weather_reaches_peers_through_a_synchronizer() -> void:
	var sync: MultiplayerSynchronizer = world.get_node("WeatherFX/WeatherSynchronizer")
	var paths: Array = sync.replication_config.get_properties().map(func(p: NodePath) -> String: return String(p))
	assert_true(paths.has(".:synced_weather"), "The weather rides the synchronizer, as the clock does")
	assert_true(paths.has(".:synced_biome"), "and so does the biome")
	assert_eq(sync.root_path, NodePath(".."), "on the WeatherFX node itself")
	assert_false(world.has_method("_sync_weather"), "No RPC of the world's own any more")
	var weather: WeatherFX = world.get_node("WeatherFX")
	assert_false(weather.is_puppet(), "Offline this side is the authority")
	weather.set_weather(ClimateData.WeatherType.SNOW)
	assert_eq(weather.synced_weather, ClimateData.WeatherType.SNOW, "and what it would send is what it shows")


func test_the_world_plays_the_weather_fx_ambience_by_biome() -> void:
	var weather: WeatherFX = world.get_node("WeatherFX")
	assert_false(weather.bgs_sets.is_empty(), "The ambience sets are WeatherFX's own, a set for every biome")
	assert_null(world.get_node_or_null("BackGroundSounds"), "with no extra node to wire")
	var audio: WeatherAudio = world.get_node("WeatherFX/WeatherAudio")
	weather.blend_zones = false
	weather.current_biome = ClimateData.BiomeZone.ANCIENT_FOREST
	var target: AudioStreamPlayer = audio.get_target_bgs_player()
	assert_not_null(target, "In a forest WeatherAudio has a player for the loop the weather and the hour call for")
	assert_true(target.playing, "and it is playing")
	weather.current_biome = ClimateData.BiomeZone.TEMPERATE_PLAINS
	var plains: AudioStreamPlayer = audio.get_target_bgs_player()
	assert_not_null(plains, "The plains have loops of their own")
	assert_ne(plains, target, "not the forest's")
	assert_true(plains.playing, "and they take over")
	assert_false(target.playing)


## The world scene wires the Player this peer controls to what follows it: the HUD's noise meter reads that Player's
## noise (M14), the SaveGame hears the spawn (H8), and the end of the Steam session goes back to the title (H10). The
## updraft aura the addon no longer loads hangs on the Player template, hidden.
func test_the_local_player_is_wired_to_the_hud_the_save_and_the_session() -> void:
	var player: Player = world.get_node("PlayerSpawner/1") as Player
	var meter: NoiseMeter = world.get_node("HUD/BottomRight/NoiseMeter/Line") as NoiseMeter
	assert_eq(meter.noise, player.get_node("PlayerNoise"), "The noise meter reads the local Player's noise")
	var spawner: PlayerSpawner = world.get_node("PlayerSpawner") as PlayerSpawner
	assert_true(spawner.local_player_spawned.is_connected((world.get_node("SaveGame") as SaveGame).load_for_player), "The SaveGame hears the spawn")
	assert_true((world.get_node("SteamPeer") as SteamPeer).session_ended.is_connected(world._on_session_ended), "The end of the session is the world's to handle")
	assert_true(ResourceLoader.exists(world.title_scene), "and it goes back to a real title scene")
	world._on_session_ended()
	assert_true(is_instance_valid(world) and world.is_inside_tree(), "A world that is not the current scene (a test's) stays put")
	assert_not_null(player.updraft_aura, "The Player carries weather_fx's updraft aura")
	assert_false(player.updraft_aura.visible, "hidden until a thermal lifts it")


## The host spawns a client's round, throw or drop only for a scene on the ProjectileSpawner's list (M1), so
## everything a client in this world fires, throws or drops is listed: the world's firearms' rounds and the bow's
## arrows, the ammunition the QA kit hands out, the fishing float, a thrown item, a dropped item's pickup and the
## equipment that drops as its own scene.
func test_the_projectile_spawner_lists_everything_a_client_spawns() -> void:
	var spawner: ProjectileSpawner = world.get_node("ProjectileSpawner")
	var scenes: Array[PackedScene] = [Inventory.ITEM_PICKUP_SCENE, HeldObject.THROWN_ITEM_SCENE, load("res://scenes/fishing_rod.tscn")]
	for firearm: Node in world.find_children("*", "Firearm", true, false):
		scenes.append((firearm as Firearm).projectile_scene)
	for bow: Node in world.find_children("*", "Bow", true, false):
		scenes.append((bow as Bow).arrow_scene)
	scenes.append((world.get_node("FishingRod") as FishingRod).bobber_scene)
	for item: Item in world.STARTING_ITEMS:
		if item is AmmoItem and (item as AmmoItem).projectile_scene:
			scenes.append((item as AmmoItem).projectile_scene)
		if item.equipment_scene:
			scenes.append(item.equipment_scene)
	assert_gt(scenes.size(), 8)
	for scene: PackedScene in scenes:
		assert_true(spawner._is_spawnable(scene.resource_path), "%s is on the Auto Spawn List" % scene.resource_path)

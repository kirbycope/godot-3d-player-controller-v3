extends Node3D
## The demo world. Players are spawned per peer by [PlayerSpawner]; the lobby owner hosts the Steam
## session through [SteamPeer]. Server-owned state (clock, weather, NPCs, physics props, harvestables)
## replicates to clients through the synchronizers in the scenes; projectiles spawn on every peer
## through [ProjectileSpawner].

const RADIO_OFF_ICON: Texture2D = preload("res://addons/radi_ot/assets/icons/stop_icon.svg")
## The QA kit: what a freshly spawned local player carries, topped up to these counts (a saved inventory keeps
## whatever else it holds). This world is the test bed, so nothing has to be found first. Equipment items go in
## the backpack stowed, one each, unless a copy from their scene is carried already.
const STARTING_ITEMS: Dictionary[Item, int] = {
	preload("res://resources/lures/worm.tres"): 10,
	preload("res://resources/items/rifle_clip.tres"): 2,
	preload("res://resources/items/pistol_magazine.tres"): 1,
	preload("res://resources/items/arrow.tres"): 20,
	preload("res://resources/items/fire_arrow.tres"): 5,
	preload("res://resources/items/ice_arrow.tres"): 5,
	preload("res://resources/items/rifle_clip_incendiary.tres"): 1,
	preload("res://resources/items/rock.tres"): 5,
	preload("res://resources/items/apple.tres"): 3,
	preload("res://resources/items/dagger.tres"): 1,
}

## GodotSteam constant mirrors (the Steam class is absent on web exports).
const STEAM_RESULT_OK: int = 1
const STEAM_LOBBY_TYPE_PUBLIC: int = 2

## The pad layout this world is played on, put on the Player as it spawns. Tears of the Kingdom's, the one the
## world was built around: Focus locks on, the bottom button dashes and the right one is Action. Clear it to
## leave the Player on whatever its own scene or the settings menu chose.
@export var control_scheme: ControlScheme = preload("res://addons/3d_player_controller/resources/control_schemes/tears_of_the_kingdom.tres")
## Forces the whole on-screen control HUD. Off, the saved On-Screen setting decides: Auto by default, so the
## buttons show on a touchscreen and otherwise only as contextual hints. The demo levels draw the whole set,
## which is where a layout is checked.
@export var show_controls: bool = false

@export var max_lobby_players: int = 4

var player: Player ## The player this peer controls, once spawned.
var radi_ot_player: RadiOtPlayer3D ## The radio of the road car the local Player is in, null on foot; the car's own, heard around the car.
var _radio_car: GtaCar ## The road car the local Player is in.

@onready var player_spawner: PlayerSpawner = $PlayerSpawner
@onready var steam_peer: SteamPeer = $SteamPeer
@onready var date_and_time: DateAndTime = $DateAndTime
@onready var weather_fx: WeatherFX = $WeatherFX


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(SaveGame.GROUP)
	_initialize_steam_lobby()
	_apply_network_roles()
	# A car radio waits for a driver: off, with its HUD out of the way, until the local Player gets in
	for radio: Node in get_tree().get_nodes_in_group(&"radio"):
		(radio as RadiOtPlayer3D).set_power(false)
		(radio as RadiOtPlayer3D).get_hud().hide_hud()


## What a [SaveGame] keeps of the world itself: the clock and the weather. The Players, the enemies and the
## harvestables save themselves.
func save_state() -> Dictionary:
	return {
		"time": date_and_time.get_datetime_dict(),
		"biome": weather_fx.current_biome,
		"weather": weather_fx.active_weather,
	}


func load_state(state: Dictionary) -> void:
	if state.get("time") is Dictionary:
		date_and_time.set_from_datetime_dict(state["time"])
	if state.has("biome") and not weather_fx.is_blending_zones():
		weather_fx.current_biome = int(state["biome"]) as ClimateData.BiomeZone
	if state.has("weather"):
		weather_fx.set_weather(int(state["weather"]) as ClimateData.WeatherType)


## A felled tree is firewood for the Guide's errand; ore is not.
## A tree came down (each tree's depleted is connected here in the scene): the chopping quest moves on.
func _on_tree_chopped() -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"chop_tree")


## Tops the player's inventory up to the [constant STARTING_ITEMS] counts.
func _grant_starting_items(target: Player) -> void:
	for item: Item in STARTING_ITEMS:
		if item.category == Item.Category.EQUIPMENT:
			_grant_starting_equipment(target, item)
			continue
		var missing: int = STARTING_ITEMS[item] - target.inventory.count_of(item)
		if missing > 0:
			target.inventory.add_item(item, missing)


## Puts one of an equipment item's scene in the backpack, stowed so the player still spawns unarmed, unless a copy
## from that scene is carried already.
func _grant_starting_equipment(target: Player, item: Item) -> void:
	if item.equipment_scene == null:
		return
	for carried: Equipment in target.inventory.get_all_weapons():
		if carried.scene_file_path == item.equipment_scene.resource_path:
			return
	var copy: Equipment = target.inventory.add_equipment_scene(item.equipment_scene)
	if copy:
		target.inventory.stow_equipment(copy)


## Binds the world to the player this peer controls (connected in the scene to PlayerSpawner.local_player_spawned).
func _on_local_player_spawned(local_player: Player) -> void:
	player = local_player
	player.enable_paraglider = true
	player.enable_stamina = true
	# The buttons on screen, drawn in this world's own layout unless the player picked one in the settings, which
	# the Player applied in its own _ready and which wins over the world's default
	if control_scheme and PlayerSettingsResource.load_or_create().picked_scheme() == null:
		player.control_scheme = control_scheme
	# Off by default: the saved On-Screen setting decides, which is Auto unless the player changed it, so the
	# buttons show on a touchscreen and otherwise only as contextual hints; the demo levels are where the whole
	# set is drawn to check a layout
	if show_controls:
		player.hud_mode_override = PlayerSettingsResource.HudMode.SHOWN
	player.state_changed.connect(_on_player_state_changed)
	player.whistled.connect(_on_player_whistled)
	_grant_starting_items(player)
	# The spawner readies before this node, so resolve siblings directly instead of through @onready
	($WeatherFX as WeatherFX).target_node = player
	# NPCs follow the server's player; clients only display them
	if multiplayer.is_server():
		($Duck as FollowerNpc).player = player
		($LittleBuddy as FollowerNpc).player = player
	print("World ready: %s spawned as peer %d" % [player.name, multiplayer.get_unique_id()]) # what tools/web_smoke_test.py waits for


## The local Player whistled: the whistle is heard, and the nearest horse in earshot comes (Horse.summon relays
## the call to its authority). The sound is an AudioStreamRandomizer on the Player's own WhistleAudio, so the
## same player does not whistle identically twice; a scene that has no WhistleAudio simply whistles silently.
func _on_player_whistled(whistler: Player) -> void:
	var whistle_audio: AudioStreamPlayer3D = whistler.get_node_or_null("WhistleAudio") as AudioStreamPlayer3D
	if whistle_audio:
		whistle_audio.play()
	Horse.summon_nearest(whistler)


## The server runs the clock; clients receive it through the TimeSynchronizer, and the weather and biome through
## the WeatherSynchronizer under WeatherFX (a client keeps its own biome while it reads the zones around its Player).
func _apply_network_roles() -> void:
	date_and_time.is_running = multiplayer.is_server()


## Powers the car's radio and puts its stations on the radial menu while the local Player is in it. The station is
## the car's (GtaCar.radio_station, replicated), and the car's scene tunes its radio to it on every peer, so the
## driver's pick is what everyone in and around the car hears.
func _on_player_state_changed(from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.RIDING and player.riding is GtaCar:
		_radio_car = player.riding as GtaCar
		radi_ot_player = _radio_car.get_node("RadiOtPlayer3D") as RadiOtPlayer3D
		radi_ot_player.tune_to_station_index(_radio_car.radio_station)
		radi_ot_player.set_power(true)
		radi_ot_player.get_hud().show_toast(5.0)
		player.radial_menu.custom_item_provider = _provide_radio_items
		player.radial_menu.custom_item_selected = _on_radio_item_selected
		player.radial_menu.custom_item_is_equipped = _is_radio_item_equipped
		player.inventory.custom_cycle_handler = _on_cycle_radio_station
	elif from_state == NodeStateMachine.States.RIDING:
		if is_instance_valid(radi_ot_player):
			radi_ot_player.set_power(false)
			radi_ot_player.get_hud().hide_toast()
		radi_ot_player = null
		_radio_car = null
		player.radial_menu.custom_item_provider = Callable()
		player.radial_menu.custom_item_selected = Callable()
		player.radial_menu.custom_item_is_equipped = Callable()
		player.inventory.custom_cycle_handler = Callable()


func _on_warp_zone_body_entered(body: Node3D, marker_path: NodePath) -> void:
	if body is Player and (body as Player).is_multiplayer_authority():
		(body as Player).warp_to((get_node(marker_path) as Marker3D).global_transform)


func _on_water_area_3d_body_entered(body: Node3D, water_area_path: NodePath) -> void:
	var water_area: Area3D = get_node(water_area_path)
	if body is Player:
		(body as Player).enter_water(water_area)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = water_area
	elif body is Horse:
		(body as Horse).in_water_area = water_area as Buoyancy


func _on_water_area_3d_body_exited(body: Node3D, water_area_path: NodePath) -> void:
	if body is Player:
		(body as Player).exit_water(get_node(water_area_path) as Area3D)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = null
	elif body is Horse:
		(body as Horse).in_water_area = null


func _provide_radio_items() -> Array:
	var items: Array = []
	items.append({
		"is_radio_off": true,
		"display_name": "Radio Off",
		"icon": RADIO_OFF_ICON
	})
	if radi_ot_player.station_collection:
		for i: int in range(radi_ot_player.station_collection.get_station_count()):
			var station: RadioStation = radi_ot_player.station_collection.get_station_at(i)
			if station:
				items.append({
					"station": station,
					"station_index": i,
					"display_name": station.get_full_title(),
					"icon": station.logo
				})
	return items


func _on_radio_item_selected(item: Variant, index: int) -> void:
	if index == 0 or (item is Dictionary and item.get("is_radio_off")):
		radi_ot_player.set_power(false)
	elif item is Dictionary and "station_index" in item:
		radi_ot_player.set_power(true)
		_radio_car.radio_station = item.station_index


func _is_radio_item_equipped(item: Variant, index: int) -> bool:
	if index == 0 or (item is Dictionary and item.get("is_radio_off")):
		return not radi_ot_player.is_power_on()
	if item is Dictionary and "station_index" in item:
		return radi_ot_player.is_power_on() and radi_ot_player.current_station_index == item.station_index
	return false


## The driver's next / previous station action moves the car's station; the radio follows through the car's signal.
func _on_cycle_radio_station(direction: int) -> void:
	if not radi_ot_player.is_power_on():
		radi_ot_player.set_power(true)
		return
	_radio_car.radio_station = posmod(_radio_car.radio_station + direction, maxi(radi_ot_player.get_station_count(), 1))


## The car radio's signals are connected here in the scene; they matter while the local Player is in that car.
func _on_radio_station_changed(_station: RadioStation) -> void:
	if radi_ot_player and player and player.riding == _radio_car:
		radi_ot_player.get_hud().show_toast(5.0)


func _on_radio_toggled(_is_playing: bool) -> void:
	if radi_ot_player and player and player.riding == _radio_car:
		radi_ot_player.get_hud().show_toast(5.0)


## Joins the lobby we arrived through (SteamPeer connects on ready) or creates one and hosts it.
func _initialize_steam_lobby() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	if not steam.isSteamRunning():
		return

	var steamworks: Node = get_node_or_null("/root/Steamworks")
	var current_lobby_id: int = steamworks.lobby_id if steamworks else 0

	# Only create a lobby if not already in one
	if current_lobby_id == 0:
		var callback_connect: int = steam.connect("lobby_created", Callable(self, "_on_steam_lobby_created"))
		if callback_connect != OK and callback_connect != ERR_ALREADY_EXISTS:
			printerr("Connecting lobby_created callback failed: %s" % callback_connect)
		# Create a public lobby for up to max_lobby_players
		steam.createLobby(STEAM_LOBBY_TYPE_PUBLIC, max_lobby_players)
		print("Requested Steam lobby creation for single-player world.")


func _on_steam_lobby_created(connect_status: int, lobby_id: int) -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	if connect_status == STEAM_RESULT_OK:
		var steamworks: Node = get_node_or_null("/root/Steamworks")
		if steamworks:
			steamworks.lobby_id = lobby_id
		var username: String = steamworks.username if steamworks else "Player"
		var lobby_name: String = "%s's World" % username
		steam.setLobbyData(lobby_id, "lobby_name", lobby_name)
		steam.setLobbyData(lobby_id, "name", lobby_name)
		steam.setLobbyData(lobby_id, "game", "Godot3DPlayerController")
		steam.setLobbyData(lobby_id, "mode", "world")
		print("Auto-created Steam Lobby: %s (ID: %d)" % [lobby_name, lobby_id])
		# Host the session for anyone who joins this lobby
		steam_peer.host()
		_apply_network_roles()
	else:
		printerr("Failed to auto-create Steam lobby: %s" % connect_status)

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

@export var max_lobby_players: int = 4

var player: Player ## The player this peer controls, once spawned.
var radi_ot_player: RadiOtPlayer3D ## The local player's car radio.

@onready var player_spawner: PlayerSpawner = $PlayerSpawner
@onready var steam_peer: SteamPeer = $SteamPeer
@onready var date_and_time: DateAndTime = $DateAndTime
@onready var weather_fx: WeatherFX = $WeatherFX


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the mouse mode to captured to hide the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_initialize_steam_lobby()
	_apply_network_roles()


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
	player.state_changed.connect(_on_player_state_changed)
	_grant_starting_items(player)
	radi_ot_player = player.get_node("RadiOtPlayer3D")
	radi_ot_player.auto_play_on_ready = false
	radi_ot_player.set_power(false)
	radi_ot_player.get_hud().hide_hud()
	radi_ot_player.radio_toggled.connect(_on_radio_toggled)
	radi_ot_player.station_changed.connect(_on_radio_station_changed)
	# The spawner readies before this node, so resolve siblings directly instead of through @onready
	($WeatherFX as WeatherFX).target_node = player
	# NPCs follow the server's player; clients only display them
	if multiplayer.is_server():
		($Duck as FollowerNpc).player = player
		($LittleBuddy as FollowerNpc).player = player


## The server runs the clock and weather; clients receive them.
func _apply_network_roles() -> void:
	var is_server: bool = multiplayer.is_server()
	date_and_time.is_running = is_server
	if is_server:
		if not weather_fx.weather_changed.is_connected(_on_weather_changed):
			weather_fx.weather_changed.connect(_on_weather_changed)
			weather_fx.biome_changed.connect(_on_biome_changed)
			multiplayer.peer_connected.connect(_send_weather_to_peer)


func _on_weather_changed(new_weather: ClimateData.WeatherType, _old_weather: ClimateData.WeatherType) -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_weather.rpc(weather_fx.current_biome, new_weather)


func _on_biome_changed(new_biome: ClimateData.BiomeZone, _old_biome: ClimateData.BiomeZone) -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_weather.rpc(new_biome, weather_fx.active_weather)


func _send_weather_to_peer(peer_id: int) -> void:
	_sync_weather.rpc_id(peer_id, weather_fx.current_biome, weather_fx.active_weather)


@rpc("authority", "call_remote", "reliable")
func _sync_weather(biome: ClimateData.BiomeZone, weather: ClimateData.WeatherType) -> void:
	weather_fx.current_biome = biome
	weather_fx.set_weather(weather)


## Powers the car radio and its radial-menu stations while the local Player drives.
func _on_player_state_changed(from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.RIDING and player.riding is Vehicle:
		radi_ot_player.set_power(true)
		radi_ot_player.get_hud().show_toast(5.0)
		player.radial_menu.custom_item_provider = _provide_radio_items
		player.radial_menu.custom_item_selected = _on_radio_item_selected
		player.radial_menu.custom_item_is_equipped = _is_radio_item_equipped
		player.inventory.custom_cycle_handler = _on_cycle_radio_station
	elif from_state == NodeStateMachine.States.RIDING:
		radi_ot_player.set_power(false)
		radi_ot_player.get_hud().hide_toast()
		player.radial_menu.custom_item_provider = Callable()
		player.radial_menu.custom_item_selected = Callable()
		player.radial_menu.custom_item_is_equipped = Callable()
		player.inventory.custom_cycle_handler = Callable()


func _on_warp_zone_body_entered(body: Node3D, marker_path: NodePath) -> void:
	if body is Player and (body as Player).is_multiplayer_authority():
		(body as Player).warp_to((get_node(marker_path) as Marker3D).global_transform)


## Respawns a Player that fell out of the world at their starting position.
func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body is Player and (body as Player).is_multiplayer_authority() and not (body as Player).is_riding and not (body as Player).is_flying:
		(body as Player).warp_to((body as Player).initial_transform)


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
		radi_ot_player.tune_to_station_index(item.station_index)


func _is_radio_item_equipped(item: Variant, index: int) -> bool:
	if index == 0 or (item is Dictionary and item.get("is_radio_off")):
		return not radi_ot_player.is_power_on()
	if item is Dictionary and "station_index" in item:
		return radi_ot_player.is_power_on() and radi_ot_player.current_station_index == item.station_index
	return false


func _on_cycle_radio_station(direction: int) -> void:
	if not radi_ot_player.is_power_on():
		radi_ot_player.set_power(true)
		return
	if direction > 0:
		radi_ot_player.tune_next_station()
	else:
		radi_ot_player.tune_previous_station()


func _on_radio_station_changed(_station: RadioStation) -> void:
	if player.riding is Vehicle:
		radi_ot_player.get_hud().show_toast(5.0)


func _on_radio_toggled(_is_playing: bool) -> void:
	if player.riding is Vehicle:
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

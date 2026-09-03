extends Node3D

const RADIO_OFF_ICON: Texture2D = preload("res://addons/radi_ot/assets/icons/stop_icon.svg")

## GodotSteam constant mirrors (the Steam class is absent on web exports).
const STEAM_RESULT_OK: int = 1
const STEAM_LOBBY_TYPE_PUBLIC: int = 2

@export var max_lobby_players: int = 4

@onready var player: Player = $Player
@onready var radi_ot_player: RadiOtPlayer3D = $Player/RadiOtPlayer3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the mouse mode to captured to hide the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Set the game style parameters
	player.enable_paraglider = true
	player.enable_stamina = true

	_initialize_steam_lobby()

	radi_ot_player.auto_play_on_ready = false
	radi_ot_player.set_power(false)
	radi_ot_player.get_hud().hide_hud()


## Powers the car radio and its radial-menu stations while the Player drives.
func _on_player_state_changed(from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.DRIVING:
		radi_ot_player.set_power(true)
		radi_ot_player.get_hud().show_toast(5.0)
		player.radial_menu.custom_item_provider = _provide_radio_items
		player.radial_menu.custom_item_selected = _on_radio_item_selected
		player.radial_menu.custom_item_is_equipped = _is_radio_item_equipped
		player.inventory.custom_cycle_handler = _on_cycle_radio_station
	elif from_state == NodeStateMachine.States.DRIVING:
		radi_ot_player.set_power(false)
		radi_ot_player.get_hud().hide_toast()
		player.radial_menu.custom_item_provider = Callable()
		player.radial_menu.custom_item_selected = Callable()
		player.radial_menu.custom_item_is_equipped = Callable()
		player.inventory.custom_cycle_handler = Callable()


func _on_warp_zone_body_entered(body: Node3D, marker_path: NodePath) -> void:
	if body is Player:
		(body as Player).warp_to((get_node(marker_path) as Marker3D).global_transform)


## Respawns a Player that fell out of the world at their starting position.
func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_driving and not (body as Player).is_flying:
		(body as Player).warp_to((body as Player).initial_transform)


func _on_water_area_3d_body_entered(body: Node3D, water_area_path: NodePath) -> void:
	var water_area: Area3D = get_node(water_area_path)
	if body is Player:
		(body as Player).enter_water(water_area)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = water_area
	elif body is BeachBall:
		(body as BeachBall).in_water_area = water_area


func _on_water_area_3d_body_exited(body: Node3D, water_area_path: NodePath) -> void:
	if body is Player:
		(body as Player).exit_water(get_node(water_area_path) as Area3D)
	elif body is FollowerNpc:
		(body as FollowerNpc).in_water_area = null
	elif body is BeachBall:
		(body as BeachBall).in_water_area = null


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
	if player.current_state == NodeStateMachine.States.DRIVING:
		radi_ot_player.get_hud().show_toast(5.0)


func _on_radio_toggled(_is_playing: bool) -> void:
	if player.current_state == NodeStateMachine.States.DRIVING:
		radi_ot_player.get_hud().show_toast(5.0)


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
	else:
		printerr("Failed to auto-create Steam lobby: %s" % connect_status)

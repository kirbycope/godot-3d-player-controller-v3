extends Node3D

const RADIO_OFF_ICON: Texture2D = preload("res://addons/radi_ot/assets/icons/stop_icon.svg")

@export var little_buddy_count: int = 64
@export var spawn_frame_interval: int = 4
@export var max_lobby_players: int = 4

@onready var player: Player = $Player
@onready var first_buddy: Node3D = get_node_or_null("LittleBuddy") as Node3D
@onready var radi_ot_player: RadiOtPlayer3D = get_node_or_null("Player/RadiOtPlayer3D") as RadiOtPlayer3D
var buddy_list: Array[Node3D] = []
var frame_counter: int = 0
var _was_driving: bool = false


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the mouse mode to captured to hide the mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Set the game style parameters
	player.enable_paraglider = true
	player.enable_stamina = true

	_initialize_steam_lobby()

	if radi_ot_player:
		radi_ot_player.auto_play_on_ready = false
		radi_ot_player.set_power(false)
		radi_ot_player.station_changed.connect(_on_radio_station_changed)
		radi_ot_player.radio_toggled.connect(_on_radio_toggled)
		var hud = radi_ot_player.get_hud()
		if hud:
			hud.hide_hud()

	if first_buddy:
		if player:
			first_buddy.set("player", player)
		buddy_list.append(first_buddy)


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# DEBUG - Whistle action triggers ragdoll state for the player
	if event.is_action_pressed("whistle"):
		if player and (player.is_paused or (player.pause and player.pause.visible)):
			return
		if player and player.held_object and player.held_object.is_holding_object():
			return
		player.state_machine.travel(player.current_state, NodeStateMachine.States.RAGDOLLING)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	var is_actively_driving: bool = (
		player != null
		and player.is_driving
		and not player.is_entering_vehicle
		and not player.is_exiting_vehicle
	)
	if is_actively_driving != _was_driving:
		_was_driving = is_actively_driving
		if is_actively_driving:
			_on_player_started_driving()
		else:
			_on_player_stopped_driving()

	# Spawn LittleBuddy at the specified frame interval until reaching target count.
	#if first_buddy and buddy_list.size() < little_buddy_count:
	#	frame_counter += 1
	#	if frame_counter >= spawn_frame_interval:
	#		frame_counter = 0
	#		var duplicate_buddy = first_buddy.duplicate() as Node3D
	#		if player:
	#			duplicate_buddy.set("player", player)
	#		add_child(duplicate_buddy)
	#		buddy_list.append(duplicate_buddy)

	# If we're below -40, respawn (teleport to the initial position).
	if player and not player.is_driving and not player.is_flying:
		if player.global_position.y < -40.0:
			_warp(player, player.initial_transform)

	# Check if the "CameraRayCast" is colliding with an object that has a "display_menu" method, and if so, call that method
	if player.camera.camera_ray_cast.is_colliding():
		var collider = player.camera.camera_ray_cast.get_collider()
		if collider:
			var target = null
			var current_node = collider
			while current_node:
				if current_node.has_method("display_menu"):
					target = current_node
					break
				current_node = current_node.get_parent()
			
			if target:
				if player.camera.looking_at and player.camera.looking_at != target and player.camera.looking_at.has_method("hide_menu"):
					player.camera.looking_at.hide_menu()
				target.display_menu(player)
				player.camera.looking_at = target
			else:
				if player.camera.looking_at and player.camera.looking_at.has_method("hide_menu"):
					player.camera.looking_at.hide_menu()
				player.camera.looking_at = null
	else:
		if player.camera.looking_at and player.camera.looking_at.has_method("hide_menu"):
			player.camera.looking_at.hide_menu()
		player.camera.looking_at = null


func _on_warp_zone_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _on_warp_zone_2_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone2/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _on_warp_zone_3_body_entered(body: Node3D) -> void:
	var target_marker: Marker3D = $WarpZone3/Marker3D as Marker3D
	_warp(body, target_marker.global_transform)


func _on_water_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		var water_area := get_node_or_null("Pool/WaterArea3D") as Area3D
		(body as Player).enter_water(water_area)


func _on_water_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		var water_area := get_node_or_null("Pool/WaterArea3D") as Area3D
		(body as Player).exit_water(water_area)


func _warp(body: Node3D, target_transform: Transform3D) -> void:
	if body is Player:
		var warp_player: Player = body as Player
		warp_player.global_transform = target_transform
		warp_player.velocity = Vector3.ZERO
		warp_player.up_direction = target_transform.basis.y.normalized()
		warp_player.orientation = Transform3D(warp_player.global_transform.basis, Vector3.ZERO)
		warp_player.player_model.transform = warp_player.initial_player_model_transform
		warp_player.collision_shape.transform = warp_player.initial_collision_shape_transform


func _on_player_started_driving() -> void:
	if radi_ot_player:
		radi_ot_player.set_power(true)
		var hud = radi_ot_player.get_hud()
		if hud:
			hud.show_toast(5.0)

	if player and player.inventory:
		var radial_menu = player.inventory.get_node_or_null("RadialMenu") as RadialMenu
		if radial_menu:
			radial_menu.custom_item_provider = _provide_radio_items
			radial_menu.custom_item_selected = _on_radio_item_selected
			radial_menu.custom_item_is_equipped = _is_radio_item_equipped
		player.inventory.custom_cycle_handler = _on_cycle_radio_station


func _on_player_stopped_driving() -> void:
	if radi_ot_player:
		radi_ot_player.set_power(false)
		var hud = radi_ot_player.get_hud()
		if hud:
			hud.hide_toast()

	if player and player.inventory:
		var radial_menu = player.inventory.get_node_or_null("RadialMenu") as RadialMenu
		if radial_menu:
			radial_menu.custom_item_provider = Callable()
			radial_menu.custom_item_selected = Callable()
			radial_menu.custom_item_is_equipped = Callable()
		player.inventory.custom_cycle_handler = Callable()


func _provide_radio_items() -> Array:
	var items: Array = []
	items.append({
		"is_radio_off": true,
		"display_name": "Radio Off",
		"icon": RADIO_OFF_ICON
	})
	if radi_ot_player and radi_ot_player.station_collection:
		for i in range(radi_ot_player.station_collection.get_station_count()):
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
	if not radi_ot_player:
		return
	if index == 0 or (item is Dictionary and item.get("is_radio_off")):
		radi_ot_player.set_power(false)
	elif item is Dictionary and "station_index" in item:
		radi_ot_player.set_power(true)
		radi_ot_player.tune_to_station_index(item.station_index)


func _is_radio_item_equipped(item: Variant, index: int) -> bool:
	if not radi_ot_player:
		return false
	if index == 0 or (item is Dictionary and item.get("is_radio_off")):
		return not radi_ot_player.is_power_on()
	if item is Dictionary and "station_index" in item:
		return radi_ot_player.is_power_on() and radi_ot_player.current_station_index == item.station_index
	return false


func _on_cycle_radio_station(direction: int) -> void:
	if not radi_ot_player:
		return
	if not radi_ot_player.is_power_on():
		radi_ot_player.set_power(true)
		return
	if direction > 0:
		radi_ot_player.tune_next_station()
	else:
		radi_ot_player.tune_previous_station()


func _on_radio_station_changed(_station: RadioStation) -> void:
	if radi_ot_player and _was_driving:
		var hud = radi_ot_player.get_hud()
		if hud:
			hud.show_toast(5.0)


func _on_radio_toggled(_is_playing: bool) -> void:
	if radi_ot_player and _was_driving:
		var hud = radi_ot_player.get_hud()
		if hud:
			hud.show_toast(5.0)


func _initialize_steam_lobby() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	if not steam.isSteamRunning():
		return

	var steamworks = get_node_or_null("/root/Steamworks")
	var current_lobby_id: int = steamworks.lobby_id if steamworks else 0

	# Only create a lobby if not already in one
	if current_lobby_id == 0:
		var callback_connect: int = Steam.connect("lobby_created", Callable(self, "_on_steam_lobby_created"))
		if callback_connect != OK and callback_connect != ERR_ALREADY_EXISTS:
			printerr("Connecting lobby_created callback failed: %s" % callback_connect)
		# Create a public lobby for up to max_lobby_players
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_lobby_players)
		print("Requested Steam lobby creation for single-player world.")


func _on_steam_lobby_created(connect_status: int, lobby_id: int) -> void:
	if not Engine.has_singleton("Steam"):
		return
	if connect_status == Steam.RESULT_OK:
		var steamworks = get_node_or_null("/root/Steamworks")
		if steamworks:
			steamworks.lobby_id = lobby_id
		var username: String = steamworks.username if steamworks else "Player"
		var lobby_name: String = "%s's World" % username
		Steam.setLobbyData(lobby_id, "lobby_name", lobby_name)
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		Steam.setLobbyData(lobby_id, "game", "Godot3DPlayerController")
		Steam.setLobbyData(lobby_id, "mode", "world")
		print("Auto-created Steam Lobby: %s (ID: %d)" % [lobby_name, lobby_id])
	else:
		printerr("Failed to auto-create Steam lobby: %s" % connect_status)

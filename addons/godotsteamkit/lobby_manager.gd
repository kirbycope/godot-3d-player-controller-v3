@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Lobby Manager
##
## This is a purely optional parent scene for the lobby, host, and join scenes.
## Those scenes should work on their own, independent of this manager scene. The
## most important piece here is the _on_lobby_joined function which controls
## showing the lobby node when the player joins one.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

## The main lobby scene that is displayed when the user has successfully joined a lobby.
const LOBBY = preload("uid://b3i138wxixo4y")
## The hosting scene which allows the user to set up their own lobby.
const LOBBY_HOST = preload("uid://cyjki2kcfa34b")
## The join / lobby list scene to browse up to 50 lobbies and set filters for searching.
const LOBBY_JOIN = preload("uid://dvg3786kfbaty")

@onready var _exit: Button = %Exit
@onready var _host: Button = %Host
@onready var _join: Button = %Join
@onready var _scene: Control = %Scene


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_signals()
	_get_command_line_invite()


#region Signals
func _connect_signals() -> void:
	_exit.pressed.connect(_on_exit_pressed)
	_host.pressed.connect(_on_host_pressed)
	_join.pressed.connect(_on_join_pressed)


func _on_close_panel(this_panel: Control) -> void:
	_host.disabled = false
	_join.disabled = false
	this_panel.visible = false
	this_panel.queue_free()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_host_pressed() -> void:
	_clear_lobby()
	_clear_scene()
	_host.disabled = true
	_join.disabled = false
	var new_host := LOBBY_HOST.instantiate()
	new_host.close_panel.connect(_on_close_panel.bind(new_host))
	_scene.call_deferred("add_child", new_host)


func _on_join_pressed() -> void:
	_clear_lobby()
	_clear_scene()
	_host.disabled = false
	_join.disabled = true
	var new_join := LOBBY_JOIN.instantiate()
	new_join.close_panel.connect(_on_close_panel.bind(new_join))
	_scene.call_deferred("add_child", new_join)
#endregion


#region Steam signals
func _connect_steam_signals() -> void:
	_steam_callback_wrapper("lobby_joined", "_on_lobby_joined")


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: int, response: Steam.ChatRoomEnterResponse) -> void:
	if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Lobby %s joined successfully" % lobby_id)
		Steamworks.lobby_id = lobby_id
		_clear_scene()

		var new_lobby := LOBBY.instantiate()
		new_lobby.close_panel.connect(_on_close_panel.bind(new_lobby))
		_scene.call_deferred("add_child", new_lobby)
	else:
		match response:
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				printerr("Failed joining lobby %s, this lobby no longer exists.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
				printerr("Failed joining lobby %s, you don't have permission to join this Lobbies.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
				printerr("Failed joining lobby %s, the lobby is now full.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_ERROR:
				printerr("Failed joining lobby %s, something unexpected happened!")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				printerr("Failed joining lobby %s, you are banned from this lobby.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
				printerr("Failed joining lobby %s, you cannot join due to having a limited account.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED:
				printerr("Failed joining lobby %s, this lobby is locked or disabled.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN:
				printerr("Failed joining lobby %s, this lobby is community locked.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
				printerr("Failed joining lobby %s, a user in the lobby has blocked you from joining.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
				printerr("Failed joining lobby %s, a user you have blocked is in the lobby.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_RATE_LIMIT_EXCEEDED:
				printerr("Failed joining lobby %s, you have exceeded the rate limit.")


# A helper function to wrap a Steam callback and check if it has failed to
# connect properly.
func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


#region Helpers
func _clear_lobby() -> void:
	if Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0


func _clear_scene() -> void:
	if _scene.get_child_count() > 0:
		for this_child in _scene.get_children():
			this_child.visible = false
			this_child.queue_free()


func _get_command_line_invite() -> void:
	var command_line_args: Array = OS.get_cmdline_args()
	if command_line_args.size() > 0:
		print("Command line arguments from Godot: %s" % [OS.get_cmdline_args()])
	if command_line_args[0] != "+connect_lobby":
		return
	if int(command_line_args[1]) > 0:
		Steam.joinLobby(int(command_line_args[1]))
#endregion

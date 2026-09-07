extends Node
## Steam Autoload
##
## A script for loading Steam and checking various things.

## This triggers if there is some kind of Steamworks error, the Steam singleton
## is not present in Godot, or is the Steam client is not running. It can be
## used to display an error to the player in any scene.
signal steamworks_error
## This pulls the app ID from project settings or it can be overridden here.
var app_id: int = ProjectSettings.get_setting("steam/initialization/app_data/app_id")
var app_installed_depots: Array = []
var app_languages: String = ""
var app_owner: int = 0
var build_id: int = 0
var game_acquired: int = 0
var install_dir: String = ""
var is_low_violence: bool = false
var is_on_steam_deck: bool = false
var is_on_vr: bool = false
var is_parental_blocked: bool = false
var is_vac_banned: bool = false
var language_game: String = ""
var language_ui: String = "EN"
var launch_command_line: String = ""
var leaderboard_handles: Dictionary[StringName, int] = {}
var lobby_id: int = 0
var steam_id: int = 0
var username: String = "Player"


func _ready() -> void:
	if OS.has_feature("web"):
		return
	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if rendering_method == "forward_plus" and Engine.has_singleton("Steam"):
		initialize_steam()


#region Collect data
func collect_build_data() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	build_id = steam.getAppBuildId()
	install_dir = steam.getAppInstallDir(app_id)


func collect_game_data() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	app_owner = steam.getAppOwner()
	app_languages = steam.getAvailableGameLanguages()
	app_installed_depots = steam.getInstalledDepots(app_id)
	launch_command_line = steam.getLaunchCommandLine()
	is_low_violence = steam.isLowViolence() if steam.has_method("isLowViolence") else false
	is_on_steam_deck = steam.call("isSteamRunningOnSteamDeck") if steam.has_method("isSteamRunningOnSteamDeck") else false
	is_on_vr = steam.isSteamRunningInVR() if steam.has_method("isSteamRunningInVR") else false


# We will get some general data about the user's setup from Steam. This will let
# us know if we need to change the in-game language (if that is possible), if we
# should try to block multiplayer due to VAC bans, etc. Oh, and the Steam ID!
# Most important piece.
func collect_user_data() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	steam_id = steam.getSteamID()
	username = steam.getPersonaName()
	language_game = steam.getCurrentGameLanguage()
	language_ui = steam.getSteamUILanguage()
	game_acquired = steam.getEarliestPurchaseUnixTime(app_id)
	is_vac_banned = steam.isVACBanned()
#endregion


func initialize_steam() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam does not exist in this application, canceling intialization.")
		steamworks_error.emit("Steam does not exist in this application, canceling initialization.")
		return

	var steam: Object = Engine.get_singleton("Steam")
	if not steam.isSteamRunning():
		printerr("Steam is not running.")
		steamworks_error.emit("Steam is not running, canceling initialization.")
		return

	var initialize_data: Dictionary = steam.steamInitEx(app_id, true)
	print("Steam initialization: %s" % initialize_data)

	if initialize_data.get('status', -1) != steam.get("STEAM_API_INIT_RESULT_OK"):
		printerr("Failed to initialize Steam. Reason: %s" % initialize_data.get('verbose', ''))
		steamworks_error.emit("Failed to initialized Steam.")
		return

	# Collect data about everything
	collect_build_data()
	collect_game_data()
	collect_user_data()
	print("Finished Steam data collection")


#region Helpers
func steam_debug(message: String, is_error: bool = false) -> void:
	if ProjectSettings.get_setting("steam/debug/debug_messages"):
		if is_error:
			printerr(message)
		else:
			print(message)
##endregion

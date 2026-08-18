@icon("uid://bg2lm15tg20gg")
extends Panel
## Steam Leaderboard Entry
##
## A child node that contains information for a leader on the Steam leaderboard.
##
## @tutorial(Valve's overview of leaderboards): https://partner.steamgames.com/doc/features/leaderboards
## @tutorial(GodotSteam's leaderboards tutorial): https://godotsteam.com/tutorials/leaderboards/
## @tutorial(GodotSteamKit leaderboards usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/leaderboards

## A call to the main leaderboard scene to display the UGC contents.  This works
## for video or images but may need tweaked for anything else.
signal ugc_displayed

## The default question mark avatar for Steam users.
const AVATAR_DEFAULT = preload("uid://c5cm6165mpvlx")
## A leaderboard UGC custom scene. This is used to display UGC for the leaderboard; specifically
## images.
const LEADERBOARD_UGC = preload("uid://dt5mdtfdvyy1m")

## The Steam ID of the player this leaderboard entry belongs to.
var steam_id: int = 0
## If there is UGC for this leaderboard, this is the handle used to retrieve it.
var ugc_handle: int = 0 : set = set_ugc_handle

@onready var _avatar: SteamAvatarRect = %Avatar
@onready var _rank: Label = %Rank
@onready var _score: Label = %Score
@onready var _ugc: Button = %UGC
@onready var _username: SteamUsername = %Name


func _ready() -> void:
	_connect_signals()


#region Setups
## Currently UGC handles can wrap around into the negative value but still function. We are checking
## if it is a non-zero value for now.
func set_ugc_handle(new_handle: int) -> void:
	ugc_handle = new_handle
	_ugc.visible = true if ugc_handle != 0 else false


## Take the details dictionary and process the data within.  We are ignoring the 'details' key as it
## is very game specific. You can ready more about it here:
## https://godotsteam.com/tutorials/leaderboards/#passing-extra-details
func setup_entry(these_details: Dictionary) -> void:
	print("Details: %s" % [these_details])
	steam_id = these_details['steam_id']
	if not is_node_ready(): await ready
	_avatar.texture = AVATAR_DEFAULT
	_avatar.steam_id = steam_id
	_username.steam_id = steam_id
	_rank.text = str(these_details['global_rank'])
	_score.text = str(these_details['score'])
	ugc_handle = these_details['ugc_handle']
#endregion


#region Signals
func _connect_signals() -> void:
	_ugc.pressed.connect(_on_ugc_pressed)


func _on_ugc_pressed() -> void:
	ugc_displayed.emit(ugc_handle)
#endregion

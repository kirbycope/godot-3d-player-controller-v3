@icon("uid://bg2lm15tg20gg")
class_name SteamUsername
extends Label
## An automatically updating Steam username node.
##
## A custom Label node used to automatically update a player's Steam username
## based on the Steam ID that is set.

## Mirrors Steam.PersonaChange.PERSONA_CHANGE_NAME (Steam class is absent on web exports).
const PERSONA_CHANGE_NAME: int = 1

## The Steam ID associated with this username. Used to check the username and
## persona callbacks.
var steam_id: int = 0 : set = set_steam_id

## Steam singleton when the GodotSteam extension is present, otherwise null.
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


func _ready() -> void:
	if _steam:
		_steam.connect("persona_state_change", _on_persona_state_change)


func _on_persona_state_change(changed_id: int, flags: int) -> void:
	if steam_id == changed_id:
		if flags & PERSONA_CHANGE_NAME:
			text = _steam.getFriendPersonaName(steam_id)


## Sets the Steam ID to track and automatically requests the username.
func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready(): await ready
	if _steam == null:
		return
	text = _steam.getFriendPersonaName(steam_id)
	# If this wasn't used in a lobby, game server, etc. it may be blank so we
	# request the information from Steam.
	if text.is_empty() or text == "[unknown]":
		if not _steam.requestUserInformation(steam_id, true):
			printerr("Failed to request user %s information" % steam_id)

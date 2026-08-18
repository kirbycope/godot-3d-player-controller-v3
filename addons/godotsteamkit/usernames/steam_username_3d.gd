@icon("uid://bg2lm15tg20gg")
class_name SteamUsername3D
extends Label3D
## An automatically updating Steam username node.
##
## A custom Label3D node used to automatically update a player's Steam username
## based on the Steam ID that is set.

## The Steam ID associated with this username. Used to check the username and
## persona callbacks.
var steam_id: int = 0 : set = set_steam_id


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		Steam.persona_state_change.connect(_on_persona_state_change)


func _on_persona_state_change(changed_id: int, flags: int) -> void:
	if steam_id == changed_id:
		if flags & Steam.PersonaChange.PERSONA_CHANGE_NAME:
			text = Steam.getFriendPersonaName(steam_id)


## Sets the Steam ID to track and automatically requests the username.
func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready(): await ready
	text = Steam.getFriendPersonaName(steam_id)
	# If this wasn't used in a lobby, game server, etc. it may be blank so we
	# request the information from Steam.
	if text.is_empty() or text == "[unknown]":
		if not Steam.requestUserInformation(steam_id, true):
			printerr("Failed to request user %s information" % steam_id)

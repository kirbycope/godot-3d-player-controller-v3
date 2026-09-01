@icon("uid://bg2lm15tg20gg")
class_name SteamAvatarRect
extends TextureRect
## An automatically updating Steam avatar node.
##
## A custom TextureRect node used to automatically update a player's Steam avatar based on the Steam ID
## that is set.

## Mirrors Steam.AvatarSizes (Steam class is absent on web exports).
enum AvatarSizes { AVATAR_SMALL = 1, AVATAR_MEDIUM = 2, AVATAR_LARGE = 3 }
## Mirrors Steam.PersonaChange.PERSONA_CHANGE_AVATAR.
const PERSONA_CHANGE_AVATAR: int = 64

## The size of the requested avatar. Small is 32 pixel, medium is 64 pixels, and large is 184 pixels.
@export var avatar_size: AvatarSizes = AvatarSizes.AVATAR_MEDIUM
## Set a specific size for the Steam avatar which will override the avatar sizes. Make sure this is
## smaller than the avatar_size you are using. For example, if custom_size is 50 pixel then select
## AVATAR_MEDIUM (or 2) as your avatar_size.
@export var custom_size: int = 0
## The Steam ID associated with this avatar. Used to retrieve the current avatar and check the
## avatar and persona callbacks.
@export var steam_id: int = 0 : set = set_steam_id

## Steam singleton when the GodotSteam extension is present, otherwise null.
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


func _ready() -> void:
	if _steam:
		_steam.connect("avatar_loaded", _on_avatar_loaded)
		_steam.connect("persona_state_change", _on_persona_state_change)


func _on_avatar_loaded(avatar_id: int, image_size: int, image_data: Array) -> void:
	if steam_id == avatar_id:
		var avatar_image: Image = Image.create_from_data(image_size, image_size, false, Image.FORMAT_RGBA8, image_data)
		if custom_size > 0:
			avatar_image.resize(custom_size, custom_size, Image.INTERPOLATE_LANCZOS)
		var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
		texture = avatar_texture


func _on_persona_state_change(changed_id: int, flags: int) -> void:
	if steam_id == changed_id:
		if flags & PERSONA_CHANGE_AVATAR:
			_steam.getPlayerAvatar(avatar_size, steam_id)


## Sets the Steam ID to track and automatically requests the avatar.
func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready(): await ready
	if _steam:
		_steam.getPlayerAvatar(avatar_size, steam_id)

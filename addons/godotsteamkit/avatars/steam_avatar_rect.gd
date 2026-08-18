@icon("uid://bg2lm15tg20gg")
class_name SteamAvatarRect
extends TextureRect
## An automatically updating Steam avatar node.
##
## A custom TextureRect node used to automatically update a player's Steam avatar based on the Steam ID
## that is set.

## The size of the requested avatar. Small is 32 pixel, medium is 64 pixels, and large is 184 pixels.
@export var avatar_size: Steam.AvatarSizes = Steam.AvatarSizes.AVATAR_MEDIUM
## Set a specific size for the Steam avatar which will override the avatar sizes. Make sure this is
## smaller than the avatar_size you are using. For example, if custom_size is 50 pixel then select
## AVATAR_MEDIUM (or 2) as your avatar_size.
@export var custom_size: int = 0
## The Steam ID associated with this avatar. Used to retrieve the current avatar and check the
## avatar and persona callbacks.
@export var steam_id: int = 0 : set = set_steam_id


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		Steam.avatar_loaded.connect(_on_avatar_loaded)
		Steam.persona_state_change.connect(_on_persona_state_change)


func _on_avatar_loaded(avatar_id: int, image_size: int, image_data: Array) -> void:
	if steam_id == avatar_id:
		var avatar_image: Image = Image.create_from_data(image_size, image_size, false, Image.FORMAT_RGBA8, image_data)
		if custom_size > 0:
			avatar_image.resize(custom_size, custom_size, Image.INTERPOLATE_LANCZOS)
		var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
		texture = avatar_texture


func _on_persona_state_change(changed_id: int, flags: int) -> void:
	if steam_id == changed_id:
		if flags & Steam.PersonaChange.PERSONA_CHANGE_AVATAR:
			Steam.getPlayerAvatar(avatar_size, steam_id)


## Sets the Steam ID to track and automatically requests the avatar.
func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready(): await ready
	Steam.getPlayerAvatar(avatar_size, steam_id)

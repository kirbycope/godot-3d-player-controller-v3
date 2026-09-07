@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Leaderboard UGC
##
## A custom scene for leaderboard UGC. This is set up specifically to handle UGC images. Requires
## modification to other file types like video.
##
## @tutorial(Valve's overview of leaderboards): https://partner.steamgames.com/doc/features/leaderboards
## @tutorial(GodotSteam's leaderboards tutorial): https://godotsteam.com/tutorials/leaderboards/
## @tutorial(GodotSteamKit leaderboards usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/leaderboards

## The absolute path to the UGC we are viewing. Used primarily to load then delete said content.
var ugc_full_path: String : set = set_ugc_content

@onready var _close: Button = %Close
@onready var _ugc_image: TextureRect = %UGCImage


func _ready() -> void:
	_connect_signals()


#region Signals
func _connect_signals() -> void:
	_close.pressed.connect(_on_close_pressed)


# Upon closing, we will delete the UGC file and then free this node.
func _on_close_pressed() -> void:
	if DirAccess.remove_absolute(ugc_full_path) != OK:
		printerr("Failed to delete downloaded UGC content: %s" % DirAccess.get_open_error())
	visible = false
	queue_free()
#endregion


#region Content handling
## Update the scene's image file based on this absolute path.
func set_ugc_content(new_path: String) -> void:
	ugc_full_path = new_path
	if not is_node_ready(): await ready
	var new_ugc_image: Image = Image.new()
	new_ugc_image.load(ugc_full_path)
	var new_ugc_texture: ImageTexture = ImageTexture.create_from_image(new_ugc_image)
	_ugc_image.texture = new_ugc_texture
#endregion

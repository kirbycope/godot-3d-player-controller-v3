extends GutHookScript
## Runs before the suite: no inventory reads or writes user://inventory.json while tests run, so a scene
## with `persist` on neither loads the real save nor overwrites it.
##
## And the tests get their canvas. A headless window is 64 pixels square and cannot be resized, and the game
## no longer sets a stretch mode (the HUD sizes itself to the window instead), so without this the fixed-size
## menus would have nothing to lay out on. Turning the stretch on for the run only gives them the design size,
## which is what a real window of that size would give them.
##
## The player's own files on this machine never decide what a test sees, and a test never writes over them: the
## run keeps its files in [constant GUT_DIR], which starts empty every run, so a record caught in one run is not
## standing in the next. The save game and the settings go there through the player controller's own static paths
## ([member SaveGame.DEFAULT_SAVE_PATH], [member SaveGame.DEFAULT_CLIENT_SAVE_PATH], [member PlayerSettingsResource.SAVE_PATH]), set before any test reads
## them. Nothing is moved aside, so a run that is killed half way leaves the player's files as they were.

const GUT_DIR: String = "user://gut/"


func run() -> void:
	Inventory.persistence_enabled = false
	var gut_dir: String = ProjectSettings.globalize_path(GUT_DIR)
	DirAccess.make_dir_recursive_absolute(gut_dir)
	for file: String in DirAccess.get_files_at(GUT_DIR):
		DirAccess.remove_absolute(gut_dir.path_join(file))
	SaveGame.DEFAULT_SAVE_PATH = GUT_DIR + SaveGame.DEFAULT_SAVE_PATH.get_file()
	SaveGame.DEFAULT_CLIENT_SAVE_PATH = GUT_DIR + SaveGame.DEFAULT_CLIENT_SAVE_PATH.get_file()
	SaveGame.SAVES_DIR = GUT_DIR + "saves" # the numbered saves too, or a run would list the player's own
	PlayerSettingsResource.SAVE_PATH = GUT_DIR + PlayerSettingsResource.SAVE_PATH.get_file()
	PlayerSettingsResource._cached = null # anything read before the run came from the player's own file
	var root: Window = gut.get_tree().root
	root.content_scale_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


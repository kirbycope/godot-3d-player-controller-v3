extends GutHookScript
## Runs before the suite: no inventory reads or writes user://inventory.tres while tests run, so a scene
## with `persist` on (the world player) neither loads the real save nor overwrites it.
##
## And the tests get their canvas. A headless window is 64 pixels square and cannot be resized, and the game
## no longer sets a stretch mode (the HUD sizes itself to the window instead), so without this the fixed-size
## menus would have nothing to lay out on. Turning the stretch on for the run only gives them the design size,
## which is what a real window of that size would give them.
##
## The player's own settings and save game on this machine are set aside too (tests/gut_post_run.gd puts them
## back), so a layout or HUD mode picked in the menu, or a game saved in the world, never decides what a test sees.

const USER_FILES: PackedStringArray = ["user://settings.tres", "user://savegame.tres"]
const BACKUP_SUFFIX: String = ".gut_backup"


func run() -> void:
	Inventory.persistence_enabled = false
	for path: String in USER_FILES:
		if FileAccess.file_exists(path + BACKUP_SUFFIX):
			# A run that never reached the post hook left the real file in the backup: keep that, drop the test's
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		elif FileAccess.file_exists(path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + BACKUP_SUFFIX))
	var root: Window = gut.get_tree().root
	root.content_scale_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

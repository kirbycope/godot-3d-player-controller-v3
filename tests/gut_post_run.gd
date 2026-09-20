extends GutHookScript
## Runs after the suite: the player's own settings and save game, set aside by tests/gut_pre_run.gd, go back in
## place of whatever the tests wrote.


func run() -> void:
	for path: String in ["user://settings.tres", "user://savegame.tres"]:
		var backup: String = path + ".gut_backup"
		var real: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(backup):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(real)
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), real)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(real) # there was none before the run

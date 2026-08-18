@icon("uid://bg2lm15tg20gg")
extends Node
## Steam Leaderboard Upload Script
##
## A quick-start script for uploading scores to Steam leaderboards.
##
## @tutorial(Valve's overview of leaderboards): https://partner.steamgames.com/doc/features/leaderboards
## @tutorial(GodotSteam's leaderboards tutorial): https://godotsteam.com/tutorials/leaderboards/
## @tutorial(GodotSteamKit leaderboards usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/leaderboards

## The current leaderboard handle we are using. This is stored from the last call to
## [method upload_score].
var current_leaderboard_handle: int = 0
## Whether or not to delete the UGC content after uploading to the leaderboard.
var delete_after_upload: bool = false
## The full filename, including extension, of the UGC we are uploading to the leaderboard.
var ugc_filename: String
## The path you are storing UGC at. This must be a folder.  It can be anywhere on the system as well
## as Godot's user:// path.
var ugc_path: String = "user://ugc"


func _ready() -> void:
	_connect_steam_callbacks()


## A short-cut to [method Steam.uploadLeaderboardScore] which holds onto the leaderboard handle used
## to, if needed, upload leaderboard UGC.
func upload_score(leaderboard_handle: int, new_score: int, keeping_best: bool, detail_array: PackedInt32Array = [], ugc_content: String = "") -> void:
	print("Uploading new score to leaderboard %s" % leaderboard_handle)
	current_leaderboard_handle = leaderboard_handle
	# If there is content being uploaded, stash it for the callback
	if not ugc_content.is_empty():
		ugc_filename = ugc_content
	Steam.uploadLeaderboardScore(new_score, keeping_best, detail_array, leaderboard_handle)


#region Steam callbacks
func _connect_steam_callbacks() -> void:
	_steam_callback_wrapper("leaderboard_score_uploaded", "_on_leaderboard_score_uploaded")
	_steam_callback_wrapper("file_share_result", "_on_file_share_result")
	_steam_callback_wrapper("file_write_async_complete", "_on_file_write_async_complete")
	_steam_callback_wrapper("leaderboard_ugc_set", "_on_leaderboard_ugc_set")


func _on_file_share_result(share_result: Steam.Result, ugc_handle: int, filename: String) -> void:
	if share_result != Steam.Result.RESULT_OK:
		printerr("Failed to share UGC file %s: %s" % [filename, share_result])
		return
	print("Successfully shared UGC file %s" % filename)
	Steam.attachLeaderboardUGC(ugc_handle, current_leaderboard_handle)


func _on_file_write_async_complete(write_result: Steam.Result) -> void:
	if write_result != Steam.Result.RESULT_OK:
		print("Failed to write UGC file: %s" % write_result)
		return
	if not Steam.fileExists(ugc_filename):
		printerr("Cannot share UGC file, it does not exist in Steam Cloud")
		return
	Steam.fileShare(ugc_filename)


func _on_leaderboard_score_uploaded(was_success: int, leaderboard_handle: int, uploaded_score: Dictionary) -> void:
	if was_success == 0:
		printerr("Failed to upload scores to leaderboard %s: %s" % [leaderboard_handle, uploaded_score])
		return
	print("Successfully uploaded score to leaderboard %s: %s" % [leaderboard_handle, uploaded_score])
	# If we are uploading UGC then the ugc_filename should be filled out.
	if ugc_filename.is_empty():
		return
	var ugc_data: PackedByteArray = FileAccess.get_file_as_bytes("%s%s" % [ugc_path, ugc_filename])
	if ugc_data.is_empty():
		printerr("Failed to upload leaderboard UGC, PackedByteArray is empty.")
		return
	Steam.fileWriteAsync(ugc_filename, ugc_data, ugc_data.size())


func _on_leaderboard_ugc_set(leaderboard_handle: int, set_result: Steam.Result) -> void:
	if set_result == Steam.Result.RESULT_TIMEOUT:
		printerr("UGC upload took too long; try again")
		return
	if set_result == Steam.Result.RESULT_INVALID_PARAM:
		printerr("Leaderboard handle %s was invalid" % leaderboard_handle)
		return
	if set_result != Steam.Result.RESULT_OK:
		printerr("Failed to set leaderboard UGC: %s" % set_result)
		return
	if delete_after_upload:
		if not DirAccess.remove_absolute("%s%s" % [ugc_path, ugc_filename]) == OK:
			printerr("Failed to delete leaderboard UGC after uploading and setting, must manually delete this file")
	print("Leaderboard UGC was set for %s" % leaderboard_handle)


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion

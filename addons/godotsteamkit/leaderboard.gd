@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Leaderboard
##
## A quick-start framework for Steam leaderboards.
##
## Make sure to set all Steam leaderboard API names as the keys to the
## [member leaderboard_api_names] dictionary either manually or in the Inspector.
##
## @tutorial(Valve's overview of leaderboards): https://partner.steamgames.com/doc/features/leaderboards
## @tutorial(GodotSteam's leaderboards tutorial): https://godotsteam.com/tutorials/leaderboards/
## @tutorial(GodotSteamKit leaderboards usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/leaderboards

## A leaderboard entry node that contains all the data about this leader: rank, name, score, avatar,
## etc.
const LEADERBOARD_ENTRY = preload("uid://cqdmu6pqa5ejs")
## A subtitle LabelSetting that formats our temporary labels for search and failure pop-ups.
const LEADERBOARD_SUBTITLES = preload("uid://dioy8u206kxue")
## Used to display leaderboard UGC.
const LEADERBOARD_UGC = preload("uid://dt5mdtfdvyy1m")

## Whether or not to download the first leaderboard when the scene is ready.
@export var download_at_ready: bool = false
## Whether to have a download button or automatically download leaderboards on any dropdown
## selections.
@export var download_on_select: bool = false :
	set = _set_download_on_select
## The last index to retrieve entries for; relative to the request type.
@export var download_rank_end: int = 10
## The first index to retrieve entries for; relative to the request type.
@export var download_rank_start: int = 1
## Whether or not leaderboard entries contain UGC that needs downloaded.
@export var has_ugc_attached: bool = false
## A dictionary of Steam leaderboard API names and their full name or community title. These will be
## used to populate the leaderboard dropdown.
@export var leaderboard_api_names: Dictionary[StringName, StringName] = { }
## Maximum amount of extra details to retrieve per leaderboard.  This only works if you are storing
## additional details.
@export var leaderboard_details_max: int = Steam.LEADERBOARD_DETAILS_MAX :
	set = _set_leaderboard_details_max
## Only used if you are attaching UGC. This path seemed like the easier place to temporarily stash
## UGC content.
@export var ugc_path: String = "user://leaderboards/ugc/"

## The current leaderboard handle we are using.
var current_leaderboard_handle: int = 0 :
	set = set_current_leaderboard_handle
## A dictionary of Steam leaderboard API names and their current handles. This gets populated as
## leaderboards are called for. You will probably want to use these handles elsewhere to upload
## scores. In that case, replace current_leaderboard_handles in this script with the location of
## your global leaderboard handle variable that matches this configuration.
var current_leaderboard_handles: Dictionary[StringName, int] = {}
## The current type of leaderboard request to make.
var current_request_type: Steam.LeaderboardDataRequest = Steam.LeaderboardDataRequest.LEADERBOARD_DATA_REQUEST_GLOBAL :
	set = set_current_request_type
## The current sorting option used in requests.
var current_sort_option: Steam.LeaderboardSortMethod = Steam.LeaderboardSortMethod.LEADERBOARD_SORT_METHOD_NONE :
	set = set_current_sort_option
var ugc_file_name: String

@onready var _api_name_dropdown: OptionButton = %APINames
@onready var _download_entries_button: Button = %DownloadEntries
@onready var _leaders_list: VBoxContainer = %LeadersList
@onready var _request_types_dropdown: OptionButton = %RequestTypes
@onready var _sort_options_dropdown: OptionButton = %SortOptions


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_callbacks()
	_set_defaults()
	_download_first_leaderboard()


# Downloads the first listed leaderboard if download_at_ready is set to true.
func _download_first_leaderboard() -> void:
	if download_at_ready:
		_request_leaderboard_handle()


func _set_defaults() -> void:
	if leaderboard_api_names.size() > 0:
		for this_leaderboard in leaderboard_api_names.keys():
			_api_name_dropdown.add_item(leaderboard_api_names[this_leaderboard])


#region Signals
# A new leaderboard was selected by the user. If there is no handle associated, disable the download
# button (if applicable) and request the handle.
func _on_api_name_selected(selected_index: int) -> void:
	var selected_leaderboard: StringName = leaderboard_api_names.keys()[selected_index]
	if not current_leaderboard_handles.has(selected_leaderboard):
		_download_entries_button.disabled = true
		_request_leaderboard_handle(selected_index)
	else:
		_download_entries_button.disabled = false
		current_leaderboard_handle = current_leaderboard_handles[selected_leaderboard]


func _connect_signals() -> void:
	_api_name_dropdown.item_selected.connect(_on_api_name_selected)
	_api_name_dropdown.pressed.connect(_size_dropdown_popup.bind(_api_name_dropdown))
	_download_entries_button.pressed.connect(_on_download_entries)
	_request_types_dropdown.item_selected.connect(_on_request_type_selected)
	_request_types_dropdown.pressed.connect(_size_dropdown_popup.bind(_request_types_dropdown))
	_sort_options_dropdown.item_selected.connect(_on_sort_option_selected)
	_sort_options_dropdown.pressed.connect(_size_dropdown_popup.bind(_sort_options_dropdown))


func _on_download_entries() -> void:
	if current_leaderboard_handle == 0:
		printerr("Current handle is 0, cannot download entries")
		return
	_clear_leaderboard_entries()
	_create_download_request()


func _on_request_type_selected(selected_index: int) -> void:
	Steamworks.steam_debug("Updating request type to %s" % selected_index)
	current_request_type = selected_index as Steam.LeaderboardDataRequest


func _on_sort_option_selected(selected_index: int) -> void:
	Steamworks.steam_debug("Updating leaderboard sort option to %s" % selected_index)
	current_sort_option = selected_index as Steam.LeaderboardSortMethod
#endregion


#region Steam callbacks
func _connect_steam_callbacks() -> void:
	_steam_callback_wrapper("download_ugc_result", "_on_download_ugc_result")
	_steam_callback_wrapper("leaderboard_find_result", "_on_leaderboard_find_result")
	_steam_callback_wrapper("leaderboard_scores_downloaded", "_on_leaderboard_scores_downloaded")
	_steam_callback_wrapper("leaderboard_ugc_set", "_on_leaderboard_ugc_set")


# Result when finding a leaderboard.
func _on_leaderboard_find_result(leaderboard_handle: int, was_found: int) -> void:
	if was_found != 1:
		printerr("Leaderboard %s could not be found: %s" % [leaderboard_handle, was_found])
		return

	var leaderboard_name: String = Steam.getLeaderboardName(leaderboard_handle)
	Steamworks.steam_debug("Leaderboard %s was found: %s" % [leaderboard_name, current_leaderboard_handle])
	_download_entries_button.disabled = false
	current_leaderboard_handles[leaderboard_name] = leaderboard_handle
	current_leaderboard_handle = leaderboard_handle


# Called when scores for a leaderboard have been downloaded and are ready to be retrieved.
func _on_leaderboard_scores_downloaded(this_message: String, this_handle: int, these_results: Array) -> void:
	if current_leaderboard_handle != this_handle:
		printerr("Got scores for the wrong leaderboard handle: %s" % this_handle)
		return

	_clear_leaderboard_entries()
	if these_results.size() == 0:
		print("No results found for leaderboard %s" % this_handle)
		_set_temporary_message("No scores found")
		return

	for this_result in these_results:
		var leaderboard_entry := LEADERBOARD_ENTRY.instantiate()
		leaderboard_entry.ugc_displayed.connect(_on_ugc_displayed)
		leaderboard_entry.setup_entry(this_result)
		_leaders_list.call_deferred("add_child", leaderboard_entry)


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


#region Leaderboard retrieval
func _create_download_request() -> void:
	# If the current handle is invalid, try to request it from the currently selected API name.
	if current_leaderboard_handle == 0:
		_request_leaderboard_handle(_api_name_dropdown.selected)
		return

	_clear_leaderboard_entries()
	_set_temporary_message("Looking for leaderboard entries...")
	Steam.downloadLeaderboardEntries(
			download_rank_start,
			download_rank_end,
			current_request_type,
			current_leaderboard_handle
			)


func _request_leaderboard_handle(selected_index: int = 0) -> void:
	var leaderboard_api_name: String = leaderboard_api_names.keys()[selected_index]
	Steam.findLeaderboard(leaderboard_api_name)
	print("Requesting handle for leaderboard %s" % leaderboard_api_name)
#endregion


#region Set/gets
## Set the current leaderboard handle to be used and, if download_on_select is enabled, request a
## new set of leaderboards.
func set_current_leaderboard_handle(new_handle: int) -> void:
	current_leaderboard_handle = new_handle
	if not is_node_ready(): await ready
	if download_on_select:
		_create_download_request()


## Set the current type of leaderboard request to make and, if download_on_select is enabled,
## request a new set of leaderboards.
func set_current_request_type(new_request_type: Steam.LeaderboardDataRequest) -> void:
	current_request_type = new_request_type
	if download_on_select:
		_create_download_request()


## Set the current sorting option used in requests, if download_on_select is enabled, request a new
## set of leaderboards.
func set_current_sort_option(new_sort_option: Steam.LeaderboardSortMethod) -> void:
	current_sort_option = new_sort_option
	if download_on_select:
		_create_download_request()


func _set_download_on_select(change_download: bool) -> void:
	download_on_select = change_download
	if not is_node_ready(): await ready
	_download_entries_button.visible = not download_on_select


func _set_function_buttons() -> void:
	for this_button in get_tree().get_nodes_in_group("function_buttons"):
		this_button.disabled = true if current_leaderboard_handle == 0 else false


func _set_leaderboard_details_max(new_max: int) -> void:
	leaderboard_details_max = new_max
	Steam.leaderboard_details_max = leaderboard_details_max
#endregion


#region UGC handling
# This function assumes you a downloading an image file. Clearly you can alter this to support any
# kind of file you want.
func _on_download_ugc_result(result: Steam.Result, download_data: Dictionary) -> void:
	if result != Steam.Result.RESULT_OK:
		printerr("Failed to download leaderboard UGC: %s" % result)
		return

	var ugc_content := LEADERBOARD_UGC.instantiate()
	ugc_content.ugc_full_path = ProjectSettings.globalize_path("%s%s.png" % [ugc_path, download_data['handle']])
	call_deferred("add_child", ugc_content)


func _on_ugc_displayed(ugc_handle: int) -> void:
	var ugc_absolute_path: String = ProjectSettings.globalize_path("%s%s.png" % [ugc_path, ugc_handle])
	Steam.ugcDownloadToLocation(ugc_handle, ugc_absolute_path, 0)
#endregion


#region Helpers
# Helper function to wipe all previous leaders when a new leaderboards is downloaded.
func _clear_leaderboard_entries() -> void:
	for this_entry in _leaders_list.get_children():
		this_entry.visible = false
		this_entry.queue_free()


# Create a temporary message when searching for leaderboard data or getting no results.
func _set_temporary_message(message: String) -> void:
	var no_result_label := Label.new()
	no_result_label.text = message
	no_result_label.label_settings = LEADERBOARD_SUBTITLES
	_leaders_list.call_deferred("add_child", no_result_label)


# Resize the dropdown pop-up windows based on number of items.
func _size_dropdown_popup(this_node: OptionButton) -> void:
	this_node.get_popup().size.y = this_node.get_item_count() * 40
#endregion

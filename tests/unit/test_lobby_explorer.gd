extends GutTest

const LOBBY_EXPLORER_SCENE = preload("res://addons/3d_player_controller/scenes/lobby_explorer.tscn")
const LOBBY_EXPLORER_ENTRY_SCENE = preload("res://addons/3d_player_controller/scenes/lobby_explorer_entry.tscn")


func test_lobby_explorer_initial_nodes() -> void:
	var explorer = LOBBY_EXPLORER_SCENE.instantiate()
	add_child_autofree(explorer)

	assert_not_null(explorer.host_button, "Host button should exist")
	assert_not_null(explorer.refresh_button, "Refresh button should exist")
	assert_not_null(explorer.back_button, "Back button should exist")
	assert_not_null(explorer.status_label, "StatusLabel should exist")
	assert_not_null(explorer.lobby_list, "LobbyList should exist")
	assert_not_null(explorer.distance_option, "DistanceOption should exist")
	assert_not_null(explorer.label_version, "Label_Version should exist")
	assert_not_null(explorer.label_copyright, "Label_Copyright should exist")


func test_lobby_explorer_version_and_copyright_format() -> void:
	var explorer = LOBBY_EXPLORER_SCENE.instantiate()
	add_child_autofree(explorer)

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var expected_version: String = version if version.begins_with("v") else "v" + version
	assert_eq(explorer.label_version.text, expected_version, "Version label should match app config")

	var current_year: int = Time.get_date_dict_from_system().year
	var expected_copyright: String = "© Timothy Cope %d" % current_year
	assert_eq(explorer.label_copyright.text, expected_copyright, "Copyright label should match current year")


func test_lobby_explorer_entry_initial_state_and_signal() -> void:
	var entry = LOBBY_EXPLORER_ENTRY_SCENE.instantiate()
	add_child_autofree(entry)
	watch_signals(entry)

	entry.set_lobby_id(123456789)
	assert_eq(entry.lobby_id, 123456789, "Lobby ID should be stored")

	entry.join_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(entry, "join_requested", [123456789], 0)

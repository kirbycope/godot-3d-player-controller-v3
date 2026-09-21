extends GutTest

const MAIN_SCENE = preload("res://scenes/main.tscn")
const TITLE_SCREEN_SCENE = preload("res://scenes/title_screen.tscn")
const LOADING_SCENE = preload("res://addons/3d_player_controller/scenes/ui/loading.tscn")


func test_loading_node_initial_state() -> void:
	var loading: Loading = LOADING_SCENE.instantiate() as Loading
	add_child_autofree(loading)

	assert_false(loading.visible, "Loading screen should start hidden")
	assert_false(loading.is_processing(), "Loading screen should not poll while idle")
	assert_gt(loading.tips.size(), 0, "Tips array should not be empty")
	assert_eq(loading._scene_path, "", "Initial scene path should be empty")


func test_loading_node_load_scene_starts_request() -> void:
	var loading: Loading = LOADING_SCENE.instantiate() as Loading
	add_child_autofree(loading)

	loading.load_scene("res://scenes/world.tscn")

	assert_true(loading.visible, "Loading screen should become visible when loading starts")
	assert_true(loading.is_processing(), "Loading screen should poll while a request is in flight")
	assert_eq(loading._scene_path, "res://scenes/world.tscn", "Scene path should be stored")
	assert_eq(loading.progress_bar.value, 0.0, "Progress bar should reset to 0")
	assert_ne(loading.tip.text, "", "Tip label text should be set")
	assert_true(loading.details.get_parsed_text().contains("Requesting res://scenes/world.tscn"), "Details log should report request")


func test_loading_node_ignores_second_request_while_loading() -> void:
	var loading: Loading = LOADING_SCENE.instantiate() as Loading
	add_child_autofree(loading)

	loading.load_scene("res://scenes/world.tscn")
	loading.load_scene("res://scenes/main.tscn")

	assert_eq(loading._scene_path, "res://scenes/world.tscn", "A request in flight should not be replaced")
	assert_false(loading.details.get_parsed_text().contains("Requesting res://scenes/main.tscn"), "The second request should be ignored")


func test_title_screen_opens_on_the_main_menu() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	assert_true(title_screen.menu_main.visible, "The title screen opens on Single-Player, Multi-Player, Options and Quit")
	assert_false(title_screen.menu_single_player.visible, "New Game and Continue live behind Single-Player, not on the main menu")
	assert_true(title_screen.button_single_player.has_focus(), "Single-Player takes the opening focus")


func test_title_screen_single_player_opens_the_new_game_menu() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	title_screen.button_single_player.emit_signal("pressed")

	assert_false(title_screen.menu_main.visible, "The main menu gives way to the single-player panel")
	assert_true(title_screen.menu_single_player.visible, "Single-Player presents New Game and Continue")
	assert_signal_not_emitted(title_screen, "new_game_pressed", "Single-Player opens a menu, it does not start the game")


func test_title_screen_single_player_opens_the_new_game_menu_on_touch_button() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	var touch_sp: TouchScreenButton = title_screen.get_node("VBoxContainer/Button_SinglePlayer/TouchScreenButton_SinglePlayer")
	touch_sp.emit_signal("pressed")

	assert_true(title_screen.menu_single_player.visible, "The touch button opens the same panel as the button")


func test_title_screen_emits_new_game_pressed_on_button() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	title_screen.button_single_player.emit_signal("pressed")
	title_screen.button_new_game.emit_signal("pressed")

	assert_signal_emitted(title_screen, "new_game_pressed", "New Game button should emit new_game_pressed signal")


func test_title_screen_emits_new_game_pressed_on_touch_button() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	var touch_ng: TouchScreenButton = title_screen.get_node("VBoxContainer_SinglePlayer/Button_NewGame/TouchScreenButton_NewGame")
	touch_ng.emit_signal("pressed")

	assert_signal_emitted(title_screen, "new_game_pressed", "Touch button should emit new_game_pressed signal")


func test_title_screen_back_returns_to_the_main_menu() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	title_screen.button_single_player.emit_signal("pressed")
	title_screen.button_back.emit_signal("pressed")

	assert_true(title_screen.menu_main.visible, "Back returns to the main menu")
	assert_false(title_screen.menu_single_player.visible, "Back closes the single-player panel")
	assert_true(title_screen.button_single_player.has_focus(), "Back puts the focus where it came from")


func test_title_screen_cancel_backs_out_of_the_single_player_menu() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	title_screen.button_single_player.emit_signal("pressed")

	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	title_screen._unhandled_input(cancel)

	assert_true(title_screen.menu_main.visible, "Cancel backs out of the single-player panel")


func test_title_screen_default_button_follows_the_open_panel() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	assert_eq(title_screen.default_button(), title_screen.button_single_player, "On the main menu, Accept means Single-Player")
	title_screen.button_single_player.emit_signal("pressed")
	var expected: Button = title_screen.button_continue if title_screen.button_continue.visible else title_screen.button_new_game
	assert_eq(title_screen.default_button(), expected, "In the panel, Accept means Continue when there is a save and New Game otherwise")


func test_title_screen_emits_multi_player_pressed_on_button() -> void:
	var title_screen: CanvasLayer = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	var button_mp: Button = title_screen.get_node("VBoxContainer/Button_MultiPlayer")
	button_mp.emit_signal("pressed")

	assert_signal_emitted(title_screen, "multi_player_pressed", "Multi-player button should emit multi_player_pressed signal")


func test_title_screen_emits_multi_player_pressed_on_touch_button() -> void:
	var title_screen: CanvasLayer = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	var touch_mp: TouchScreenButton = title_screen.get_node("VBoxContainer/Button_MultiPlayer/TouchScreenButton_MultiPlayer")
	touch_mp.emit_signal("pressed")

	assert_signal_emitted(title_screen, "multi_player_pressed", "Touch button should emit multi_player_pressed signal")


func test_title_screen_version_and_copyright_labels() -> void:
	var title_screen: CanvasLayer = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var expected_version: String = version if version.begins_with("v") else "v" + version
	assert_eq(title_screen.label_version.text, expected_version, "Label_Version should match config/version")

	var current_year: int = Time.get_date_dict_from_system().year
	var expected_copyright: String = "© Timothy Cope %d" % current_year
	assert_eq(title_screen.label_copyright.text, expected_copyright, "Label_Copyright should match current year")


func test_title_screen_buttons_focus_on_mouse_entered() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)

	title_screen.button_quit.mouse_entered.emit()
	assert_true(title_screen.button_quit.has_focus(), "Hovering a title button should focus it (wired in the scene)")


func test_main_scene_wiring() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)

	assert_eq(main.single_player_scene, "res://scenes/world.tscn", "Main single_player_scene should point to world.tscn string path")

	# Verify child nodes
	var title_screen = main.get_node_or_null("TitleScreen")
	var loading = main.get_node_or_null("Loading")
	var lobby_explorer: LobbyExplorer = main.get_node_or_null("LobbyExplorer")
	assert_not_null(title_screen, "Main should have TitleScreen child node")
	assert_not_null(loading, "Main should have Loading child node")
	assert_not_null(lobby_explorer, "Main should have LobbyExplorer child node")
	assert_false(lobby_explorer.visible, "LobbyExplorer should start hidden")
	assert_eq(lobby_explorer.world_scene, "res://scenes/world.tscn", "Main should set the project world scene on the explorer")
	assert_eq(lobby_explorer.title_scene, "res://scenes/main.tscn", "Main should set the project title scene on the explorer")
	assert_eq(lobby_explorer.footer_text, "© Timothy Cope", "Main should set the project footer on the explorer")

	# Verify node-based signal connections
	assert_true(
		title_screen.is_connected("new_game_pressed", Callable(main, "new_game")),
		"TitleScreen new_game_pressed is connected to Main.new_game, which resets the controls before loading the world"
	)
	assert_true(
		title_screen.is_connected("multi_player_pressed", Callable(main, "multi_player")),
		"TitleScreen multi_player_pressed signal should be connected to Main.multi_player"
	)


func test_main_multi_player_shows_lobby_explorer() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)

	main.multi_player()
	assert_true(main.lobby_explorer.visible, "multi_player should show the lobby explorer")
	assert_false(main.title_screen.visible, "multi_player should hide the title screen")


func test_main_click_to_start_shows_title_screen_on_press_only() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.click_to_start.show()
	main.title_screen.hide()

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	main._input(release)
	assert_true(main.click_to_start.visible, "A release should not dismiss click-to-start")

	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main._input(press)
	assert_false(main.click_to_start.visible, "A press should dismiss click-to-start")
	assert_false(main.title_screen.visible, "The click is the start of the game on the web, not a reveal of the title screen")
	assert_eq(main.loading._scene_path, "res://scenes/world.tscn", "and it loads the single-player world")


func test_main_unhandled_input_button_0_selects_focused_option() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.click_to_start.hide()
	main.title_screen.show()

	var title_screen = main.get_node("TitleScreen")
	var btn_mp: Button = title_screen.get_node("VBoxContainer/Button_MultiPlayer")
	btn_mp.grab_focus()

	watch_signals(title_screen)

	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	main._unhandled_input(joy_event)

	assert_signal_emitted(title_screen, "multi_player_pressed", "Button 0 (JOY_BUTTON_A) in _unhandled_input should activate focused button")


## The desktop and the editor open on the title screen; nothing loads until a button is pressed.
func test_main_opens_on_the_title_screen_on_desktop() -> void:
	var main: Node3D = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_true(main.title_screen.visible, "The title screen shows")
	assert_false(main.click_to_start.visible, "no Click to Start on the desktop")
	assert_eq(main.loading._scene_path, "", "and nothing loads until a button is pressed")


func test_new_game_puts_the_controls_back_to_zelda_and_auto() -> void:
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.control_scheme_name = "WoW"
	settings.hud_mode = PlayerSettingsResource.HudMode.SHOWN
	settings.save()
	var main: Node = MAIN_SCENE.instantiate()
	main.single_player_scene = "" # no world to load here; what New Game does before loading is the point
	add_child_autofree(main)
	main.new_game()
	assert_eq(settings.control_scheme_name, "", "New Game forgets the picked layout, so the world's own (Zelda) is what a new game starts on")
	assert_eq(settings.hud_mode, PlayerSettingsResource.HudMode.AUTO, "and the on-screen controls are back on Auto")
	PlayerSettingsResource._cached = null
	var reloaded: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	assert_eq(reloaded.control_scheme_name, "", "written to the file, so the world spawns the Player that way")
	assert_eq(reloaded.hud_mode, PlayerSettingsResource.HudMode.AUTO)
	assert_null(reloaded.picked_scheme(), "and the world applies its own layout, since nothing is picked")

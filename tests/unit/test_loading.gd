extends GutTest

const MAIN_SCENE = preload("res://scenes/main.tscn")
const TITLE_SCREEN_SCENE = preload("res://scenes/title_screen.tscn")
const LOADING_SCENE = preload("res://addons/3d_player_controller/scenes/ui/loading.tscn")


## A real finger on the middle of [param control], pressed and lifted, pushed through the viewport as the display
## server delivers it. Only a TouchScreenButton that is shown in the tree answers it. The containers lay their
## buttons out at the end of a frame, so the finger waits for that first.
func _touch(control: Control) -> void:
	await wait_process_frames(1)
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = control.get_global_rect().get_center()
		touch.pressed = pressed
		get_viewport().push_input(touch, true)


## The loading screen's own scene is saved shown, so it can be seen in its own tab; main.tscn hides its instance.
func test_loading_node_initial_state() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var loading: Loading = main.get_node("Loading") as Loading

	assert_false(loading.visible, "Main hides its loading screen until something loads")
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

	watch_signals(title_screen)

	assert_true(title_screen.get_node("VBoxContainer/Button_SinglePlayer/TouchScreenButton_SinglePlayer").is_visible_in_tree(), "The touch buttons are not saved hidden")
	await _touch(title_screen.button_single_player)

	assert_true(title_screen.menu_single_player.visible, "A touch on Single-Player opens the same panel as the button")
	assert_signal_not_emitted(title_screen, "multi_player_pressed", "and presses nothing else")


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

	await _touch(title_screen.button_single_player)
	assert_signal_not_emitted(title_screen, "new_game_pressed", "The touch that opens the panel does not also start the game")
	await _touch(title_screen.button_new_game)

	assert_signal_emitted(title_screen, "new_game_pressed", "A touch on New Game emits new_game_pressed")


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

	await _touch(title_screen.get_node("VBoxContainer/Button_MultiPlayer"))

	assert_signal_emitted(title_screen, "multi_player_pressed", "A touch on Multi-Player emits multi_player_pressed")


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


func test_title_screen_options_opens_the_settings_and_back_returns() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	assert_false(title_screen.settings.visible, "The settings are instanced hidden")

	title_screen.button_options.pressed.emit()
	assert_true(title_screen.settings.visible, "Options opens the player controller's settings")
	assert_false(title_screen.menu_main.visible, "over the main menu, which steps aside")
	assert_true(title_screen.get_node("Settings/Panel/VBoxContainer/Audio").has_focus(), "The settings take the focus")
	assert_null(title_screen.default_button(), "A controller's Accept has no title button to fall back on meanwhile")

	title_screen.get_node("Settings/Panel/VBoxContainer/BACK").pressed.emit()
	assert_false(title_screen.settings.visible, "Back closes the settings")
	assert_true(title_screen.menu_main.visible, "and the main menu is back")
	assert_true(title_screen.button_options.has_focus(), "with the focus on Options, where it came from")


func test_title_screen_options_opens_on_a_touch() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	await _touch(title_screen.button_options)
	assert_true(title_screen.settings.visible, "A touch on Options opens the settings")


func test_title_screen_settings_pages_lead_to_one_another() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	title_screen.button_options.pressed.emit()
	for page: String in ["Audio", "Video", "Controls"]:
		var page_menu: PlayerMenuLayer = title_screen.get_node(page + "Settings")
		assert_false(page_menu.visible, "%s is instanced hidden" % page)
		title_screen.get_node("Settings/Panel/VBoxContainer/" + page).pressed.emit()
		assert_true(page_menu.visible, "The %s button opens its page with no Player about" % page)
		assert_false(title_screen.settings.visible, "in place of the settings")
		page_menu.get_node("Panel/VBoxContainer/BACK").pressed.emit()
		assert_false(page_menu.visible, "Back on %s closes it" % page)
		assert_true(title_screen.settings.visible, "and returns to the settings")


## The pages close on "start", an action only a Player registers; on the title, with no Player, they keep their own
## input and look for the action before asking for it, so a mouse move is no InputMap error.
func test_title_screen_settings_take_input_without_a_player() -> void:
	var title_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	title_screen.button_options.pressed.emit()
	for page: Node in title_screen.get_children():
		if page is PlayerMenuLayer:
			assert_true(page.is_processing_input(), "%s keeps its own input" % page.name)
			page._input(InputEventMouseMotion.new())
	assert_true(title_screen.settings.visible, "and a mouse move closes nothing")


func test_main_controls_page_lists_the_projects_own_layouts() -> void:
	PlayerControls.forget_registered_schemes()
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var scheme_button: OptionButton = main.get_node("TitleScreen/ControlsSettings/Panel/VBoxContainer/ControlScheme")
	var names: Array[String] = []
	for i: int in scheme_button.item_count:
		names.append(scheme_button.get_item_text(i))
	assert_has(names, "GTA", "Main registers its layouts before the title's Controls page fills its list")


func test_main_accept_does_nothing_while_the_title_is_hidden() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.click_to_start.hide()
	main.multi_player() # the lobby explorer replaces the title screen
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	watch_signals(main.title_screen)

	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	main._unhandled_input(joy_event)

	assert_false(main.title_screen.menu_single_player.visible, "A in the lobby explorer does not press Single-Player behind it")
	assert_signal_not_emitted(main.title_screen, "new_game_pressed")


func test_main_accept_does_not_reach_behind_the_settings() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main.click_to_start.hide()
	main.title_screen.show()
	main.title_screen.button_options.pressed.emit()
	main.title_screen.get_node("Settings/Panel/VBoxContainer/Audio").pressed.emit()
	(main.title_screen.get_node("AudioSettings/Panel/VBoxContainer/Music/VolumeSlider") as Control).grab_focus() # focused, but not a button

	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	main._unhandled_input(joy_event)

	assert_false(main.title_screen.menu_single_player.visible, "A on a slider in the settings does not press Single-Player behind them")

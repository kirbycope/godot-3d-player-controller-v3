extends GutTest

const MAIN_SCENE = preload("res://scenes/main.tscn")
const TITLE_SCREEN_SCENE = preload("res://scenes/title_screen.tscn")
const LOADING_SCENE = preload("res://scenes/loading.tscn")


func test_loading_node_initial_state() -> void:
	var loading: Loading = LOADING_SCENE.instantiate() as Loading
	add_child_autofree(loading)

	assert_false(loading.visible, "Loading screen should start hidden")
	assert_gt(loading.tips.size(), 0, "Tips array should not be empty")
	assert_eq(loading._scene_path, "", "Initial scene path should be empty")


func test_loading_node_load_scene_starts_request() -> void:
	var loading: Loading = LOADING_SCENE.instantiate() as Loading
	add_child_autofree(loading)

	loading.load_scene("res://scenes/world.tscn")

	assert_true(loading.visible, "Loading screen should become visible when loading starts")
	assert_eq(loading._scene_path, "res://scenes/world.tscn", "Scene path should be stored")
	assert_eq(loading.progress_bar.value, 0.0, "Progress bar should reset to 0")
	assert_ne(loading.tip.text, "", "Tip label text should be set")
	assert_true(loading.details.get_parsed_text().contains("Requesting res://scenes/world.tscn"), "Details log should report request")


func test_title_screen_emits_single_player_pressed_on_button() -> void:
	var title_screen: CanvasLayer = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	var button_sp: Button = title_screen.get_node("VBoxContainer/Button_SinglePlayer")
	button_sp.emit_signal("pressed")

	assert_signal_emitted(title_screen, "single_player_pressed", "Single-player button should emit single_player_pressed signal")


func test_title_screen_emits_single_player_pressed_on_touch_button() -> void:
	var title_screen: CanvasLayer = TITLE_SCREEN_SCENE.instantiate()
	add_child_autofree(title_screen)
	watch_signals(title_screen)

	var touch_sp: TouchScreenButton = title_screen.get_node("VBoxContainer/Button_SinglePlayer/TouchScreenButton_SinglePlayer")
	touch_sp.emit_signal("pressed")

	assert_signal_emitted(title_screen, "single_player_pressed", "Touch button should emit single_player_pressed signal")


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


func test_main_scene_wiring() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)

	assert_eq(main.single_player_scene, "res://scenes/world.tscn", "Main single_player_scene should point to world.tscn string path")
	assert_eq(main.multi_player_scene, "res://addons/3d_player_controller/scenes/lobby_explorer.tscn", "Main multi_player_scene should point to lobby_explorer.tscn string path")

	# Verify child nodes
	var title_screen = main.get_node_or_null("TitleScreen")
	var loading = main.get_node_or_null("Loading")
	assert_not_null(title_screen, "Main should have TitleScreen child node")
	assert_not_null(loading, "Main should have Loading child node")

	# Verify node-based signal connections
	assert_true(
		title_screen.is_connected("single_player_pressed", Callable(main, "single_player")),
		"TitleScreen single_player_pressed signal should be connected to Main.single_player"
	)
	assert_true(
		title_screen.is_connected("multi_player_pressed", Callable(main, "multi_player")),
		"TitleScreen multi_player_pressed signal should be connected to Main.multi_player"
	)


func test_main_unhandled_input_button_0_selects_focused_option() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child_autofree(main)

	var title_screen = main.get_node("TitleScreen")
	var btn_mp: Button = title_screen.get_node("VBoxContainer/Button_MultiPlayer")
	btn_mp.grab_focus()

	watch_signals(title_screen)

	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	main._unhandled_input(joy_event)

	assert_signal_emitted(title_screen, "multi_player_pressed", "Button 0 (JOY_BUTTON_A) in _unhandled_input should activate focused button")

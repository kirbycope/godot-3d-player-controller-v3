extends GutTest

## GUT Unit tests for RadiOtHUD.

const HUD_SCENE: PackedScene = preload("res://addons/radi_ot/scenes/radi_ot_hud.tscn")

var _hud: RadiOtHUD


func before_each() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)


func test_set_error_state_shows_no_signal() -> void:
	_hud.set_error_state("Connection failed")
	assert_eq(_hud._status_label.text, "NO SIGNAL", "Badge should read NO SIGNAL on stream failure")
	assert_eq(_hud._tagline_label.text, "Connection failed", "Tagline should show the error message")


func test_hint_text_controls_hint_row() -> void:
	assert_false(_hud._hint_label.visible, "Hint row hidden without hint_text")
	_hud.hint_text = "[M] Power"
	assert_eq(_hud._hint_label.text, "[M] Power")
	assert_true(_hud._hint_label.visible)


func test_auto_hide_timer_fades_panel() -> void:
	assert_false(_hud._panel_container.visible, "Panel starts hidden with toast_hide")
	_hud.show_hud(0.05)
	assert_true(_hud._panel_container.visible)
	assert_false(_hud._auto_hide_timer.is_stopped(), "show_hud starts the auto-hide Timer")
	await wait_for_signal(_hud._auto_hide_timer.timeout, 1.0)
	await wait_seconds(RadiOtHUD.FADE_SECONDS + 0.2)
	assert_almost_eq(_hud._panel_container.modulate.a, 0.0, 0.001, "Tween fades the panel out")
	assert_false(_hud._panel_container.visible, "Panel hidden after the fade")


func test_bulletin_keeps_panel_visible() -> void:
	_hud.show_urgent_bulletin("Test")
	assert_true(_hud._bulletin_banner.visible)
	assert_true(_hud._auto_hide_timer.is_stopped(), "Bulletin stops the auto-hide Timer")
	_hud.hide_urgent_bulletin()
	assert_false(_hud._bulletin_banner.visible)
	assert_false(_hud._auto_hide_timer.is_stopped(), "Auto-hide resumes after the bulletin")

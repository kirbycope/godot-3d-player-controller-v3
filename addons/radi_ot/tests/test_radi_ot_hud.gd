extends GutTest

## GUT Unit tests for RadiOtHUD.

const HUD_SCENE: PackedScene = preload("res://addons/radi_ot/scenes/radi_ot_hud.tscn")


func test_set_error_state_shows_no_signal() -> void:
	var hud: RadiOtHUD = HUD_SCENE.instantiate() as RadiOtHUD
	add_child_autofree(hud)
	hud.set_error_state("Connection failed")
	assert_eq(hud._status_label.text, "NO SIGNAL", "Badge should read NO SIGNAL on stream failure")
	assert_eq(hud._tagline_label.text, "Connection failed", "Tagline should show the error message")

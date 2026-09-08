extends GutTest

## Purpose: the catch screen holds the catch up Zelda style: the species' model turning in front of the rays, its
## name, its length with a star on a record (Junk for junk), its flavour text; Action puts it away; it is a world
## pausing menu; and the rod on the world player opens it once the catch has arced into the hands, instead of the
## HUD card.

const SCREEN_SCENE: PackedScene = preload("res://scenes/fish_caught_screen.tscn")
const CARP: Fish = preload("res://resources/fish/carp.tres")
const BOOT: Fish = preload("res://resources/fish/old_boot.tres")

var screen: FishCaughtScreen


func before_each() -> void:
	screen = SCREEN_SCENE.instantiate() as FishCaughtScreen
	add_child_autofree(screen)
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().paused = false


func test_the_screen_names_the_catch_its_length_and_its_flavour_with_the_model_turning() -> void:
	assert_false(screen.visible)
	screen.show_catch(CARP, 42.3, false)
	assert_true(screen.visible)
	assert_eq(screen.name_label.text, "Carp")
	assert_eq(screen.size_label.text, "42.3 cm")
	assert_eq(screen.flavor_label.text, CARP.description, "The flavour text is the item's description")
	assert_true(screen.preview.visible, "The model preview is up")
	assert_false(screen.icon.visible)
	assert_eq(screen.model_pivot.get_child_count(), 1, "The species' model is in the pivot")
	var rays: ColorRect = screen.get_node("Center/VBox/Stage/Rays")
	assert_true(rays.material is ShaderMaterial, "The rays fan out behind it")
	assert_true((rays.material as ShaderMaterial).shader.resource_path.ends_with("radial_shine.gdshader"))
	var heading: float = screen.model_pivot.rotation.y
	await wait_process_frames(3)
	assert_ne(screen.model_pivot.rotation.y, heading, "The model turns while the screen is up")
	screen.hide_menu()


func test_a_record_gets_a_star_and_junk_reads_junk() -> void:
	screen.show_catch(CARP, 61.0, true)
	assert_eq(screen.size_label.text, "61.0 cm  * record")
	screen.show_catch(BOOT, 0.0, false)
	assert_eq(screen.name_label.text, "Old Boot")
	assert_eq(screen.size_label.text, "Junk")
	assert_eq(screen.flavor_label.text, BOOT.description)
	screen.hide_menu()


func test_action_puts_the_screen_away_and_it_pauses_the_world_alone() -> void:
	assert_true(screen.pauses_world, "The catch is a moment the world waits for")
	screen.show_catch(CARP, 30.0)
	assert_true(get_tree().paused, "Alone, the world stands still while the catch is held up")
	var press := InputEventAction.new()
	press.action = "action"
	press.pressed = true
	screen._input(press)
	assert_false(screen.visible, "Action puts it away")
	assert_false(get_tree().paused, "and the world runs again")

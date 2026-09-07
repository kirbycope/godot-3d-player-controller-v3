extends GutTest

## Purpose: the Fish Index shows each species' own model where it has one: the Old Boot turns as the peasant boot
## from the outfit pack, sized like a catch, and a species without a model still gets the placeholder fish.

const INDEX_SCENE: PackedScene = preload("res://scenes/fish_index_screen.tscn")
const OLD_BOOT: Fish = preload("res://resources/fish/old_boot.tres")
const CARP: Fish = preload("res://resources/fish/carp.tres")

var index: FishIndexScreen


func before_each() -> void:
	index = INDEX_SCENE.instantiate()
	add_child_autofree(index)
	await wait_process_frames(1)


func after_each() -> void:
	await wait_process_frames(1)


func test_the_old_boot_has_the_peasant_boot_model_and_the_index_turns_it() -> void:
	assert_not_null(OLD_BOOT.model_scene, "The Old Boot names its model")
	assert_null(OLD_BOOT.equipment_scene, "as a model to turn, not equipment to pick up")
	assert_false(OLD_BOOT.model_scene.resource_path.ends_with("fish_model.tscn"), "A model of its own, not the placeholder")
	index._show(OLD_BOOT)
	await wait_process_frames(1)
	var model: Node3D = index.model_pivot.get_child(0)
	assert_false(model is FishModel, "Not the placeholder box")
	var meshes: Array[Node] = model.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(meshes.size(), 0, "The boot mesh is in the pivot")
	var longest: float = 0.0
	for mesh: Node in meshes:
		var visual: GeometryInstance3D = mesh as GeometryInstance3D
		var box: AABB = (index.model_pivot.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		longest = maxf(longest, box.get_longest_axis_size())
	assert_almost_eq(longest, FishModel.BASE_LENGTH_CM / 100.0, 0.02, "Sized to the placeholder's length, like any catch")
	assert_true(index.record_label.text.begins_with("Not yet"), "Without a log nothing is caught")
	assert_not_null((meshes[0] as GeometryInstance3D).material_override, "and the boot is a silhouette until it is")


func test_the_crate_of_boots_is_junk_that_outweighs_a_boot_eleven_times_and_is_listed() -> void:
	var crate: Fish = load("res://resources/fish/boot_crate.tres")
	assert_true(crate.is_junk)
	assert_gte(crate.mass_kg, 11.0 * OLD_BOOT.mass_kg, "At least eleven times heavier than a boot")
	assert_lt(crate.weight, OLD_BOOT.weight, "but rarer on the line: weight is the bite chance, not the kilograms")
	assert_true(crate.describe_conditions().has("Weighs 15.0 kg"), "The index says what it weighs")
	assert_eq(crate.category, Item.Category.MATERIALS, "Junk goes on the Materials tab")
	assert_eq(OLD_BOOT.category, Item.Category.MATERIALS, "and so does the boot: its resource says so, is_junk does not decide")
	assert_false(OLD_BOOT.consumable)
	assert_eq(OLD_BOOT.max_stack, 99)
	assert_eq(crate.max_stack, 99)
	assert_false(crate.consumable)
	assert_true(index.species.has(crate), "The index lists it")
	index._show(crate)
	await wait_process_frames(1)
	assert_true(index.model_pivot.get_child(0) is FishModel, "A crate is the junk box until it has a model")


func test_the_window_keeps_its_size_whatever_the_entry_says() -> void:
	var panel: Control = index.get_node("Panel")
	var window: Vector2 = index.get_viewport().get_visible_rect().size
	index._show(CARP)
	await wait_process_frames(2)
	var with_a_fish: Vector2 = panel.size
	assert_almost_eq(with_a_fish.x, window.x * 0.76, 1.0, "The panel is a fixed share of the window")
	assert_almost_eq(with_a_fish.y, window.y * 0.8, 1.0)
	index._show(load("res://resources/fish/boot_crate.tres"))
	await wait_process_frames(2)
	assert_eq(panel.size, with_a_fish, "Shorter text does not shrink it")
	index._show(load("res://resources/fish/catfish.tres"))
	await wait_process_frames(2)
	assert_eq(panel.size, with_a_fish, "Longer text does not grow it")


func test_a_species_without_a_model_still_shows_the_placeholder_fish() -> void:
	var nameless: Fish = Fish.new()
	nameless.display_name = "Nameless"
	index._show(nameless)
	await wait_process_frames(1)
	assert_true(index.model_pivot.get_child(0) is FishModel)
	assert_null(nameless.model_scene, "A species without a model of its own")
	assert_not_null(CARP.get_model_scene(), "Every shipped species resolves to some model")


func test_a_fresh_fish_takes_the_item_defaults_and_is_junk_only_flags_the_catch() -> void:
	var fresh: Fish = Fish.new()
	assert_eq(fresh.category, Item.Category.MATERIALS, "A Fish keeps Item's declared defaults, so a saved resource only stores what differs")
	assert_eq(fresh.max_stack, 99)
	assert_false(fresh.consumable)
	fresh.category = Item.Category.FOOD
	fresh.max_stack = 10
	fresh.consumable = true
	fresh.is_junk = true
	assert_eq(fresh.category, Item.Category.FOOD, "is_junk leaves the Item fields alone")
	assert_eq(fresh.max_stack, 10)
	assert_true(fresh.consumable)
	assert_almost_eq(fresh.roll_length(), 0.0, 0.001, "It only takes the length away")
	assert_true(fresh.describe_conditions()[0].begins_with("Not a fish"))

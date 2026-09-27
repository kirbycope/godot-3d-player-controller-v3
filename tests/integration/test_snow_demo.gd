extends GutTest

## Purpose: the snow demo's starting kit (the sword, shield, pistol and bow at the spawn) goes to a fresh start on
## its first frame, and goes away when a save is continued, whose backpack already holds what it held; otherwise a
## Continue left a second set of weapons floating where the Player spawns.

const DEMO_SCENE: PackedScene = preload("res://scenes/snow_demo.tscn")

var demo: Node3D
var player: Player
var saver: SaveGame


func before_each() -> void:
	_clear_saves()
	SaveGame.slot = 0
	SaveGame.load_requested = false


func after_each() -> void:
	_clear_saves()
	SaveGame.slot = 0
	SaveGame.load_requested = false


func _clear_saves() -> void:
	if DirAccess.dir_exists_absolute(SaveGame.SAVES_DIR):
		for file: String in DirAccess.get_files_at(SaveGame.SAVES_DIR):
			DirAccess.remove_absolute(SaveGame.SAVES_DIR.path_join(file))


func _open_demo() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(4)
	player = demo.get_node("Player")
	saver = demo.get_node("SaveGame")


func test_the_starting_kit_is_wired_and_a_fresh_start_takes_it() -> void:
	await _open_demo()
	assert_true(saver.loaded.is_connected(demo._on_save_loaded), "The SaveGame's loaded frees the kit, wired in the scene")
	assert_not_null(demo.starting_equipment, "The demo knows its starting kit")
	assert_true(is_instance_valid(demo.get_node_or_null("StartingEquipment")), "A fresh start keeps the pickups where they are")
	# Carried, not necessarily in hand: the four pickups are taken in physics order, and whichever comes last stows the
	# others, so after another suite the sword may sit in the backpack rather than the hand
	var took_it: bool = await wait_until(func() -> bool: return _carries(Equipment.EquipmentType.SWORD_1H), 2.0)
	assert_true(took_it, "and the Player carries the sword as soon as the pickups have seen it")


func test_continue_frees_the_starting_kit_and_brings_the_saved_backpack() -> void:
	await _open_demo()
	SaveGame.slot = 3
	assert_eq(saver.save_game(), OK)
	var saved_pieces: int = player.inventory.equipment.size()
	assert_gt(saved_pieces, 0, "The save holds the kit the Player picked up")
	demo.free()
	SaveGame.load_requested = true
	await _open_demo()
	assert_false(SaveGame.load_requested, "The save was loaded")
	assert_null(demo.get_node_or_null("StartingEquipment"), "and the starting kit is gone, not floating at the spawn")
	assert_null(demo.starting_equipment)
	assert_eq(player.inventory.equipment.size(), saved_pieces, "The Player carries the save's pieces, once each")


func _carries(type: Equipment.EquipmentType) -> bool:
	for piece: Equipment in player.inventory.get_all_weapons():
		if piece.equipment_type == type:
			return true
	return false

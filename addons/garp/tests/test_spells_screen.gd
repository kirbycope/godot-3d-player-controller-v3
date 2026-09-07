extends GutTest

## Purpose: Pause shows a Spells button when its screen path is set; the Tree page draws the tree and unlocks on
## Confirm, the Loadout page lifts an unlocked spell onto a wheel slot and clears slots, the pages switch with the
## bumper actions and Back returns to Pause.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const DEMO_TREE: SpellTree = preload("res://addons/garp/resources/spell_tree_demo.tres")
const STEALTH: Ability = preload("res://addons/3d_player_controller/resources/abilities/stealth.tres")
const HEAL: Ability = preload("res://addons/3d_player_controller/resources/abilities/heal.tres")

var root: Node3D
var player: Player
var spellbook: Spellbook
var pause: Node
var screen: SpellsScreen
var sender


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER_SCENE.instantiate()
	var none: Array[Ability] = []
	player.get_node("Abilities").abilities = none
	player.get_node("Abilities").active_ability = null
	var book: Spellbook = player.get_node("Inventory/Spellbook")
	book.tree = DEMO_TREE
	book.skill_points = 3
	root.add_child(player)
	player.controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	spellbook = player.inventory.spellbook
	pause = player.pause
	sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	await wait_physics_frames(3)
	screen = pause.spells_screen as SpellsScreen


func after_each() -> void:
	sender.release_all()
	sender.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open() -> void:
	pause.show_menu()
	pause._on_spells_pressed()
	await wait_physics_frames(1)


func test_pause_shows_the_spells_button_and_opens_the_screen() -> void:
	assert_true(pause.spells_button.visible, "player.tscn sets the GARP spells screen path")
	assert_not_null(screen)
	assert_eq(screen.get_parent(), player)
	await _open()
	assert_true(screen.visible)
	assert_false(pause.visible)
	assert_eq(screen.page, SpellsScreen.Page.TREE, "Opens on the tree")
	assert_eq(screen.points_label.text, "Skill points: 3")
	assert_true(screen.get_viewport().gui_get_focus_owner() is SpellNodeButton, "A tree node has focus")
	screen._on_back_pressed()
	await wait_physics_frames(1)
	assert_true(pause.visible, "Back returns to Pause")
	pause.hide_menu()


func test_the_tree_page_draws_the_nodes_and_unlocks_on_confirm() -> void:
	await _open()
	var stealth_button: SpellNodeButton = screen._node_buttons[STEALTH]
	var heal_button: SpellNodeButton = screen._node_buttons[HEAL]
	assert_eq(stealth_button.cost_label.text, "1 pt")
	assert_eq(heal_button.cost_label.text, "2 pt")
	assert_lt(heal_button.modulate.a, 1.0, "Heal is dim: Stealth comes first")
	assert_eq(stealth_button.modulate.a, 1.0, "Stealth is unlockable")
	stealth_button.grab_focus()
	assert_eq(screen.detail_name.text, "Stealth")
	assert_eq(screen.detail_status.text, "Costs 1 skill point")
	assert_false(screen.unlock_button.disabled)
	sender.action_down("ui_accept")
	await wait_physics_frames(1)
	sender.action_up("ui_accept")
	await wait_physics_frames(1)
	assert_true(spellbook.is_unlocked(STEALTH), "Confirm on the node unlocks it")
	assert_eq(stealth_button.cost_label.text, "Unlocked")
	assert_eq(screen.points_label.text, "Skill points: 2")
	assert_eq(heal_button.modulate.a, 1.0, "Heal is now unlockable")
	heal_button.grab_focus()
	assert_eq(screen.detail_requires.text, "Requires: Stealth")
	screen._on_unlock_pressed()
	assert_true(spellbook.is_unlocked(HEAL), "The Unlock button unlocks the focused node")
	assert_true(screen.unlock_button.disabled, "Nothing more to unlock here")
	pause.hide_menu()


func test_the_tree_page_lays_the_nodes_out_by_cell_like_the_editor_graph() -> void:
	await _open()
	assert_eq(screen._node_buttons.size(), DEMO_TREE.nodes.size(), "A button per node, no spacers")
	for node: SpellNode in DEMO_TREE.nodes:
		var expected: Vector2 = Vector2(node.column, node.row) * SpellTree.CELL
		assert_eq(screen._node_buttons[node.ability].position, expected, node.ability.display_name + " sits at its column and row")
		assert_eq(SpellTree.cell_position(node), expected)
	assert_eq(screen.tree_canvas.custom_minimum_size, DEMO_TREE.pixel_size(), "The canvas spans every column and row")
	assert_eq(DEMO_TREE.pixel_size(), Vector2(DEMO_TREE.column_count(), DEMO_TREE.row_count()) * SpellTree.CELL)
	var line: PackedVector2Array = SpellTree.connection_segment(Rect2(0, 0, 96, 80), Rect2(112, 120, 96, 80))
	assert_almost_eq(line[0].y, 80.0, 0.01, "A prerequisite line leaves the earlier spell's edge, aimed at the later one")
	assert_between(line[0].x, 48.0, 96.0)
	assert_almost_eq(line[1].y, 120.0, 0.01, "and reaches the later spell's edge")
	var sideways: PackedVector2Array = SpellTree.connection_segment(Rect2(0, 0, 96, 80), Rect2(224, 0, 96, 80))
	assert_eq(sideways[0], Vector2(96, 40), "Side by side, it runs edge to edge")
	assert_eq(sideways[1], Vector2(224, 40))
	pause.hide_menu()


func test_the_loadout_page_places_and_clears_wheel_slots() -> void:
	spellbook.unlock(STEALTH)
	spellbook.unlock(HEAL)
	await _open()
	sender.action_down(screen.next_page_action)
	await wait_physics_frames(1)
	sender.action_up(screen.next_page_action)
	await wait_physics_frames(1)
	assert_eq(screen.page, SpellsScreen.Page.LOADOUT, "The bumper action turns the page")
	assert_eq(screen._unlocked_buttons.size(), 2, "Both unlocked spells are listed")
	assert_eq(screen._slot_buttons.size(), Spellbook.MAX_ACTIVE, "Eight wheel slots")
	assert_eq(screen._slot_buttons[0].ability, STEALTH, "Unlocking put them on the wheel already")
	assert_eq(screen._slot_buttons[1].ability, HEAL)
	screen._on_unlocked_pressed(HEAL)
	assert_eq(screen.held_ability, HEAL, "Confirm on a spell lifts it")
	assert_true(screen.held_icon.visible)
	screen._on_wheel_slot_pressed(5)
	assert_null(screen.held_ability, "Confirm on a slot places it")
	assert_eq(spellbook.active[5], HEAL)
	assert_null(spellbook.active[1], "And it left its old slot")
	screen._on_wheel_slot_pressed(5)
	assert_null(spellbook.active[5], "Confirm on a filled slot with nothing held clears it")
	assert_eq(player.abilities.abilities, [STEALTH] as Array[Ability], "The wheel follows")
	screen._on_wheel_slot_focused(0)
	screen._on_clear_pressed()
	assert_null(spellbook.active[0], "Clear empties the focused slot")
	sender.action_down(screen.previous_page_action)
	await wait_physics_frames(1)
	sender.action_up(screen.previous_page_action)
	await wait_physics_frames(1)
	assert_eq(screen.page, SpellsScreen.Page.TREE)
	pause.hide_menu()

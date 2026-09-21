extends GutTest

## Purpose: test_abilities.tscn is a range that runs. At ready every ability in its library is on the Player's wheel
## and has a row on the panel: three buttons for what the Player casts it on (nothing, the Player, the picked enemy)
## and three for what the picked enemy casts it on (nothing, the enemy, the Player), each running the real cast
## through the caster's own node with the chosen body as its target.

const RANGE_SCENE: PackedScene = preload("res://tests/unit/test_abilities.tscn")

var range: Node3D


func before_each() -> void:
	range = RANGE_SCENE.instantiate()
	add_child_autofree(range)
	await wait_physics_frames(2)


func _focus_spell() -> Ability:
	for ability: Ability in range.library.get_abilities():
		if ability.target_kinds & Ability.Kind.HOSTILE and ability.cast_time > 0.0:
			return ability
	return null


func test_every_ability_in_the_library_is_on_the_wheel_and_the_panel() -> void:
	var abilities: Array[Ability] = range.library.get_abilities()
	assert_gt(abilities.size(), 0, "The range's library carries this game's spells")
	assert_eq(range.player.abilities.abilities, abilities, "All of them on the Player's wheel")
	assert_eq(range.player.abilities.active_ability, abilities[0], "the first in hand")
	assert_eq(range.rows.get_child_count(), abilities.size(), "and a row each on the panel")
	assert_eq(range.enemy_picker.item_count, range.enemies.get_child_count(), "with every enemy to pick from")
	assert_eq((range.player_buttons[abilities[0]] as Array).size(), 3, "Three targets for the Player")
	assert_eq((range.enemy_buttons[abilities[0]] as Array).size(), 3, "and three for the enemy")
	assert_eq((range.player_buttons[abilities[0]][2] as Button).shortcut.events[0].keycode, KEY_1, "1 is the Player at the enemy")
	assert_true((range.enemy_buttons[abilities[0]][2] as Button).shortcut.events[0].shift_pressed, "Shift 1 the enemy at the Player")


func test_the_player_casts_on_self_and_on_the_picked_enemy() -> void:
	var spell: Ability = _focus_spell()
	assert_not_null(spell, "A timed spell that normally needs a focus target")
	range.enemy_picker.selected = 0
	var enemy: EnemyNpc = range.picked_enemy()
	(range.player_buttons[spell][2] as Button).pressed.emit()
	assert_eq(range.player.abilities.casting, spell, "The Player's own Abilities node runs the cast")
	assert_eq(spell.get_target(range.player), enemy, "aimed at the picked enemy, with nothing locked on")
	range.player.abilities.interrupt_cast()
	assert_null(Ability.chosen_target(range.player), "An interrupted cast forgets the chosen body")
	(range.player_buttons[spell][1] as Button).pressed.emit()
	assert_eq(spell.get_target(range.player), range.player, "Cast on self, it lands on the Player")
	range.player.abilities.interrupt_cast()
	(range.player_buttons[spell][0] as Button).pressed.emit()
	assert_ne(spell.get_target(range.player), range.player, "Cast on nothing, the ability's own aim decides")


func test_the_picked_enemy_casts_on_the_player_on_itself_and_on_nothing() -> void:
	var spell: Ability = _focus_spell()
	range.enemy_picker.selected = 0
	var enemy: EnemyNpc = range.picked_enemy()
	assert_not_null(enemy, "The first enemy is picked")
	(range.enemy_buttons[spell][2] as Button).pressed.emit()
	assert_eq(enemy.caster.casting, spell, "Its NpcCaster runs the spell on demand")
	assert_eq(spell.get_target(enemy), range.player, "at the Player")
	enemy.caster.interrupt()
	(range.enemy_buttons[spell][1] as Button).pressed.emit()
	assert_eq(spell.get_target(enemy), enemy, "on itself")
	enemy.caster.interrupt()
	(range.enemy_buttons[spell][0] as Button).pressed.emit()
	assert_null(Ability.chosen_target(enemy), "on nothing: its own target, whatever the hunt says")

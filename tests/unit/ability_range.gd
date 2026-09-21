extends Node3D
## A range for trying abilities while the game runs. Every ability in the library goes on the Player's wheel, and the
## panel gives each a row of what the Player casts it on (nothing, the Player, the picked enemy) and what the picked
## enemy casts it on (nothing, the enemy, the Player), so the whole sequence plays for real in both directions: the
## animation, the channeling, the bolt, the impact, the damage. A number key is the Player casting at the enemy,
## Shift and the number the enemy casting at the Player. Edit the ability resources in the remote inspector while
## it runs and cast again.

enum On { NONE, SELF, OTHER } ## What a cast lands on: nothing (where the caster aims), the caster, or the other side.

@export var library: AbilityLibrary
@export var player: Player
@export var enemies: Node3D ## Its children are the enemies the picker offers.
@export var rows: VBoxContainer ## One row per ability, built at ready.
@export var enemy_picker: OptionButton

var player_buttons: Dictionary[Ability, Array] = {} ## Ability -> the Player's three buttons, in [enum On] order.
var enemy_buttons: Dictionary[Ability, Array] = {} ## Ability -> the enemy's three buttons, in [enum On] order.


func _ready() -> void:
	# The panel is clicked, so the cursor stays free here whatever the Player's scheme wants (the Player readied
	# first and captured it); a left click on the ground is click-to-move, a right-drag turns the camera
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var abilities: Array[Ability] = library.get_abilities()
	player.abilities.abilities = abilities
	if not abilities.is_empty():
		player.abilities.active_ability = abilities[0]
	for enemy: Node in enemies.get_children():
		enemy_picker.add_item(enemy.name)
	var index: int = 0
	for ability: Ability in abilities:
		index += 1
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = "%d  %s" % [index, ability.display_name if not ability.display_name.is_empty() else String(ability.get_id())]
		label.custom_minimum_size.x = 180.0
		row.add_child(label)
		var key: Key = (KEY_0 + index % 10) as Key if index <= 10 else KEY_NONE
		row.add_child(_caption("Player on"))
		player_buttons[ability] = []
		for on: On in [On.NONE, On.SELF, On.OTHER]:
			var button: Button = _button(["nothing", "self", "enemy"][on], player_casts.bind(ability, on))
			if on == On.OTHER and key != KEY_NONE:
				button.shortcut = _shortcut(key, false)
			row.add_child(button)
			player_buttons[ability].append(button)
		row.add_child(_caption("Enemy on"))
		enemy_buttons[ability] = []
		for on: On in [On.NONE, On.SELF, On.OTHER]:
			var button: Button = _button(["nothing", "self", "player"][on], enemy_casts.bind(ability, on))
			if on == On.OTHER and key != KEY_NONE:
				button.shortcut = _shortcut(key, true)
			row.add_child(button)
			enemy_buttons[ability].append(button)
		rows.add_child(row)


## The Player casts [param ability] the way a tap of the ability button would, landing it on [param on].
func player_casts(ability: Ability, on: On) -> void:
	player.abilities.cast(ability, _body_for(on, player, picked_enemy()))


## The picked enemy casts [param ability] at [param on], through its own NpcCaster.
func enemy_casts(ability: Ability, on: On) -> void:
	var enemy: EnemyNpc = picked_enemy()
	if enemy == null:
		return
	enemy.caster.cast(ability, _body_for(on, enemy, player))


## The enemy the picker names, or null with nothing picked.
func picked_enemy() -> EnemyNpc:
	if enemy_picker.selected < 0 or enemy_picker.selected >= enemies.get_child_count():
		return null
	return enemies.get_child(enemy_picker.selected) as EnemyNpc


## What [param on] means for a cast by [param caster] with [param other] across from it: null for nothing, so the
## ability's own targeting decides.
static func _body_for(on: On, caster: Node3D, other: Node3D) -> Node3D:
	match on:
		On.SELF:
			return caster
		On.OTHER:
			return other
		_:
			return null


func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	return button


func _shortcut(key: Key, shift: bool) -> Shortcut:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.shift_pressed = shift
	var shortcut: Shortcut = Shortcut.new()
	shortcut.events = [event]
	return shortcut

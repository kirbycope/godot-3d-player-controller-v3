class_name SpellNodeButton
extends Button
## One node of the tree on the [SpellsScreen]: the spell's icon, name and cost, drawn dim while locked and marked
## once unlocked, with a [TouchScreenButton] for fingers.

signal node_pressed(ability: Ability)
signal node_focused(ability: Ability)

var ability: Ability

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var cost_label: Label = %Cost
@onready var touch_button: TouchScreenButton = $TouchScreenButton


func _ready() -> void:
	pressed.connect(func() -> void: node_pressed.emit(ability))
	focus_entered.connect(func() -> void: node_focused.emit(ability))
	mouse_entered.connect(grab_focus)
	touch_button.pressed.connect(func() -> void:
		grab_focus()
		node_pressed.emit(ability))
	var shape: RectangleShape2D = touch_button.shape as RectangleShape2D
	if shape:
		shape.size = custom_minimum_size
		touch_button.position = custom_minimum_size / 2.0


## Shows [param node]'s spell in one of three looks: unlocked, unlockable now, or locked.
func set_node(node: SpellNode, is_unlocked: bool, is_unlockable: bool) -> void:
	ability = node.ability
	icon_rect.texture = ability.icon if ability else null
	icon_rect.modulate = ability.icon_color if ability else Color.WHITE
	name_label.text = ability.display_name if ability else ""
	cost_label.text = "Unlocked" if is_unlocked else ("%d pt" % node.cost if node.cost != 1 else "1 pt")
	modulate = Color.WHITE if is_unlocked or is_unlockable else Color(1.0, 1.0, 1.0, 0.45)
	tooltip_text = name_label.text

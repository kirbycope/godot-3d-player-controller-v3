class_name SpellTree
extends Resource
## A tree of [SpellNode]s the [Spellbook] unlocks through: each node names its ability, its cost in skill points,
## its prerequisites and its row and column on the [SpellsScreen] grid. A project can ship several trees and
## point a Player's Spellbook at one.

@export var display_name: String = "Spells"
@export var nodes: Array[SpellNode] = []


## The node that unlocks [param ability], or null when the tree does not have it.
func get_node_for(ability: Ability) -> SpellNode:
	for node: SpellNode in nodes:
		if node.ability == ability:
			return node
	return null


func has(ability: Ability) -> bool:
	return get_node_for(ability) != null


## Rows on the grid (the deepest node's row plus one).
func row_count() -> int:
	var rows: int = 0
	for node: SpellNode in nodes:
		rows = maxi(rows, node.row + 1)
	return rows


## Columns on the grid (the rightmost node's column plus one).
func column_count() -> int:
	var columns: int = 0
	for node: SpellNode in nodes:
		columns = maxi(columns, node.column + 1)
	return columns


## The node at a grid cell, or null.
func get_node_at(row: int, column: int) -> SpellNode:
	for node: SpellNode in nodes:
		if node.row == row and node.column == column:
			return node
	return null

class_name Mineable
extends Harvestable
## An ore deposit mined with a pickaxe: once spent it shows the bare rock, which stays as solid as the deposit was.

@export var with_nodes: Node3D ## The ore model with mineable nodes.
@export var without_nodes: Node3D ## The depleted ore model shown after mining.


## Swaps the ore model for the bare rock, which keeps the deposit's collision.
func _on_depleted() -> void:
	super()
	if with_nodes:
		with_nodes.hide()
	if without_nodes:
		without_nodes.show()

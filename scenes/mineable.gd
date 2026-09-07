class_name Mineable
extends Harvestable
## An ore deposit depleted after enough hits from the "action" interaction or mining-capable weapons.

@export var with_nodes: Node3D ## The ore model with mineable nodes.
@export var without_nodes: Node3D ## The depleted ore model shown after mining.


## Swaps the ore model for its depleted version.
func _on_depleted() -> void:
	if with_nodes:
		with_nodes.hide()
	if without_nodes:
		without_nodes.show()

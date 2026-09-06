extends GutHookScript
## Runs before the suite: no inventory reads or writes user://garp_inventory.tres while tests run, so a scene
## with `persist` on (the world player) neither loads the real save nor overwrites it.


func run() -> void:
	Inventory.persistence_enabled = false

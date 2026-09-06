class_name Lure
extends Item
## Bait for the [FishingRod]: a GARP [Item] that, used from the inventory, goes on the line and stays there
## until another is used. Fish list the lures they bite on in [member Fish.lures]; a fish with none listed
## bites on anything, including a bare hook.


func _init() -> void:
	category = Category.MATERIALS
	max_stack = 99

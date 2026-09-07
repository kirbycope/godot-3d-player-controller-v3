class_name Lure
extends Item
## Bait for the [FishingRod]: a GARP [Item] that, used from the inventory, goes on the line and stays there
## until another is used, or, when [member consumable], until a fish eats it. Fish list the lures they bite
## on in [member Fish.lures]; a fish with none listed bites on anything, including a bare hook.

@export var bite_time_scale: float = 1.0 ## Multiplies the wait for a bite: 0.5 halves it.
@export var attract_range_bonus: float = 0.0 ## Metres added to the species' [member Fish.attract_range] while this is on the line.


func _init() -> void:
	category = Category.MATERIALS
	max_stack = 99


## Plain lines describing what the bait does, for the rod's inventory entry.
func describe_effects() -> PackedStringArray:
	var effects: PackedStringArray = []
	if not is_equal_approx(bite_time_scale, 1.0):
		effects.append("Bites come %d%% sooner" % roundi((1.0 - bite_time_scale) * 100.0) if bite_time_scale < 1.0 else "Bites come %d%% later" % roundi((bite_time_scale - 1.0) * 100.0))
	if attract_range_bonus > 0.0:
		effects.append("Draws shadows from %.1f m further" % attract_range_bonus)
	if consumable:
		effects.append("Eaten with each bite")
	return effects

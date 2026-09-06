class_name Fish
extends Item
## One catchable species (or piece of junk) in a water's fish table; see [member Buoyancy.fish]. A Fish is a GARP
## [Item], so a catch goes into the Player's inventory: its name, icon, description, tab and stack size are the
## Item's, and the rest says when it bites, on what, how big it runs and what it looks like when landed.

enum Rain { ANY, RAIN_ONLY, DRY_ONLY }

@export var color: Color = Color(0.6, 0.65, 0.7) ## Body colour of the placeholder model, the catch card swatch and the inventory icon.
@export var model_scene: PackedScene ## Model shown on a catch; empty uses the placeholder fish.
@export var min_length_cm: float = 20.0
@export var max_length_cm: float = 40.0
@export var weight: float = 1.0 ## Relative chance against the other fish available at the time.
@export_range(0, 24) var from_hour: int = 0 ## First hour it bites (inclusive); later than [member to_hour] wraps past midnight.
@export_range(0, 24) var to_hour: int = 24 ## Hour it stops biting (exclusive).
@export var rain: Rain = Rain.ANY
@export var lures: Array[Item] = [] ## Lures it bites on; empty means any lure, or none at all.
@export var is_junk: bool = false ## Junk has no length and never shows a shadow.
@export var shadow_scale: float = 1.0 ## Size of the shadow it casts under the surface.


func _init() -> void:
	category = Category.FOOD
	max_stack = 10
	consumable = true


## Whether it bites at [param hour], in this weather, on [param lure] (null for a bare hook).
func is_available(hour: int, raining: bool, lure: Item = null) -> bool:
	if (rain == Rain.RAIN_ONLY and not raining) or (rain == Rain.DRY_ONLY and raining):
		return false
	if not lures.is_empty() and (lure == null or not lures.any(func(wanted: Item) -> bool: return wanted.is_same(lure))):
		return false
	if from_hour <= to_hour:
		return hour >= from_hour and hour < to_hour
	return hour >= from_hour or hour < to_hour


## Length in centimetres for one catch; junk has none.
func roll_length() -> float:
	return 0.0 if is_junk else snappedf(randf_range(min_length_cm, max_length_cm), 0.1)


## The inventory tints the shared fish icon with the species' colour.
func get_icon_color() -> Color:
	return color

class_name Fish
extends Item
## One catchable species (or piece of junk) in a water's fish table; see [member Buoyancy.fish]. A Fish is an inventory
## [Item], so a catch goes into the Player's inventory: its name, icon, description, tab and stack size are the
## Item's, and the rest says when it bites, on what, how big it runs and what it looks like when landed.

enum Rain { ANY, RAIN_ONLY, DRY_ONLY }

@export var color: Color = Color(0.6, 0.65, 0.7) ## Body colour of the placeholder model, the catch card swatch and the inventory icon.
@export var min_length_cm: float = 20.0
@export var max_length_cm: float = 40.0
@export var weight: float = 1.0 ## Relative chance against the other fish available at the time.
@export var mass_kg: float = 0.0 ## What it weighs in the hand, for the index and the inventory; 0 leaves it unsaid.
@export_range(0, 24) var from_hour: int = 0 ## First hour it bites (inclusive); later than [member to_hour] wraps past midnight.
@export_range(0, 24) var to_hour: int = 24 ## Hour it stops biting (exclusive).
@export var rain: Rain = Rain.ANY
@export var lures: Array[Item] = [] ## Lures it bites on; empty means any lure, or a bare hook under [member bare_hook_chance].
@export_range(0.0, 1.0) var bare_hook_chance: float = 0.05 ## Share of [member weight] it keeps when nothing is on the line; 0 never bites bare, junk sets 1.
@export var biomes: Array[ClimateData.BiomeZone] = [] ## Waters in these biomes hold it; empty means any water.
@export var attract_range: float = 1.0 ## Metres from the float within which a shadow takes the bait; further ones stay put.
@export var is_junk: bool = false ## Junk has no length and never shows a shadow. Its tab, stack size and whether it is eaten are the Item fields in the resource, as for any fish.
@export var shadow_scale: float = 1.0 ## Size of the shadow it casts under the surface.


## Whether it bites at [param hour], in this weather, on [param lure] (null for a bare hook), in the water's
## [param biome] (-1 for water in no zone, which every fish accepts).
func is_available(hour: int, raining: bool, lure: Item = null, biome: int = -1) -> bool:
	if (rain == Rain.RAIN_ONLY and not raining) or (rain == Rain.DRY_ONLY and raining):
		return false
	if biome >= 0 and not biomes.is_empty() and not biomes.has(biome as ClimateData.BiomeZone):
		return false
	if not lures.is_empty() and (lure == null or not lures.any(func(wanted: Item) -> bool: return wanted.is_same(lure))):
		return false
	if lure == null and bare_hook_chance <= 0.0:
		return false
	if from_hour <= to_hour:
		return hour >= from_hour and hour < to_hour
	return hour >= from_hour or hour < to_hour


## Its share of the bites with [param lure] on the line (null for a bare hook), for the water's weighted pick.
func bite_weight(lure: Item = null) -> float:
	return weight * (bare_hook_chance if lure == null else 1.0)


## Metres from the float within which a shadow comes over with [param lure] on the line: bait can stretch
## [member attract_range], a bare hook shrinks it by [member bare_hook_chance], so that bite comes from a fish you never saw.
func attract_range_for(lure: Item = null) -> float:
	if lure == null:
		return attract_range * bare_hook_chance
	var bait: Lure = lure as Lure
	return attract_range + (bait.attract_range_bonus if bait else 0.0)


## Length in centimetres for one catch; junk has none.
func roll_length() -> float:
	return 0.0 if is_junk else snappedf(randf_range(min_length_cm, max_length_cm), 0.1)


## The inventory tints the shared fish icon with the species' colour.
func get_icon_color() -> Color:
	return color


## The lengths in the bag, biggest first with a star on the record, for the inventory entry under the description.
func get_details(owner: Node) -> String:
	var log: FishingLog = owner.get_node_or_null(^"FishingLog") as FishingLog if owner else null
	if log == null or is_junk:
		return ""
	var lines: PackedStringArray = []
	var record: float = log.record_of(self)
	var lengths: Array[float] = log.lengths_of(self)
	lengths.sort()
	lengths.reverse()
	for length: float in lengths:
		lines.append("%.1f cm%s" % [length, " *" if is_equal_approx(length, record) else ""])
	if lines.is_empty():
		return ""
	return "In the bag:\n" + "\n".join(lines) + "\n* record catch"


## The inventory preview and the fish index show the species at its base size.
func prepare_model(model: Node3D) -> void:
	dress_model(model, FishModel.BASE_LENGTH_CM)


## Makes an instanced model this fish at [param length_cm]: the placeholder takes the colour and the scale, a
## real model is scaled so its longest axis is that length and swims its first animation if it has one.
func dress_model(model: Node3D, length_cm: float) -> void:
	if model is FishModel:
		(model as FishModel).setup(self, length_cm)
		return
	var bounds: AABB = AABB()
	var first: bool = true
	for geometry: Node in model.find_children("*", "GeometryInstance3D", true, false):
		var visual: GeometryInstance3D = geometry as GeometryInstance3D
		var box: AABB = (model.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var longest: float = bounds.get_longest_axis_size()
	if not first and longest > 0.001:
		model.scale = Vector3.ONE * (length_cm / 100.0 / longest)
	for animator: Node in model.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = animator as AnimationPlayer
		var clips: PackedStringArray = player.get_animation_list()
		if not clips.is_empty():
			player.get_animation(clips[0]).loop_mode = Animation.LOOP_LINEAR
			player.play(clips[0])


## A species without a model of its own shows the shared placeholder fish, as the catch does.
func get_model_scene() -> PackedScene:
	return model_scene if model_scene else load("res://scenes/fish_model.tscn")


## Plain lines describing when and how it bites, for the fish index.
func describe_conditions() -> PackedStringArray:
	var lines: PackedStringArray = []
	if is_junk:
		lines.append("Not a fish. %s, any time." % ("Bites on anything" if lures.is_empty() else "Only takes: " + ", ".join(_lure_names())))
		if mass_kg > 0.0:
			lines.append("Weighs %.1f kg" % mass_kg)
		return lines
	lines.append("%d to %d cm" % [roundi(min_length_cm), roundi(max_length_cm)])
	if from_hour == 0 and to_hour == 24:
		lines.append("Any hour")
	else:
		lines.append("From %02d:00 to %02d:00" % [from_hour, to_hour])
	match rain:
		Rain.RAIN_ONLY:
			lines.append("Only in the rain")
		Rain.DRY_ONLY:
			lines.append("Only in dry weather")
	if not lures.is_empty():
		lines.append("Only takes: " + ", ".join(_lure_names()))
	elif bare_hook_chance >= 1.0:
		lines.append("Takes any bait, or a bare hook")
	elif bare_hook_chance > 0.0:
		lines.append("Takes any bait; hardly ever a bare hook")
	else:
		lines.append("Takes any bait, never a bare hook")
	if not biomes.is_empty():
		var places: PackedStringArray = []
		for biome: ClimateData.BiomeZone in biomes:
			places.append(ClimateData.get_biome_display_name(biome))
		lines.append("Found in: " + ", ".join(places))
	return lines


func _lure_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for wanted: Item in lures:
		names.append(wanted.get_display_name())
	return names

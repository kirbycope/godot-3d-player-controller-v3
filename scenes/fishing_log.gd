class_name FishingLog
extends Node
## What the Player has landed: the lengths of the fish still in the bag, oldest first, and the record length
## per species. Sits on the Player next to the inventory; the rod records catches, the inventory's use and
## drop signals take lengths back out, and with [member persist] on it survives a restart in a ConfigFile.

signal changed ## A catch was logged or a fish left the bag.

@export var persist: bool = false ## Save to [member save_path] on every change and load it on ready.
@export var save_path: String = "user://fishing_log.cfg"

var records: Dictionary[StringName, float] = {} ## Species id -> longest ever landed.
var held: Dictionary[StringName, Array] = {} ## Species id -> lengths in the bag, oldest first.


func _ready() -> void:
	if persist:
		load_log()
	var player: Player = get_parent() as Player
	if player == null:
		return
	if player.is_node_ready():
		_watch_inventory(player)
	else:
		player.ready.connect(_watch_inventory.bind(player), CONNECT_ONE_SHOT)


func _watch_inventory(player: Player) -> void:
	if player.inventory:
		player.inventory.item_used.connect(_on_item_gone)
		player.inventory.item_dropped.connect(func(item: Item, count: int, _pickup: Node) -> void: _on_item_gone(item, count))


## Logs a landed fish; true when it is the biggest of its kind so far. Junk is logged as found (so the index shows
## it) but never as a record, and its lengths are not kept.
func record_catch(fish: Fish, length_cm: float) -> bool:
	var id: StringName = fish.get_id()
	if fish.is_junk:
		if not records.has(id):
			records[id] = 0.0
			_changed()
		return false
	var is_record: bool = length_cm > records.get(id, 0.0)
	if is_record:
		records[id] = length_cm
	if not held.has(id):
		held[id] = []
	held[id].append(length_cm)
	_changed()
	return is_record


## Lengths of this species in the bag, oldest first.
func lengths_of(fish: Fish) -> Array[float]:
	var lengths: Array[float] = []
	lengths.assign(held.get(fish.get_id(), []))
	return lengths


## The longest ever landed, or 0 for a species never caught.
func record_of(fish: Fish) -> float:
	return records.get(fish.get_id(), 0.0)


func has_caught(fish: Fish) -> bool:
	return records.has(fish.get_id())


## Eating or dropping takes the oldest lengths out of the bag.
func _on_item_gone(item: Item, count: int) -> void:
	var fish: Fish = item as Fish
	if fish == null or not held.has(fish.get_id()):
		return
	var lengths: Array = held[fish.get_id()]
	for i: int in mini(count, lengths.size()):
		lengths.pop_front()
	_changed()


func _changed() -> void:
	if persist:
		save_log()
	changed.emit()


func save_log() -> void:
	var file: ConfigFile = ConfigFile.new()
	for id: StringName in records:
		file.set_value("records", id, records[id])
	for id: StringName in held:
		file.set_value("held", id, PackedFloat32Array(held[id]))
	file.save(save_path)


func load_log() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(save_path) != OK:
		return
	records.clear()
	held.clear()
	for key: String in file.get_section_keys("records") if file.has_section("records") else PackedStringArray():
		records[StringName(key)] = float(file.get_value("records", key))
	for key: String in file.get_section_keys("held") if file.has_section("held") else PackedStringArray():
		held[StringName(key)] = Array(file.get_value("held", key))

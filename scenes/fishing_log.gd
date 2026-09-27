class_name FishingLog
extends Node
## What the Player has landed: the lengths of the fish still in the bag, oldest first, and the record length
## per species. Sits on the Player next to the inventory; the rod records catches, the inventory's use and
## drop signals take lengths back out, and it is Saveable, so a [SaveGame] keeps it in the numbered save with the
## bag: a New Game starts with an empty log and Continue brings it back.

signal changed ## A catch was logged or a fish left the bag.

var records: Dictionary[StringName, float] = {} ## Species id -> longest ever landed.
var held: Dictionary[StringName, Array] = {} ## Species id -> lengths in the bag, oldest first.


func _ready() -> void:
	add_to_group(SaveGame.GROUP)


## What a [SaveGame] keeps: the records and the lengths in the bag, keyed by species id.
func save_state() -> Dictionary:
	var state_held: Dictionary = {}
	for id: StringName in held:
		state_held[String(id)] = held[id].duplicate()
	var state_records: Dictionary = {}
	for id: StringName in records:
		state_records[String(id)] = records[id]
	return {"records": state_records, "held": state_held}


## Puts a [method save_state] back, replacing whatever was logged.
func load_state(state: Dictionary) -> void:
	records.clear()
	held.clear()
	var saved_records: Dictionary = state.get("records", {})
	for id: String in saved_records:
		records[StringName(id)] = float(saved_records[id])
	var saved_held: Dictionary = state.get("held", {})
	for id: String in saved_held:
		var lengths: Array = []
		for length: Variant in saved_held[id]:
			lengths.append(float(length))
		held[StringName(id)] = lengths
	changed.emit()


## A carried fish was dropped (the Inventory's item_dropped is connected here in the scene): it leaves the log's count.
func _on_item_dropped(item: Item, count: int, _pickup: Node) -> void:
	_on_item_gone(item, count)


## Logs a landed fish; true when it is the biggest of its kind so far. Its length joins the bag's only when
## [param in_bag] (a full tab leaves the catch out of the inventory); the record counts either way. Junk is logged as
## found (so the index shows it) but never as a record, and its lengths are not kept.
func record_catch(fish: Fish, length_cm: float, in_bag: bool = true) -> bool:
	var id: StringName = fish.get_id()
	if fish.is_junk:
		if not records.has(id):
			records[id] = 0.0
			_changed()
		return false
	var is_record: bool = length_cm > records.get(id, 0.0)
	if is_record:
		records[id] = length_cm
	if in_bag:
		if not held.has(id):
			held[id] = []
		held[id].append(length_cm)
	_changed()
	var player: Player = get_parent() as Player
	if player and player.quest_log:
		player.quest_log.progress(&"catch_fish")
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
	changed.emit()


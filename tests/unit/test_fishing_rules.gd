extends GutTest

## Purpose: The fishing data rules: biome filtering on Fish, bait effects on Lure, the fishing log's records and
## bag lengths, the details fish print in the inventory, and the fish index conditions text.

const CATFISH: Fish = preload("res://resources/fish/catfish.tres")
const CARP: Fish = preload("res://resources/fish/carp.tres")
const BOOT: Fish = preload("res://resources/fish/old_boot.tres")
const WORM: Lure = preload("res://resources/lures/worm.tres")
const CHUM: Lure = preload("res://resources/lures/chum.tres")
const LOG_SCRIPT = preload("res://scenes/fishing_log.gd")


func test_fish_respects_the_waters_biome() -> void:
	assert_true(CATFISH.is_available(22, false, WORM, ClimateData.BiomeZone.TEMPERATE_PLAINS), "The pool's biome is listed")
	assert_false(CATFISH.is_available(22, false, WORM, ClimateData.BiomeZone.DESERT_DUNES), "A desert pool has no catfish")
	assert_true(CATFISH.is_available(22, false, WORM, -1), "Water in no zone holds every fish")
	assert_true(BOOT.is_available(12, false, null, ClimateData.BiomeZone.DESERT_DUNES), "An empty biome list means anywhere")


func test_fish_carry_an_attract_range() -> void:
	assert_eq(CATFISH.attract_range, 0.8)
	assert_eq(Fish.new().attract_range, 1.0, "One metre by default")


func test_chum_is_consumable_bait_with_effects() -> void:
	assert_true(CHUM.consumable)
	assert_eq(CHUM.bite_time_scale, 0.5)
	assert_eq(CHUM.attract_range_bonus, 1.5)
	var effects := CHUM.describe_effects()
	assert_true("Bites come 50% sooner" in effects)
	assert_true("Draws shadows from 1.5 m further" in effects)
	assert_true("Eaten with each bite" in effects)
	assert_true(WORM.describe_effects().is_empty(), "A plain worm has nothing to add")


func test_fishing_log_records_and_bag() -> void:
	var log: FishingLog = LOG_SCRIPT.new()
	add_child_autofree(log)
	assert_true(log.record_catch(CARP, 30.0), "The first catch is the record")
	assert_false(log.record_catch(CARP, 25.0))
	assert_true(log.record_catch(CARP, 45.5))
	assert_eq(log.record_of(CARP), 45.5)
	assert_eq(log.lengths_of(CARP), [30.0, 25.0, 45.5])
	assert_true(log.has_caught(CARP))
	assert_false(log.has_caught(CATFISH))
	assert_false(log.record_catch(BOOT, 0.0), "Junk is not logged")
	log._on_item_gone(CARP, 2)
	assert_eq(log.lengths_of(CARP), [45.5], "Eating takes the oldest out of the bag")
	assert_eq(log.record_of(CARP), 45.5, "The record stays")


func test_fish_details_list_the_bag_with_a_star_on_the_record() -> void:
	var owner := Node.new()
	add_child_autofree(owner)
	var log: FishingLog = LOG_SCRIPT.new()
	log.name = "FishingLog"
	owner.add_child(log)
	assert_eq(CARP.get_details(owner), "", "Nothing in the bag, nothing to list")
	log.record_catch(CARP, 30.0)
	log.record_catch(CARP, 52.3)
	var details := CARP.get_details(owner)
	assert_true(details.begins_with("In the bag:\n52.3 cm *\n30.0 cm"), details)
	assert_true(details.ends_with("* record catch"))


func test_fishing_log_saves_and_loads() -> void:
	var log: FishingLog = LOG_SCRIPT.new()
	log.persist = true
	log.save_path = "user://test_fishing_log.cfg"
	add_child_autofree(log)
	log.record_catch(CARP, 33.0)
	var other: FishingLog = LOG_SCRIPT.new()
	other.save_path = log.save_path
	add_child_autofree(other)
	other.load_log()
	assert_eq(other.record_of(CARP), 33.0)
	assert_eq(other.lengths_of(CARP), [33.0])
	DirAccess.remove_absolute(log.save_path)


func test_conditions_describe_the_resource() -> void:
	var lines := CATFISH.describe_conditions()
	assert_true("40 to 90 cm" in lines)
	assert_true("From 20:00 to 05:00" in lines)
	assert_true("Only takes: Worm" in lines)
	var found := false
	for line in lines:
		if line.begins_with("Found in: Temperate Plains"):
			found = true
	assert_true(found, "The biomes are listed by name")
	assert_eq(BOOT.describe_conditions()[0], "Not a fish. Bites on anything, any time.")

extends GutTest

## GUT Unit tests for RadioStation and RadioStationCollection.

const KEXP_PATH: String = "res://addons/radi_ot/resources/stations/kexp_90_3.tres"
const C895_PATH: String = "res://addons/radi_ot/resources/stations/c89_5.tres"
const DEFAULT_COLLECTION_PATH: String = (
	"res://addons/radi_ot/resources/stations/seattle_stations_default.tres"
)


func test_kexp_station_resource() -> void:
	var kexp: Resource = load(KEXP_PATH)
	assert_not_null(kexp, "KEXP resource should load successfully")
	assert_is(kexp, RadioStation, "KEXP resource should be a RadioStation instance")

	var station: RadioStation = kexp as RadioStation
	assert_eq(station.call_sign, "KEXP", "Call sign should be KEXP")
	assert_almost_eq(station.frequency, 90.3, 0.01, "Frequency should be 90.3")
	assert_eq(station.get_display_frequency(), "90.3 MHz", "Formatted display frequency")
	assert_false(station.stream_url.is_empty(), "Stream URL should not be empty")
	assert_true(station.get_full_title().begins_with("KEXP"), "Full title should begin with call sign")
	assert_not_null(station.logo, "KEXP logo should not be null")
	assert_is(station.logo, Texture2D, "KEXP logo should be a Texture2D")


func test_c895_station_resource() -> void:
	var c895: Resource = load(C895_PATH)
	assert_not_null(c895, "C89.5 resource should load successfully")
	assert_is(c895, RadioStation, "C89.5 resource should be a RadioStation instance")

	var station: RadioStation = c895 as RadioStation
	assert_eq(station.call_sign, "C89.5", "Call sign should be C89.5")
	assert_almost_eq(station.frequency, 89.5, 0.01, "Frequency should be 89.5")
	assert_eq(station.get_display_frequency(), "89.5 MHz", "Formatted display frequency")
	assert_false(station.stream_url.is_empty(), "Stream URL should not be empty")
	assert_not_null(station.logo, "C89.5 logo should not be null")
	assert_is(station.logo, Texture2D, "C89.5 logo should be a Texture2D")


func test_all_station_resources_in_folder() -> void:
	var dir := DirAccess.open("res://addons/radi_ot/resources/stations")
	assert_not_null(dir, "Stations resource directory should exist and open")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var station_count: int = 0

	while file_name != "":
		if file_name.ends_with(".tres") and "collection" not in file_name and "default" not in file_name:
			var path: String = "res://addons/radi_ot/resources/stations/" + file_name
			var res: Resource = load(path)
			assert_not_null(res, "Resource %s should load" % file_name)
			if res is RadioStation:
				var station: RadioStation = res as RadioStation
				assert_false(station.call_sign.is_empty(), "%s call sign should not be empty" % file_name)
				assert_gt(station.frequency, 0.0, "%s frequency should be positive" % file_name)
				assert_false(station.stream_url.is_empty(), "%s stream URL should not be empty" % file_name)
				assert_not_null(station.logo, "%s should have a logo assigned" % file_name)
				station_count += 1
		file_name = dir.get_next()

	assert_gte(station_count, 5, "Should have loaded at least 5 Seattle radio station resources")


func test_default_station_collection() -> void:
	var collection_res: Resource = load(DEFAULT_COLLECTION_PATH)
	assert_not_null(collection_res, "Default Seattle station collection should load")
	assert_is(collection_res, RadioStationCollection, "Collection should be a RadioStationCollection instance")

	var collection: RadioStationCollection = collection_res as RadioStationCollection
	assert_gte(collection.get_station_count(), 5, "Collection should have at least 5 stations")

	var first_station: RadioStation = collection.get_station_at(0)
	assert_not_null(first_station, "First station in collection should not be null")
	assert_eq(first_station.call_sign, "KEXP", "First station in collection should be KEXP")


func test_collection_wrap_around_indexing() -> void:
	var collection: RadioStationCollection = load(DEFAULT_COLLECTION_PATH) as RadioStationCollection
	assert_not_null(collection, "Collection should not be null")

	var count: int = collection.get_station_count()
	var station_0: RadioStation = collection.get_station_at(0)
	var station_wrapped: RadioStation = collection.get_station_at(count)
	assert_eq(station_wrapped, station_0, "Index count should wrap around to index 0")

	var last_station: RadioStation = collection.get_station_at(count - 1)
	var station_neg: RadioStation = collection.get_station_at(-1)
	assert_eq(station_neg, last_station, "Index -1 should wrap around to the last station")


func test_collection_find_by_call_sign() -> void:
	var collection: RadioStationCollection = load(DEFAULT_COLLECTION_PATH) as RadioStationCollection
	assert_not_null(collection, "Collection should not be null")

	var idx_kexp: int = collection.find_station_by_call_sign("KEXP")
	assert_eq(idx_kexp, 0, "Find KEXP should return index 0")

	# Test case-insensitivity and whitespace tolerance
	var idx_lower: int = collection.find_station_by_call_sign("  c89.5  ")
	assert_eq(idx_lower, 1, "Find '  c89.5  ' should return index 1")

	var idx_non_existent: int = collection.find_station_by_call_sign("NON_EXISTENT_STATION")
	assert_eq(idx_non_existent, -1, "Non-existent call sign should return -1")


func test_collection_find_closest_by_frequency() -> void:
	var collection: RadioStationCollection = load(DEFAULT_COLLECTION_PATH) as RadioStationCollection
	assert_not_null(collection, "Collection should not be null")

	var idx_exact: int = collection.find_closest_station_by_frequency(90.3)
	var station_exact: RadioStation = collection.get_station_at(idx_exact)
	assert_eq(station_exact.call_sign, "KEXP", "Closest to 90.3 MHz should be KEXP")

	var idx_kuow: int = collection.find_closest_station_by_frequency(95.0)
	var station_kuow: RadioStation = collection.get_station_at(idx_kuow)
	assert_eq(station_kuow.call_sign, "KUOW", "Closest to 95.0 MHz should be KUOW (94.9)")


func test_empty_collection_handling() -> void:
	var empty_collection: RadioStationCollection = RadioStationCollection.new()
	assert_eq(empty_collection.get_station_count(), 0, "Empty collection count is 0")
	assert_null(empty_collection.get_station_at(0), "Empty collection get_station_at returns null")
	assert_eq(empty_collection.find_station_by_call_sign("KEXP"), -1, "Empty collection find call sign is -1")
	assert_eq(empty_collection.find_closest_station_by_frequency(90.3), -1, "Empty collection find frequency is -1")

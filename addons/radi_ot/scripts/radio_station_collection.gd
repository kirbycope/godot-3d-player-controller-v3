@tool
class_name RadioStationCollection
extends Resource

## Collection container holding an ordered list of RadioStation resources.

@export var stations: Array[RadioStation] = []


func get_station_count() -> int:
	return stations.size()


func get_station_at(index: int) -> RadioStation:
	if stations.is_empty():
		return null
	var clamped_index: int = posmod(index, stations.size())
	return stations[clamped_index]


func find_station_by_call_sign(call_sign: String) -> int:
	var target_sign: String = call_sign.to_upper().strip_edges()
	for i in range(stations.size()):
		var station: RadioStation = stations[i]
		if station and station.call_sign.to_upper().strip_edges() == target_sign:
			return i
	return -1


func find_closest_station_by_frequency(frequency: float) -> int:
	if stations.is_empty():
		return -1
	var closest_index: int = 0
	var min_diff: float = 999999.0
	for i in range(stations.size()):
		var station: RadioStation = stations[i]
		if station:
			var diff: float = absf(station.frequency - frequency)
			if diff < min_diff:
				min_diff = diff
				closest_index = i
	return closest_index

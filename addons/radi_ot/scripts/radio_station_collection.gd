@tool
class_name RadioStationCollection
extends Resource

## Collection container holding an ordered list of RadioStation resources.

@export var stations: Array[RadioStation] = []


func get_station_count() -> int:
	return stations.size()


## Returns the station at `index`, or null when out of range (RadiOtPlayer3D handles wrap-around).
func get_station_at(index: int) -> RadioStation:
	if index < 0 or index >= stations.size():
		return null
	return stations[index]


func find_station_by_call_sign(call_sign: String) -> int:
	var target_sign: String = call_sign.to_upper().strip_edges()
	for i: int in stations.size():
		if stations[i] != null and stations[i].call_sign.to_upper().strip_edges() == target_sign:
			return i
	return -1


func find_closest_station_by_frequency(frequency: float) -> int:
	var closest_index: int = -1
	var min_diff: float = INF
	for i: int in stations.size():
		if stations[i] != null and absf(stations[i].frequency - frequency) < min_diff:
			min_diff = absf(stations[i].frequency - frequency)
			closest_index = i
	return closest_index

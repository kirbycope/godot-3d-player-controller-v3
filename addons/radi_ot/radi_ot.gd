@tool
extends EditorPlugin

## Radi-ot plugin editor integration.
## Registers custom types and nodes for 3D radio streaming.


func _enter_tree() -> void:
	add_custom_type(
		"RadiOtPlayer3D",
		"AudioStreamPlayer3D",
		preload("res://addons/radi_ot/scripts/radi_ot_player_3d.gd"),
		preload("res://addons/radi_ot/assets/icons/radio_icon.svg")
	)
	add_custom_type(
		"RadioStation",
		"Resource",
		preload("res://addons/radi_ot/scripts/radio_station.gd"),
		preload("res://addons/radi_ot/assets/icons/radio_icon.svg")
	)
	add_custom_type(
		"RadioStationCollection",
		"Resource",
		preload("res://addons/radi_ot/scripts/radio_station_collection.gd"),
		preload("res://addons/radi_ot/assets/icons/radio_icon.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("RadiOtPlayer3D")
	remove_custom_type("RadioStation")
	remove_custom_type("RadioStationCollection")

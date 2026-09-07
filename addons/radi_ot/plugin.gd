# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
extends EditorPlugin

## Radi-ot plugin editor integration. RadiOtPlayer3D ships as a scene
## (scenes/radi_ot_player_3d.tscn) and is not registered as a bare custom node.


func _enter_tree() -> void:
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
	remove_custom_type("RadioStation")
	remove_custom_type("RadioStationCollection")

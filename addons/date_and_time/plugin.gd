# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"DateAndTime",
		"Node",
		preload("res://addons/date_and_time/scripts/date_and_time.gd"),
		preload("res://addons/date_and_time/assets/icons/date_and_time_icon.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("DateAndTime")

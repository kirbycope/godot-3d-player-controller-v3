# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
extends EditorPlugin


func _enter_tree() -> void:
	var icon = preload("res://addons/date_and_time/icons/date_and_time_icon.svg")
	add_custom_type("DateAndTime", "Node", preload("res://addons/date_and_time/date_and_time.gd"), icon)
	add_custom_type("DateAndTimeDisplay", "PanelContainer", preload("res://addons/date_and_time/date_and_time_display.gd"), icon)


func _exit_tree() -> void:
	remove_custom_type("DateAndTime")
	remove_custom_type("DateAndTimeDisplay")

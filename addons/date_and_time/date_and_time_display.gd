# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name DateAndTimeDisplay
extends PanelContainer

## Optional HUD widget that connects to a DateAndTime node and displays the live time and date.

@export var date_and_time_node: DateAndTime :
	set(value):
		if date_and_time_node != value:
			if date_and_time_node and date_and_time_node.time_changed.is_connected(_on_time_changed):
				date_and_time_node.time_changed.disconnect(_on_time_changed)
			date_and_time_node = value
			if date_and_time_node:
				date_and_time_node.time_changed.connect(_on_time_changed)
				_update_display()

@export var show_date: bool = true :
	set(value):
		show_date = value
		_update_display()

@export var show_seconds: bool = false :
	set(value):
		show_seconds = value
		_update_display()

@export var use_12_hour: bool = false :
	set(value):
		use_12_hour = value
		_update_display()

var _label: Label


func _ready() -> void:
	_setup_ui()
	if date_and_time_node == null:
		# Search parent or scene root
		var found = get_tree().root.find_child("DateAndTime", true, false)
		if found is DateAndTime:
			date_and_time_node = found
	_update_display()


func _setup_ui() -> void:
	if _label == null:
		_label = Label.new()
		_label.name = "TimeLabel"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)


func _on_time_changed(_time: float) -> void:
	_update_display()


func _update_display() -> void:
	if _label == null:
		return
	if date_and_time_node == null:
		_label.text = "--:--"
		return

	var h = date_and_time_node.get_hour()
	var m = date_and_time_node.get_minute()
	var s = date_and_time_node.get_second()

	var time_str = ""
	if use_12_hour:
		var am_pm = "AM" if h < 12 else "PM"
		var display_h = h % 12
		if display_h == 0: display_h = 12
		if show_seconds:
			time_str = "%02d:%02d:%02d %s" % [display_h, m, s, am_pm]
		else:
			time_str = "%02d:%02d %s" % [display_h, m, am_pm]
	else:
		if show_seconds:
			time_str = "%02d:%02d:%02d" % [h, m, s]
		else:
			time_str = "%02d:%02d" % [h, m]

	if show_date:
		_label.text = "%s  %s" % [date_and_time_node.get_formatted_date(), time_str]
	else:
		_label.text = time_str

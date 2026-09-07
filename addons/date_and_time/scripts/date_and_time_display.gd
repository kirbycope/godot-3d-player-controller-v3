# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name DateAndTimeDisplay
extends PanelContainer

## HUD widget that shows the time and date of an assigned DateAndTime node, either in
## Zelda: Breath of the Wild styling (RichTextLabel) or as a plain Label.
## Instantiate res://addons/date_and_time/scenes/date_and_time_display.tscn.

@export_group("Node References")
@export var date_and_time_node: DateAndTime:
	set(value):
		if date_and_time_node == value:
			return
		if is_instance_valid(date_and_time_node):
			date_and_time_node.time_changed.disconnect(_on_time_changed)
		date_and_time_node = value
		if date_and_time_node != null:
			date_and_time_node.time_changed.connect(_on_time_changed)
		_update_display()

@export_group("Display Settings")
@export var botw_style: bool = true:
	set(value):
		botw_style = value
		if is_node_ready():
			_botw_box.visible = botw_style
			_standard_label.visible = not botw_style

@export var minute_increment: int = 5:
	set(value):
		minute_increment = maxi(0, value)
		_update_display()

@export var use_12_hour: bool = true:
	set(value):
		use_12_hour = value
		_update_display()

@export var show_date: bool = false:
	set(value):
		show_date = value
		_update_display()

@export var show_seconds: bool = false:
	set(value):
		show_seconds = value
		_update_display()

@export var show_down_arrow: bool = true:
	set(value):
		show_down_arrow = value
		if is_node_ready():
			_down_arrow.visible = show_down_arrow

@onready var _botw_box: VBoxContainer = %BotwBox
@onready var _rich_label: RichTextLabel = %TimeRichLabel
@onready var _down_arrow: TextureRect = %DownArrow
@onready var _standard_label: Label = %TimeLabel


func _ready() -> void:
	_botw_box.visible = botw_style
	_standard_label.visible = not botw_style
	_down_arrow.visible = show_down_arrow
	_update_display()


## The text currently shown, formatted per the display settings ("--:--" without a clock).
func get_display_text() -> String:
	if date_and_time_node == null:
		return "--:--"
	var h: int = date_and_time_node.get_hour()
	var m: int = date_and_time_node.get_minute()
	var s: int = date_and_time_node.get_second()
	if minute_increment > 1:
		m = (m / minute_increment) * minute_increment
	var time_str: String
	if use_12_hour:
		var display_h: int = 12 if h % 12 == 0 else h % 12
		if botw_style:
			time_str = "%d:%02d:%02d" % [display_h, m, s] if show_seconds else "%d:%02d" % [display_h, m]
		else:
			var am_pm: String = "AM" if h < 12 else "PM"
			time_str = "%02d:%02d:%02d %s" % [display_h, m, s, am_pm] if show_seconds else "%02d:%02d %s" % [display_h, m, am_pm]
	else:
		time_str = "%02d:%02d:%02d" % [h, m, s] if show_seconds else "%02d:%02d" % [h, m]
	if show_date:
		return "%s  %s" % [date_and_time_node.get_formatted_date(), time_str]
	return time_str


func _on_time_changed(_time: float) -> void:
	_update_display()


func _update_display() -> void:
	if not is_node_ready():
		return
	var text: String = get_display_text()
	_rich_label.text = "[i]%s[/i]" % text
	_standard_label.text = text

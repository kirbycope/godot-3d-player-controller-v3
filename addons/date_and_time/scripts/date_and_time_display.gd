# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

@tool
class_name DateAndTimeDisplay
extends PanelContainer

## HUD widget that connects to a DateAndTime node and displays the live time and date
## in Zelda: Breath of the Wild styling with customizable rounding and styling options.

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const COLOR_CYAN: Color = Color(0.565, 0.843, 0.929, 1.0)
const COLOR_OUTLINE: Color = Color(0.0, 0.541, 0.682, 1.0)
const COLOR_SHADOW: Color = Color(0.0, 0.541, 0.682, 0.275)
const DOWN_ARROW_TEXTURE_PATH: String = "res://addons/date_and_time/assets/icons/down_arrow.svg"
const ITALIC_FONT_PATH: String = "res://assets/fonts/Rodin-Italic.ttf"

# ------------------------------------------------------------------------------
# Exported Groups: Node References
# ------------------------------------------------------------------------------
@export_group("Node References")
@export var date_and_time_node: DateAndTime:
	set(value):
		if date_and_time_node != value:
			if date_and_time_node and date_and_time_node.time_changed.is_connected(_on_time_changed):
				date_and_time_node.time_changed.disconnect(_on_time_changed)
			date_and_time_node = value
			if date_and_time_node:
				date_and_time_node.time_changed.connect(_on_time_changed)
				_update_display()

# ------------------------------------------------------------------------------
# Exported Groups: Display Settings
# ------------------------------------------------------------------------------
@export_group("Display Settings")
@export var botw_style: bool = true:
	set(value):
		botw_style = value
		_rebuild_ui()
		_update_display()

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
		if _arrow_rect:
			_arrow_rect.visible = show_down_arrow and botw_style
		_update_display()

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _rtl: RichTextLabel
var _standard_label: Label
var _vbox: VBoxContainer
var _arrow_rect: TextureRect


# ------------------------------------------------------------------------------
# Virtual Callbacks
# ------------------------------------------------------------------------------
func _ready() -> void:
	_setup_ui()
	if date_and_time_node == null:
		var found: Node = get_tree().root.find_child("DateAndTime", true, false)
		if found is DateAndTime:
			date_and_time_node = found
	_update_display()


# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _rebuild_ui() -> void:
	for child in get_children():
		child.queue_free()
	_rtl = null
	_standard_label = null
	_vbox = null
	_arrow_rect = null
	_setup_ui()


func _setup_ui() -> void:
	if botw_style:
		var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
		add_theme_stylebox_override("panel", empty_style)

		if _vbox == null:
			_vbox = VBoxContainer.new()
			_vbox.name = "VBox"
			_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			_vbox.add_theme_constant_override("separation", 2)
			add_child(_vbox)

		if _rtl == null:
			_rtl = RichTextLabel.new()
			_rtl.name = "TimeRichLabel"
			_rtl.bbcode_enabled = true
			_rtl.fit_content = true
			_rtl.scroll_active = false
			_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
			_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_rtl.custom_minimum_size = Vector2(48, 20)

			_rtl.add_theme_color_override("default_color", COLOR_CYAN)
			_rtl.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
			_rtl.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
			_rtl.add_theme_constant_override("outline_size", 1)
			_rtl.add_theme_constant_override("shadow_outline_size", 1)
			_rtl.add_theme_font_size_override("italics_font_size", 14)
			_rtl.add_theme_font_size_override("normal_font_size", 14)

			if ResourceLoader.exists(ITALIC_FONT_PATH):
				var font_res: Font = load(ITALIC_FONT_PATH) as Font
				if font_res:
					_rtl.add_theme_font_override("italics_font", font_res)
					_rtl.add_theme_font_override("normal_font", font_res)

			_vbox.add_child(_rtl)

		if _arrow_rect == null:
			_arrow_rect = TextureRect.new()
			_arrow_rect.name = "DownArrow"
			_arrow_rect.custom_minimum_size = Vector2(8, 6)
			_arrow_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_arrow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_arrow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_arrow_rect.modulate = COLOR_CYAN

			if ResourceLoader.exists(DOWN_ARROW_TEXTURE_PATH):
				_arrow_rect.texture = load(DOWN_ARROW_TEXTURE_PATH)

			_arrow_rect.visible = show_down_arrow
			_vbox.add_child(_arrow_rect)
	else:
		remove_theme_stylebox_override("panel")
		if _standard_label == null:
			_standard_label = Label.new()
			_standard_label.name = "TimeLabel"
			_standard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_standard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(_standard_label)


func _on_time_changed(_time: float) -> void:
	_update_display()


func _update_display() -> void:
	if botw_style and _rtl == null:
		return
	if not botw_style and _standard_label == null:
		return

	if date_and_time_node == null:
		if botw_style:
			_rtl.text = "[i]--:--[/i]"
		else:
			_standard_label.text = "--:--"
		return

	var h: int = date_and_time_node.get_hour()
	var m: int = date_and_time_node.get_minute()
	var s: int = date_and_time_node.get_second()

	if minute_increment > 1:
		m = (m / minute_increment) * minute_increment

	var time_str: String = ""
	if use_12_hour:
		var display_h: int = h % 12
		if display_h == 0:
			display_h = 12

		if botw_style:
			# BotW format: 12-hour without AM/PM text suffix
			if show_seconds:
				time_str = "%d:%02d:%02d" % [display_h, m, s]
			else:
				time_str = "%d:%02d" % [display_h, m]
		else:
			var am_pm: String = "AM" if h < 12 else "PM"
			if show_seconds:
				time_str = "%02d:%02d:%02d %s" % [display_h, m, s, am_pm]
			else:
				time_str = "%02d:%02d %s" % [display_h, m, am_pm]
	else:
		if show_seconds:
			time_str = "%02d:%02d:%02d" % [h, m, s]
		else:
			time_str = "%02d:%02d" % [h, m]

	if botw_style:
		if show_date:
			_rtl.text = "[i]%s  %s[/i]" % [date_and_time_node.get_formatted_date(), time_str]
		else:
			_rtl.text = "[i]%s[/i]" % time_str
	else:
		if show_date:
			_standard_label.text = "%s  %s" % [date_and_time_node.get_formatted_date(), time_str]
		else:
			_standard_label.text = time_str

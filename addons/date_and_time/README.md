# Date and Time Addon for Godot 4.8+

In-game and in-editor date, time, and calendar progression system with full `@tool` controls, leap year logic, custom time scale, and Godot signals.

> [!NOTE]
> **Plugin Activation vs Scene Usage**:
> All core scripts use `class_name` (`DateAndTime`, `DateAndTimeDisplay`).
> - **Direct Usage**: You can add and use these nodes immediately in your scenes, drag `.gd` scripts, or call them via code without enabling anything in Project Settings.
> - **Enabling the Plugin**: Enabling `Date and Time` in **Project Settings > Plugins** registers the custom icon and adds the node types directly to Godot's "Create New Node" hierarchy dialog.

---

## Interactive Demo Scene

Open and run **`res://addons/date_and_time/scenes/demo/demo.tscn`** to explore time flow, day/night transitions, and calendar features:
- **Time Scrubber**: Drag the slider (0:00 to 24:00) with real-time sun/moon lighting synchronization.
- **Pace / Speed Multipliers**: Run time at 1x, 5x, 24x (1 min/day), 60x, or 300x.
- **Date & Calendar Controls**: Increment Day, Month, and Year with leap year handling.
- **Display Options**: Toggle 12h/24h format, show/hide date, and 5-min/10-min/exact minute rounding.
- **OS Clock Sync**: Toggle synchronization with real-world system time.

---

## Features
- **In-Editor & Runtime Execution (`@tool`)**: Start, stop, and scrub through time directly in the editor viewport or at runtime.
- **Customizable Day Length**: Set `minutes_per_day` (e.g. 15.0 or 24.0 real minutes for a 24h day).
- **Calendar & Leap Years**: Full Gregorian calendar wrapping with leap year calculations.
- **OS Clock Sync**: Optional `system_sync` to mirror real world time.
- **Rich Signals**: `time_changed`, `minute_changed`, `hour_changed`, `day_changed`, `month_changed`, `year_changed`.
- **UI Display Component**: Includes `DateAndTimeDisplay` panel with 12/24 hour and seconds formatting options.

---

## How to Add to Your Scene

### Scene Setup
1. (Optional) Enable `Date and Time` in **Project Settings > Plugins**.
2. Add a `DateAndTime` node to your scene (e.g. as a child of your root `Main` node).
3. In the Inspector:
   - **`Minutes Per Day`**: Adjust the length of a full 24-hour cycle in real minutes (e.g., `24.0` minutes means 1 real minute = 1 in-game hour).
   - **`Current Time`**: Set the starting hour (e.g. `8.0` for 8:00 AM, `12.0` for noon).
   - **`Is Running`**: Check to start the clock running.
4. (Optional) Add a `DateAndTimeDisplay` node under your HUD `CanvasLayer` to show a digital clock on screen.

### GDScript API Examples

```gdscript
extends Node

@onready var clock: DateAndTime = $DateAndTime

func _ready() -> void:
    clock.minute_changed.connect(_on_minute_changed)
    clock.hour_changed.connect(_on_hour_changed)
    clock.day_changed.connect(_on_day_changed)

func _on_hour_changed(new_hour: int) -> void:
    print("It is now %02d:00" % new_hour)
    if clock.is_day():
        print("Daytime")
    else:
        print("Nighttime")

# Set time directly (Hour, Minute, Second)
func set_morning() -> void:
    clock.set_time(6, 30, 0)

# Pause and resume
func pause_clock() -> void:
    clock.pause()

func resume_clock() -> void:
    clock.play()
```

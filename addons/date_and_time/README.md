# Date and Time Addon for Godot 4.8+

In-game and in-editor date, time, and calendar progression system with full `@tool` controls, leap year logic, custom time scale, and Godot signals.

> [!NOTE]
> **Plugin Activation vs Scene Usage**:
> `DateAndTime` is a script-only node (`class_name DateAndTime`); `DateAndTimeDisplay` ships as a scene.
> - **Direct Usage**: Add a `DateAndTime` node and instantiate `scenes/date_and_time_display.tscn` without enabling anything in Project Settings.
> - **Enabling the Plugin**: Enabling `Date and Time` in **Project Settings > Plugins** registers the custom icon and adds `DateAndTime` to Godot's "Create New Node" dialog.

---

## Interactive Demo Scene

Open and run **`res://addons/date_and_time/scenes/demo/demo.tscn`** to explore time flow, day/night transitions, and calendar features:
- **Time Scrubber**: Drag the slider (0:00 to 24:00) with real-time sun/moon lighting synchronization.
- **Pace / Speed Multipliers**: Run time at 1x, 5x, 24x (1 min/day), 60x, or 300x.
- **Date & Calendar Controls**: Increment Day, Month, and Year with leap year handling.
- **Display Options**: Toggle 12h/24h format, show/hide date, and 5-min/10-min/exact minute rounding.
- **OS Clock Sync**: Toggle synchronization with real-world system time.

All demo UI signals are wired in `demo.tscn`; the script only handles camera input in `_process`.

---

## Features
- **Timer-driven clock**: A child `Timer` ticks once per in-game minute (`minutes_per_day / (24 * time_scale)` real seconds, recomputed whenever those properties change). Each tick advances `current_time` by one minute and emits `time_changed`; nothing runs per frame. Paces faster than 60 ticks/s advance several minutes per tick so the clock stays accurate at 300x. While `system_sync` is on the Timer ticks once per real second and copies the OS clock, which is the only mode where seconds advance.
- **In-Editor & Runtime Execution (`@tool`)**: The Timer also runs in the editor while `editor_time_enabled` and `is_running` are true.
- **Customizable Day Length**: Set `minutes_per_day` (e.g. 15.0 or 24.0 real minutes for a 24h day) and `time_scale`.
- **Calendar & Leap Years**: Full Gregorian calendar wrapping (forward and backward across day, month and year) with leap year calculations. Changing `month` or `year` clamps `day` to the new month's length (Jan 31 -> Feb 28).
- **OS Clock Sync**: Optional `system_sync` to mirror real world time.
- **Rich Signals**: `time_changed`, `minute_changed`, `hour_changed`, `day_changed`, `month_changed`, `year_changed`, `clock_paused`, `clock_resumed`.
- **UI Display Scene**: `scenes/date_and_time_display.tscn` (`DateAndTimeDisplay`) contains both a Breath of the Wild styled `RichTextLabel` path and a plain `Label` path; `botw_style` toggles which is visible. It reformats only when the clock ticks, and `get_display_text()` returns the current text.

---

## How to Add to Your Scene

### Scene Setup

| Node | Where it goes | Set in the Inspector |
|---|---|---|
| `DateAndTime` (add a `Node`, attach `scripts/date_and_time.gd`, or pick it from Create New Node once the plugin is enabled) | Once per level, as a child of the level root | `minutes_per_day` (real minutes for a 24 h day), `time_scale`, `current_time` (start hour, `8.0` is 8:00), `day` / `month` / `year`, `is_running`, `system_sync` to mirror the OS clock, `editor_time_enabled` to let it tick in the editor |
| `DateAndTimeDisplay` (instance `scenes/date_and_time_display.tscn`) | Under your HUD `CanvasLayer` | `date_and_time_node` -> the `DateAndTime` node; `botw_style`, `use_12_hour`, `show_date`, `show_seconds`, `minute_increment` |

Minimum scene:

```text
Level (Node3D)
├── DateAndTime                                   minutes_per_day, current_time, is_running
└── HUD (CanvasLayer)
    └── DateAndTimeDisplay (date_and_time_display.tscn)   date_and_time_node
```

Anything that should react to the clock (lighting, weather, shops) connects to the `DateAndTime` signals, in the editor or in code. The Weather FX addon's `WeatherFX` node takes it directly through its `date_and_time_node` export.

### How `demo.tscn` does it

| Demo node | What it demonstrates |
|---|---|
| `DateAndTime` | The script on a plain `Node` with `minutes_per_day = 1.0`, so a whole day passes in one real minute. `demo.gd` reads its `day`, `month` and `year` into the spin boxes in `_ready()`. |
| `HUD/BottomRight/DateAndTimeDisplay` | `date_and_time_display.tscn` instanced with `date_and_time_node` pointing at `../../../DateAndTime`. |
| `DateAndTime` signals -> root | `time_changed`, `day_changed`, `month_changed`, `year_changed`, `clock_paused` and `clock_resumed` are connected in the scene to handlers that move the slider, the spin boxes and the status label. |
| `DirectionalLight3D` and `Sundial` | `_on_time_changed` rotates the sun with the hour and dims it at night, so the gnomon's shadow reads the time. |
| `HUD/ControlPanel/...` | The time slider, speed dropdown, play/pause button, date spin boxes, format / date / rounding toggles and OS sync button are connected in the scene to handlers that set `current_time`, `time_scale`, `is_running`, `day` / `month` / `year`, `system_sync` and the display's `use_12_hour`, `show_date` and `minute_increment`. |

### GDScript API Examples

```gdscript
extends Node

@onready var clock: DateAndTime = $DateAndTime
@onready var clock_display: DateAndTimeDisplay = $HUD/DateAndTimeDisplay

func _ready() -> void:
    clock.minute_changed.connect(_on_minute_changed)
    clock.hour_changed.connect(_on_hour_changed)
    clock.day_changed.connect(_on_day_changed)

func _on_hour_changed(new_hour: int) -> void:
    print("It is now %02d:00, %s" % [new_hour, "daytime" if clock.is_day() else "nighttime"])
    print(clock_display.get_display_text())

# Set time directly (Hour, Minute, Second)
func set_morning() -> void:
    clock.set_time(6, 30, 0)

# Pause and resume
func toggle_clock() -> void:
    clock.is_running = not clock.is_running
```

---

## Assets

- `assets/fonts/Rodin-Italic.ttf` — Fontworks Rodin. License not recorded — fill in.
- `assets/icons/date_and_time_icon.svg`, `assets/icons/down_arrow.svg` — Source not recorded — fill in.

---

## Testing

```powershell
& 'C:\Godot\godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://addons/date_and_time/tests -gexit
```

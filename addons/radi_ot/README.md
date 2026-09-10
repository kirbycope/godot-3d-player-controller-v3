This repository **is** that project. It uses the layout the
[Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) expects, with the addon at `addons/radi_ot/` and a
`project.godot` at the root, so you can clone it, open it in Godot and edit the addon in
place. Nothing is copied anywhere first, and the root `project.godot` is skipped as a
conflict when the asset is installed from the library.

There used to be a second Godot project under `demo/` holding a `robocopy` mirror of this
repository. It is gone: it meant the only project that mounted the addon held a throwaway
copy, so edits made there were destroyed by the next mirror.

Then open this repository in Godot.

---

## Quick Start

### 1. Add to Your Scene

Instantiate the player scene in your 3D world (the script requires its children, so a bare `RadiOtPlayer3D` node is not supported):

```text
res://addons/radi_ot/scenes/radi_ot_player_3d.tscn
```

Its children are the `RadiOtStreamer`, the static and bulletin `AudioStreamPlayer3D`s, the `BulletinTimer` and the `RadiOtHUD`; all signals between them are wired in the scene. Set `hint_text` on the HUD from the scene that binds the keys:

```gdscript
radio.get_hud().hint_text = "[J] Prev Station   [L] Next Station   [M] Power"
```

### 2. Configure & Tune

- Select the `RadiOtPlayer3D` node in the Scene tree.
- In the Inspector, verify that `station_collection` is set to `seattle_stations_default.tres` (or assign your own custom collection).
- Run the scene (`F5` or `F6`).
- Call `tune_next_station()` to go to the Next Station
  - The demo uses the [L] key to tune next station.
- Call `tune_previous_station()` to go to the Previous Station
  - The demo uses the [J] key to tune previous station.
- Call `toggle_power()` to turn the radio on or off
  - The demo uses the [M] key to toggle power.

---

## How to Use

### Nodes to add and where

| Node | Where it goes | Set in the Inspector |
|---|---|---|
| `RadiOtPlayer3D` (instance `scenes/radi_ot_player_3d.tscn`) | Under the mesh of the radio prop, so it moves with the prop and sounds from it | `station_collection` (defaults to `seattle_stations_default.tres`), `auto_play_on_ready` to tune in as soon as the scene runs, `play_static_while_buffering`; the inherited `AudioStreamPlayer3D` `max_distance` / `unit_size` for how far the radio carries |
| `RadiOtHUD` (already inside the player scene) | Nothing to add; it is the `CanvasLayer` child of the player | `toast_hide` (auto-hide the panel after `toast_hide_seconds`), `hint_text`; or `enable_hud = false` on the player to drop it |
| `RadioStation` and `RadioStationCollection` resources | `.tres` files anywhere in your project | Station fields, then assign the collection to `station_collection` |

Minimum scene:

```text
World (Node3D)
└── RadioMesh (MeshInstance3D)
    └── RadiOtPlayer3D (radi_ot_player_3d.tscn)        <- the only node you add
        ├── RadiOtStreamer                              (inside the scene)
        ├── StaticPlayer3D, BulletinPlayer3D, BulletinTimer
        └── RadiOtHUD
```

Nothing else is required: the scene wires its own children. Drive it from buttons connected in the editor or from your own input code with `tune_next_station()`, `tune_previous_station()`, `toggle_power()` and `urgent_bulletin()`.

### How `demo.tscn` does it

| Demo node | What it demonstrates |
|---|---|
| `RadioMesh/RadiOtPlayer3D` | The player scene instanced under the radio mesh with `auto_play_on_ready = true`, so it tunes to the first station on start. On the web the `ClickToStart` layer waits for a click first, because browsers block audio until then. |
| `RadioMesh/RadiOtPlayer3D/RadiOtHUD` | `toast_hide = false` keeps the panel on screen; `demo.gd` sets `hint_text` in `_ready()`. |
| `RadiOtDemo` (root, `demo.gd`) | Holds the `radio_player` export (a NodePath to the player) and the J / L / M keys in `_unhandled_input`. |
| `UI/PreviousStation`, `UI/NextStation` (and their `TouchScreenButton`s) | `pressed` is connected in the scene to `_on_previous_station_pressed` / `_on_next_station_pressed`, which call the tune methods. |
| `UI/VBoxContainer/BulletinBtn1`, `BulletinBtn2`, `CancelBulletinBtn` | `pressed` is connected in the scene to handlers that call `urgent_bulletin(stream, text)` and `cancel_bulletin()`. |
| `Camera3D` | Orbited by `demo.gd` so you hear the positional attenuation and panning. |
| `Retro Radio` | A cosmetic GLB model; the sound comes from `RadiOtPlayer3D`. |

---

## Narrative Story Bulletins (`urgent_bulletin`)

Trigger emergency announcements, breaking news alerts, or story events that temporarily override the live stream:

```gdscript
extends Node3D

@onready var radio: RadiOtPlayer3D = $RadiOtPlayer3D

func trigger_emergency_story_event() -> void:
    var news_audio: AudioStream = preload("res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3")

    radio.urgent_bulletin(
        news_audio,
        "EMERGENCY BROADCAST: Unidentified objects spotted over Elliott Bay and the Space Needle!",
        15.0 # Optional duration override in seconds
    )
```

You can also cancel an active bulletin early:

```gdscript
radio.cancel_bulletin()
```

---

## Custom Stations & Collections (`.tres`)

### Creating a New Station

Create a new `RadioStation` resource (`.tres`) in the Godot inspector:

```text
station_name: "Space Needle Beats"
call_sign: "KSEA"
frequency: 101.5
stream_url: "http://stream.example.com/live.mp3"
genre: "Synthwave / Cyberpunk"
tagline: "Soundtrack of the Emerald City"
description: "Late-night synthwave broadcast from atop the Space Needle."
```

### Station Collections

Group your stations into a `RadioStationCollection` resource (`.tres`) and assign it to the `station_collection` property of `RadiOtPlayer3D`.

---

## Public API Reference

### `RadiOtPlayer3D`

- `tune_next_station()` — Cycles to the next station in the collection.
- `tune_previous_station()` — Cycles to the previous station in the collection.
- `tune_to_station_index(index: int)` — Tunes directly to a specific station index.
- `tune_to_frequency(freq: float)` — Finds and tunes to the station closest to the given frequency (e.g. `90.3`).
- `tune_to_call_sign(call_sign: String)` — Tunes to a station matching the call sign (e.g. `"KEXP"`).
- `toggle_power()` / `set_power(is_enabled: bool)` — Powers the radio on or off.
- `urgent_bulletin(stream: AudioStream, text: String, duration: float = 0.0)` — Broadcasts a narrative alert.
- `cancel_bulletin()` — Cancels the current bulletin and resumes the live station.
- `get_current_station() -> RadioStation` — Returns the currently tuned `RadioStation` resource.
- `get_station_count() -> int` — Number of stations in the collection.
- `get_hud() -> RadiOtHUD` — The HUD child (`show_toast(seconds)`, `hide_toast()`, `hide_hud()`, `hint_text`, `toast_hide`, `toast_hide_seconds`).
- `set_volume(linear: float)` — Linear volume for the stream channels, the bulletin player and the node (also reachable through the `radio` group).

### Signals

- `station_changed(station: RadioStation)`
- `stream_buffering_started`
- `stream_playback_started`
- `stream_playback_failed(error_message: String)`
- `bulletin_started(bulletin_text: String)`
- `bulletin_finished`
- `radio_toggled(is_playing: bool)`

---

## Testing

Run the automated [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) suite via the command line or the in-editor GUT panel:

### Command Line (Headless)

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://addons/radi_ot/tests/
```

Or run all project GUT tests:

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

### Godot Editor

1. Open the project in the Godot Editor.
2. Open the **GUT** bottom panel.
3. Click **Run All** (or select test scripts in `res://addons/radi_ot/tests/`).

---

## Assets

- `assets/models/retro-radio-boombox` — Retro Radio model and textures. Source and license not recorded — fill in.
- `assets/audio/eleven_labs` — Bulletin voice clips generated with [ElevenLabs](https://elevenlabs.io).
- `assets/logos` — Station logos are trademarks of the respective stations.
- `assets/icons` — HUD and editor icons. Source not recorded — fill in.
- Radio static is generated procedurally by `RadiOtStaticGenerator` (no asset).

---

## License

Code is licensed under the MIT License.

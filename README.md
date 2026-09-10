![Preview](/godot-3d-player-controller-v3.png)

# godot-3d-player-controller-v3

The QA world for the addons developed at [github.com/kirbycope](https://github.com/kirbycope): a
GodotSteam multiplayer sandbox that installs every addon at once and puts something in the level to
exercise each of them.

Click [here](https://timothycope.com/godot-3d-player-controller-v3/) to play!

---

## Addons

Each addon is developed in its own repository and vendored into `addons/` here (see
[The addons are vendored](#the-addons-are-vendored-not-submodules)), and **its README is where its
features are documented**. This file covers only what belongs to the game project.

| Addon | Repository | What it provides |
| --- | --- | --- |
| `addons/3d_player_controller` | [godot-3d-player-controller-addon](https://github.com/kirbycope/godot-3d-player-controller-addon) | The Player: locomotion state machine, camera, equipment and combat, projectiles, inventory and spell system, abilities, chat, throwing, toon shading, health, stamina, settings, Steam lobby UI and the multiplayer spawners |
| `addons/controls` | [godot-controls](https://github.com/kirbycope/godot-controls) | On-screen input hints and the world-space `ActionPrompt` |
| `addons/weather_fx` | [weather-fx](https://github.com/kirbycope/weather-fx) | Biomes, precipitation, wind, wildfire, lightning, the sky and cloud driver, water shader and ripples |
| `addons/date_and_time` | [date-and-time](https://github.com/kirbycope/date-and-time) | The in-game clock and calendar HUD |
| `addons/gta` | [gta](https://github.com/kirbycope/gta) | Drivable vehicles with GTA V style handling |
| `addons/tcps` | [tcps](https://github.com/kirbycope/tcps) | The skateboard |
| `addons/radi_ot` | [radi-ot](https://github.com/kirbycope/radi-ot) | Internet radio, played through the car |
| `addons/godot_doom_gdextension` | [godot-doom-gdextension](https://github.com/kirbycope/godot-doom-gdextension) | PureDOOM as a GDExtension, plus a fallback raycaster |

The third-party addons (`gut`, `midi`, `godotsteam`, `GPUTrail-main`) are other people's work and
are not in `addons.json`; the pull script leaves them alone. See
[Third-party addons](#third-party-addons) for each one's author, licence and upstream.

---

## What is in the world

`scenes/world.tscn` is the level. The parts below are this project's own, under `scenes/` and
`resources/`:

- **Fishing** (`FishingRod`, `Bobber`, `FishShadows`, `FishingLog`): cast where you aim, watch the
  float dip, hook inside the window and the catch arcs into your hands and onto the Food tab of the
  inventory. Each water's `Buoyancy` holds its fish table (`resources/fish/`, keyed by hour, rain,
  lure and biome); lures (`resources/lures/`) are consumable items that go on the line. The catch
  screen holds the fish up Zelda style, the pause menu's Fish Index lists every species with its
  record, and the whole thing replicates through the `ProjectileSpawner`.
- **Enemies** (`EnemyNpc`, `NpcCaster`): a swordsman, an archer, a rifleman and a spellcaster east of
  the spawn. They hunt over the navmesh, attack in reach, take headshots, and leash back to their
  post like a WoW mob.
- **Companions** (`FollowerNpc`): a duck that respawns as a giant boss and a "little buddy" that can
  be picked up and thrown.
- **Horse** (`Horse`): a rideable on the player controller's `Riding` contract, with a whistle that
  summons the nearest one over the navmesh. It swims, replicates, and hands its authority to the
  rider.
- **Project spells** (`scenes/*_ability.gd`, `resources/abilities/`): the WoW-style set built on the
  addon's `Ability` resource - Firebolt, Fireball, Frostbolt, Lightning Bolt, Lightning, Chain
  Lightning, Flash of Light, Consecration, Shadowstep, Sword Slash and Freeze - arranged on the QA
  spell tree (`resources/spells/qa_tree.tres`).
- **Elemental ammunition** (`fire_arrow.tscn`, `ice_arrow.tscn`, `incendiary_round.tscn`,
  `ice_block.tscn`): fire lights grass and sets enemies ablaze, ice freezes a walkable slab into the
  pond.
- **Retro computer** (`RetroComputer`): a beige desktop whose CRT runs DOOM through the GDExtension,
  behind a curved-glass shader (`scenes/crt_screen.gdshader`).
- **Water and props**: the pool with `Buoyancy` on its area, floating the beach ball and rocking the
  boat on the weather addon's Gerstner waves; a bowling alley, balloons to shoot, choppable trees and
  mineable ore (`Harvestable`), a push button, warp zones, a kill zone and a moon with its own
  gravity.
- **Torch and fire** (`Torch`): a throwable that ignites grass fields, spreads downwind and goes out
  in the pool.
- **The QA kit**: `STARTING_ITEMS` in `scenes/world.gd` hands every spawned player lures, ammunition,
  throwables and a dagger, topped up on each spawn. The weapons and rod around the spawn are
  walk-over pickups.
- **Steam multiplayer**: the world auto-creates a public lobby and hosts it (`SteamPeer`);
  `PlayerSpawner` spawns `scenes/world_player.tscn` per peer, the host owns the clock, weather, NPCs,
  physics props and harvestables, and the car hands its authority to whoever drives it.

---

## Running and testing

Clone normally. The addons are committed to this repository, so it opens and runs straight away
with no fetch step.

### The addons are vendored, not submodules

Each addon is developed in its own repository, and a copy of it lives here under `addons/<name>/`,
committed like any other file. `tools/addons.json` names the repository and branch each copy comes
from, and `tools/addons.lock.json` records the exact commit each was taken at, so a vendored copy is
always traceable upstream.

Two scripts move code between here and those repositories. Both keep a clone of each addon under
`.addon_cache/` (git-ignored) and compare by content, so only real changes show up.

```powershell
python tools/pull_addons.py                     # take the latest of every addon
python tools/pull_addons.py controls gta        # only these
python tools/pull_addons.py --dry-run           # report, change nothing
python tools/pull_addons.py --locked            # the commits in the lock file, not the branch tip
```

`pull_addons.py` is the install step. It mirrors each addon's payload into `addons/<name>/` and
rewrites the lock file. The addon's own scaffolding is never vendored: its `demo/` project,
`.github/` workflows and git metadata stay upstream, while `scenes/demo/`, the demo scene inside the
addon, is part of the addon and comes along.

Because it is a mirror, a file sitting in `addons/<name>/` that upstream does not have would be
deleted. That is how an upstream removal reaches this project, but it is also how unpushed work
would be lost, so **the pull stops rather than delete anything**, names the files and leaves that
addon untouched:

```
3d_player_controller  18686a7  STOPPED: 8 local file(s) are not upstream
                        assets\mixamonimations\source\Sitting Typing.fbx
                        ...
                      push them first, or re-run with --force to delete them
```

So the rule is **push before you pull**. `--force` is there for when the local files really are
rubbish. The addons are committed here in any case, so `git checkout -- addons/<name>` brings back
anything a forced pull removed.

### Working on an addon from here

Edit the addon in place under `addons/<name>/`, against the whole game, then send it upstream:

```powershell
python tools/push_addons.py --dry-run                         # always look first
python tools/push_addons.py -m "fix the swim ledge ray"       # commit and push each addon that differs
git add addons tools/addons.lock.json
git commit -m "..."
git push origin main
```

`push_addons.py` copies `addons/<name>/` over the cached clone of that addon's repository, and where
that produces a change, commits it there and pushes to the branch `addons.json` names. It never
commits or pushes this repository: the vendored copies are ordinary files here, so they go in your
own commit alongside whatever project changes came with them. `--no-push` commits upstream without
pushing, and naming an addon limits it to that one.

It pushes straight to the addon's `main`, with no branch and no pull request. That has one
consequence worth remembering: `godot-3d-player-controller-addon` is the only addon that still
publishes releases, and its `release-addon.yml` fires on a merged pull request, never on a direct
push. So a player controller change sent this way cuts no release. Cut one when it is wanted by
running that workflow from the Actions tab (`workflow_dispatch`), or by putting a later change
through a pull request.

Two more things to know. Run an addon's own tests in its own repository, against that repository's
`demo/` project, rather than from here. And other projects vendor these addons too, so a push from
here does not reach `seattle-emerald-city`, `gta` or `tcps`; update each of those separately.

Open the project in Godot 4.8+ and run `scenes/main.tscn`, or the world directly with
`scenes/world.tscn`.

The project renders with D3D12 on Windows and sets
`rendering/rendering_device/d3d12/max_resource_descriptors` to 1000000 (the Tier 3 hardware limit) in
`project.godot`. The default of 16384 is exhausted once the editor has the world, player and main
scenes open, and 131072 still ran out on some launches; every draw then fails with
`Uniforms were never supplied for set (1)` spammed thousands of times in the Output panel, preceded
once by `Cannot create uniform set because there's not enough room in the RESOURCES descriptor heap`.
If it ever returns, that heap message is the one to look for.

Each addon owns its own tests and runs them in its own repository against that repository's `demo/`
project, which imports a fraction of this project's assets. This project runs only its own two
suites:

```powershell
& 'C:\Godot\godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
```

---

## Example resources

The spells, fish, lures and items a designer edits are `.tres` files, and they live at two levels:

- **Addon folders** hold only examples for that addon's own demo and tests, and reference nothing
  outside the addon. Each addon documents its own:
  [inventory](addons/3d_player_controller/inventory/README.md#example-resources),
  [3D Player Controller](addons/3d_player_controller/README.md#example-resources),
  [radi-ot](addons/radi_ot/README.md#custom-stations--collections-tres).
- **`resources/` at the project root** holds this game's content. It may reference project scripts
  (`scenes/*_ability.gd`, `scenes/fish.gd`, `scenes/lure.gd`), project assets and the addons.

So `resources/spells/qa_tree.tres` and `addons/3d_player_controller/inventory/resources/spell_tree_demo.tres`
are two different trees: the QA world plays the first, the inventory demo plays the second.

| File | Class (script) | What it is | Used by | Tests that load it |
|---|---|---|---|---|
| `resources/spells/qa_tree.tres` | `SpellTree` (`addons/3d_player_controller/inventory/scripts/spell_tree.gd`) | The QA world's tree: every project ability plus Stealth, 12 nodes | `scenes/world_player.tscn` (`Inventory/Spellbook.tree`, with 6 skill points) | Anything that instances `world_player.tscn`: `tests/unit/test_world_player_connector.gd`, `tests/integration/test_fishing_extras.gd` |
| `resources/abilities/*.tres` (11) | `DamageAbility` (`firebolt`, `fireball`, `frostbolt`, `lightning_bolt`), `AreaDamageAbility` (`consecration`), `ShadowstepAbility`, `MeleeAbility` (`sword_slash`), `LightningAbility`, `ChainLightningAbility`, `FreezeAbility` (`freeze`), all in `scenes/*_ability.gd`; `flash_of_light` is the addon's `HealAbility` | The shipped spells | `world_player.tscn` (`Abilities.abilities` starts with Stealth and Flash of Light; the rest come through the tree), `scenes/enemy_spellcaster.tscn` (Firebolt and the addon's Heal) | `tests/unit/test_wow_spells.gd` (loads `fireball`, `frostbolt`, `consecration`, `shadowstep`, `flash_of_light`, `firebolt`, `freeze` by file name), `test_lightning_spells.gd` (`lightning`, `chain_lightning`), `test_melee_ability.gd` (`sword_slash`) |
| `resources/fish/*.tres` (7) | `Fish` (`scenes/fish.gd`, extends the inventory's `Item`) | Five species (`carp`, `perch`, `catfish`, `rainbow_trout`, `koi`) and two pieces of junk (`old_boot`, which bites on a bare hook, and `boot_crate`, which only takes a worm); each carries `bare_hook_chance`; the shared icons `fish.svg`, `boot.svg`, `crate.svg` sit beside them | The pool's water in `scenes/world.tscn` (`Pool/WaterArea3D`, its `Buoyancy.fish` table is what bites there) and `scenes/fish_index_screen.tscn` (`FishIndexScreen.species`, the Fish Index order) | `tests/unit/test_fishing.gd`, `test_fishing_rules.gd`, `test_fish_index_models.gd`, `tests/integration/test_fishing_extras.gd`, `test_fishing_sync.gd`, `test_fishing_world.gd` |
| `resources/lures/*.tres` (3) | `Lure` (`scenes/lure.gd`, extends `Item`) | `worm`, `fly`, `chum`, all consumable (a bite eats one and the next goes on), with `worm.svg` and `fly.svg` | `worm` is in the QA kit (`STARTING_ITEMS` in `scenes/world.gd`) and is what the catfish and the crate of boots bite on; the trout wants `fly`; `chum` is what a shot fish turns into (`Pool/FishShadows.chum` in `world.tscn`) | `test_fishing.gd`, `test_fishing_rules.gd`, `test_fishing_extras.gd`, `test_fishing_world.gd`, `tests/integration/test_world.gd` |
| `resources/items/*.tres` (6) | `AmmoItem` (`addons/3d_player_controller/scripts/ammo_item.gd`, extends the inventory's `Item`) | Ammunition: `arrow`, `fire_arrow`, `ice_arrow` (bow), `pistol_magazine`, `rifle_clip`, `rifle_clip_incendiary` (rifle); the special kinds name their `projectile_scene` under `scenes/` | The QA kit in `scenes/world.gd` | `tests/integration/test_world.gd` (the plain three; the addon's `test_ammo_items.gd` builds its own) |
| `resources/audio/*.tres` (6) | `AudioStreamRandomizer` | The guns' sounds: `pistol_shot`, `rifle_shot`, `pistol_reload`, `rifle_reload` (three takes each) and the shared `gun_draw` / `gun_holster`, over the 96 kbps Vorbis clips in `assets/gravitysound/Gun SFX/` | The pistol's and rifle's `FireAudio` / `ReloadAudio` nodes and `equip_sfx` / `stow_sfx` in `scenes/world.tscn` | `tests/integration/test_shooting_world.gd` |
| `resources/items/rock.tres`, `apple.tres` | `Item` | Throwables: `throwable` on both, the rock with `throw_damage` 5 and `scenes/rock.tscn` (the ore mesh at 0.3) as its model, the apple a consumable food that flies as its icon | The QA kit in `scenes/world.gd`; the seeker wheel lists them when not aiming | `tests/integration/test_world.gd`, the addon's `test_throwables.gd` |
| `resources/items/dagger.tres` | `Item` | Equipment: `equipment_scene` is `scenes/dagger.tscn`, the world dagger's model and hand offsets with `is_throwable` and `throw_damage` 10; it lands as its own walk-over scene | The QA kit, stowed on spawn | `tests/integration/test_world.gd` |

Not examples, just engine resources the scenes use: `resources/enemy_replication.tres` (a
`SceneReplicationConfig` for `enemy_npc.tscn`), `resources/horse_replication.tres`, `resources/vfx/`
(the harvestables' chip particles) and `resources/pool_water_material.tres` (the pool's
`ShaderMaterial`).

**Adding a spell tree.** New Resource, `SpellTree`, save it under `resources/spells/`. Select the file
in the FileSystem dock and the Spell Tree bottom panel opens (the inventory's
`editor/spell_tree_editor.gd`); its palette lists every `.tres` whose script class extends `Ability`,
from any folder. Assign the tree to `Inventory/Spellbook.tree` in the player scene, as
`world_player.tscn` does.

**Adding an ability.** New Resource, pick the class (`DamageAbility`, `AreaDamageAbility`,
`MeleeAbility`, `ShadowstepAbility`, `LightningAbility`, `ChainLightningAbility` from
`scenes/*_ability.gd`, or the addon's `HealAbility` and `StealthAbility`), or extend `Ability` in a
new script under `scenes/`. Save it under `resources/abilities/`. The addon's README documents the
fields. `test_wow_spells.gd` loads the shipped spells by file name, so renaming one breaks that test.

**Adding a fish.** New Resource, `Fish`, save it under `resources/fish/`. A Fish is an Item, so it
keeps `id`, `display_name`, `description`, `icon` (the shared `fish.svg`, tinted by `color`),
`category`, `max_stack` and `consumable`, then adds the fishing fields: `from_hour` / `to_hour` (a
later `from_hour` wraps past midnight), `rain`, `lures` (empty bites on anything), `biomes` (empty is
every water), `weight`, `min_length_cm` / `max_length_cm`, `attract_range`, `shadow_scale`, `is_junk`
and `model_scene`. Add it to the water's `fish` array in `world.tscn` and to `species` in
`fish_index_screen.tscn`. The fishing tests preload species by file name.

**Adding an item or a lure.** New Resource, `Item` (or `Lure` for bait: `bite_time_scale`,
`attract_range_bonus`, and `consumable` means a bite eats it), save it under `resources/items/` or
`resources/lures/`. Hand it out with the inventory's `item_pickup.tscn` in the level, or add it to
`STARTING_ITEMS` in `world.gd` for the QA kit.

---

## Web export

The `Web` preset in `export_presets.cfg` exports only what the listed scenes reach
(`export_filter="scenes"`) plus the include filter. Two rules keep that working. Anything a script
reaches only by `preload`, `load` or a path in a String property (the pause menu's screens, the wind
and lightning bolt scenes, spell projectiles) is not a scene dependency and has to be ticked in the
export dialog, so it lands in `export_files`; tick those, not whole asset packs, since every ticked
scene and all it reaches is exported (the VFX packs ticked wholesale made a 127 MB pack, over
GitHub's 100 MB file limit; the referenced 79 scenes make 81 MB). The exporter takes dependencies from
the editor's filesystem cache, `.godot/editor/filesystem_cache10`, not from the files; if a scene's
files go missing from the pack although the scene is in it, delete that cache and export again.
`tools/pck_report.py` on the exported pack shows what got in, and `tools/pck_missing.py` lists what it
should carry but does not (a preload in a packed script, a scene a packed `.tres` names). A
scene-filtered export walks only the scenes in `export_files`, so a listed `.tres` is copied but never
walked. The include filter lists `*.gdshaderinc` (shader include files are not resources; without them
the BinbunVFX shaders fail in the browser with `#include` errors) and every image extension, because a
material that comes in through the `*.tres` filter is not walked for its textures, which is how the
horse lost its saddle. Everything (`all_resources`) would be a 204 MB pack, so the scene list stays.
GodotSteam has no wasm32 build and logs a warning at export; the code guards Steam behind
`OS.has_feature("web")`.

The build is meant to stay under 100 MB (GitHub refuses a larger file). It is 84 MB now: 27 MB of
textures, 19 MB of scenes (9 MB of it the Honda's mesh), 17 MB of audio and 7.5 MB of Doom. Audio is
the second lever after textures: every looping ambience clip is a 60 s Vorbis stream, and the six
weather_fx forest loops came in at about 500 kbps (4 MB each) until they were re-encoded to 96 kbps
(`ffmpeg -c:a libvorbis -q:a 2`, 0.8 MB each) along with the heavier rain and wind loops; keep new
loops at that quality, since a `.ogg` goes into the pack byte for byte. Every image import
(`[importer_defaults]` in `project.godot`, and every existing `.import`) is Lossy (WebP), capped at 512
on its largest edge by `process/size_limit`, with `detect_3d/compress_to` off so a texture first seen
in 3D is not switched back to VRAM compression.

`tools/web_smoke_test.py` serves `docs/` and drives the export in headless Chromium through Playwright
(`pip install playwright && playwright install chromium`): click to start, Single-Player, the world,
failing on any error the engine or the page logs, with screenshots and the console under
`scratch/web_smoke/`. `tools/tinyify.py <folder> --engine local` downsizes the PNGs under a folder to
512 and stamps them with `TINYIFY_*` metadata so they are skipped next time.

---

## Credits & Asset Attributions

### Third-party addons

The addons written here come from their own repositories (see [Addons](#addons)) and are managed by
`tools/pull_addons.py`. These four are other people's work, copied into `addons/` by hand and not
listed in `tools/addons.json`, so the pull script never touches them.

They are updated by hand rather than by script, because they are not developed here and their
upstreams do not publish the addon at a repository root the way ours do: `gut` sits at `addons/gut/`
inside a Godot project and `midi` at `addons/midi/`, while the two GodotSteam pieces ship through
releases and the asset library. `GPUTrail-main` is the odd one out, an asset of this project rather
than part of any addon developed here, kept as a copy of a downloaded zip (hence the `-main`
suffix); the Le Lu trail effects are what use it. All four must credit their upstream rather than be
republished as ours.

| Addon | What it is | Author | Version | License (as recorded in folder) | Upstream |
| --- | --- | --- | --- | --- | --- |
| `addons/gut` | Godot Unit Test, the test runner the whole suite uses | Butch Wesley | 9.7.1 | MIT (`LICENSE.md`) | https://github.com/bitwes/Gut |
| `addons/midi` | Godot MIDI Player, the SoundFont synthesiser DOOM's music plays through | arlez80 (Yui Kinomoto) | 4.5.0 | MIT (`LICENSE.txt`) | https://bitbucket.org/arlez80/godot-midi-player-g4 |
| `addons/godotsteam` | GodotSteam GDExtension Updater; the Steamworks binding itself is the GDExtension it updates | GP Garcia, Chris Ridenour and contributors | 4.21 | MIT (`license.md`) | https://godotsteam.com |
| `addons/GPUTrail-main` | GPUTrail; an asset of this project rather than part of any addon here, used by the Le Lu trail effects | celyk | 0.1 | MIT (`LICENSE`) | https://github.com/celyk/GPUTrail |

### Assets

Third-party assets under `assets/`, with the license as recorded in each folder's license/readme file.
"not recorded" means the folder has no license file; fill it in from the source page.

| Folder | Asset | Author | License (as recorded in folder) | Source |
| --- | --- | --- | --- | --- |
| `assets/BinbunGrass` | Godot Grass Shader | Binbun (Binbun3D) | not recorded - fill in | https://binbun3d.itch.io/godot-grass |
| `assets/BinbunVFX` | Fire, Ice, Impact, Magic Area, Magic Orb, Magic Projectiles, Smoke, Beam, Card, Hologram, Loot, Muzzle Flash, Poison, Portal VFX | Binbun (Binbun3D) | not recorded - fill in (no license file in the Vol.1 packs) | https://binbun3d.itch.io (each pack folder has a `.url` to its page) |
| `assets/BinbunVFX_Vol2` | Battle, Dark Magic, Electric, Elemental Magic, Explosion, Flame, Frosted Glass, Status, Stylized Hit FX | Binbun (Binbun3D) | CC0 (each pack's `license.txt`) | https://binbun3d.itch.io (each pack folder has a `.url` to its page) |
| `assets/BinbunGlassUI`, `assets/BinbunMaterials`, `assets/BinbunWater`, `assets/TransitionKit` | Fluid Glass UI, Ultimate Toon Shader, Water, Modular Transitions | Binbun (Binbun3D) | not recorded - fill in | https://binbun3d.itch.io (each folder has a `.url` to its page) |
| `assets/Character`, `assets/Flower`, `assets/Misc`, `PolyBlocks` | WeisC character, flower, misc props, PolyBlocks effect blocks | not recorded - fill in | not recorded - fill in | not recorded - fill in |
| `assets/ambientcg_com` | Grass001, Planks020, Wood073 PBR textures | ambientCG | not recorded - fill in | https://ambientcg.com |
| `assets/cgtrader/bilalcreation` | Duck Rigged Animated (low-poly) | Bilal Creation | not recorded - fill in | https://www.cgtrader.com/3d-models/animal/bird/duck-animated |
| `addons/gta/assets/cgtrader/honda_crv` | Wheel model and tyre texture | not recorded - fill in | not recorded - fill in | https://www.cgtrader.com |
| `assets/fonts` | FOT-Rodin Pro B, Rodin Italic | Fontworks | not recorded - fill in | not recorded - fill in |
| `assets/freesound` | fotballplast (117111) | blindmanonacid | not recorded - fill in (`.txt` is empty) | https://freesound.org/s/117111/ |
| `assets/freesound` | Single bowling pin knock (499788) | Rvgerxini | CC0 | https://freesound.org/s/499788/ |
| `addons/3d_player_controller/assets/freesound` | Flag flicking on strong wind (570701) | Robinhood76 | CC BY-NC 4.0 | https://freesound.org/s/570701/ |
| `addons/3d_player_controller/assets/freesound` | Parachute (72853) | Benboncan | CC BY 4.0 | https://freesound.org/s/72853/ |
| `assets/freesound` | IR Caravan Ballon POP (850645) | Sadiquecat | CC0 | https://freesound.org/s/850645/ |
| `assets/galacticlake` | Godot Plush (rigged, game ready) | GalacticLake | not recorded - fill in | https://galacticlake.itch.io/godot-plushie |
| `assets/godotshaders` | Wind Waker 2D water shader | not recorded - fill in | not recorded - fill in | https://godotshaders.com |
| `assets/gravitysound`, `addons/tcps/assets/gravitysound` (Skateboard SFX), `addons/gta/assets/gravitysound` (Car Sound Effects) | Animal SFX, Gun SFX (the pistol and rifle shots, reloads, draws and holsters), Car Sound Effects, Skateboard SFX | Gravity Sound | not recorded - fill in | https://gravity-sound.itch.io/car-sound-effects, https://gravity-sound.itch.io/skateboard-sound-effects |
| `assets/justcreate3d` | Low Poly FPS Weapons Pack Lite, Stylized Tropical Island (boat) | JustCreate3D | not recorded - fill in | https://justcreate3d.itch.io/low-poly-fps-weapons-pack-lite |
| `assets/kenney_nl` | Prototype Textures, Road Textures | Kenney | CC0 (`License.txt`) | https://kenney.nl |
| `addons/godot_doom_gdextension/thirdparty` | PureDOOM single-header DOOM engine | Daivuk (David St-Louis), from the id Software source | GPL 2.0 (`LICENSE` in the folder) | https://github.com/Daivuk/PureDOOM |
| `addons/godot_doom_gdextension/assets` | DOOM shareware `doom1.wad` | id Software | Shareware, freely redistributable | https://github.com/Daivuk/PureDOOM |
| `addons/godot_doom_gdextension/assets` | `gzdoom.sf2`, GZDoom's default General MIDI SoundFont (SC-55 preset) | ZDoom team | not recorded - fill in (ships with GZDoom, no license file of its own) | https://github.com/ZDoom/gzdoom/blob/master/soundfont/gzdoom.sf2 |
| `addons/gta/assets/libertycity/2024_Honda_CRV` | 2024 Honda CR-V | not recorded - fill in | not recorded - fill in | https://libertycity.net |
| `assets/loop_box` | Ray mesh and line shader VFX | not recorded - fill in | not recorded - fill in | not recorded - fill in |
| `assets/n_hance_studio` | Stylized Craft Assets (ore), Stylized Newbie Weapons Pack | N-Hance Studio | not recorded - fill in | https://assetstore.unity.com/packages/3d/props/stylized-craft-assets-204769, https://assetstore.unity.com/packages/3d/props/weapons/stylized-newbie-weapons-pack-200709 |
| `assets/n_hance_studio/horse` | Horse (model, brown body and saddle textures, copied from the aethereal project) | N-Hance Studio | not recorded - fill in | https://assetstore.unity.com/publishers/34848 |
| `assets/nasa` | Moon colour map, starmap | NASA SVS (normal map via NormalMap-Online) | not recorded - fill in (`credits.md` lists sources only) | https://svs.gsfc.nasa.gov/4720/, https://svs.gsfc.nasa.gov/vis/a000000/a003800/a003895/starmap_g8k.jpg |
| `resources/fish/fish.svg`, `resources/lures/worm.svg`, `resources/lures/fly.svg` | Inventory icons for the fish and lures | Drawn for this project | CC0 | - |
| `resources/fish/boot.svg` (`leather-boot`) | The Old Boot's icon | Lorc, [game-icons.net](https://game-icons.net/1x1/lorc/leather-boot.html) | CC BY 3.0 | - |
| `resources/fish/crate.svg` (`wooden-crate`) | The Crate of Boots' icon | Delapouite, [game-icons.net](https://game-icons.net/1x1/delapouite/wooden-crate.html) | CC BY 3.0 | - |
| `assets/pixabay` | Bow loading/release (the arrow swish/twang moved to `addons/3d_player_controller/assets/pixabay`) | freesound_community | not recorded - fill in | https://pixabay.com |
| `assets/pixelloops` | Explosion Sound Effects Pack | PixelLoops Audio | PixelLoops royalty-free license (`LICENSE.txt`) | https://pixelloops.com |
| `assets/quaternius/nature`, `assets/quaternius/logs` | Ultimate Stylized Nature Pack (trees, bark, logs) | Quaternius | not recorded - fill in (`README.txt` only lists minified files) | https://quaternius.com/packs/ultimatestylizednature.html |
| `addons/3d_player_controller/assets/quaternius/paraglider` | Paraglider | Quaternius | CC0 1.0 (`License.txt`) | https://www.patreon.com/quaternius |
| `assets/modular_character_outfits` | Modular Character Outfits - Fantasy (`Male_Peasant_Feet.gltf`, `old_boot.gltf`, `T_Peasant_*` textures; the Old Boot fish) | Quaternius | CC0 1.0 (`License_Source.txt`) | https://www.patreon.com/quaternius |
| `assets/sketchfab/bowling_pin` | Bowling Pin | MSerdar Tekin | CC BY 4.0 | https://sketchfab.com/3d-models/bowling-pin-028ccb945012460aa9056ffda5b53e20 |
| `assets/sketchfab/cc0_pinwheel` | CC0 - Pinwheel | plaggy | CC BY 4.0 (as recorded in `license.txt`) | https://sketchfab.com/3d-models/cc0-pinwheel-7abebdf80d2f4df2bb19ae5f2cf9a5c6 |
| `assets/sketchfab/fishing_rod` | Fishing Rod, Rigged and Animated | Ergin ERYILDIR | CC BY 4.0 | https://skfb.ly/oHVzO |
| `assets/sketchfab/knife` | Knife Low-poly | MaX3Dd | not recorded - fill in | https://sketchfab.com/3d-models/knife-low-poly-b864f3bbc333401d84dcadb94027d31d |
| `addons/tcps/assets/sketchfab/skateboard` | Skateboard | Jamoues | CC BY 4.0 | https://sketchfab.com/3d-models/skateboard-0f7b8ea366654674b217a743959798e7 |
| `assets/tommusic`, `addons/3d_player_controller/assets/tommusic` | Fantasy SFX (torch loop, impacts, spell sounds, the horse's Idle calls; the bow and sword attack, hit, sheath and unsheath sets live in the addon under `fantasy_sfx/Attacks/`) | TomMusic | not recorded - fill in (`ReadMe.txt` has no license) | https://tommusic.itch.io/ |
| `Le_Lu/` | Fire, Elemental (Elementary Pack), Explosions, Full Screen, Healing & Protection, Level Up, Loot Drop, Magic Area, Puff, Smoke, Stylized Smoke, Trails, Vertical Beam and Wind VFX packs | Le Lu | not recorded - fill in (Patreon packs, no license file) | https://www.patreon.com/Le_Lu (each pack folder has a `.url` to its post) |
| `addons/GPUTrail-main` | GPUTrail3D (used by the Le Lu fire projectiles) | celyk | MIT (`LICENSE`) | https://github.com/celyk/GPUTrail |

Icons in the player addon HUD come from [Game-icons.net](https://game-icons.net) (**CC BY 3.0**, by
Lorc, Delapouite and contributors) and [Kenney](https://kenney.nl) input prompts (**CC0**).

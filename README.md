![Preview](godot-3d-player-controller-v3.png)

# godot-3d-player-controller-v3

The QA world for the addons developed at [github.com/kirbycope](https://github.com/kirbycope): a
GodotSteam multiplayer sandbox that installs every addon at once and puts something in the level to
exercise each of them.

Click [here](https://timothycope.com/godot-3d-player-controller-v3/) to play!

---

## Addons

Each addon is developed in its own repository and fetched into `addons/` here (see
[Running and testing](#running-and-testing)), and **its README is where its
features are documented**. This file covers only what belongs to the game project.

| Addon | Repository | What it provides |
| --- | --- | --- |
| `addons/3d_player_controller` | [godot-3d-player-controller-addon](https://github.com/kirbycope/godot-3d-player-controller-addon) | The Player: locomotion state machine, camera, equipment and combat, projectiles, inventory and spell system, abilities, chat, throwing, toon shading, health, stamina, settings, Zelda and GTA control schemes, checkpoints and the death flow, the save game, the NPCs (`FollowerNpc`, `EnemyNpc`, `NpcCaster`, `TalkingNpc`), dialogue and quests, local split screen, Steam lobby UI and the multiplayer spawners |
| `addons/controls` | [godot-controls](https://github.com/kirbycope/godot-controls) | On-screen input hints and the world-space `ActionPrompt` |
| `addons/weather_fx` | [weather-fx](https://github.com/kirbycope/weather-fx) | Biomes, precipitation, wind, wildfire, lightning, the sky and cloud driver, water shader and ripples |
| `addons/date_and_time` | [date-and-time](https://github.com/kirbycope/date-and-time) | The in-game clock and calendar HUD |
| `addons/gta` | [gta](https://github.com/kirbycope/gta) | Drivable vehicles with GTA V style handling |
| `addons/tcps` | [tcps](https://github.com/kirbycope/tcps) | The skateboard |
| `addons/radi_ot` | [radi-ot](https://github.com/kirbycope/radi-ot) | Internet radio, played through the car |
| `addons/godot_doom_gdextension` | [godot-doom-gdextension](https://github.com/kirbycope/godot-doom-gdextension) | PureDOOM as a GDExtension, plus a fallback raycaster |
| `addons/dialogic` | [dialogic](https://github.com/dialogic-godot/dialogic) (third party, 2.0 alpha 20) | The dialogue system: timelines, characters, the text box, choices and conditions |

The third-party addons (`dialogic`, `gut`, `midi`, `godotsteam`, `GPUTrail`) are other people's work.
They are fetched by the same script, pinned to a release, and never pushed to. See
[Third-party addons](#third-party-addons) for each one's author, licence and upstream.

---

The game has two starts on purpose. On the desktop, and when run from the editor, `scenes/main.tscn` opens on
the title screen. Its main menu is Single-Player, Multi-Player, Options and Quit Game; Single-Player opens a
second panel offering **New Game**, **Continue** while a save exists at the `SaveGame` default path, and Back.
Continue is not on the main menu, so the top level says what kind of game you want before it asks which one.
Back, and the Cancel action (B on a controller, Escape), return to the main menu. New Game emits
`new_game_pressed` and Continue emits `continue_pressed`; `scenes/main.tscn` wires the first to `Main.single_player`
and the second to `Main.continue_game`, which sets `SaveGame.load_requested` before loading the same world.
The web export opens on the Click to Start
overlay, since a browser lets the game capture the mouse and play audio only from inside a user gesture, and
the click or touch goes straight into the single-player world; there is no Steam on the web and no title screen.

## What is in the world

`scenes/world.tscn` is the level. The parts below are this project's own, under `scenes/` and
`resources/`:

- **Fishing** (`FishingRod`, `Bobber`, `FishShadows`, `FishingLog`): cast where you aim, watch the
  float dip, hook inside the window and the catch arcs into your hands and onto the Food tab of the
  inventory. Each water's `Buoyancy` holds its fish table (`resources/fish/`, keyed by hour, rain,
  lure and biome); lures (`resources/lures/`) are consumable items that go on the line. The catch
  screen holds the fish up Zelda style (the fish keeps turning on its own clock while the world behind it is frozen), the pause menu's Fish Index lists every species with its
  record, and the whole thing replicates through the `ProjectileSpawner`.
- **Enemies** (`enemy_swordsman.tscn`, `enemy_archer.tscn`, `enemy_rifleman.tscn`,
  `enemy_spellcaster.tscn`): a swordsman, an archer, a rifleman and a spellcaster east of the spawn.
  They hunt over the navmesh, attack in reach, take headshots, and leash back to their post like a
  WoW mob. The scripts (`EnemyNpc`, `NpcCaster`, `FollowerNpc`) and the base scene are the addon's
  now; this project's `scenes/npc/enemy_npc.tscn` inherits it and hangs the weather addon's flame under
  `BurnVFX`, and the four enemies inherit that, each with its N-Hance weapon.
- **The ability library**: `AbilityLibrary` in `world.tscn` is the addon's `scenes/ability_library.tscn` made editable, with the game's eleven spells (`resources/abilities/`) added as `AbilityEntry` children beside the addon's Heal and Stealth. It warms every spell's VFX at start, and the Player's `Abilities` and every `NpcCaster` take their abilities from it, so the enemy spellcaster and the Player share one loaded copy of each.
- **The Guide** (`TalkingNpc` with a `Conversation` under it, `scenes/conversation.gd`,
  `resources/dialogues/qa_guide.dtl` and `guide.dch`, `resources/quests/qa_errand.tres`): stands by the
  spawn with an errand: talk to him, fell a tree with an axe and land a fish, and he pays three apples. The
  addon's NPC only offers Talk, holds the Player still and emits `talked_to`; the conversation itself is
  [Dialogic](https://github.com/dialogic-godot/dialogic), this project's. `Conversation` publishes the quest
  log to Dialogic as `{quest.<id>}` (`not_started`, `active`, `complete`) and `{objective.<id>}`, so the
  timeline branches on them, and the timeline drives the log back through Dialogic's signal event:
  `[signal arg="start_quest qa_errand"]`, `[signal arg="progress talk_guide"]`. The Action button advances
  the text and reads Next; while a question is up it reads Pick and picks the focused choice (Dialogic focuses the first, the d-pad or stick moves it); Start ends the conversation. `world.gd` reports the tree through every `Harvestable`'s `depleted` signal and
  `FishingLog.record_catch` reports the fish. The tracker sits top right and the Quests page is in the
  pause menu.
- **Checkpoint, kill zone and saving**: the beacon west of the spawn is the addon's `Checkpoint`; the
  `KillZone` fifty metres down is lethal, so falling off the map is a death, the death screen and a
  respawn at the checkpoint. The `SaveGame` node writes `user://savegame.tres` from the pause menu's
  Save Game (and on every checkpoint), keeping the Player, the world's clock and weather (`world.gd` is
  in the `Saveable` group), every `Harvestable`'s hits and the enemies; Load Game reads it back, and
  the title screen's Single-Player panel shows Continue while the file exists.
- **Companions** (`FollowerNpc`): a duck that respawns as a giant boss (its size, animation and
  health replicate, so every peer sees the giant walk and eat) and a "little buddy" that can be
  picked up and thrown: the carrier's peer owns it while it is in their hands, every peer sees it on
  their arm, and its walk blend replicates.
- **Horse** (`Horse`): a rideable on the player controller's `Riding` contract, with a whistle that
  summons the nearest one over the navmesh. The whistle is heard as well as answered: `WhistleAudio` on
  the world's Player template takes an `AudioStreamRandomizer` of the three AudioHero human whistles, so the same
  player never whistles identically twice, and `world.gd` plays it on `Player.whistled` before
  `Horse.summon_nearest` picks the horse. It swims, replicates, and hands its authority to the
  rider; a horse somebody else is riding refuses the prompt and the mount. Getting on puts up Breath
  of the Wild's horse layout (`resources/control_schemes/totk_horse.tres`, the horse's
  `riding_control_scheme`): A gallops, B gets off, X jumps and the rest of the pad is cleared, with
  the rider's own layout back on getting off, the way the skateboard swaps to Tony Hawk's. On the
  keyboard Shift gallops and E gets off, and the HUD draws those keys on the buttons that do them.
- **Project spells** (`scenes/*_ability.gd`, `resources/abilities/`): the WoW-style set built on the
  addon's `Ability` resource - Firebolt, Fireball, Frostbolt, Lightning Bolt, Lightning, Chain
  Lightning, Flash of Light, Consecration, Shadowstep, Sword Slash and Freeze - arranged on the QA
  spell tree (`resources/spells/qa_tree.tres`).
- **Elemental ammunition** (`fire_arrow.tscn`, `ice_arrow.tscn`, `incendiary_round.tscn`,
  `ice_block.tscn`): fire lights grass and sets enemies ablaze, ice freezes a walkable slab into the
  pond.
- **Retro computer** (`RetroComputer`): a beige desktop whose CRT runs DOOM through the GDExtension,
  behind a curved-glass shader (`scenes/crt_screen.gdshader`). One Player at a time: a chair another
  peer's Player is already in is refused. Hands on the keyboard hold nothing: sitting down stows what was equipped and standing up puts it back in hand. Select/View still swaps perspective at the keyboard: the seat's view moves between the over-the-shoulder shot and square on to the screen, and the Player's own camera changes with it, so they stand up in the perspective they chose.
- **Water and props**: the pool with `Buoyancy` on its area, floating the beach ball (a bump on what
  it rolls into, never a weapon hit and never a chop; shoot it and it deflates, see below) and rocking the boat on the weather addon's
  Gerstner waves; a bowling alley, balloons to shoot (the ring spins on every peer), choppable trees
  and mineable ore (`Harvestable`), a push button, warp zones, a wooden sign and a moon with its own
  gravity. The boat, the harvestables and the sign answer a client's Action too.
- **Shooting the beach ball deflates it** (`scenes/beach_ball.gd`, `scenes/beach_ball_deflated.tscn`): a round
  or an arrow arrives through `register_projectile_hit`, and the ball hands over to a `SoftBody3D` twin wearing
  the same shader. Squashing the rigid ball's own mesh was the first attempt and only ever looked like a
  squashed sphere, because the collider stays a sphere underneath; the twin is real cloth, so it creases and
  folds the way plastic does. The twin's `pressure_coefficient` falls to nothing over `deflate_seconds`, which
  is the air going out; Jolt implements that as `SoftBodySharedSettings::mPressure`, so it is honoured here.

  Getting the whole deflation to read took three levers rather than one, and the order they were found in is
  worth keeping. **Pressure** gives the sag: the shell holds round at 45 and caves in as it empties, but much
  above that the pressure propels the twin, and 150 threw it five metres. **Stiffness** tweens down with it, so
  the plastic softens as it empties. Neither flattens it: emptied and softened the shell still settles as a
  bowl, because once its vertices are at rest nothing is left pushing them down, and loosening
  `simulation_precision` at that point does nothing either. **Weight** is what finishes it, so `_go_limp` raises
  `total_mass` to `deflated_mass` and the shell folds into a flat ring.

  One bug hid all of that for a while: the twin used to be built before the rigid ball's collider was disabled,
  and a soft body born inside a live sphere collider is shoved out of it and creased flat within a frame or
  two. That is why the deflation looked instant however it was tuned. The collider now goes first, immediately
  rather than deferred.

  Three things about `SoftBody3D` are worth knowing before changing any of this, because each one cost a
  rewrite. It cannot sit in the scene waiting its turn: this project runs Jolt (`3d/physics_engine`), which
  reports "Doing so without a physics space is not supported when using Jolt Physics" for any transform set on
  a soft body outside the space, and a disabled node is outside it, so a dormant twin logs that on every touch. It cannot be positioned either, at any point in its life, out of
  the space because Jolt refuses and in it because the physics server owns its vertices; the twin is therefore
  instantiated at the moment of the hit and added as a **child of the ball**, which is what places it, since
  entering the tree is when a soft body is built and it is built wherever it finds itself. And its deformation
  is invisible to `get_aabb()`, which keeps reporting the undeformed mesh, so the only honest check on how it
  looks is to look at it.

  It deflates on every peer the way a balloon pops, server-authoritative, and `is_deflated` replicates
  (`scenes/beach_ball_replication.tres`) so a peer joining later gets a ball that is already empty with no
  deflation to watch. Each ball copies the scene's shared `ShaderMaterial` on ready, so deflating one cannot
  reach the others. `deflate_sound` takes an `AudioStreamRandomizer` of the three AudioHero air-release clips, so the same ball does not hiss identically twice. They run 4.3s, 5.4s and 9.3s against a deflation of about a second and a half, so `_go_limp` stops the player when the pressure reaches nothing: the hiss ends with the air rather than carrying on over a flat ball.
- **The world's controls**: `world.gd` puts its own `control_scheme` on the Player as it spawns and turns the
  whole on-screen HUD on only when asked (`show_controls`, off by default, so the saved On-Screen setting decides: Auto shows the buttons on a touchscreen and otherwise only as contextual hints), so the world is played on Tears of the Kingdom's pad with every
  button readable: A dashes, B is Action, X attacks, Y jumps, the triggers are Focus and Shoot. The Player
  applies the saved settings in its own `_ready`, which runs first, so the world's choice is the one that
  sticks; clear either export to leave the Player on whatever its scene or the settings menu chose.
- **The noise meter** (`NoiseMeter`, mounted in `world.tscn` under `HUD/BottomRight`): the Breath of the
  Wild style readout of how much noise the Player is making, a flat line when they are quiet and a waveform
  that grows with the racket. Both it and the `PlayerNoise` that feeds it belong to the player controller
  addon, which documents how the reading is built and what hears it; what this project supplies is the corner
  of the HUD it sits in, beside the enemies that come looking when it runs loud.
- **Torch and fire** (`Torch`): a throwable that ignites grass fields within its exported
  `ignite_radius` for `burn_duration` seconds (the fire arrow's ignite, on every peer through the
  spawner), spreads downwind and goes out in the pool.
- **The QA kit**: `STARTING_ITEMS` in `scenes/world.gd` hands every spawned player lures, ammunition,
  throwables and a dagger, topped up on each spawn. The weapons and rod around the spawn are
  walk-over pickups.
- **Steam multiplayer**: the world auto-creates a public lobby and hosts it (`SteamPeer`);
  `PlayerSpawner` spawns a copy of its Player template per peer (`PlayerSpawner/Player` in `world.tscn`: the
  addon's Player with this game's abilities, spellbook, fishing log, whistle and fish screens set on
  it, standing where players spawn; there is no separate player scene), the host owns the clock and weather (each on a `MultiplayerSynchronizer` in `world.tscn`), the NPCs,
  physics props and harvestables, the car and the horse hand their authority to whoever drives or
  rides, the little buddy to whoever carries it, and the training dummy's hit reactions travel by
  RPC so it flinches on every peer. The radio is the car's (`RadiOtPlayer3D` on `scenes/honda_crv.tscn`,
  heard around the car) and its station is the car's too (`GtaCar.radio_station`, replicated): the driver's
  next and previous station actions and the radial menu move it, and the car scene tunes its radio to it on
  every peer, so everyone in and around the car hears the driver's pick.

---

## Running and testing

Clone, then fetch the addons before opening the project:

```powershell
python tools/pull_addons.py
git config core.hooksPath .githooks   # once per clone, see below
```

`addons/` is git-ignored for everything the manifest manages, which is all of it, so a fresh clone has
empty addon folders until that runs. The third-party addons are `"third_party": true` entries, pinned to
a release tag or commit (GodotSteam, published only as an archive, to an `"archive"` URL), and
`push_addons.py` never touches them.

### The third-party addons are pulled too, and only ever pulled

None of them is developed here, so none is pushed to: `push_addons.py` skips a `third_party` entry, and a
change one of them needs goes upstream, never into a fork. Each is pinned in `tools/addons.json`: `gut`
and `dialogic` to a release tag, `midi` and `GPUTrail` to a commit (neither upstream tags releases), and
`godotsteam` to an archive of the commit on its `gdextension-plugin` branch that carries the 4.22.1 binaries,
since that plugin is published as a zip rather than at a repository root. All five must credit their
upstream rather than be republished as ours; they are credited in `CREDITS.md`.

Third-party assets are credited in [CREDITS.md](CREDITS.md).

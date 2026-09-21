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
- **The Guide** (`TalkingNpc` with a `Conversation` under it, `scenes/conversation.gd`,
  `resources/dialogues/qa_guide.dtl` and `guide.dch`, `resources/quests/qa_errand.tres`): stands by the
  spawn with an errand: talk to him, fell a tree with an axe and land a fish, and he pays three apples. The
  addon's NPC only offers Talk, holds the Player still and emits `talked_to`; the conversation itself is
  [Dialogic](https://github.com/dialogic-godot/dialogic), this project's. `Conversation` publishes the quest
  log to Dialogic as `{quest.<id>}` (`not_started`, `active`, `complete`) and `{objective.<id>}`, so the
  timeline branches on them, and the timeline drives the log back through Dialogic's signal event:
  `[signal arg="start_quest qa_errand"]`, `[signal arg="progress talk_guide"]`. The Action button advances
  the text, Start ends the conversation, and the bottom-action label reads Continue. `world.gd` reports the tree through every `Harvestable`'s `depleted` signal and
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
  `world_player.tscn` takes an `AudioStreamRandomizer` of the three AudioHero human whistles, so the same
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
  `PlayerSpawner` spawns `scenes/world_player.tscn` per peer, the host owns the clock, weather, NPCs,
  physics props and harvestables, the car and the horse hand their authority to whoever drives or
  rides, the little buddy to whoever carries it, and the training dummy's hit reactions travel by
  RPC so it flinches on every peer. The car radio's station is the car's (`GtaCar.radio_station`,
  replicated): the driver's next and previous station actions and the radial menu move it, and every
  rider's own radio follows it while they are in the car, so two players in one car hear one station.

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
upstream rather than be republished as ours.

| Addon | What it is | Author | Version | License (as recorded in folder) | Upstream |
| --- | --- | --- | --- | --- | --- |
| `addons/dialogic` | Dialogic 2, the dialogue system the Guide talks through | Jowan Spooner, Emi, Cake, Zak and contributors | 2.0 alpha 20 | MIT (`LICENSE` upstream) | https://github.com/dialogic-godot/dialogic |
| `addons/gut` | Godot Unit Test, the test runner the whole suite uses | Butch Wesley | 9.7.1 | MIT (`LICENSE.md`) | https://github.com/bitwes/Gut |
| `addons/midi` | Godot MIDI Player, the SoundFont synthesiser DOOM's music plays through | arlez80 (Yui Kinomoto) | 4.5.0 | MIT (upstream `readme.md`) | https://bitbucket.org/arlez80/godot-midi-player-g4 |
| `addons/godotsteam` | GodotSteam GDExtension Updater; the Steamworks binding itself is the GDExtension it updates | GP Garcia, Chris Ridenour and contributors | 4.22.1 | MIT (`license.md`) | https://codeberg.org/godotsteam/godotsteam (branch `gdextension-plugin`) |
| `addons/GPUTrail` | GPUTrail, used by the Le Lu trail and fire effects | celyk | 0.1 | MIT (`LICENSE`) | https://github.com/celyk/GPUTrail |

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
| `assets/audiohero` | AirReleasePressureDeflation PEHD032101, 032102 and 032103, the beach ball's deflation hiss; Whistles-HumanWhistles-C-62, C-63 and C-64, the whistle that calls a horse. Converted from the pack's MP3 (256 kbps for the deflations, 320 for the whistles) to Ogg Vorbis with `oggenc -q 6` | Audio Hero Inc. | Audio Hero End User License Agreement (`license.pdf`) | https://www.audiohero.com |
| `assets/ambientcg_com` | Grass001, Planks020, Wood073 PBR textures | ambientCG | not recorded - fill in | https://ambientcg.com |
| `assets/cgtrader/bilalcreation` | Duck Rigged Animated (low-poly) | Bilal Creation | not recorded - fill in | https://www.cgtrader.com/3d-models/animal/bird/duck-animated |
| `assets/cgtrader/remofair` | 32 Unique Stylized Cartoon Fish pack, all 126 maps at the resolution the pack ships (2048 for normal, roughness and metalness, 1024 for diffuse). The fishing scenes use five of the fish, Fish_08, 09, 10, 14 and 23; the rest are kept at full resolution so restoring them is not a job to do twice | remofair | not recorded - fill in | https://www.cgtrader.com/3d-models/animal/fish/32-unique-stylized-cartoon-fish-pack-game-ready |
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
| `assets/nasa` | Moon colour map (`lroc_color_poles_4k.png`, the LROC WAC mosaic) and normal map (`ldem_normal_4k.png`, derived from LOLA elevation by `tools/make_moon_textures.py`), both 4096x2048 | NASA's Scientific Visualization Studio | Public domain | https://svs.gsfc.nasa.gov/4720/ |
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
| `addons/GPUTrail` | GPUTrail3D (used by the Le Lu fire projectiles) | celyk | MIT (`LICENSE`) | https://github.com/celyk/GPUTrail |

Icons in the player addon HUD come from [Game-icons.net](https://game-icons.net) (**CC BY 3.0**, by
Lorc, Delapouite and contributors) and [Kenney](https://kenney.nl) input prompts (**CC0**).

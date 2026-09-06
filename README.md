![Preview](/godot-3d-player-controller-v3.png)

# godot-3d-player-controller-v3

Godot 3D Player Controller v3 uses [CharacterBody3D](//docs.godotengine.org/en/stable/classes/class_characterbody3d.html) and [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html).

Click [here](https://timothycope.com/godot-3d-player-controller-v3/) to play!

---

## Features

- **Player controller** (`addons/3d_player_controller`): `CharacterBody3D` + `AnimationTree` locomotion state machine (standing, sprinting, crouching, jumping, climbing, hanging, swimming/diving, sliding, ragdoll, sitting), first/third-person camera with interaction prompts, equipment/combat/inventory radial menu, stamina, paraglider and skateboard gadgets, multiplayer synchronizer and voice chat.
- **Vehicle**: a drivable Honda CR-V (`scenes/honda_crv.tscn`) with enter/exit animations and an in-car radio driven by the `radi_ot` addon (stations appear in the radial menu while driving).
- **NPCs**: `FollowerNpc` companions that follow the player over the navigation mesh, swim in water areas and react to physics impacts: a duck that respawns as a giant, and a "little buddy" that can be picked up and thrown.
- **World interactions**: choppable trees and mineable ore (`Harvestable`), a push button, a boat seat, warp zones, a kill zone that respawns the player, a moon with its own gravity, balloons to shoot, a bowling alley and a beach ball that floats.
- **Torch and fire**: a throwable torch (`Torch`) that ignites `weather_fx` grass fields and burnable grass; fires create thermal updrafts for the paraglider.
- **Weather, date and radio addons**: `weather_fx` (biomes, precipitation, wind, wildfire), `date_and_time` (clock and calendar HUD) and `radi_ot` (internet radio) work alongside each other and the player addon.
- **Steam lobby**: with GodotSteam present, the world auto-creates a public lobby (`scenes/world.gd`) and the title screen lists joinable lobbies.

---

## Running and testing

Open the project in Godot 4.8+ and run `scenes/main.tscn`, or run the world directly with `scenes/world.tscn`.

Run the full GUT suite headless (all six test directories):

```powershell
& 'C:\Godot\godot.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration,res://addons/3d_player_controller/tests,res://addons/weather_fx/tests,res://addons/date_and_time/tests,res://addons/radi_ot/tests -gexit
```

---

## Documentation

The general idea of this addon is that the [NodeStateMachine](/addons/3d_player_controller/scripts/state.gd) handles transitions between primary **Locomotion states** (e.g., "standing", "jumping", "climbing", "swimming"). Think of locomotion as what your character does with their lower body; only one locomotion state can be active at a time. Upper-body actions (like shooting or boxing) layer on top as secondary actions/sub-states.

The character's [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html) controls the actual animation playback by reading boolean state flags on the Player (e.g., `is_sprinting`, `is_climbing`).

### Getting Started

1. Download `3d_player_controller-v3.#.#.zip` from the [Releases](https://github.com/kirbycope/godot-3d-player-controller-v3/releases) page
1. Copy the contents of the zip (the `3d-player-controller` folder) to your project's `addons` folder.
1. Drag-and-drop the `addons/3d_player_controller/scenes/player.tscn` file from the FileSystem dock into your scene.

### Adding (and Preparing) New Animations

1. Go to https://www.mixamo.com/#/ and log in
   - To download files, you must be logged in
1. Navigate to https://www.mixamo.com/#/?page=1&query=Y+Bot&type=Character and select the "Y Bot"
   - When prompted, select the "USE THIS CHARACTER" button
1. Navigate to https://www.mixamo.com/#/?page=1&query=Y+Bot&type=Motion%2CMotionPack
1. Search for your desired animation and select it
   - For example, search `Idle` and select the 5th result
1. Select the "DOWNLOAD" button
1. Change the "Skin" to "Without Skin" and then select the "DOWNLOAD" button
1. Move the downloaded file to `/addons/3d_player_controller/assets/mixamo/animations/source/`
1. Open the project in a terminal
1. Run the following command: `blender --background --python tools/bake_root_motion.py`
   - This runs the [bake_root_motion](/tools/bake_root_motion.py) Blender/Python script to add a "root" bone and reparent the "hips" to it. The positional data is moved from "hips" to "root".
   - Once complete, the processed files are located in [/addons/3d_player_controller/assets/mixamo/animations/root_motion/](/addons/3d_player_controller/assets/mixamo/animations/root_motion/)
   - As an added benefit, the `.glb` files seem to be much smaller than the `.fbx` files.
1. Open the project in Godot
1. Select the new animation in the FileSystem (it will have the Scene icon)
1. Select the "Import" tab (near the top-left of the Editor, next to "Scene")
1. Change "Import As" to "Animation Library" and then select the "Reimport" button
1. Select the "Advanced..." button
1. Select "Skeleton3D" in the Scene tree
1. On the right side, under "Retarget > Bone Map", select "<empty>"
1. Select "Load..."
1. Find and select "C:/GitHub/godot-3d-player-controller-v3/addons/3d_player_controller/assets/mixamo/characters/mixamo_root_bone_map.tres" and then select the "Open" button
1. On the left, select "AnimationPlayer > mixamo_com"
1. On the right, change "Settings > Loop Mode" to "Linear"
   - Do not do this step for one-shot animations, like emotes
1. Select the "Reimport" button
1. Open the [Player scene](/addons/3d_player_controller/scenes/player.tscn)
1. Select the "AnimationPlayer" from the Scene tree
1. Select "Animation > Manage Animations"
1. Select the "Load Library" button
1. Find and select your animation under [/addons/3d_player_controller/assets/mixamo/animations/root_motion/](/addons/3d_player_controller/assets/mixamo/animations/root_motion/)
1. Select "Open"
1. Select "OK"
   - Your animation is now available to the AnimationPlayer and, by extension, the AnimationTree.

---

## GitHub Notes

### Releases

When code is merged into `main`, the GitHub Action at `.github/workflows/release-addon.yml` will:

1. Find the latest Git tag in the `vX.Y.Z` format
1. Increment the patch version (`Z`) by 1
1. Build `3d_player_controller-vX.Y.Z.zip` from `addons/3d_player_controller`
1. Publish a GitHub Release with the new tag and the zip as a downloadable asset

The first automated release starts from `v3.0.0` if no previous `v*` tag exists.


---

## Credits & Asset Attributions

Third-party assets under `assets/`, with the license as recorded in each folder's license/readme file. "not recorded" means the folder has no license file; fill it in from the source page.

| Folder | Asset | Author | License (as recorded in folder) | Source |
| --- | --- | --- | --- | --- |
| `assets/BinbunGrass` | Godot Grass Shader | Binbun (Binbun3D) | not recorded - fill in | https://binbun3d.itch.io/godot-grass |
| `assets/BinbunVFX` | Fire Effects | Binbun (Binbun3D) | not recorded - fill in | https://bun3d.com |
| `assets/BinbunVFX_Vol2` | Stylized Explosion FX | Binbun (Binbun3D) | CC0 (`ExplosionFX/license.txt`) | https://bun3d.com |
| `assets/ambientcg_com` | Grass001, Planks020, Wood073 PBR textures | ambientCG | not recorded - fill in | https://ambientcg.com |
| `assets/cgtrader/bilalcreation` | Duck Rigged Animated (low-poly) | Bilal Creation | not recorded - fill in | https://www.cgtrader.com/3d-models/animal/bird/duck-animated |
| `assets/cgtrader/honda_crv` | Wheel model and tyre texture | not recorded - fill in | not recorded - fill in | https://www.cgtrader.com |
| `assets/fonts` | FOT-Rodin Pro B, Rodin Italic | Fontworks | not recorded - fill in | not recorded - fill in |
| `assets/freesound` | fotballplast (117111) | blindmanonacid | not recorded - fill in (`.txt` is empty) | https://freesound.org/s/117111/ |
| `assets/freesound` | Single bowling pin knock (499788) | Rvgerxini | CC0 | https://freesound.org/s/499788/ |
| `assets/freesound` | Flag flicking on strong wind (570701) | Robinhood76 | CC BY-NC 4.0 | https://freesound.org/s/570701/ |
| `assets/freesound` | Parachute (72853) | Benboncan | CC BY 4.0 | https://freesound.org/s/72853/ |
| `assets/freesound` | IR Caravan Ballon POP (850645) | Sadiquecat | CC0 | https://freesound.org/s/850645/ |
| `assets/galacticlake` | Godot Plush (rigged, game ready) | GalacticLake | not recorded - fill in | https://galacticlake.itch.io/godot-plushie |
| `assets/godotshaders` | Wind Waker 2D water shader | not recorded - fill in | not recorded - fill in | https://godotshaders.com |
| `assets/gravitysound` | Animal SFX, Car Sound Effects, Skateboard SFX | Gravity Sound | not recorded - fill in | https://gravity-sound.itch.io/car-sound-effects, https://gravity-sound.itch.io/skateboard-sound-effects |
| `assets/justcreate3d` | Low Poly FPS Weapons Pack Lite, Stylized Tropical Island (boat) | JustCreate3D | not recorded - fill in | https://justcreate3d.itch.io/low-poly-fps-weapons-pack-lite |
| `assets/kenney_nl` | Prototype Textures, Road Textures | Kenney | CC0 (`License.txt`) | https://kenney.nl |
| `assets/libertycity` | 2024 Honda CR-V | not recorded - fill in | not recorded - fill in | https://libertycity.net |
| `assets/loop_box` | Ray mesh and line shader VFX | not recorded - fill in | not recorded - fill in | not recorded - fill in |
| `assets/n_hance_studio` | Stylized Craft Assets (ore), Stylized Newbie Weapons Pack | N-Hance Studio | not recorded - fill in | https://assetstore.unity.com/packages/3d/props/stylized-craft-assets-204769, https://assetstore.unity.com/packages/3d/props/weapons/stylized-newbie-weapons-pack-200709 |
| `assets/nasa` | Moon colour map, starmap | NASA SVS (normal map via NormalMap-Online) | not recorded - fill in (`credits.md` lists sources only) | https://svs.gsfc.nasa.gov/4720/, https://svs.gsfc.nasa.gov/vis/a000000/a003800/a003895/starmap_g8k.jpg |
| `assets/pixabay` | Arrow swish/twang, bow loading/release | djartmusic, freesound_community | not recorded - fill in | https://pixabay.com |
| `assets/pixelloops` | Explosion Sound Effects Pack | PixelLoops Audio | PixelLoops royalty-free license (`LICENSE.txt`) | https://pixelloops.com |
| `assets/quaternius/nature`, `assets/quaternius/logs` | Ultimate Stylized Nature Pack (trees, bark, logs) | Quaternius | not recorded - fill in (`README.txt` only lists minified files) | https://quaternius.com/packs/ultimatestylizednature.html |
| `assets/quaternius/paraglider` | Paraglider | Quaternius | CC0 1.0 (`License.txt`) | https://www.patreon.com/quaternius |
| `assets/sketchfab/bowling_pin` | Bowling Pin | MSerdar Tekin | CC BY 4.0 | https://sketchfab.com/3d-models/bowling-pin-028ccb945012460aa9056ffda5b53e20 |
| `assets/sketchfab/cc0_pinwheel` | CC0 - Pinwheel | plaggy | CC BY 4.0 (as recorded in `license.txt`) | https://sketchfab.com/3d-models/cc0-pinwheel-7abebdf80d2f4df2bb19ae5f2cf9a5c6 |
| `assets/sketchfab/fishing_rod` | Fishing Rod, Rigged and Animated | Ergin ERYILDIR | CC BY 4.0 | https://skfb.ly/oHVzO |
| `assets/sketchfab/knife` | Knife Low-poly | MaX3Dd | not recorded - fill in | https://sketchfab.com/3d-models/knife-low-poly-b864f3bbc333401d84dcadb94027d31d |
| `assets/sketchfab/skateboard` | Skateboard | Jamoues | CC BY 4.0 | https://sketchfab.com/3d-models/skateboard-0f7b8ea366654674b217a743959798e7 |
| `assets/tommusic` | Fantasy SFX (torch loop and impacts) | TomMusic | not recorded - fill in (`ReadMe.txt` has no license) | https://tommusic.itch.io/ |

Icons in the player addon HUD come from [Game-icons.net](https://game-icons.net) (**CC BY 3.0**, by Lorc, Delapouite and contributors) and [Kenney](https://kenney.nl) input prompts (**CC0**).

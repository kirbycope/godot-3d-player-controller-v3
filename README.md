![Preview](/godot-3d-player-controller-v3.png)

# godot-3d-player-controller-v3

Godot 3D Player Controller v3 uses [CharacterBody3D](//docs.godotengine.org/en/stable/classes/class_characterbody3d.html) and [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html).

Click [here](https://timothycope.com/godot-3d-player-controller-v3/) to play!

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


----

## AI Notes
- VSCode
   - Skills: [.agents/skills/](.agents/skills/) and/or [.github/skills/](.github/skills/)
   - MCP: [.vscode/mcp.json](.vscode/mcp.json)

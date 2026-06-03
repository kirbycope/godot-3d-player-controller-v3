# godot-3d-player-controller-v3
Godot 3D Player Controller v3

## Notes
- [Using AnimationTree - Root motion](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html#root-motion)
    - [Godot Third Person Shooter with high quality assets and lighting](https://github.com/godotengine/tps-demo)
- [Godot 3D Character Animation ](https://www.youtube.com/watch?v=fIHQ1fqxA_M)
    - https://github.com/Bonkahe/GodotEducationalBiped
- https://github.com/xDellTog/root-motion
- https://github.com/RichardPerry/Mixamo-Root


### Adding (and Preparing) New Animations
1. Go to https://www.mixamo.com/#/ and login
    - To download, you are required to login
1. Navigate to https://www.mixamo.com/#/?page=1&query=Y+Bot&type=Character and select the "Y Bot"
    - When prompted, select the "USE THIS CHARACTER" button
1. Navigate to https://www.mixamo.com/#/?page=1&query=Y+Bot&type=Motion%2CMotionPack
1. Search for your desired animation and select it
    - For example, search `Idle` and select the 5th result
1. Select the "DOWNLOAD" button
1. Change the "Skin" to "Without Skin" and then select the "DOWNLOAD" button
1. Move the downloaded file from your Downloads to [/addons/3d_player_controller/assets/mixamo/animations/source/](/addons/3d_player_controller/assets/mixamo/animations/source/)
1. Open the project using Terminal
1. Run the following command:
    ```
    blender --background --python tools/bake_root_motion.py
    ```
    - This runs the [bake_root_motion](/tools/bake_root_motion.py) Blender/Python script to add a "root" bone and reparent the "hips" to it. The positional data is moved from "hips" to "root".
    - Once complete, the processed files are located in [/addons/3d_player_controller/assets/mixamo/animations/root_motion/](/addons/3d_player_controller/assets/mixamo/animations/root_motion/)
    - As an added benefit the `.glb` files seem to be much smaller than the `.fbx` files!
1. Open the project in Godot
1. Select the new animation in the FileSystem (they will have the Scene icon)
1. Select the "Import" tab (near the top-left of the Editor, next to "Scene")
1. Change "Import As" to "Animation Library" and then select the "Reimport" button
1. Select the "Advanced..." button
1. Select "Skeleton3D" in the Scene tree
1. On the right side, under "Retarget > Bone Map", select "<empty>"
1. Select "Load..."
1. Find and select "C:/GitHub/godot-3d-player-controller-v3/addons/3d_player_controller/assets/mixamo/characters/mixamo_root_bone_map.tres" and then select the "Open" button
1. On the left, select "ANimationPlayer > mixamo_com"
1. On the right, change "Settings > Loop Mode" to "Linear"
    - Do not do this step for one-shot animations, like emotes
1. Select the "Reimport" button
1. Open the [Player scene](/addons/3d_player_controller/player.tscn)
1. Select the "AnimationPlayer" from the Scene tree
1. Select "Animation > Manage Animations"
1. Select the "Load Library" button
1. Find and select your animation under [/addons/3d_player_controller/assets/mixamo/animations/root_motion/](/addons/3d_player_controller/assets/mixamo/animations/root_motion/)
1. Select "Open"
1. Select "OK"
    - Your animation is now avaiable to the AnimationPLayer and by extension, then AnimationTree.

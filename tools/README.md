# Tools

## Blender Root Motion Bake

Script: `blender_bake_root_motion.py`

Purpose:
- Bake root-motion data in Blender once.
- Avoid runtime conversion cost from `addons/root_motion` on first game load.

### What it does

- Ensures root bone exists (default: `mixamorig_Root`).
- Reparents hips under root.
- For each hips location key:
  - Moves hips X/Z to root X/Z.
  - Keeps hips Y at or below rest Y.
  - Moves Y overflow above rest height to root Y.

### Run

1. Open Blender file with armature + actions.
2. Open Scripting tab.
3. Open `tools/blender_bake_root_motion.py`.
4. Edit `CONFIG` at top.
5. Run script.
6. Export GLB/FBX.

Output:
- Prints one line per action with `PROCESS` or `SKIP`.

### Important config

- `armature_name`: blank uses active armature.
- `process_all_actions`: process all actions in blend file.
- `action_name_filter`: optional substring filter.

### Godot side

After baking + export, disable runtime root-motion conversion for that model so load stays fast.

## Blender Bulk Root Motion Bake (FBX Folder)

Script: `blender_bulk_bake_root_motion.py`

Purpose:
- Batch-process `.fbx` files from a folder.
- Preserve folder structure in output folder.
- Support safe re-runs with skip modes.

### Run in bulk

```bash
blender --background --python tools/blender_bulk_bake_root_motion.py -- \
  --input-dir addons/3d_player_controller/assets/mixamo/animations \
  --output-dir addons/3d_player_controller/assets/mixamo/animations/root_motion \
  --recursive --skip-existing --skip-already-baked
```

Output:
- Prints one line per action with `PROCESS` or `SKIP`.
- Prints one line per FBX file with `PROCESS`, `SKIP`, or `ERROR`.

### Skip behavior

- `--skip-existing`: skip when destination FBX already exists.
- `--skip-already-baked`: imports source FBX and skips if it already appears baked
  (root exists, hips parented to root, hips X/Z keys already zeroed with matching root keys).

### Notes

- The `root_motion` output folder in the example command is not present by default.
  The bulk script creates it automatically.
- If you want in-place overwrite, set `--output-dir` to same path as `--input-dir`
  and do not use `--skip-existing`.

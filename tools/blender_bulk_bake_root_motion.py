"""
Bulk bake Mixamo-style root motion for FBX files in a folder.

Behavior mirrors addons/root_motion add_root_bone position split:
- Ensure root bone exists.
- Parent hips under root.
- Move hips X/Z to root X/Z per key.
- Move only Y above hips rest height to root Y.
- Keep hips local X/Z at 0.

Run (example):
blender --background --python tools/blender_bulk_bake_root_motion.py -- \
  --input-dir addons/3d_player_controller/assets/mixamo/animations \
  --output-dir addons/3d_player_controller/assets/mixamo/animations/root_motion \
  --recursive --skip-existing --skip-already-baked
"""

import argparse
import os
from pathlib import Path

import bpy


def log(verbose, message):
    if verbose:
        print(f"[bulk_bake_root_motion] {message}")


def find_bone_case_insensitive(arm_data, name_hint):
    lower_hint = name_hint.lower()
    for bone in arm_data.bones:
        if lower_hint in bone.name.lower():
            return bone.name
    return None


def get_or_create_fcurve(action, data_path, array_index, group_name):
    fc = action.fcurves.find(data_path, index=array_index)
    if fc is None:
        fc = action.fcurves.new(data_path=data_path, index=array_index, action_group=group_name)
    return fc


def eval_loc(action, data_path, frame):
    x = action.fcurves.find(data_path, index=0)
    y = action.fcurves.find(data_path, index=1)
    z = action.fcurves.find(data_path, index=2)
    if x is None or y is None or z is None:
        return None
    return (x.evaluate(frame), y.evaluate(frame), z.evaluate(frame))


def remove_keyframe_at_frame(fc, frame, eps=1e-5):
    for kp in fc.keyframe_points:
        if abs(kp.co.x - frame) < eps:
            fc.keyframe_points.remove(kp)
            return True
    return False


def clear_vector_keys_at_frame(action, data_path, frame, size):
    for idx in range(size):
        fc = action.fcurves.find(data_path, index=idx)
        if fc is not None:
            remove_keyframe_at_frame(fc, frame)


def insert_vector_key(action, data_path, frame, values, group_name):
    for idx, val in enumerate(values):
        fc = get_or_create_fcurve(action, data_path, idx, group_name)
        fc.keyframe_points.insert(frame, val, options={"FAST"})


def collect_frames_from_vector_fcurves(action, data_path, size):
    frames = set()
    for idx in range(size):
        fc = action.fcurves.find(data_path, index=idx)
        if not fc:
            continue
        for kp in fc.keyframe_points:
            frames.add(float(kp.co.x))
    return sorted(frames)


def ensure_root_and_parent(arm_obj, root_name, hips_name):
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    ebones = arm_obj.data.edit_bones
    root = ebones.get(root_name)
    if root is None:
        root = ebones.new(root_name)
        root.head = (0.0, 0.0, 0.0)
        root.tail = (0.0, 0.1, 0.0)

    hips = ebones.get(hips_name)
    if hips is None:
        bpy.ops.object.mode_set(mode="OBJECT")
        raise RuntimeError(f"Hips bone not found in edit bones: {hips_name}")

    if hips.parent != root:
        hips.parent = root

    bpy.ops.object.mode_set(mode="OBJECT")


def bake_action(action, hips_name, root_name, hips_rest_y):
    hips_loc_path = f'pose.bones["{hips_name}"].location'
    root_loc_path = f'pose.bones["{root_name}"].location'

    frames = collect_frames_from_vector_fcurves(action, hips_loc_path, 3)
    if not frames:
        return -1

    inserted = 0
    for frame in frames:
        hips_loc = eval_loc(action, hips_loc_path, frame)
        if hips_loc is None:
            continue

        hx, hy, hz = hips_loc
        root_y = 0.0
        hips_y = hy
        if hy > hips_rest_y:
            diff = hy - hips_rest_y
            root_y = diff
            hips_y -= diff

        root_loc = (hx, root_y, hz)
        new_hips_loc = (0.0, hips_y, 0.0)

        clear_vector_keys_at_frame(action, root_loc_path, frame, 3)
        clear_vector_keys_at_frame(action, hips_loc_path, frame, 3)
        insert_vector_key(action, root_loc_path, frame, root_loc, root_name)
        insert_vector_key(action, hips_loc_path, frame, new_hips_loc, hips_name)
        inserted += 1

    for fc in action.fcurves:
        fc.update()

    return inserted


def action_has_root_motion_keys(action, root_name):
    root_loc_path = f'pose.bones["{root_name}"].location'
    frames = collect_frames_from_vector_fcurves(action, root_loc_path, 3)
    return len(frames) > 0


def action_looks_baked(action, hips_name, root_name, eps=1e-4):
    hips_loc_path = f'pose.bones["{hips_name}"].location'
    root_loc_path = f'pose.bones["{root_name}"].location'

    hips_frames = collect_frames_from_vector_fcurves(action, hips_loc_path, 3)
    if not hips_frames:
        return True

    root_frames = set(collect_frames_from_vector_fcurves(action, root_loc_path, 3))
    if not root_frames:
        return False

    for frame in hips_frames:
        if frame not in root_frames:
            return False
        loc = eval_loc(action, hips_loc_path, frame)
        if loc is None:
            continue
        if abs(loc[0]) > eps or abs(loc[2]) > eps:
            return False

    return True


def armature_looks_baked(arm_obj, root_name, hips_name):
    arm_data = arm_obj.data
    root_bone = arm_data.bones.get(root_name)
    hips_bone = arm_data.bones.get(hips_name)
    if root_bone is None or hips_bone is None:
        return False
    if hips_bone.parent != root_bone:
        return False

    checked = 0
    for action in bpy.data.actions:
        hips_loc_path = f'pose.bones["{hips_name}"].location'
        if not collect_frames_from_vector_fcurves(action, hips_loc_path, 3):
            continue
        checked += 1
        if not action_looks_baked(action, hips_name, root_name):
            return False

    if checked == 0:
        return action_has_root_motion_keys(next(iter(bpy.data.actions), None), root_name) if bpy.data.actions else False
    return True


def pick_armature(imported_objects):
    armatures = [obj for obj in imported_objects if obj.type == "ARMATURE"]
    if not armatures:
        return None
    armatures.sort(key=lambda o: len(o.data.bones), reverse=True)
    return armatures[0]


def import_fbx(filepath):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(filepath))
    after = set(bpy.data.objects)
    return list(after - before)


def export_fbx(filepath, objects_to_export):
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in objects_to_export:
        if obj.name in bpy.data.objects:
            obj.select_set(True)

    Path(filepath).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=str(filepath),
        use_selection=True,
        add_leaf_bones=False,
        bake_anim=True,
    )


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bake_single_fbx(src_path, dst_path, root_name, hips_hint, skip_already_baked, verbose):
    clear_scene()
    imported_objects = import_fbx(src_path)
    if not imported_objects:
        return (False, "imported no objects")

    arm_obj = pick_armature(imported_objects)
    if arm_obj is None:
        return (False, "no armature found")

    hips_name = find_bone_case_insensitive(arm_obj.data, hips_hint)
    if not hips_name:
        return (False, "hips bone not found")

    if skip_already_baked and armature_looks_baked(arm_obj, root_name, hips_name):
        return (False, "already baked (detected in source)")

    ensure_root_and_parent(arm_obj, root_name, hips_name)

    hips_bone = arm_obj.data.bones.get(hips_name)
    hips_rest_y = hips_bone.matrix_local.to_translation().y

    total_actions = 0
    total_keys = 0
    for action in bpy.data.actions:
        total_actions += 1
        keys = bake_action(action, hips_name, root_name, hips_rest_y)
        if keys < 0:
            print(f"[bulk_bake_root_motion] SKIP action '{action.name}' in '{src_path.name}' (no hips location keys)")
            continue

        total_keys += keys
        print(f"[bulk_bake_root_motion] PROCESS action '{action.name}' in '{src_path.name}' (hips keys migrated: {keys})")

    log(verbose, f"Processed actions={total_actions} keys={total_keys} for {src_path.name}")
    export_fbx(dst_path, imported_objects)
    return (True, f"exported actions={total_actions} keys={total_keys}")


def parse_args():
    argv = []
    if "--" in os.sys.argv:
        argv = os.sys.argv[os.sys.argv.index("--") + 1 :]

    parser = argparse.ArgumentParser(description="Bulk bake root motion for FBX files.")
    parser.add_argument("--input-dir", required=True, help="Folder to scan for .fbx files.")
    parser.add_argument("--output-dir", required=True, help="Folder to write baked .fbx files.")
    parser.add_argument("--recursive", action="store_true", help="Scan subfolders recursively.")
    parser.add_argument("--root-bone-name", default="mixamorig_Root", help="Root bone name.")
    parser.add_argument("--hips-name-hint", default="Hips", help="Substring used to find hips bone.")
    parser.add_argument("--skip-existing", action="store_true", help="Skip when output file already exists.")
    parser.add_argument("--skip-already-baked", action="store_true", help="Skip source file when root-motion bake is already present.")
    parser.add_argument("--verbose", action="store_true", help="Verbose logs.")
    return parser.parse_args(argv)


def gather_fbx_files(input_dir, recursive):
    if recursive:
        return sorted(input_dir.rglob("*.fbx"))
    return sorted(input_dir.glob("*.fbx"))


def main():
    args = parse_args()

    input_dir = Path(args.input_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()

    if not input_dir.exists() or not input_dir.is_dir():
        raise RuntimeError(f"Input directory not found: {input_dir}")

    files = gather_fbx_files(input_dir, args.recursive)
    if not files:
        print("[bulk_bake_root_motion] No .fbx files found.")
        return

    processed = 0
    skipped = 0
    failed = 0

    for src_path in files:
        rel = src_path.relative_to(input_dir)
        dst_path = output_dir / rel

        if args.skip_existing and dst_path.exists():
            skipped += 1
            print(f"[bulk_bake_root_motion] SKIP file '{src_path}' (output exists: '{dst_path}')")
            continue

        try:
            wrote, detail = bake_single_fbx(
                src_path=src_path,
                dst_path=dst_path,
                root_name=args.root_bone_name,
                hips_hint=args.hips_name_hint,
                skip_already_baked=args.skip_already_baked,
                verbose=args.verbose,
            )
            if wrote:
                processed += 1
                print(f"[bulk_bake_root_motion] PROCESS file '{src_path}' -> '{dst_path}' ({detail})")
            else:
                skipped += 1
                print(f"[bulk_bake_root_motion] SKIP file '{src_path}' ({detail})")
        except Exception as exc:
            failed += 1
            print(f"[bulk_bake_root_motion] ERROR {src_path}: {exc}")

    print(
        "[bulk_bake_root_motion] Done. "
        f"found={len(files)} processed={processed} skipped={skipped} failed={failed}"
    )


if __name__ == "__main__":
    main()

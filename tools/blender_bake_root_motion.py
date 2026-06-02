"""
Bake Mixamo-style root motion in Blender, matching addons/root_motion runtime behavior.

What this does (default):
- Ensures a root bone exists (default name: mixamorig_Root).
- Reparents hips bone under root.
- For each action and each hips location keyframe:
  - Moves hips X/Z to root X/Z.
  - Keeps hips Y at/below rest Y.
  - If hips Y rises above rest Y, overflow Y is moved to root Y.

Run from Blender:
- Scripting tab -> open this file -> Run Script.
- Configure options in CONFIG below.
"""

import bpy


CONFIG = {
    "armature_name": "",  # Empty means use active armature object
    "root_bone_name": "mixamorig_Root",
    "hips_name_hint": "Hips",
    "process_all_actions": True,
    "action_name_filter": "",  # Optional substring filter, case-insensitive
    "verbose": True,
}


def log(msg):
    if CONFIG["verbose"]:
        print(f"[bake_root_motion] {msg}")


def get_target_armature():
    if CONFIG["armature_name"]:
        obj = bpy.data.objects.get(CONFIG["armature_name"])
        if not obj or obj.type != "ARMATURE":
            raise RuntimeError(f"Armature not found or invalid: {CONFIG['armature_name']}")
        return obj

    obj = bpy.context.active_object
    if not obj or obj.type != "ARMATURE":
        raise RuntimeError("Select an Armature or set CONFIG['armature_name'].")
    return obj


def find_bone_case_insensitive(arm_data, name_hint):
    lower_hint = name_hint.lower()
    for bone in arm_data.bones:
        if lower_hint in bone.name.lower():
            return bone.name
    return None


def ensure_root_and_parent(arm_obj, root_name, hips_name):
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    ebones = arm_obj.data.edit_bones
    root = ebones.get(root_name)
    if root is None:
        root = ebones.new(root_name)
        root.head = (0.0, 0.0, 0.0)
        root.tail = (0.0, 0.1, 0.0)
        log(f"Created root bone: {root_name}")
    else:
        log(f"Root bone already exists: {root_name}")

    hips = ebones.get(hips_name)
    if hips is None:
        bpy.ops.object.mode_set(mode="OBJECT")
        raise RuntimeError(f"Hips bone not found in edit bones: {hips_name}")

    if hips.parent != root:
        hips.parent = root
        log(f"Parented hips '{hips_name}' under root '{root_name}'")

    bpy.ops.object.mode_set(mode="OBJECT")


def iter_target_actions(arm_obj):
    if CONFIG["process_all_actions"]:
        for action in bpy.data.actions:
            if CONFIG["action_name_filter"] and CONFIG["action_name_filter"].lower() not in action.name.lower():
                continue
            yield action
        return

    if arm_obj.animation_data and arm_obj.animation_data.action:
        action = arm_obj.animation_data.action
        if CONFIG["action_name_filter"] and CONFIG["action_name_filter"].lower() not in action.name.lower():
            return
        yield action


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
    for i, kp in enumerate(fc.keyframe_points):
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


def bake_action(arm_obj, action, hips_name, root_name, hips_rest_y):
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

        # Match Godot plugin behavior for position split.
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


def main():
    arm_obj = get_target_armature()
    arm_data = arm_obj.data

    hips_name = find_bone_case_insensitive(arm_data, CONFIG["hips_name_hint"])
    if not hips_name:
        raise RuntimeError("Could not find hips bone. Update CONFIG['hips_name_hint'].")

    ensure_root_and_parent(arm_obj, CONFIG["root_bone_name"], hips_name)

    hips_bone = arm_data.bones.get(hips_name)
    hips_rest_y = hips_bone.matrix_local.to_translation().y

    if not arm_obj.animation_data:
        arm_obj.animation_data_create()

    total_actions = 0
    total_keys = 0
    for action in iter_target_actions(arm_obj):
        total_actions += 1
        keys = bake_action(arm_obj, action, hips_name, CONFIG["root_bone_name"], hips_rest_y)
        if keys < 0:
            print(f"[bake_root_motion] SKIP action '{action.name}' (no hips location keys)")
            continue

        total_keys += keys
        print(f"[bake_root_motion] PROCESS action '{action.name}' (hips keys migrated: {keys})")

    log(f"Done. Actions: {total_actions}, hips keys migrated: {total_keys}")


if __name__ == "__main__":
    main()

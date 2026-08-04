import bpy

# Change this to match your collection's name in the Outliner
COLLECTION_NAME = "Collection"
RATIO = 0.65

collection = bpy.data.collections.get(COLLECTION_NAME)

if collection:
    for obj in collection.all_objects:
        # Process only visible mesh objects
        if obj.type == 'MESH':
            # Add Decimate modifier
            mod = obj.modifiers.new(name="Auto_Decimate", type='DECIMATE')
            mod.decimate_type = 'COLLAPSE'
            mod.ratio = RATIO
            
            # Select object and set as active to apply the modifier
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            
            # Apply the modifier immediately
            bpy.ops.object.modifier_apply(modifier=mod.name)
            
    print(f"Successfully decimated all meshes in '{COLLECTION_NAME}' to ratio {RATIO}.")
else:
    print(f"Collection '{COLLECTION_NAME}' not found.")

# Run this in Blender on the script tab

"""
One-off repair for armor pieces built before armor.py baked object offsets into the mesh: pieces whose first part
carried an offset lost it when the presentation layout overwrote their location (the rogue pauldron sat at the feet,
the boots were shifted 10 cm). Moves those offsets into the mesh data so every piece's local space is the fitting space.

    blender -b Art/Blender/MedievalDarkFantasyKit.blend --python Scripts/blender_kit/fix_armor_offsets.py
Safe to run once; it records the fix on the object ("offset_baked") and skips already repaired pieces.
"""

import bpy
from mathutils import Matrix, Vector

OFFSETS = {
    "SK_Rogue_Shoulder_01": (-0.2, 0.0, 1.42),
    "SK_Rogue_Boots_01": (-0.1, 0.0, 0.0),
    "SK_Mage_Boots_01": (-0.1, 0.0, 0.0),
}

for name, offset in OFFSETS.items():
    obj = bpy.data.objects.get(name)
    if obj is None or obj.get("offset_baked"):
        continue
    obj.data.transform(Matrix.Translation(Vector(offset)))
    obj["offset_baked"] = True
    for child in obj.children:
        child.matrix_parent_inverse = Matrix.Translation(Vector(offset)).inverted() @ child.matrix_parent_inverse
    print("[fix] baked offset", name, offset)

bpy.ops.wm.save_mainfile()

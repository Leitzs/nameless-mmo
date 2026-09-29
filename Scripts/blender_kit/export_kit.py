"""
Exports the Medieval Dark Fantasy kit's environment and prop meshes for Unreal.

Run inside Blender with Art/Blender/MedievalDarkFantasyKit.blend open (Scripting tab, or exec() it). Writes:
  Art/Export/Kit/<Collection>/<SM_Name>.fbx   one file per asset, pivot at the asset origin, with its UCX_ collision
                                              and any FX_*/Gate_* part meshes (Unreal merges them on import)
  Art/Export/Kit/materials.json               a flat approximation of every kit material (the node graphs are
                                              procedural and do not survive FBX): base color, roughness,
                                              metallic, emissive color and strength.
Then run Scripts/import_kit.py in the Unreal editor.
"""

import json
import os

import bpy
from mathutils import Vector

COLLECTIONS = ["ENV_Buildings", "ENV_Castle", "ENV_Dungeon", "ENV_Nature", "ENV_Roads", "ENV_Ruins", "PROP_Magic", "PROP_Village",
               "ITEM_Staffs", "ITEM_Weapons"]
HELPER_PREFIXES = ("UCX_", "FX_", "Grip_", "Hang_", "Gate_")
ROOT = os.path.normpath(os.path.join(os.path.dirname(bpy.data.filepath), "..", "Export", "Kit"))


# --- Material approximation ------------------------------------------------------------------------------------------

def _color(value):
    return [float(value[0]), float(value[1]), float(value[2])]


def _average(colors):
    return [sum(c[i] for c in colors) / len(colors) for i in range(3)] if colors else None


def evaluate_color(socket, depth=0):
    """Rough average color flowing into a socket: ramps average their stops, mixes blend their inputs."""
    if depth > 12:
        return None
    if not socket.is_linked:
        value = socket.default_value
        return _color(value) if hasattr(value, "__len__") and len(value) >= 3 else [float(value)] * 3
    node = socket.links[0].from_node
    if node.type == "VALTORGB":
        return _average([_color(e.color) for e in node.color_ramp.elements])
    if node.type == "RGB":
        return _color(node.outputs[0].default_value)
    if node.type == "MIX":
        a = next((s for s in node.inputs if s.name == "A" and s.enabled), None)
        b = next((s for s in node.inputs if s.name == "B" and s.enabled), None)
        factor = next((s for s in node.inputs if s.name == "Factor" and s.enabled), None)
        ca, cb = (evaluate_color(a, depth + 1) if a else None), (evaluate_color(b, depth + 1) if b else None)
        t = 0.5 if factor is None or factor.is_linked else float(factor.default_value if not hasattr(factor.default_value, "__len__") else factor.default_value[0])
        if ca and cb:
            return [ca[i] * (1 - t) + cb[i] * t for i in range(3)]
        return ca or cb
    for inp in node.inputs:
        if inp.is_linked or inp.type == "RGBA":
            c = evaluate_color(inp, depth + 1)
            if c:
                return c
    return None


def evaluate_scalar(socket, fallback):
    if not socket.is_linked:
        return float(socket.default_value)
    node = socket.links[0].from_node
    if node.type == "VALTORGB":
        return sum(e.color[0] for e in node.color_ramp.elements) / len(node.color_ramp.elements)
    if node.type == "MAP_RANGE":
        return (node.inputs["To Min"].default_value + node.inputs["To Max"].default_value) * 0.5
    return fallback


def describe_material(mat):
    info = {"base": list(mat.diffuse_color[:3]), "roughness": 0.8, "metallic": 0.0, "emissive": [0.0, 0.0, 0.0], "emissive_strength": 0.0, "opacity": 1.0}
    if not mat.use_nodes:
        return info
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    emission = next((n for n in mat.node_tree.nodes if n.type == "EMISSION"), None)
    if bsdf:
        info["base"] = evaluate_color(bsdf.inputs["Base Color"]) or info["base"]
        info["roughness"] = evaluate_scalar(bsdf.inputs["Roughness"], 0.7)
        info["metallic"] = evaluate_scalar(bsdf.inputs["Metallic"], 0.0)
        info["opacity"] = evaluate_scalar(bsdf.inputs["Alpha"], 1.0)
        strength = bsdf.inputs.get("Emission Strength")
        color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if strength is not None and color is not None:
            info["emissive"] = evaluate_color(color) or info["emissive"]
            info["emissive_strength"] = evaluate_scalar(strength, 1.0)
    elif emission:
        info["base"] = [0.0, 0.0, 0.0]
        info["emissive"] = evaluate_color(emission.inputs["Color"]) or [1.0, 1.0, 1.0]
        info["emissive_strength"] = evaluate_scalar(emission.inputs["Strength"], 1.0)
    # Textured materials from nature_hq.py: alpha cards (foliage) and tiling bark with a normal map.
    images = [n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
    if images:
        info["texture"] = bpy.path.abspath(images[0].filepath_raw or images[0].filepath)
        normal = next((i for i in images if i.name.endswith("_N")), None)
        if normal is not None:
            info["normal_texture"] = bpy.path.abspath(normal.filepath_raw or normal.filepath)
        info["card"] = bool(mat.get("kit_card"))
        info["bark"] = bool(mat.get("kit_bark"))
        if mat.get("kit_tint"):
            info["base"] = list(mat["kit_tint"])
    return info


# --- Mesh export -----------------------------------------------------------------------------------------------------

def asset_parts(collection):
    """{asset name: [asset object, helpers...]} for the collection's top-level SM_ meshes."""
    objects = list(collection.all_objects)
    assets = {}
    for obj in objects:
        if obj.type == "MESH" and obj.name.startswith("SM_") and "_LOD" not in obj.name:
            assets[obj.name] = [obj]
    for obj in objects:
        if obj.type != "MESH" or not obj.name.startswith(HELPER_PREFIXES):
            continue
        for name in sorted(assets, key=len, reverse=True):
            if obj.name.endswith("_" + name) or obj.name.startswith("UCX_" + name + "_"):
                assets[name].append(obj)
                break
    return assets


def export_asset(name, parts, folder):
    root = parts[0]
    offset = root.matrix_world.translation.copy()
    moved = [p for p in parts if p.parent is None or p.parent not in parts]
    for part in moved:
        part.matrix_world.translation -= offset
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.hide_set(False)
        part.hide_viewport = False
        part.select_set(True)
    bpy.context.view_layer.objects.active = root
    try:
        bpy.ops.export_scene.fbx(filepath=os.path.join(folder, name + ".fbx"), use_selection=True, object_types={"MESH"},
                                 apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", use_mesh_modifiers=True,
                                 mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False, axis_forward="-Y", axis_up="Z")
    finally:
        for part in moved:
            part.matrix_world.translation += offset


def main():
    os.makedirs(ROOT, exist_ok=True)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    manifest = {}
    for cname in COLLECTIONS:
        folder = os.path.join(ROOT, cname)
        os.makedirs(folder, exist_ok=True)
        for name, parts in asset_parts(bpy.data.collections[cname]).items():
            export_asset(name, parts, folder)
            size = parts[0].dimensions
            manifest[name] = {"collection": cname, "size_m": [round(size.x, 3), round(size.y, 3), round(size.z, 3)]}
    materials = {m.name: describe_material(m) for m in bpy.data.materials if m.users}
    with open(os.path.join(ROOT, "materials.json"), "w") as f:
        json.dump({"materials": materials, "assets": manifest}, f, indent=1)
    print("Exported %d assets and %d materials to %s" % (len(manifest), len(materials), ROOT))


main()

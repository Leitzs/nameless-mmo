"""Shared helpers for the Medieval Dark Fantasy asset kit (run inside Blender via exec).

Scale: 1 Blender unit = 1 m. Every asset is built at the world origin, finalized (transforms applied,
normals recalculated, origin at the base) and then moved into its showcase slot.
"""
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, Euler, noise

COLLECTIONS = [
    "ENV_Buildings", "ENV_Castle", "ENV_Dungeon", "ENV_Nature", "ENV_Roads", "ENV_Ruins", "ENV_Sky",
    "PROP_Village", "PROP_Magic", "ITEM_Weapons", "ITEM_Staffs",
    "CHAR_Base", "CHAR_NPC", "CHAR_Creatures", "CHAR_Armor_Mage", "CHAR_Armor_Rogue",
    "MAT_Master", "_Presentation",
]


# ---------------------------------------------------------------------------------------------------------------
# Scene organization

def collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def ensure_collections():
    for name in COLLECTIONS:
        collection(name)


def link_only(obj, col_name):
    col = collection(col_name)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    for child in obj.children:
        link_only(child, col_name)


def remove_asset(name):
    """Deletes an asset root and all of its children so a build step can be rerun."""
    obj = bpy.data.objects.get(name)
    if obj is None:
        return
    for child in list(obj.children_recursive):
        bpy.data.objects.remove(child, do_unlink=True)
    bpy.data.objects.remove(obj, do_unlink=True)


# ---------------------------------------------------------------------------------------------------------------
# Materials (procedural PBR, Principled BSDF looked up by type)

def _bsdf(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _new_material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type not in ("BSDF_PRINCIPLED", "OUTPUT_MATERIAL"):
            nt.nodes.remove(n)
    return mat, nt, _bsdf(mat)


def _ramp(nt, stops, x=-400, y=0):
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (x, y)
    els = ramp.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
    for pos, col in stops[1:]:
        e = els.new(pos)
        e.color = (*col, 1)
    return ramp


def _coords(nt, scale=1.0, stretch=(1, 1, 1)):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale * stretch[0], scale * stretch[1], scale * stretch[2])
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    return mp.outputs["Vector"]


def _noise(nt, vec, scale, detail=8.0, rough=0.6):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    nt.links.new(vec, n.inputs["Vector"])
    return n


def _bump(nt, height, strength, distance=0.02):
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    b.inputs["Distance"].default_value = distance
    nt.links.new(height, b.inputs["Height"])
    return b.outputs["Normal"]


def _mix(nt, a, b, fac, mode="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = mode
    nt.links.new(fac, m.inputs["Factor"])
    for sock, val in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(val, tuple):
            sock.default_value = (*val, 1)
        else:
            nt.links.new(val, sock)
    return m.outputs[2]


def _math(nt, op, a, b=None):
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            m.inputs[i].default_value = v
        else:
            nt.links.new(v, m.inputs[i])
    return m.outputs[0]


def _grime(nt, vec, color_socket, amount=0.35, dark=(0.02, 0.018, 0.015)):
    """Darkens cavities/lower areas with large-scale dirt noise."""
    g = _noise(nt, vec, 1.6, 6, 0.7)
    r = _ramp(nt, [(0.45, (0, 0, 0)), (0.75, (1, 1, 1))])
    nt.links.new(g.outputs["Fac"], r.inputs["Fac"])
    fac = _math(nt, "MULTIPLY", r.outputs["Color"], amount)
    return _mix(nt, color_socket, dark, fac)


def mat_wood(name, light, dark, grain_scale=6.0, rough=0.78, stretch=(1, 1, 8)):
    """Weathered wood: long grain streaks along the axis with the small stretch value (object space)."""
    mat, nt, b = _new_material(name)
    vec = _coords(nt, grain_scale, stretch)
    grain = _noise(nt, vec, 1.0, 12, 0.72)
    ramp = _ramp(nt, [(0.3, dark), (0.5, tuple((l + d) / 2 for l, d in zip(light, dark))), (0.68, light)])
    nt.links.new(grain.outputs["Fac"], ramp.inputs["Fac"])
    # Fine fibre streaks + large tone variation between boards.
    fibre = _noise(nt, _coords(nt, grain_scale * 6, stretch), 1.0, 4, 0.5)
    col = _mix(nt, ramp.outputs["Color"], dark, _math(nt, "MULTIPLY", _math(nt, "GREATER_THAN", fibre.outputs["Fac"], 0.62), 0.5))
    tone = _noise(nt, _coords(nt, 1.0), 0.8, 2, 0.4)
    col = _mix(nt, col, tuple(c * 0.7 for c in light), _math(nt, "MULTIPLY", tone.outputs["Fac"], 0.25))
    col = _grime(nt, _coords(nt, 1.0), col, 0.25)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(_math(nt, "ADD", rough - 0.08, _math(nt, "MULTIPLY", grain.outputs["Fac"], 0.16)), b.inputs["Roughness"])
    h = _math(nt, "ADD", grain.outputs["Fac"], _math(nt, "MULTIPLY", fibre.outputs["Fac"], 0.6))
    nt.links.new(_bump(nt, h, 0.25, 0.006), b.inputs["Normal"])
    return mat


def mat_stone(name, base, var, scale=3.0, rough=0.9, moss=0.0, blocks=False):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE" if blocks else "F1"
    vor.inputs["Scale"].default_value = scale
    nt.links.new(vec, vor.inputs["Vector"])
    n = _noise(nt, vec, scale * 4, 10, 0.65)
    ramp = _ramp(nt, [(0.2, var), (0.6, base), (0.9, tuple(min(1, c * 1.25) for c in base))])
    nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]
    edge_src = vor.outputs["Distance"]
    if blocks:
        edge = _ramp(nt, [(0.0, (0, 0, 0)), (0.06, (1, 1, 1))])
        nt.links.new(edge_src, edge.inputs["Fac"])
        col = _mix(nt, col, (0.03, 0.028, 0.025), _math(nt, "SUBTRACT", 1.0, edge.outputs["Color"]))
        height = _math(nt, "ADD", edge.outputs["Color"], _math(nt, "MULTIPLY", n.outputs["Fac"], 0.4))
    else:
        height = _math(nt, "ADD", edge_src, _math(nt, "MULTIPLY", n.outputs["Fac"], 0.8))
    if moss > 0:
        # Moss on upward-facing surfaces.
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
        mn = _noise(nt, vec, 2.5, 8, 0.7)
        up = _math(nt, "MULTIPLY", sep.outputs["Z"], mn.outputs["Fac"])
        mr = _ramp(nt, [(0.55 - moss * 0.3, (0, 0, 0)), (0.62 - moss * 0.3, (1, 1, 1))])
        nt.links.new(up, mr.inputs["Fac"])
        moss_col = _mix(nt, (0.035, 0.06, 0.012), (0.08, 0.1, 0.02), mn.outputs["Fac"])
        col = _mix(nt, col, moss_col, mr.outputs["Color"])
    col = _grime(nt, vec, col, 0.4)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    nt.links.new(_bump(nt, height, 0.6, 0.03), b.inputs["Normal"])
    return mat


def mat_plaster(name, color=(0.42, 0.37, 0.29)):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    n = _noise(nt, vec, 3.0, 12, 0.7)
    ramp = _ramp(nt, [(0.3, tuple(c * 0.55 for c in color)), (0.55, color), (0.8, tuple(min(1, c * 1.1) for c in color))])
    nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"])
    col = _grime(nt, vec, ramp.outputs["Color"], 0.55, (0.05, 0.04, 0.03))
    # Vertical streaks of water damage.
    streak = _noise(nt, _coords(nt, 1.0, (6, 6, 0.4)), 4, 4, 0.5)
    col = _mix(nt, col, (0.12, 0.1, 0.07), _math(nt, "MULTIPLY", streak.outputs["Fac"], 0.35))
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.93
    nt.links.new(_bump(nt, n.outputs["Fac"], 0.4, 0.02), b.inputs["Normal"])
    return mat


def mat_metal(name, color, rough=0.45, rust=0.0):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    n = _noise(nt, vec, 25, 8, 0.6)
    scratches = _noise(nt, _coords(nt, 1.0, (1, 1, 40)), 30, 2, 0.4)
    col = _mix(nt, color, tuple(c * 0.6 for c in color), n.outputs["Fac"])
    metal = b.inputs["Metallic"]
    metal.default_value = 1.0
    rough_s = _math(nt, "ADD", rough - 0.1, _math(nt, "MULTIPLY", scratches.outputs["Fac"], 0.25))
    if rust > 0:
        rn = _noise(nt, vec, 4, 12, 0.7)
        rr = _ramp(nt, [(0.62 - rust * 0.25, (0, 0, 0)), (0.7 - rust * 0.25, (1, 1, 1))])
        nt.links.new(rn.outputs["Fac"], rr.inputs["Fac"])
        rust_col = _mix(nt, (0.07, 0.03, 0.015), (0.16, 0.065, 0.028), n.outputs["Fac"])
        col = _mix(nt, col, rust_col, rr.outputs["Color"])
        inv = _math(nt, "SUBTRACT", 1.0, rr.outputs["Color"])
        nt.links.new(inv, metal)
        rough_s = _math(nt, "MAXIMUM", rough_s, _math(nt, "MULTIPLY", rr.outputs["Color"], 0.9))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(rough_s, b.inputs["Roughness"])
    nt.links.new(_bump(nt, n.outputs["Fac"], 0.15, 0.005), b.inputs["Normal"])
    return mat


def mat_fabric(name, color, rough=0.95, weave_scale=180.0, sheen=0.3):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    wave1 = nt.nodes.new("ShaderNodeTexWave")
    wave1.inputs["Scale"].default_value = weave_scale
    nt.links.new(vec, wave1.inputs["Vector"])
    n = _noise(nt, vec, 5, 8, 0.6)
    col = _mix(nt, color, tuple(c * 0.55 for c in color), n.outputs["Fac"])
    col = _grime(nt, vec, col, 0.35)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if "Sheen Weight" in b.inputs:
        b.inputs["Sheen Weight"].default_value = sheen
    nt.links.new(_bump(nt, wave1.outputs["Fac"], 0.12, 0.002), b.inputs["Normal"])
    return mat


def mat_leather(name, color):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 90
    nt.links.new(vec, vor.inputs["Vector"])
    n = _noise(nt, vec, 6, 8, 0.6)
    col = _mix(nt, color, tuple(c * 0.5 for c in color), n.outputs["Fac"])
    col = _grime(nt, vec, col, 0.3)
    nt.links.new(col, b.inputs["Base Color"])
    rough = _math(nt, "ADD", 0.55, _math(nt, "MULTIPLY", n.outputs["Fac"], 0.3))
    nt.links.new(rough, b.inputs["Roughness"])
    nt.links.new(_bump(nt, vor.outputs["Distance"], 0.2, 0.003), b.inputs["Normal"])
    return mat


def mat_emissive(name, color, strength=6.0, transmission=0.6):
    mat, nt, b = _new_material(name)
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.08
    if "Transmission Weight" in b.inputs:
        b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    return mat


def mat_bone(name="M_Bone_01"):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    n = _noise(nt, vec, 20, 10, 0.6)
    col = _mix(nt, (0.55, 0.5, 0.38), (0.25, 0.2, 0.13), n.outputs["Fac"])
    col = _grime(nt, vec, col, 0.5)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    nt.links.new(_bump(nt, n.outputs["Fac"], 0.3, 0.003), b.inputs["Normal"])
    return mat


def mat_foliage(name, color_a, color_b):
    mat, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    n = _noise(nt, vec, 3, 4, 0.5)
    col = _mix(nt, color_a, color_b, n.outputs["Fac"])
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    if "Subsurface Weight" in b.inputs:
        b.inputs["Subsurface Weight"].default_value = 0.15
    return mat


def build_materials():
    M = {}
    M["OldWood"] = mat_wood("M_OldWood_01", (0.17, 0.12, 0.075), (0.05, 0.035, 0.022), 3.0, stretch=(6, 6, 0.3))
    M["DarkWood"] = mat_wood("M_DarkWood_01", (0.075, 0.052, 0.036), (0.018, 0.013, 0.01), 3.0, rough=0.7, stretch=(6, 6, 0.3))
    M["Planks"] = mat_wood("M_WoodPlanks_01", (0.19, 0.14, 0.085), (0.06, 0.042, 0.026), 3.0, stretch=(0.3, 0.3, 6))
    M["CastleStone"] = mat_stone("M_CastleStone_01", (0.24, 0.23, 0.21), (0.09, 0.085, 0.08), 1.2, moss=0.35)
    M["FoundationStone"] = mat_stone("M_FoundationStone_01", (0.2, 0.19, 0.17), (0.07, 0.065, 0.06), 1.5, moss=0.2)
    M["Rock"] = mat_stone("M_Rock_01", (0.22, 0.21, 0.2), (0.07, 0.068, 0.065), 1.5)
    M["MossRock"] = mat_stone("M_MossRock_01", (0.2, 0.2, 0.19), (0.06, 0.06, 0.055), 1.5, moss=0.8)
    M["Plaster"] = mat_plaster("M_Plaster_01")
    M["RoofTiles"] = mat_stone("M_RoofTiles_01", (0.2, 0.09, 0.06), (0.08, 0.04, 0.03), 5.0, rough=0.85, moss=0.3)
    M["Shingles"] = mat_wood("M_RoofShingles_01", (0.12, 0.1, 0.085), (0.035, 0.03, 0.026), 4.0, rough=0.92, stretch=(0.4, 6, 0.4))
    M["Iron"] = mat_metal("M_MetalIron_01", (0.16, 0.16, 0.17), 0.45)
    M["RustedIron"] = mat_metal("M_RustedIron_01", (0.1, 0.095, 0.095), 0.55, rust=0.5)
    M["Gold"] = mat_metal("M_AgedBrass_01", (0.45, 0.32, 0.12), 0.38)
    M["Leather"] = mat_leather("M_Leather_01", (0.13, 0.075, 0.04))
    M["DarkLeather"] = mat_leather("M_DarkLeather_01", (0.045, 0.035, 0.03))
    M["ClothMage"] = mat_fabric("M_Cloth_MageRobe_01", (0.05, 0.06, 0.14))
    M["ClothMageTrim"] = mat_fabric("M_Cloth_MageTrim_01", (0.17, 0.035, 0.035))
    M["ClothRogue"] = mat_fabric("M_Cloth_Rogue_01", (0.045, 0.05, 0.045))
    M["Bark"] = mat_stone("M_Bark_Oak_01", (0.1, 0.08, 0.06), (0.035, 0.028, 0.022), 6.0, rough=0.95, moss=0.35)
    M["DeadBark"] = mat_stone("M_Bark_Dead_01", (0.16, 0.15, 0.14), (0.05, 0.045, 0.04), 6.0, rough=0.95)
    M["OakLeaves"] = mat_foliage("M_Leaves_Oak_01", (0.03, 0.06, 0.015), (0.07, 0.09, 0.02))
    M["Bone"] = mat_bone()
    M["NecroCrystal"] = mat_emissive("M_Crystal_Necro_01", (0.08, 0.55, 0.14), 2.0)
    M["ArcaneCrystal"] = mat_emissive("M_Crystal_Arcane_01", (0.16, 0.1, 0.9), 2.5)
    M["Glass"] = mat_emissive("M_Window_Glow_01", (0.9, 0.55, 0.2), 2.5, transmission=0.0)
    M["Steel"] = mat_metal("M_Steel_01", (0.45, 0.45, 0.47), 0.3)
    M["Straw"] = mat_wood("M_Straw_01", (0.3, 0.24, 0.11), (0.1, 0.075, 0.035), 8.0, rough=0.95, stretch=(0.2, 0.2, 8))
    # Keep material references alive on a hidden holder in MAT_Master so the library is visible in the outliner.
    holder = bpy.data.objects.get("MAT_Library")
    if holder is None:
        me = bpy.data.meshes.new("MAT_Library")
        holder = bpy.data.objects.new("MAT_Library", me)
    link_only(holder, "MAT_Master")
    holder.data.materials.clear()
    for m in M.values():
        m.use_fake_user = True
        holder.data.materials.append(m)
    holder.hide_viewport = True
    holder.hide_render = True
    return M


def M(key):
    names = {
        "OldWood": "M_OldWood_01", "DarkWood": "M_DarkWood_01", "Planks": "M_WoodPlanks_01",
        "CastleStone": "M_CastleStone_01", "FoundationStone": "M_FoundationStone_01", "Rock": "M_Rock_01",
        "MossRock": "M_MossRock_01", "Plaster": "M_Plaster_01", "RoofTiles": "M_RoofTiles_01",
        "Shingles": "M_RoofShingles_01", "Iron": "M_MetalIron_01", "RustedIron": "M_RustedIron_01",
        "Gold": "M_AgedBrass_01", "Leather": "M_Leather_01", "DarkLeather": "M_DarkLeather_01",
        "ClothMage": "M_Cloth_MageRobe_01", "ClothMageTrim": "M_Cloth_MageTrim_01", "ClothRogue": "M_Cloth_Rogue_01",
        "Bark": "M_Bark_Oak_01", "DeadBark": "M_Bark_Dead_01", "OakLeaves": "M_Leaves_Oak_01", "Bone": "M_Bone_01",
        "NecroCrystal": "M_Crystal_Necro_01", "ArcaneCrystal": "M_Crystal_Arcane_01", "Glass": "M_Window_Glow_01",
        "Steel": "M_Steel_01", "Straw": "M_Straw_01",
    }
    return bpy.data.materials[names[key]]


# ---------------------------------------------------------------------------------------------------------------
# Mesh helpers. All return objects linked to the scene collection; the caller parents/joins them.

def _obj_from_bm(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        me.materials.append(mat)
    return obj


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, segs=2, jitter=0.0, seed=0):
    """Box with optional bevel and vertex jitter so edges look hand-cut rather than CAD-perfect."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", profile=0.5)
    if jitter > 0:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * jitter
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def cylinder(name, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, verts=16, bevel=0.0, radius_top=None, jitter=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=radius, radius2=radius if radius_top is None else radius_top, depth=depth)
    if bevel > 0:
        rim = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
        bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=2, affect="EDGES", profile=0.5)
    if jitter > 0:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3))) * jitter
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def tube_along(name, points, radii, mat=None, sides=10, twist_noise=0.0, seed=0, cap=True):
    """Lofts a tube through points with per-point radius (branches, roots, staff shafts, straps)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = []
    n = len(points)
    prev_side = None
    for i, p in enumerate(points):
        p = Vector(p)
        if i == 0:
            d = (Vector(points[1]) - p).normalized()
        elif i == n - 1:
            d = (p - Vector(points[i - 1])).normalized()
        else:
            d = (Vector(points[i + 1]) - Vector(points[i - 1])).normalized()
        if prev_side is None:
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            side = d.cross(ref).normalized()
        else:
            side = (prev_side - d * prev_side.dot(d)).normalized()
        prev_side = side
        up = d.cross(side).normalized()
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            r = radii[i] * (1 + (rnd.uniform(-1, 1) * twist_noise if twist_noise else 0))
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            bm.faces.new((a[s], a[(s + 1) % sides], b[(s + 1) % sides], b[s]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, mat)


def rock(name, size, seed=0, mat=None, subdiv=4, roughness=0.35, flatten=0.8):
    """Irregular boulder: icosphere displaced by layered noise, flattened base, sharp-ish breaks."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in bm.verts:
        p = v.co.copy()
        d = noise.noise(p * 0.9 + off) * 0.45 + noise.noise(p * 2.3 + off) * 0.18 + noise.noise(p * 6.0 + off) * 0.05
        # Facet-like breaks: quantize some of the displacement.
        d += round(noise.noise(p * 1.4 - off) * 3) / 3 * roughness * 0.35
        v.co = p * (1 + d)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if v.co.z < -size[2] * 0.35:
            v.co.z = -size[2] * 0.35 + (v.co.z + size[2] * 0.35) * (1 - flatten)
    obj = _obj_from_bm(name, bm, mat)
    return obj


def join(name, objs, parent=None):
    """Joins meshes into one object (keeps material slots)."""
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    out.data.name = name
    return out


def finalize(obj, origin="BASE", smooth_angle=35.0):
    """Applies transforms, recalculates normals, sets auto-smooth-like shading and the pivot."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    except Exception:
        bpy.ops.object.shade_smooth()
    if origin == "BASE":
        mn = Vector((min(v.co.x for v in obj.data.vertices), min(v.co.y for v in obj.data.vertices), min(v.co.z for v in obj.data.vertices)))
        mx = Vector((max(v.co.x for v in obj.data.vertices), max(v.co.y for v in obj.data.vertices), max(v.co.z for v in obj.data.vertices)))
        pivot = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
        obj.data.transform(Matrix.Translation(-pivot))
        obj.location += pivot
    return obj


def smart_uv(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def ucx_box(asset, size, center=(0, 0, 0), suffix=0, rot=(0, 0, 0)):
    """Simple convex collision hull parented to the asset: UCX_<Asset>_NN."""
    name = f"UCX_{asset.name}_{suffix:02d}"
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    c = box(name, size, center, rot)
    c.parent = asset
    c.display_type = "WIRE"
    c.hide_render = True
    for col in list(c.users_collection):
        col.objects.unlink(c)
    for col in asset.users_collection:
        col.objects.link(c)
    return c


def socket(asset, name, loc):
    """Empty used as an Unreal socket / Niagara attachment point (exported as SOCKET_ prefix optional)."""
    old = bpy.data.objects.get(name + "_" + asset.name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name + "_" + asset.name, None)
    e.empty_display_type = "SPHERE"
    e.empty_display_size = 0.03
    e["socket_name"] = name
    for col in asset.users_collection:
        col.objects.link(e)
    e.parent = asset
    e.location = loc
    return e


def make_lods(asset, ratios=(0.5, 0.2)):
    """Creates <asset>_LOD1/_LOD2 decimated copies (hidden) for props that are not Nanite targets."""
    out = []
    for i, r in enumerate(ratios, start=1):
        name = f"{asset.name}_LOD{i}"
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        lod = asset.copy()
        lod.data = asset.data.copy()
        lod.name = name
        lod.data.name = name
        for col in asset.users_collection:
            col.objects.link(lod)
        lod.parent = asset
        lod.matrix_parent_inverse.identity()
        lod.location = (0, 0, 0)
        mod = lod.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = r
        bpy.ops.object.select_all(action="DESELECT")
        lod.select_set(True)
        bpy.context.view_layer.objects.active = lod
        bpy.ops.object.modifier_apply(modifier="Decimate")
        lod.hide_viewport = True
        lod.hide_render = True
        out.append(lod)
    return out


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def finish_asset(name, parts, col, ucx=(), lods=True, smooth=40, origin="BASE"):
    """Join parts, UV, finalize, move to its collection, add UCX boxes [(size, center)], optional LOD1/LOD2."""
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, origin, smooth)
    link_only(obj, col)
    for i, (size, center) in enumerate(ucx):
        ucx_box(obj, size, center, i)
    if lods:
        make_lods(obj)
    for c in obj.children:
        if c.name.startswith("UCX_") or "_LOD" in c.name:
            c.hide_set(True)
    return obj


def dent(obj, amount, seed=0, count=30, radius=0.04):
    """Knocks and chips: pushes clusters of vertices inward along their normals."""
    rnd = random.Random(seed)
    verts = obj.data.vertices
    if not len(verts):
        return obj
    for _ in range(count):
        c = verts[rnd.randrange(len(verts))].co.copy()
        for v in verts:
            d = (v.co - c).length
            if d < radius:
                v.co -= v.normal * amount * (1 - d / radius)
    return obj


def plank(name, size, loc, rot=(0, 0, 0), mat_key="Planks", seed=0, wear=0.004):
    """Board with bevelled, slightly irregular edges and a few knocks."""
    b = box(name, size, loc, rot, mat=M(mat_key), bevel=min(0.006, min(size) * 0.2), segs=2, jitter=min(0.003, min(size) * 0.08), seed=seed)
    return dent(b, wear, seed=seed, count=3, radius=max(size) * 0.08)


def render_asset(obj_names, path, res=(900, 600), elev=22, azim=-35, pad=1.25, lens=50):
    """Frames one or more objects from their world bounding boxes with PRES_Cam_Inspect and renders a still."""
    sc = bpy.context.scene
    cam = bpy.data.objects.get("PRES_Cam_Inspect")
    if cam is None:
        cam = bpy.data.objects.new("PRES_Cam_Inspect", bpy.data.cameras.new("PRES_Cam_Inspect"))
        link_only(cam, "_Presentation")
    bpy.context.view_layer.update()
    pts = []
    for n in obj_names:
        o = bpy.data.objects[n]
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (mn + mx) / 2
    radius = (mx - mn).length / 2
    cam.data.lens = lens
    fov = 2 * math.atan(18 / lens)
    dist = radius * pad / math.sin(fov / 2)
    e, a = math.radians(elev), math.radians(azim)
    cam.location = ctr + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_start = 0.01
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

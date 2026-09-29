"""
Builds the playable characters from the Medieval Dark Fantasy kit, skinned to the UE5 mannequin skeleton so every
existing mannequin animation (ABP_Unarmed, casting, hit reactions, deaths) drives them unchanged.

Run in background Blender (it resets the scene it runs in, so never inside the kit file's session):
    blender -b --factory-startup --python Scripts/blender_kit/build_game_characters.py

Inputs:  Art/Blender/MedievalDarkFantasyKit.blend (bodies, heads, armor sets)
         Art/Export/Mannequin/SKM_Quinn_Simple.fbx, SKM_Manny_Simple.fbx (exported from /Game/Characters/Mannequins)
Outputs: (with `-- --rig ual`: godot/assets/characters/<Name>.glb on the CC0 UAL rig, for the Godot port)
         Art/Export/Characters/<Name>.fbx   (import onto /Game/Characters/Mannequins/Meshes/SK_Mannequin)
         Art/Blender/Characters/<Name>.blend (the fitted, skinned result, for inspection or touch-ups)
         Art/Export/Characters/<Name>.png    (front/three-quarter preview render)

Per character:
  1. the kit body is scaled to the mannequin and its limbs are posed onto the mannequin's rest pose (bone
     directions matched joint by joint), the armor pieces are rigged to the kit body and follow that pose;
  2. body faces fully hidden under armor are removed (no skin poking through cloth when animating);
  3. skin weights are transferred from the mannequin mesh (cloth pieces get smoothed weights, eyes and hair are
     bound rigidly to the head), everything is joined into one mesh bound to the mannequin armature;
  4. exported with the armature named `root`, so Unreal sees the exact SK_Mannequin hierarchy.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
KIT = os.path.join(ROOT, "Art", "Blender", "MedievalDarkFantasyKit.blend")
MANNEQUIN_DIR = os.path.join(ROOT, "Art", "Export", "Mannequin")
OUT_DIR = os.path.join(ROOT, "Art", "Export", "Characters")
BLEND_DIR = os.path.join(ROOT, "Art", "Blender", "Characters")

CHARACTERS = {
    "SKM_Mage_Kit": dict(mannequin="SKM_Quinn_Simple", body="SK_Human_Female_01", hair=True,
                         armor=["SK_Mage_Robe_01", "SK_Mage_Hood_01", "SK_Mage_Belt_01", "SK_Mage_Mantle_01", "SK_Mage_Gloves_01", "SK_Mage_Boots_01"],
                         cloth=["SK_Mage_Robe_01", "SK_Mage_Mantle_01", "SK_Mage_Hood_01"]),
    "SKM_Rogue_Kit": dict(mannequin="SKM_Manny_Simple", body="SK_Human_Male_01", hair=True,
                          armor=["SK_Rogue_Chest_01", "SK_Rogue_Shoulder_01", "SK_Rogue_Hood_01", "SK_Rogue_Mask_01", "SK_Rogue_Belt_01",
                                 "SK_Rogue_Pants_01", "SK_Rogue_Boots_01", "SK_Rogue_Gloves_01", "SK_Rogue_Cloak_01"],
                          cloth=["SK_Rogue_Cloak_01", "SK_Rogue_Hood_01", "SK_Rogue_Chest_01"]),
}

# Target rig. "ue" (default): the UE5 mannequin, FBX for Unreal. "ual" (`-- --rig ual`): the CC0 Quaternius Universal
# Animation Library rig (Godot variant), GLB for the Godot port in godot/assets/characters, so the UAL clips drive it.
RIG = "ual" if "--rig" in sys.argv and sys.argv[sys.argv.index("--rig") + 1] == "ual" else "ue"
UAL_GLTF = os.path.join(ROOT, "Art", "ThirdParty", "UniversalAnimationLibrary", "AnimationLibrary_Godot_Standard.gltf")
GODOT_OUT_DIR = os.path.join(ROOT, "godot", "assets", "characters")

# UE mannequin bone name -> UAL bone name (only the joints this script measures or weights by name).
UAL_BONES = {"root": "root", "pelvis": "DEF-hips", "spine_05": "DEF-spine.003", "neck_01": "DEF-neck", "head": "DEF-head"}
for _s, _S in (("l", "L"), ("r", "R")):
    UAL_BONES.update({f"clavicle_{_s}": f"DEF-shoulder.{_S}", f"upperarm_{_s}": f"DEF-upper_arm.{_S}", f"lowerarm_{_s}": f"DEF-forearm.{_S}",
                      f"hand_{_s}": f"DEF-hand.{_S}", f"middle_01_{_s}": f"DEF-f_middle.01.{_S}", f"thigh_{_s}": f"DEF-thigh.{_S}",
                      f"calf_{_s}": f"DEF-shin.{_S}", f"foot_{_s}": f"DEF-foot.{_S}", f"ball_{_s}": f"DEF-toe.{_S}"})


def B(name):
    """Target-rig bone name for a UE mannequin bone name."""
    return UAL_BONES.get(name, name) if RIG == "ual" else name


ARM_BONE_KEYS = ("clavicle", "upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky",
                 "shoulder", "upper_arm", "forearm", "f_")
ARM_REACH = 0.13  # metres: armor farther than this from an arm (in the reference pose) gets no arm weights
SLEEVE_REACH = 0.24  # metres: wider allowance along the upper arm and forearm, so loose sleeves follow the arm
NO_ARM_PIECES = ("Cloak", "Belt")  # never follow the arms (they may clip through the cloak rather than drag it)

# kit bone -> (mannequin joint the bone starts at, mannequin joint it points to)
ALIGN = []
for s in ("l", "r"):
    ALIGN += [(f"clavicle_{s}", f"clavicle_{s}", f"upperarm_{s}"), (f"upperarm_{s}", f"upperarm_{s}", f"lowerarm_{s}"),
              (f"lowerarm_{s}", f"lowerarm_{s}", f"hand_{s}"), (f"hand_{s}", f"hand_{s}", f"middle_01_{s}"),
              (f"thigh_{s}", f"thigh_{s}", f"calf_{s}"), (f"calf_{s}", f"calf_{s}", f"foot_{s}"), (f"foot_{s}", f"foot_{s}", f"ball_{s}")]


def log(*a):
    print("[chars]", *a, flush=True)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images, bpy.data.actions):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def load_kit_objects(names):
    with bpy.data.libraries.load(KIT, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
    loaded = {}
    for o in dst.objects:
        if o is not None:
            bpy.context.scene.collection.objects.link(o)
            loaded[o.name] = o
    return loaded


def import_mannequin(name):
    if RIG == "ual":
        return import_ual_mannequin()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MANNEQUIN_DIR, name + ".fbx"), ignore_leaf_bones=False, use_anim=False)  # UE FBX has no _end bones; True drops head, finger tips, toes
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    mesh = next(o for o in new if o.type == "MESH")
    empties = [o for o in new if o.type == "EMPTY"]
    # Flatten the 0.01-scaled wrapper so the rig lives in metres with unit scale.
    select_only([arm])
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for e in empties:
        bpy.data.objects.remove(e, do_unlink=True)
    select_only([arm, mesh], arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    arm.name = "root"
    arm.data.name = "root"
    return arm, mesh


def import_ual_mannequin():
    """The UAL rig ("Rig") and its skinned "Mannequin" mesh, without the library's clips (Godot loads those itself)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=UAL_GLTF)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    mesh = next(o for o in new if o.type == "MESH" and o.parent == arm)
    for o in new:
        if o not in (arm, mesh):
            bpy.data.objects.remove(o, do_unlink=True)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    bpy.context.view_layer.update()
    # The UAL rig rests in a T-pose, the armor is modelled arms-down: re-rest the rig (and its mesh) in the armor's
    # reference pose so nothing is stretched from arm to hip. Only bone rotations change, and glTF clips store
    # parent-relative rotations, so the library's animations still land every bone where they did.
    pose_rig_to_reference(arm)
    for mod in list(mesh.modifiers):
        if mod.type == "ARMATURE":
            select_only([mesh])
            bpy.ops.object.modifier_apply(modifier=mod.name)
    select_only([arm])
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return arm, mesh


def joint(arm, bone):
    return arm.matrix_world @ arm.data.bones[B(bone)].head_local


def rig_armor_to_body(armor, body, kit_rig):
    """Copies the kit body's weights onto an armor piece and binds it to the kit rig."""
    for g in list(armor.vertex_groups):
        armor.vertex_groups.remove(g)
    for g in body.vertex_groups:
        armor.vertex_groups.new(name=g.name)
    mod = armor.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    select_only([armor])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    arm_mod = armor.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = kit_rig
    armor.parent = kit_rig
    armor.matrix_parent_inverse = kit_rig.matrix_world.inverted()


# armor.py fits every piece to a 1.80 m reference body with the arms hanging down (see its BODY and REF mannequin);
# these are that body's joints (left side, metres), used to pose a copy of the mannequin rig into the armor's space.
REF_JOINTS = {"upperarm": (0.2, 0.0, 1.44), "lowerarm": (0.26, 0.0, 1.18), "hand": (0.29, -0.03, 0.93), "middle_01": (0.3, -0.045, 0.78),
              "thigh": (0.09, 0.0, 0.95), "calf": (0.1, 0.0, 0.5), "foot": (0.1, 0.01, 0.08), "ball": (0.1, -0.12, 0.02)}
REF_CHAIN = [("upperarm", "lowerarm"), ("lowerarm", "hand"), ("hand", "middle_01"), ("thigh", "calf"), ("calf", "foot"), ("foot", "ball")]


def _rotate_pose_bone(rig, pb, cur_end_world, target_dir):
    head = rig.matrix_world @ pb.head
    q = (cur_end_world - head).normalized().rotation_difference(target_dir.normalized())
    world = rig.matrix_world @ pb.matrix
    world = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ world
    pb.matrix = rig.matrix_world.inverted() @ world


def pose_rig_to_reference(rig):
    """Poses a mannequin rig so its limbs point along the armor reference body's limbs (arms down)."""
    select_only([rig])
    bpy.ops.object.mode_set(mode="POSE")
    for side, sx in (("l", 1.0), ("r", -1.0)):
        ref = {k: Vector((v[0] * sx, v[1], v[2])) for k, v in REF_JOINTS.items()}
        for a, b in REF_CHAIN:
            pa, pb_ = rig.pose.bones.get(B(f"{a}_{side}")), rig.pose.bones.get(B(f"{b}_{side}"))
            if pa is None or pb_ is None:
                continue
            bpy.context.view_layer.update()
            _rotate_pose_bone(rig, pa, rig.matrix_world @ pb_.head, ref[b] - ref[a])
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")


def fit_armor(armor, cloth, mann, mann_mesh):
    """Skins the armor (modelled arms-down) and bends it onto the mannequin's rest pose.

    A copy of the rig is posed into the armor's reference pose and that pose made its rest; the mannequin mesh, posed
    the same way, lends its weights to the armor; posing the copy back to the real rest pose carries the armor with it."""
    ref_rig = mann.copy()
    ref_rig.data = mann.data.copy()
    ref_rig.name = "ref_rig"
    bpy.context.scene.collection.objects.link(ref_rig)
    pose_rig_to_reference(mann)
    pose_rig_to_reference(ref_rig)
    bpy.context.view_layer.update()
    # A real copy with the pose applied keeps its vertex groups (an evaluated mesh can drop them).
    mann_ref = mann_mesh.copy()
    mann_ref.data = mann_mesh.data.copy()
    mann_ref.name = "mann_ref"
    bpy.context.scene.collection.objects.link(mann_ref)
    for mod in list(mann_ref.modifiers):
        if mod.type == "ARMATURE":
            mod.object = mann
            select_only([mann_ref])
            bpy.ops.object.modifier_apply(modifier=mod.name)
    mw = mann_ref.matrix_world.copy()
    mann_ref.parent = None
    mann_ref.matrix_world = mw
    log("reference mannequin groups", len(mann_ref.vertex_groups), "hand_l z", round((mann.matrix_world @ mann.pose.bones[B("hand_l")].head).z, 3))
    for pb in mann.pose.bones:
        pb.matrix_basis = Matrix()
    select_only([ref_rig])
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    for a in armor:
        transfer_weights(a, mann_ref, smooth=a.name in cloth, arm_reach=None if "Gloves" in a.name else (0.0 if any(k in a.name for k in NO_ARM_PIECES) else ARM_REACH))
        if not a.vertex_groups:
            raise RuntimeError("no skin weights transferred onto " + a.name)
        mod = a.modifiers.new("Armature", "ARMATURE")
        mod.object = ref_rig

    # Pose the reference rig back onto the true rest pose, parents before children.
    select_only([ref_rig])
    bpy.ops.object.mode_set(mode="POSE")
    bones = sorted(mann.data.bones, key=lambda b: len(b.parent_recursive))
    for b in bones:
        pb = ref_rig.pose.bones.get(b.name)
        if pb is not None:
            pb.matrix = b.matrix_local.copy()
            bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    for a in armor:
        select_only([a])
        bpy.ops.object.modifier_apply(modifier="Armature")
    bpy.data.objects.remove(mann_ref, do_unlink=True)
    bpy.data.objects.remove(ref_rig, do_unlink=True)


def pose_kit_to_mannequin(kit_rig, mann):
    select_only([kit_rig])
    bpy.ops.object.mode_set(mode="POSE")
    for kit_bone, a, b in ALIGN:
        pb = kit_rig.pose.bones.get(kit_bone)
        if pb is None or B(a) not in mann.data.bones or B(b) not in mann.data.bones:
            continue
        bpy.context.view_layer.update()
        head = kit_rig.matrix_world @ pb.head
        tail = kit_rig.matrix_world @ pb.tail
        cur = (tail - head).normalized()
        target = (joint(mann, b) - joint(mann, a)).normalized()
        q = cur.rotation_difference(target)
        world = kit_rig.matrix_world @ pb.matrix
        world = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ world
        pb.matrix = kit_rig.matrix_world.inverted() @ world
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_pose(meshes):
    for m in meshes:
        for mod in list(m.modifiers):
            if mod.type == "ARMATURE":
                select_only([m])
                bpy.ops.object.modifier_apply(modifier=mod.name)
        mw = m.matrix_world.copy()
        m.parent = None
        m.matrix_world = mw
        select_only([m])
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def hide_covered_skin(body, armor_pieces, reach=0.07):
    """Deletes body faces whose vertices all sit just under armor (raycast out along the normal)."""
    trees = []
    for a in armor_pieces:
        dg = bpy.context.evaluated_depsgraph_get()
        trees.append(BVHTree.FromObject(a, dg))
    me = body.data
    covered = []
    for v in me.vertices:
        p = v.co + v.normal * 0.002
        hit = False
        for t in trees:
            # Under the armor (armor just outside the skin) or poking through it (armor just inside the skin).
            loc, _, _, _ = t.ray_cast(p, v.normal, reach)
            back, _, _, _ = t.ray_cast(v.co - v.normal * 0.002, -v.normal, 0.05)
            if loc is not None or back is not None:
                hit = True
                break
        covered.append(hit)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    doomed = [f for f in bm.faces if all(covered[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(me)
    bm.free()
    log("hidden skin faces:", len(doomed), "of", len(me.polygons) + len(doomed))


def _distance_to_arms(p):
    """Distance from p to either arm of the armor reference body (upperarm -> hand -> fingers), in ARM_REACH units:
    the upper arm and forearm segments are measured against SLEEVE_REACH, the hand (beside the hips) against ARM_REACH."""
    best = 1e9
    for sx in (1.0, -1.0):
        pts = [Vector((REF_JOINTS[k][0] * sx, REF_JOINTS[k][1], REF_JOINTS[k][2])) for k in ("upperarm", "lowerarm", "hand", "middle_01")]
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            # Full sleeve allowance on the upper arm, tapering back to ARM_REACH at the wrist.
            reach = SLEEVE_REACH if i == 0 else (SLEEVE_REACH + (ARM_REACH - SLEEVE_REACH) * t if i == 1 else ARM_REACH)
            scale = ARM_REACH / reach
            best = min(best, (p - (a + ab * t)).length * scale)
    return best


def transfer_weights(obj, source, smooth=False, rigid=None, arm_reach=None):
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    if rigid:
        g = obj.vertex_groups.new(name=rigid)
        g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        return
    for g in source.vertex_groups:
        obj.vertex_groups.new(name=g.name)
    mod = obj.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = source
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    select_only([obj])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if arm_reach is not None:
        # In the reference pose the hands hang beside the hips: armor that is not on the arm itself (skirts, cloaks,
        # belt pouches, rope) must not take arm weights, or it gets dragged along whenever the arms move.
        arm_groups = {g.index for g in obj.vertex_groups if any(k in g.name for k in ARM_BONE_KEYS)}
        for v in obj.data.vertices:
            if _distance_to_arms(obj.matrix_world @ v.co) > arm_reach:
                for ge in list(v.groups):
                    if ge.group in arm_groups:
                        obj.vertex_groups[ge.group].remove([v.index])
                if not any(ge.weight > 1e-4 for ge in v.groups):
                    obj.vertex_groups[B("pelvis")].add([v.index], 1.0, "REPLACE")
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    if smooth:
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=4, expand=0.2)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Drop empty groups so the FBX only references bones that actually deform the mesh.
    used = set()
    for v in obj.data.vertices:
        for ge in v.groups:
            if ge.weight > 1e-4:
                used.add(ge.group)
    # Collect names first: removing a group re-indexes the ones after it.
    for name in [g.name for g in obj.vertex_groups if g.index not in used]:
        obj.vertex_groups.remove(obj.vertex_groups[name])


def render_preview(obj, path):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    world = bpy.data.worlds.new("W") if not scene.world else scene.world
    scene.world = world
    world.color = (0.25, 0.27, 0.3)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    cam.location = (1.6, -3.6, 1.2)
    cam.rotation_euler = ((Vector((0, 0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler())
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (sun, cam):
        bpy.data.objects.remove(o, do_unlink=True)


def weight_hair(hair, mann):
    """Hair follows the head at the crown and fades into the neck and upper spine as it hangs down, so long strands
    ride with the shoulders instead of swinging rigidly with every head turn (and cutting through the back)."""
    for g in list(hair.vertex_groups):
        hair.vertex_groups.remove(g)
    chain = [(B(b), joint(mann, b).z) for b in ("head", "neck_01", "spine_05") if B(b) in mann.data.bones]
    groups = {b: hair.vertex_groups.new(name=b) for b, _ in chain}
    # The head bone starts at the skull base; only strands a bit below it start handing over to the neck.
    top = chain[0][1] + 0.04
    for v in hair.data.vertices:
        z = (hair.matrix_world @ v.co).z
        weights = {chain[0][0]: 1.0}
        if z < top:
            levels = [(chain[0][0], top)] + chain[1:]
            weights = {levels[-1][0]: 1.0}
            for (upper, zu), (lower, zl) in zip(levels, levels[1:]):
                if z >= zl:
                    t = (zu - z) / max(zu - zl, 1e-4)
                    weights = {upper: 1.0 - t, lower: t}
                    break
        for bone, w in weights.items():
            if w > 1e-4:
                groups[bone].add([v.index], w, "REPLACE")
    for g in [g.name for g in hair.vertex_groups]:
        if not any(ge.group == hair.vertex_groups[g].index for v in hair.data.vertices for ge in v.groups):
            hair.vertex_groups.remove(hair.vertex_groups[g])


def build(name, cfg):
    reset_scene()
    bpy.context.scene.unit_settings.scale_length = 1.0  # the previous character switched to cm for its export
    body_rig_name = cfg["body"]
    parts = [body_rig_name, body_rig_name + "_Body", body_rig_name + "_Head", body_rig_name + "_Eyes"]
    if cfg["hair"]:
        parts.append(body_rig_name + "_Hair")
    loaded = load_kit_objects(parts + cfg["armor"])
    kit_rig = loaded[body_rig_name]
    body = loaded[body_rig_name + "_Body"]
    armor = [loaded[n] for n in cfg["armor"] if n in loaded]
    mann, mann_mesh = import_mannequin(cfg["mannequin"])

    # Bring the kit character to the origin: the rig carries body/head/eyes, armor was modelled around the origin.
    kit_rig.location = (0, 0, 0)
    for a in armor:
        a.location = (0, 0, 0)
    bpy.context.view_layer.update()

    # Uniform scale to the mannequin's proportions (pelvis and neck heights).
    kit_pelvis = kit_rig.matrix_world @ kit_rig.data.bones["pelvis"].head_local
    kit_neck = kit_rig.matrix_world @ kit_rig.data.bones["neck_01"].head_local
    s = 0.5 * (joint(mann, "pelvis").z / kit_pelvis.z + joint(mann, "neck_01").z / kit_neck.z)
    log(name, "scale", round(s, 4))
    # The body is scaled to the mannequin; the armor is already at mannequin scale (fitted to a 1.80 m body).
    kit_rig.scale = (s, s, s)
    bpy.context.view_layer.update()
    kit_meshes = [c for c in kit_rig.children if c.type == "MESH"]
    select_only([kit_rig] + kit_meshes, kit_rig)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    select_only(armor)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    pose_kit_to_mannequin(kit_rig, mann)
    bake_pose(kit_meshes)
    bpy.data.objects.remove(kit_rig, do_unlink=True)

    fit_armor(armor, cfg["cloth"], mann, mann_mesh)
    hide_covered_skin(body, armor)

    head_parts = [m for m in kit_meshes if m.name.endswith(("_Eyes", "_Hair"))]
    for m in kit_meshes:
        if m.name.endswith("_Hair"):
            weight_hair(m, mann)
        elif m in head_parts:
            transfer_weights(m, mann_mesh, rigid=B("head"))
        else:
            transfer_weights(m, mann_mesh)
    all_meshes = kit_meshes + armor

    select_only(all_meshes, body)
    bpy.ops.object.join()
    char = bpy.context.view_layer.objects.active
    char.name = name
    char.data.name = name
    bpy.data.objects.remove(mann_mesh, do_unlink=True)
    char.parent = mann
    char.matrix_parent_inverse = mann.matrix_world.inverted()
    mod = char.modifiers.new("Armature", "ARMATURE")
    mod.object = mann
    try:
        bpy.ops.object.select_all(action="DESELECT")
        char.select_set(True)
        bpy.context.view_layer.objects.active = char
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
    except Exception:
        pass

    if RIG == "ual":
        # Godot: metres, glTF, the UAL armature ("Rig") so the library's clips play on it by bone name.
        os.makedirs(GODOT_OUT_DIR, exist_ok=True)
        render_preview(char, os.path.join(GODOT_OUT_DIR, name + ".png"))
        select_only([mann, char], mann)
        bpy.ops.export_scene.gltf(filepath=os.path.join(GODOT_OUT_DIR, name + ".glb"), export_format="GLB", use_selection=True,
                                  export_animations=False, export_skins=True, export_yup=True, export_apply=False)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + "_UAL.blend"))
        tris = sum(len(p.vertices) - 2 for p in char.data.polygons)
        log(name, "exported (UAL/Godot), tris", tris, "materials", [m.name for m in char.data.materials])
        return

    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(BLEND_DIR, exist_ok=True)
    render_preview(char, os.path.join(OUT_DIR, name + ".png"))
    # Export in centimetres with unit scale on the objects applied: otherwise the metres->cm factor lands on the
    # armature node and Unreal gets a root bone scaled x100, which every animation resets to 1 (a giant character).
    bpy.context.scene.unit_settings.scale_length = 0.01
    select_only([mann, char], mann)
    for o in (mann, char):
        o.matrix_world = Matrix.Scale(100.0, 4) @ o.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, name + ".fbx"), use_selection=True, object_types={"ARMATURE", "MESH"},
                             add_leaf_bones=False, bake_anim=False, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE",
                             mesh_smooth_type="FACE", use_armature_deform_only=False, primary_bone_axis="Y", secondary_bone_axis="X")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    tris = sum(len(p.vertices) - 2 for p in char.data.polygons)
    log(name, "exported, tris", tris, "materials", [m.name for m in char.data.materials])


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = [a for i, a in enumerate(args) if a != "--rig" and (i == 0 or args[i - 1] != "--rig")]
    for name, cfg in CHARACTERS.items():
        if not only or name in only:
            build(name, cfg)


main()

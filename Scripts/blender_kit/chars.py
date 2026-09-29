"""CHAR_Base: base humanoid bodies (human/elf, male/female, dark elf, undead) with separate head, eyes and hair meshes
and an armature using Unreal Engine 5 mannequin bone names (retarget-ready). Characters face -Y, feet at Z=0,
arms in a relaxed A-pose (45 degrees). exec() after kitlib."""

V = Vector
CB = "CHAR_Base"

# Bone name -> (head, tail) are generated from the landmark table per body type.
UE_BONES = ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head",
            "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "thumb_01_l", "index_01_l", "middle_01_l", "ring_01_l", "pinky_01_l",
            "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thumb_01_r", "index_01_r", "middle_01_r", "ring_01_r", "pinky_01_r",
            "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]


def body_spec(kind):
    """Landmarks (metres) and radii for each body type."""
    base = dict(h=1.8, shoulder=0.2, hip=0.1, chest_r=(0.17, 0.11), waist_r=(0.14, 0.1), hip_r=(0.16, 0.11), neck_r=0.055, arm_r=(0.048, 0.04, 0.03),
                leg_r=(0.085, 0.058, 0.042), head=(0.09, 0.105, 0.12), female=False, elf=False, gaunt=0.0, skin=(0.6, 0.42, 0.33))
    if kind == "human_female":
        base.update(h=1.7, shoulder=0.175, hip=0.105, chest_r=(0.15, 0.105), waist_r=(0.12, 0.085), hip_r=(0.175, 0.12), neck_r=0.047, arm_r=(0.04, 0.034, 0.026),
                    leg_r=(0.088, 0.055, 0.038), head=(0.083, 0.097, 0.112), female=True)
    elif kind == "elf_male":
        base.update(h=1.86, shoulder=0.19, chest_r=(0.155, 0.1), waist_r=(0.125, 0.09), hip_r=(0.145, 0.1), arm_r=(0.042, 0.035, 0.027), leg_r=(0.078, 0.052, 0.037), head=(0.085, 0.1, 0.12), elf=True, skin=(0.66, 0.5, 0.42))
    elif kind == "elf_female":
        base.update(h=1.76, shoulder=0.168, hip=0.1, chest_r=(0.14, 0.098), waist_r=(0.11, 0.08), hip_r=(0.16, 0.11), neck_r=0.044, arm_r=(0.037, 0.031, 0.024),
                    leg_r=(0.08, 0.05, 0.035), head=(0.08, 0.095, 0.112), female=True, elf=True, skin=(0.68, 0.53, 0.45))
    elif kind == "dark_elf":
        base.update(h=1.84, shoulder=0.188, chest_r=(0.15, 0.1), waist_r=(0.12, 0.088), hip_r=(0.14, 0.1), arm_r=(0.041, 0.034, 0.027), leg_r=(0.077, 0.051, 0.036), head=(0.084, 0.1, 0.12), elf=True, skin=(0.2, 0.19, 0.25))
    elif kind == "undead":
        base.update(gaunt=0.35, skin=(0.32, 0.33, 0.27), chest_r=(0.15, 0.1), waist_r=(0.1, 0.075))
    return base


def _landmarks(s):
    h = s["h"] / 1.8  # scale factor relative to the 1.8 m template
    L = {
        "pelvis": V((0, 0, 0.98 * h)), "spine_01": V((0, 0.005, 1.06 * h)), "spine_02": V((0, 0.01, 1.18 * h)), "spine_03": V((0, 0.0, 1.32 * h)),
        "neck_01": V((0, -0.005, 1.5 * h)), "head": V((0, -0.01, 1.6 * h)), "head_top": V((0, -0.01, 1.8 * h)),
    }
    for side, sx in (("l", 1), ("r", -1)):
        sh = V((sx * s["shoulder"], 0.01, 1.44 * h))
        L[f"clavicle_{side}"] = V((sx * 0.03, -0.01, 1.43 * h))
        L[f"upperarm_{side}"] = sh
        el = sh + V((sx * 0.21, 0.0, -0.21)) * h
        L[f"lowerarm_{side}"] = el
        wr = el + V((sx * 0.18, -0.03, -0.18)) * h
        L[f"hand_{side}"] = wr
        L[f"hand_end_{side}"] = wr + V((sx * 0.07, -0.02, -0.07)) * h
        L[f"thigh_{side}"] = V((sx * s["hip"], 0, 0.93 * h))
        L[f"calf_{side}"] = V((sx * (s["hip"] + 0.005), -0.01, 0.5 * h))
        L[f"foot_{side}"] = V((sx * (s["hip"] + 0.01), 0.01, 0.085 * h))
        L[f"ball_{side}"] = V((sx * (s["hip"] + 0.015), -0.13 * h, 0.025))
        L[f"toe_{side}"] = V((sx * (s["hip"] + 0.02), -0.2 * h, 0.02))
    return L


def _skin_body(name, s, L, mat):
    """Vertex/edge skeleton + Skin modifier -> quad body mesh; subdivided and applied."""
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    verts = {}
    radii = {}

    def v(key, co, r):
        verts[key] = bm.verts.new(co)
        radii[key] = r

    g = 1 - s["gaunt"]
    v("pelvis", L["pelvis"] - V((0, 0, 0.03)), s["hip_r"])
    v("waist", L["spine_02"] - V((0, 0, 0.05)), (s["waist_r"][0] * g + s["waist_r"][0] * (1 - g) * 0.8, s["waist_r"][1] * g + 0.02 * (1 - g)))
    v("chest", L["spine_03"], s["chest_r"])
    v("upper_chest", L["spine_03"] + V((0, 0, 0.1)), (s["chest_r"][0] * 1.02, s["chest_r"][1] * 0.95))
    v("neck", L["neck_01"], (s["neck_r"], s["neck_r"]))
    v("neck_top", L["head"] - V((0, 0, 0.02)), (s["neck_r"] * 0.9, s["neck_r"] * 0.9))
    for side in ("l", "r"):
        ar = s["arm_r"]
        v(f"shoulder_{side}", L[f"upperarm_{side}"], (ar[0] * 1.35, ar[0] * 1.25))
        v(f"bicep_{side}", L[f"upperarm_{side}"].lerp(L[f"lowerarm_{side}"], 0.45), (ar[0] * g, ar[0] * g))
        v(f"elbow_{side}", L[f"lowerarm_{side}"], (ar[1], ar[1]))
        v(f"forearm_{side}", L[f"lowerarm_{side}"].lerp(L[f"hand_{side}"], 0.35), (ar[1] * 1.05 * g, ar[1] * 0.95 * g))
        v(f"wrist_{side}", L[f"hand_{side}"], (ar[2], ar[2] * 0.7))
        v(f"hand_{side}", L[f"hand_{side}"].lerp(L[f"hand_end_{side}"], 0.55), (ar[2] * 1.35, ar[2] * 0.55))
        v(f"fingers_{side}", L[f"hand_end_{side}"], (ar[2] * 1.1, ar[2] * 0.4))
        lr = s["leg_r"]
        v(f"thigh_{side}", L[f"thigh_{side}"], (lr[0], lr[0]))
        v(f"midthigh_{side}", L[f"thigh_{side}"].lerp(L[f"calf_{side}"], 0.45), (lr[0] * 0.88 * g, lr[0] * 0.9 * g))
        v(f"knee_{side}", L[f"calf_{side}"], (lr[1] * 1.05, lr[1]))
        v(f"calf_{side}", L[f"calf_{side}"].lerp(L[f"foot_{side}"], 0.3) + V((0, 0.012, 0)), (lr[1] * 1.05 * g, lr[1] * 1.15 * g))
        v(f"ankle_{side}", L[f"foot_{side}"] + V((0, 0, 0.02)), (lr[2], lr[2]))
        v(f"heel_{side}", L[f"foot_{side}"] + V((0, 0.03, -0.04)), (lr[2] * 0.9, lr[2]))
        v(f"ball_{side}", L[f"ball_{side}"] + V((0, 0, 0.01)), (lr[2] * 1.15, lr[2] * 0.55))
        v(f"toe_{side}", L[f"toe_{side}"], (lr[2] * 1.05, lr[2] * 0.45))
    edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "upper_chest"), ("upper_chest", "neck"), ("neck", "neck_top")]
    for side in ("l", "r"):
        edges += [("upper_chest", f"shoulder_{side}"), (f"shoulder_{side}", f"bicep_{side}"), (f"bicep_{side}", f"elbow_{side}"), (f"elbow_{side}", f"forearm_{side}"),
                  (f"forearm_{side}", f"wrist_{side}"), (f"wrist_{side}", f"hand_{side}"), (f"hand_{side}", f"fingers_{side}"),
                  ("pelvis", f"thigh_{side}"), (f"thigh_{side}", f"midthigh_{side}"), (f"midthigh_{side}", f"knee_{side}"), (f"knee_{side}", f"calf_{side}"),
                  (f"calf_{side}", f"ankle_{side}"), (f"ankle_{side}", f"heel_{side}"), (f"ankle_{side}", f"ball_{side}"), (f"ball_{side}", f"toe_{side}")]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    bm.to_mesh(me)
    bm.free()
    mod = obj.modifiers.new("Skin", "SKIN")
    mod.use_smooth_shade = True
    obj.data.skin_vertices[0].data  # ensure layer exists
    order = list(verts.keys())
    for i, key in enumerate(order):
        sv = obj.data.skin_vertices[0].data[i]
        r = radii[key]
        k = 1.32 if not key.startswith(("fingers", "hand", "wrist", "toe", "ball", "heel", "ankle")) else 1.2
        sv.radius = (r[0] * k, r[1] * k)
        if key == "pelvis":
            sv.use_root = True
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Sub")
    # Anatomy shaping with smooth (gaussian) falloffs so no ledges appear.
    hs = s["h"] / 1.8

    def bump(c, centre, radius, amount, axis):
        d = (c - centre).length
        return amount * math.exp(-(d / radius) ** 2) * axis

    for vtx in obj.data.vertices:
        c = vtx.co.copy()
        off = V((0, 0, 0))
        if s["female"]:
            for sx in (-1, 1):
                off += bump(c, V((sx * 0.075, -0.1, 1.3 * hs)), 0.07, 0.045, V((0, -1, 0.15)))
        else:
            for sx in (-1, 1):
                off += bump(c, V((sx * 0.08, -0.11, 1.33 * hs)), 0.08, 0.012, V((0, -1, 0)))
        for sx in (-1, 1):
            off += bump(c, V((sx * 0.07, 0.12, 0.9 * hs)), 0.09, 0.03 if s["female"] else 0.02, V((0, 1, -0.2)))
            off += bump(c, V((sx * (s["shoulder"] + 0.02), 0.0, 1.43 * hs)), 0.06, 0.012, V((sx, 0, 0.3)))
        if s["gaunt"] > 0 and 1.1 * hs < c.z < 1.35 * hs and c.y < 0:
            off += V((0, 0.006 * math.sin(c.z * 90), 0))
        vtx.co = c + off
    me.materials.append(mat)
    return obj


def _head(name, s, mat, seed=0):
    """Head sculpted from a sphere: cranium, brow, eye sockets, nose, cheekbones, lips, jaw, chin, ears (pointed for elves)."""
    rx, ry, rz = s["head"]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=36, radius=1.0)
    f = s["female"]
    for vt in bm.verts:
        x, y, z = vt.co
        # Egg shape: narrower jaw, fuller back.
        k = 1.0 - 0.18 * max(0.0, -z) * (1 if y < 0.3 else 0.5)
        x *= rx * k * (0.93 if abs(z) < 0.2 and y < -0.5 else 1.0)
        yy = y * ry * (1.08 if y > 0 else 1.0)
        zz = z * rz
        # Face plane: flatten the front.
        if yy < -ry * 0.85:
            yy = -ry * 0.85 - (yy + ry * 0.85) * 0.75
        # Brow ridge.
        if 0.1 * rz < zz < 0.28 * rz and yy < -ry * 0.55:
            yy -= 0.008 * (0.7 if f else 1.0)
        # Eye sockets.
        for sx in (-1, 1):
            d = math.hypot(x - sx * rx * 0.36, zz - rz * 0.05)
            if d < rx * 0.3 and yy < -ry * 0.5:
                yy += (rx * 0.3 - d) * 0.35
        # Nose: bridge + tip.
        if abs(x) < rx * 0.14 and -rz * 0.35 < zz < rz * 0.1 and yy < -ry * 0.6:
            t = (rz * 0.1 - zz) / (rz * 0.45)
            yy -= (0.012 + 0.018 * t) * (1 - abs(x) / (rx * 0.14)) * (0.85 if f else 1.0)
        # Cheekbones.
        if -rz * 0.2 < zz < rz * 0.05 and abs(x) > rx * 0.55 and yy < -ry * 0.3:
            x *= 1.04
        # Lips.
        if abs(x) < rx * 0.28 and -rz * 0.55 < zz < -rz * 0.38 and yy < -ry * 0.6:
            yy -= 0.006 * (1.3 if f else 1.0) * (1 - abs(x) / (rx * 0.28))
        # Jaw / chin.
        if zz < -rz * 0.55:
            x *= 0.82 if f else 0.9
            if abs(x) < rx * 0.25 and yy < -ry * 0.4:
                yy -= 0.006 if not f else 0.002
        vt.co = V((x, yy, zz))
    head = _obj_from_bm(name, bm, mat)
    parts = [head]
    # Ears: shell shapes; elves get long pointed tips swept back.
    for sx in (-1, 1):
        tip_up = 0.07 if s["elf"] else 0.012
        tip_back = 0.03 if s["elf"] else 0.005
        pts = [V((sx * rx * 0.98, 0.0, -0.02)), V((sx * (rx + 0.012), 0.008, 0.01)), V((sx * (rx + 0.018), 0.015 + tip_back * 0.5, 0.035 + tip_up * 0.5)), V((sx * (rx + 0.02), 0.02 + tip_back, 0.04 + tip_up))]
        parts.append(tube_along(f"{name}_ear{sx}", pts, [0.012, 0.018, 0.012, 0.002], mat, sides=8))
    return join(name, parts)


def _eyes(name, s):
    rx, ry, rz = s["head"]
    sclera = bpy.data.materials.get("M_Eye_Sclera_01")
    if sclera is None:
        sclera, nt, b = _new_material("M_Eye_Sclera_01")
        b.inputs["Base Color"].default_value = (0.85, 0.82, 0.78, 1)
        b.inputs["Roughness"].default_value = 0.05
    iris = bpy.data.materials.get("M_Eye_Iris_01")
    if iris is None:
        iris, nt, b = _new_material("M_Eye_Iris_01")
        b.inputs["Base Color"].default_value = (0.12, 0.2, 0.15, 1)
        b.inputs["Roughness"].default_value = 0.1
    parts = []
    for sx in (-1, 1):
        c = V((sx * rx * 0.36, -ry * 0.62, rz * 0.05))
        e = rock(f"{name}_ball{sx}", (0.012, 0.012, 0.012), seed=0, mat=sclera, subdiv=3, roughness=0.0, flatten=0.0)
        e.location = c
        parts.append(e)
        parts.append(cylinder(f"{name}_iris{sx}", 0.0055, 0.002, c + V((0, -0.0115, 0)), (math.pi / 2, 0, 0), iris, verts=16))
    return join(name, parts)


def _hair(name, s, style, mat, seed=0):
    rnd = random.Random(seed)
    rx, ry, rz = s["head"]
    parts = []
    if style in ("short", "cropped"):
        cap = lathe(f"{name}_cap", [(0.035, rx * 1.03, ry * 1.04, 0.012), (0.07, rx * 0.98, ry * 1.02, 0.014), (0.1, rx * 0.78, ry * 0.84, 0.016), (0.128, 0.01, 0.01, 0.02)], mat, 32, noise_amp=0.02, seed=seed, cap_top=True)
        bm = bmesh.new(); bm.from_mesh(cap.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.calc_center_median().y < -ry * 0.45 and f.calc_center_median().z < 0.06) or (abs(f.calc_center_median().x) > rx * 0.9 and f.calc_center_median().z < 0.0 and f.calc_center_median().y < 0.02)], context="FACES")
        bm.to_mesh(cap.data); bm.free()
        parts.append(cap)
    else:
        # Long hair: cap plus ~40 lofted locks falling down the back and over the shoulders.
        cap = lathe(f"{name}_cap", [(0.03, rx * 1.04, ry * 1.05, 0.012), (0.07, rx * 1.0, ry * 1.04, 0.014), (0.105, rx * 0.8, ry * 0.85, 0.016), (0.132, 0.01, 0.01, 0.02)], mat, 32, noise_amp=0.02, seed=seed, cap_top=True)
        parts.append(cap)
        n = 44
        length = 0.42 if style == "long" else 0.25
        for i in range(n):
            a = math.pi * 0.1 + math.pi * 0.8 * i / (n - 1)
            base = V((math.cos(a) * rx * 1.02, math.sin(a) * ry * 1.02 * 0.9 + 0.01, 0.02))
            outward = V((math.cos(a), math.sin(a), 0))
            pts = [base]
            for j in range(1, 7):
                t = j / 6
                pts.append(base + outward * (0.02 + 0.025 * math.sin(t * math.pi)) + V((rnd.uniform(-0.01, 0.01), 0.02 * t, -length * t)))
            parts.append(tube_along(f"{name}_lock{i}", pts, [0.016, 0.018, 0.017, 0.015, 0.012, 0.008, 0.002], mat, sides=6, twist_noise=0.2, seed=i))
    out = join(name, parts) if len(parts) > 1 else parts[0]
    out.name = name
    out.data.name = name
    return out


def _armature(name, L):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(n, head, tail, parent=None):
        b = eb.new(n)
        b.head, b.tail = head, tail
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        return b

    bone("root", V((0, 0, 0)), V((0, 0.2, 0)))
    bone("pelvis", L["pelvis"], L["spine_01"], "root")
    bone("spine_01", L["spine_01"], L["spine_02"], "pelvis")
    bone("spine_02", L["spine_02"], L["spine_03"], "spine_01")
    bone("spine_03", L["spine_03"], L["neck_01"], "spine_02")
    bone("neck_01", L["neck_01"], L["head"], "spine_03")
    bone("head", L["head"], L["head_top"], "neck_01")
    for side in ("l", "r"):
        bone(f"clavicle_{side}", L[f"clavicle_{side}"], L[f"upperarm_{side}"], "spine_03")
        bone(f"upperarm_{side}", L[f"upperarm_{side}"], L[f"lowerarm_{side}"], f"clavicle_{side}")
        bone(f"lowerarm_{side}", L[f"lowerarm_{side}"], L[f"hand_{side}"], f"upperarm_{side}")
        bone(f"hand_{side}", L[f"hand_{side}"], L[f"hand_{side}"].lerp(L[f"hand_end_{side}"], 0.5), f"lowerarm_{side}")
        hb = L[f"hand_{side}"].lerp(L[f"hand_end_{side}"], 0.5)
        d = (L[f"hand_end_{side}"] - L[f"hand_{side}"]).normalized()
        sx = 1 if side == "l" else -1
        for i, fn in enumerate(("index", "middle", "ring", "pinky")):
            off = V((0, -0.012 + i * 0.008, 0))
            bone(f"{fn}_01_{side}", hb + off, hb + off + d * 0.035, f"hand_{side}")
        bone(f"thumb_01_{side}", L[f"hand_{side}"] + V((0, -0.02, -0.01)), L[f"hand_{side}"] + V((sx * 0.02, -0.05, -0.03)), f"hand_{side}")
        bone(f"thigh_{side}", L[f"thigh_{side}"], L[f"calf_{side}"], "pelvis")
        bone(f"calf_{side}", L[f"calf_{side}"], L[f"foot_{side}"], f"thigh_{side}")
        bone(f"foot_{side}", L[f"foot_{side}"], L[f"ball_{side}"], f"calf_{side}")
        bone(f"ball_{side}", L[f"ball_{side}"], L[f"toe_{side}"], f"foot_{side}")
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.show_in_front = True
    return obj


def _skin_mat(name, col):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m, nt, b = _new_material(name)
    vec = _coords(nt, 1.0)
    n = _noise(nt, vec, 40, 6, 0.6)
    c = _mix(nt, col, tuple(x * 0.85 for x in col), n.outputs["Fac"])
    nt.links.new(c, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.5
    if "Subsurface Weight" in b.inputs:
        b.inputs["Subsurface Weight"].default_value = 0.15
    if "Subsurface Radius" in b.inputs:
        b.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.08)
    return m


def build_character(asset_name, kind, hair_style, hair_col, seed=0):
    """Creates SK_<name> armature with child meshes <name>_Body/_Head/_Eyes/_Hair, auto-weighted."""
    for suffix in ("", "_Body", "_Head", "_Eyes", "_Hair"):
        remove_asset(asset_name + suffix)
    s = body_spec(kind)
    L = _landmarks(s)
    skin = _skin_mat(f"M_Skin_{kind}_01", s["skin"])
    hair_mat = bpy.data.materials.get(f"M_Hair_{hair_style}_{seed}") or mat_fabric(f"M_Hair_{hair_style}_{seed}", hair_col, rough=0.55, weave_scale=400, sheen=0.5)
    arm = _armature(asset_name, L)
    body = _skin_body(asset_name + "_Body", s, L, skin)
    head = _head(asset_name + "_Head", s, skin, seed)
    head.location = L["head"] + V((0, -0.01, 0.075 * s["h"] / 1.8))
    eyes = _eyes(asset_name + "_Eyes", s)
    eyes.location = head.location
    hair = _hair(asset_name + "_Hair", s, hair_style, hair_mat, seed) if hair_style else None
    if hair:
        hair.location = head.location
    meshes = [m for m in (body, head, eyes, hair) if m]
    for m in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for poly in m.data.polygons:
            poly.use_smooth = True
    # Body gets automatic weights; head/eyes/hair are rigidly bound to the head bone.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for m in meshes[1:]:
        m.parent = arm
        vg = m.vertex_groups.new(name="head")
        vg.add(list(range(len(m.data.vertices))), 1.0, "REPLACE")
        mod = m.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    for o in [arm] + meshes:
        link_only(o, CB)
    return arm, [(m.name, tris(m)) for m in meshes]


def build_characters_batch():
    out = []
    specs = [("SK_Human_Male_01", "human_male", "short", (0.08, 0.05, 0.03)), ("SK_Human_Female_01", "human_female", "long", (0.12, 0.07, 0.035)),
             ("SK_Elf_Male_01", "elf_male", "long", (0.55, 0.48, 0.32)), ("SK_Elf_Female_01", "elf_female", "long", (0.6, 0.55, 0.4)),
             ("SK_DarkElf_Male_01", "dark_elf", "long", (0.75, 0.75, 0.78)), ("SK_Undead_Humanoid_01", "undead", None, (0, 0, 0))]
    x = 70.0
    for i, (n, kind, hair, col) in enumerate(specs):
        arm, meshes = build_character(n, kind, hair, col, seed=2100 + i)
        arm.location = (x, -10, 0)
        out.append((n, meshes))
        x += 1.2
    return out

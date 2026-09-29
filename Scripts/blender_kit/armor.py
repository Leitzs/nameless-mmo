"""Character armor sets (mage, rogue) fitted to a 1.80 m reference mannequin. exec() after kitlib.py.

Everything is built in the A-pose-less "rest" space of the mannequin: Z up, character faces -Y, feet at Z=0.
Pieces are separate meshes (SK_ candidates once skinned) so they can be mixed and matched on the base body.
"""

# Mannequin landmarks (metres) for a 1.80 m male.
BODY = dict(neck=1.52, chest=1.32, waist=1.05, hip=0.95, knee=0.5, ankle=0.08, shoulder_x=0.2, shoulder_z=1.45)


def _ring_profile(z, rx, ry, cy=0.0):
    return (z, rx, ry, cy)


def lathe(name, profile, mat, segments=40, fold_amp=0.0, fold_freq=9, fold_start=0.0, open_front=0.0, noise_amp=0.0, seed=0, cap_top=False, thickness=0.0):
    """Surface of revolution through (z, radius_x, radius_y, centre_y) rings. Optional cloth folds that grow toward
    the hem (fold_start is the normalized height where folds begin), a front opening gap (radians) and noise."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = []
    n = len(profile)
    zmin = min(p[0] for p in profile)
    zmax = max(p[0] for p in profile)
    phase = [rnd.uniform(0, 2 * math.pi) for _ in range(3)]
    for i, (z, rx, ry, cy) in enumerate(profile):
        ring = []
        hem = 1 - (z - zmin) / max(1e-5, zmax - zmin)  # 1 at the hem, 0 at the top
        fold = fold_amp * max(0.0, (hem - fold_start) / max(1e-5, 1 - fold_start)) ** 1.3
        for s in range(segments + (1 if open_front > 0 else 0)):
            if open_front > 0:
                a = -math.pi / 2 + open_front / 2 + (2 * math.pi - open_front) * s / segments
            else:
                a = 2 * math.pi * s / segments
            f = 1 + fold * (math.sin(a * fold_freq + phase[0]) * 0.6 + math.sin(a * fold_freq * 1.7 + phase[1]) * 0.4)
            nz = noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, z * 3 + seed))) * noise_amp
            x = math.cos(a) * rx * (f + nz)
            y = cy + math.sin(a) * ry * (f + nz)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    k = len(rings[0])
    for a_, b_ in zip(rings, rings[1:]):
        rng = k - 1 if open_front > 0 else k
        for s in range(rng):
            bm.faces.new((a_[s], a_[(s + 1) % k], b_[(s + 1) % k], b_[s]))
    if cap_top and open_front == 0:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if thickness > 0:
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
    return _obj_from_bm(name, bm, mat)


def band(name, z, rx, ry, height, mat, cy=0.0, segments=48, thick=0.006, open_front=0.0):
    return lathe(name, [(z - height / 2, rx, ry, cy), (z + height / 2, rx, ry, cy)], mat, segments, open_front=open_front, thickness=thick)


def build_mannequin(name="REF_Mannequin_Male_180"):
    """Neutral grey fitting form. Not an export asset: lives in _Presentation and is hidden from render tests."""
    remove_asset(name)
    mat = bpy.data.materials.get("M_REF_Mannequin") or bpy.data.materials.new("M_REF_Mannequin")
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.35, 0.35, 0.36, 1)
    b.inputs["Roughness"].default_value = 0.6
    parts = []
    torso = lathe(f"{name}_torso", [(0.92, 0.17, 0.11, 0), (1.02, 0.15, 0.1, 0), (1.12, 0.155, 0.1, 0), (1.3, 0.18, 0.115, 0), (1.42, 0.2, 0.11, 0), (1.5, 0.08, 0.07, 0)], mat, 24, cap_top=True)
    parts.append(torso)
    parts.append(lathe(f"{name}_neck", [(1.48, 0.055, 0.055, 0), (1.6, 0.05, 0.05, 0)], mat, 12))
    head = rock(f"{name}_head", (0.085, 0.1, 0.12), seed=0, mat=mat, subdiv=3, roughness=0.0, flatten=0.0)
    for v in head.data.vertices:
        v.co *= 1.0
    head.location = (0, -0.01, 1.7)
    parts.append(head)
    for sx in (-1, 1):
        parts.append(tube_along(f"{name}_arm", [Vector((sx * 0.2, 0, 1.44)), Vector((sx * 0.26, 0, 1.18)), Vector((sx * 0.29, -0.03, 0.93)), Vector((sx * 0.3, -0.04, 0.8))], [0.05, 0.042, 0.035, 0.03], mat, sides=10))
        parts.append(tube_along(f"{name}_leg", [Vector((sx * 0.09, 0, 0.95)), Vector((sx * 0.1, 0, 0.5)), Vector((sx * 0.1, 0.01, 0.08))], [0.085, 0.055, 0.04], mat, sides=10))
        parts.append(box(f"{name}_foot", (0.09, 0.25, 0.07), (sx * 0.1, -0.06, 0.035), mat=mat, bevel=0.02, segs=2))
    obj = join(name, parts)
    finalize(obj, "BASE", 60)
    link_only(obj, "_Presentation")
    return obj


# ---------------------------------------------------------------------------------------------------------------
# Mage set

def build_mage_armor(root_name="CHAR_Armor_Mage_Set01", x=0.0):
    robe_m, trim_m, leather, brass = M("ClothMage"), M("ClothMageTrim"), M("Leather"), M("Gold")
    pieces = {}

    def keep(key, obj):
        smart_uv(obj)
        finalize(obj, origin=None, smooth_angle=50)
        # Bake the object offset into the mesh so the piece's local space is the fitting space (origin = feet), even
        # after the object is moved around for presentation.
        obj.data.transform(Matrix.Translation(obj.location))
        obj.location = (0, 0, 0)
        obj.name = key
        obj.data.name = key
        link_only(obj, "CHAR_Armor_Mage")
        obj.location.x += x
        pieces[key] = obj
        return obj

    for k in ("SK_Mage_Robe_01", "SK_Mage_Hood_01", "SK_Mage_Belt_01", "SK_Mage_Mantle_01", "SK_Mage_Gloves_01", "SK_Mage_Boots_01"):
        remove_asset(k)
    # Robe: fitted chest, cinched waist, long skirt flaring to the ankles with deep folds; split at the front below the belt.
    upper = lathe("robe_up", [(1.02, 0.165, 0.112, 0), (1.12, 0.168, 0.113, 0), (1.3, 0.195, 0.128, 0), (1.42, 0.215, 0.125, 0), (1.49, 0.1, 0.085, 0)], robe_m, 48, noise_amp=0.01, seed=1, thickness=0.008)
    skirt = lathe("robe_skirt", [(0.1, 0.34, 0.3, 0.01), (0.35, 0.3, 0.25, 0.0), (0.7, 0.23, 0.18, 0), (0.95, 0.19, 0.135, 0), (1.04, 0.172, 0.118, 0)], robe_m, 64, fold_amp=0.09, fold_freq=11, open_front=0.35, noise_amp=0.015, seed=2, thickness=0.008)
    # Embroidered trim along hem and front opening, and a deep V collar.
    hem = lathe("robe_hem", [(0.09, 0.345, 0.305, 0.01), (0.16, 0.335, 0.295, 0.01)], trim_m, 64, fold_amp=0.09, fold_freq=11, open_front=0.35, seed=2, thickness=0.012)
    runes = []
    for i in range(22):
        a = -math.pi / 2 + 0.25 + (2 * math.pi - 0.5) * i / 21
        runes.append(box(f"rune{i}", (0.02, 0.004, 0.028), (math.cos(a) * 0.35, 0.01 + math.sin(a) * 0.31, 0.125), rot=(0, 0, a + math.pi / 2), mat=brass, bevel=0.001, segs=1))
    for sx in (-1, 1):
        runes.append(tube_along(f"placket{sx}", [Vector((sx * 0.06, -0.3, 0.12)), Vector((sx * 0.045, -0.2, 0.6)), Vector((sx * 0.03, -0.13, 1.0))], [0.012, 0.011, 0.01], trim_m, sides=6))
        runes.append(tube_along(f"collar{sx}", [Vector((sx * 0.02, -0.13, 1.18)), Vector((sx * 0.08, -0.11, 1.38)), Vector((sx * 0.1, -0.04, 1.5))], [0.018, 0.02, 0.018], trim_m, sides=7))
    # Sleeves: wide bell sleeves falling from the shoulder.
    sleeves = []
    for sx in (-1, 1):
        pts = [Vector((sx * 0.2, 0, 1.45)), Vector((sx * 0.25, 0, 1.25)), Vector((sx * 0.28, -0.02, 1.05)), Vector((sx * 0.3, -0.03, 0.9))]
        sleeves.append(tube_along(f"sleeve{sx}", pts, [0.07, 0.075, 0.09, 0.13], robe_m, sides=18, twist_noise=0.08, seed=sx + 5, cap=False))
        sleeves.append(tube_along(f"cuff{sx}", [pts[-1] + Vector((0, 0, 0.02)), pts[-1] - Vector((0, 0, 0.02))], [0.135, 0.135], trim_m, sides=18, cap=False))
    robe = join("robe", [upper, skirt, hem] + runes + sleeves)
    keep("SK_Mage_Robe_01", robe)

    # Hood: deep cowl thrown back over the shoulders with a pointed tail.
    hood_prof = [(1.46, 0.17, 0.15, 0.02), (1.55, 0.13, 0.13, 0.04), (1.68, 0.12, 0.13, 0.05), (1.77, 0.1, 0.12, 0.07), (1.82, 0.05, 0.07, 0.1)]
    hood = lathe("hood", hood_prof, robe_m, 40, fold_amp=0.05, fold_freq=5, fold_start=0.0, open_front=1.6, noise_amp=0.02, seed=4, thickness=0.01)
    tail = tube_along("hoodtail", [Vector((0, 0.12, 1.84)), Vector((0, 0.2, 1.72)), Vector((0, 0.22, 1.55))], [0.05, 0.03, 0.005], robe_m, sides=8)
    rim = lathe("hoodrim", [(1.46, 0.172, 0.152, 0.02), (1.5, 0.155, 0.14, 0.03)], trim_m, 40, open_front=1.6, thickness=0.012)
    keep("SK_Mage_Hood_01", join("hood", [hood, tail, rim]))

    # Belt: layered leather belt, brass buckle, two pouches, a hanging tome and a crystal focus.
    belt = [band("belt", 1.03, 0.178, 0.125, 0.06, leather, thick=0.008), band("belt2", 0.97, 0.19, 0.14, 0.04, M("DarkLeather"), thick=0.006)]
    belt.append(box("buckle", (0.07, 0.015, 0.06), (0, -0.13, 1.03), mat=brass, bevel=0.006, segs=2))
    belt.append(box("buckletongue", (0.012, 0.02, 0.05), (0, -0.14, 1.03), mat=brass, bevel=0.002, segs=1))
    for sx, sz in ((1, 1.0), (-1, 0.98)):
        belt.append(box("pouch", (0.1, 0.06, 0.11), (sx * 0.15, -0.08, sz - 0.06), rot=(0, 0, sx * 0.5), mat=leather, bevel=0.015, segs=3, jitter=0.003, seed=sx + 3))
        belt.append(box("pouchflap", (0.105, 0.065, 0.04), (sx * 0.15, -0.085, sz - 0.01), rot=(0.2, 0, sx * 0.5), mat=M("DarkLeather"), bevel=0.01, segs=2, seed=sx))
    tome = box("tome", (0.13, 0.05, 0.17), (0.2, 0.05, 0.86), rot=(0, 0.1, 0.6), mat=M("DarkLeather"), bevel=0.01, segs=2, jitter=0.002, seed=5)
    belt.append(tome)
    belt.append(tube_along("tomechain", [Vector((0.18, -0.02, 0.99)), Vector((0.2, 0.02, 0.93)), Vector((0.2, 0.04, 0.95))], [0.004] * 3, M("Iron"), sides=5))
    cr = bpy.data.objects.new("focus", bpy.data.meshes.new("focus"))
    bpy.context.scene.collection.objects.link(cr)
    exec_crystal = globals().get("_crystal")
    if exec_crystal:
        c = exec_crystal("focus_c", 0.05, 0.014, M("ArcaneCrystal"), 6, 3)
        c.location = (-0.07, -0.14, 0.95)
        belt.append(c)
    bpy.data.objects.remove(cr, do_unlink=True)
    keep("SK_Mage_Belt_01", join("belt", belt))

    # Mantle: short layered shoulder cape with a brass clasp and one modest leather pauldron plate per shoulder.
    mant = lathe("mantle", [(1.2, 0.3, 0.22, 0.01), (1.32, 0.27, 0.18, 0.0), (1.44, 0.22, 0.14, 0), (1.5, 0.11, 0.09, 0)], robe_m, 48, fold_amp=0.05, fold_freq=7, open_front=0.5, seed=7, thickness=0.01)
    trim = lathe("manttrim", [(1.19, 0.302, 0.222, 0.01), (1.22, 0.297, 0.217, 0.01)], trim_m, 48, fold_amp=0.05, fold_freq=7, open_front=0.5, seed=7, thickness=0.012)
    clasp = [cylinder(f"clasp{sx}", 0.022, 0.012, (sx * 0.06, -0.12, 1.42), (math.pi / 2, 0, 0), brass, verts=14, bevel=0.003) for sx in (-1, 1)]
    chain = tube_along("claspchain", [Vector((-0.06, -0.13, 1.42)), Vector((0, -0.14, 1.39)), Vector((0.06, -0.13, 1.42))], [0.004] * 3, brass, sides=5)
    plates = []
    for sx in (-1, 1):
        for k in range(3):
            p = lathe(f"pl{sx}{k}", [(-0.06 - k * 0.05, 0.085 - k * 0.005, 0.08, 0), (0.04 - k * 0.05, 0.05, 0.05, 0)], leather, 20, thickness=0.006)
            p.location = (sx * 0.2, 0.0, 1.43)
            p.rotation_euler = (0, sx * 0.5, 0)
            plates.append(p)
    keep("SK_Mage_Mantle_01", join("mantle", [mant, trim, chain] + clasp + plates))

    # Gloves (fingerless leather, wrapped cuffs) and boots (soft leather, turned-down cuff, straps).
    gl = []
    for sx in (-1, 1):
        gl.append(tube_along(f"glove{sx}", [Vector((sx * 0.29, -0.03, 0.93)), Vector((sx * 0.3, -0.04, 0.82)), Vector((sx * 0.3, -0.045, 0.76))], [0.04, 0.034, 0.03], leather, sides=12))
        _wrap(gl, f"gwrap{sx}", 0.86, 0.93, 0.042, M("DarkLeather"), turns=4, band=0.006)
        gl[-1].location.x += sx * 0.29
        gl[-1].location.y -= 0.035
    keep("SK_Mage_Gloves_01", join("gloves", gl))
    bt = []
    for sx in (-1, 1):
        bt.append(lathe(f"boot{sx}", [(0.0, 0.055, 0.07, -0.02), (0.08, 0.05, 0.06, -0.01), (0.25, 0.048, 0.05, 0), (0.38, 0.055, 0.055, 0)], leather, 20, thickness=0.006))
        bt[-1].location.x = sx * 0.1
        bt.append(box(f"toe{sx}", (0.085, 0.16, 0.07), (sx * 0.1, -0.12, 0.035), mat=leather, bevel=0.03, segs=3, jitter=0.003, seed=sx))
        bt.append(lathe(f"cuffb{sx}", [(0.34, 0.064, 0.064, 0), (0.42, 0.07, 0.07, 0)], M("DarkLeather"), 20, fold_amp=0.04, fold_freq=5, thickness=0.006))
        bt[-1].location.x = sx * 0.1
        for sz in (0.12, 0.22):
            bt.append(band(f"strap{sx}{sz}", sz, 0.053, 0.056, 0.02, M("DarkLeather"), thick=0.004))
            bt[-1].location.x = sx * 0.1
            bt.append(box(f"sbuckle{sx}", (0.02, 0.006, 0.02), (sx * 0.1 + sx * 0.05, 0, sz), mat=brass, bevel=0.002, segs=1))
        bt.append(box(f"sole{sx}", (0.1, 0.3, 0.025), (sx * 0.1, -0.06, 0.0125), mat=M("DarkLeather"), bevel=0.01, segs=2))
    keep("SK_Mage_Boots_01", join("boots", bt))
    return pieces


# ---------------------------------------------------------------------------------------------------------------
# Rogue set

def build_rogue_armor(root_name="CHAR_Armor_Rogue_Set01", x=0.0):
    leather, dark, cloth, iron, steel = M("Leather"), M("DarkLeather"), M("ClothRogue"), M("Iron"), M("Steel")
    pieces = {}

    def keep(key, obj):
        smart_uv(obj)
        finalize(obj, origin=None, smooth_angle=45)
        obj.data.transform(Matrix.Translation(obj.location))
        obj.location = (0, 0, 0)
        obj.name = key
        obj.data.name = key
        link_only(obj, "CHAR_Armor_Rogue")
        obj.location.x += x
        pieces[key] = obj
        return obj

    for k in ("SK_Rogue_Chest_01", "SK_Rogue_Hood_01", "SK_Rogue_Mask_01", "SK_Rogue_Belt_01", "SK_Rogue_Pants_01", "SK_Rogue_Boots_01", "SK_Rogue_Gloves_01", "SK_Rogue_Cloak_01", "SK_Rogue_Shoulder_01"):
        remove_asset(k)
    # Cuirass: layered, overlapping leather lames over a padded gambeson; stitched seams; laced sides.
    parts = [lathe("gambeson", [(0.9, 0.185, 0.13, 0), (1.05, 0.17, 0.118, 0), (1.3, 0.195, 0.128, 0), (1.45, 0.21, 0.122, 0), (1.5, 0.1, 0.085, 0)], cloth, 48, noise_amp=0.012, seed=9, thickness=0.008)]
    for k in range(6):
        z0 = 1.02 + k * 0.065
        prof = [(z0, 0.18 + k * 0.006, 0.126 + k * 0.002, -0.004), (z0 + 0.075, 0.176 + k * 0.006, 0.124 + k * 0.002, -0.004)]
        parts.append(lathe(f"lame{k}", prof, leather if k % 2 == 0 else dark, 48, open_front=0.0, thickness=0.007))
        # Stitch line along each lame's lower edge.
        for s in range(30):
            a = 2 * math.pi * s / 30
            parts.append(box("stitch", (0.008, 0.002, 0.002), (math.cos(a) * (0.187 + k * 0.006), -0.004 + math.sin(a) * (0.132 + k * 0.002), z0 + 0.008), rot=(0, 0, a + math.pi / 2), mat=M("Straw"), bevel=0, jitter=0))
    for sx in (-1, 1):
        parts.append(tube_along(f"rsleeve{sx}", [Vector((sx * 0.2, 0, 1.45)), Vector((sx * 0.26, 0, 1.18)), Vector((sx * 0.28, -0.025, 1.02))], [0.062, 0.052, 0.046], cloth, sides=14, twist_noise=0.05, seed=sx))
        parts.append(box(f"elbow{sx}", (0.06, 0.04, 0.07), (sx * 0.265, 0.035, 1.18), rot=(0, sx * 0.2, 0), mat=leather, bevel=0.015, segs=3))
    # Side lacing.
    for sx in (-1, 1):
        for i in range(5):
            z = 1.08 + i * 0.07
            parts.append(tube_along("lace", [Vector((sx * 0.2, -0.02, z)), Vector((sx * 0.205, 0.0, z + 0.035)), Vector((sx * 0.2, 0.02, z))], [0.003] * 3, dark, sides=4))
    # Bandolier across the chest with 4 throwing knives in sheaths.
    bpts = [Vector((-0.17, -0.14, 1.44)), Vector((-0.05, -0.155, 1.3)), Vector((0.08, -0.15, 1.15)), Vector((0.18, -0.12, 1.02))]
    parts.append(tube_along("bandolier", bpts, [0.014] * 4, dark, sides=6))
    for i in range(4):
        t = 0.2 + i * 0.18
        p = bpts[0].lerp(bpts[-1], t) + Vector((0, -0.02, 0))
        parts.append(box(f"sheath{i}", (0.03, 0.015, 0.1), p, rot=(0, -0.75, 0), mat=leather, bevel=0.005, segs=2))
        parts.append(box(f"knifehilt{i}", (0.012, 0.012, 0.05), p + Vector((-0.035, -0.002, 0.04)), rot=(0, -0.75, 0), mat=iron, bevel=0.002, segs=1))
    keep("SK_Rogue_Chest_01", join("chest", parts))

    # Single light pauldron on the left shoulder: 3 riveted overlapping leather plates.
    sp = []
    for k in range(3):
        p = lathe(f"sp{k}", [(-0.11 - k * 0.055, 0.095, 0.085, 0), (0.03 - k * 0.04, 0.055, 0.05, 0)], leather if k != 1 else dark, 24, thickness=0.008)
        p.location = (-0.2, 0, 1.42)
        p.rotation_euler = (0, -0.55, 0)
        sp.append(p)
        for r in range(3):
            a = -math.pi / 2 - 0.5 + r * 0.5
            rv = cylinder(f"rivet{k}{r}", 0.006, 0.012, (math.cos(a) * 0.092, math.sin(a) * 0.084, -0.1 - k * 0.055), (0, 0, 0), iron, verts=6)
            bpy.context.view_layer.update()
            rv.matrix_world = Matrix.Translation(Vector((-0.2, 0, 1.42))) @ Matrix.Rotation(-0.55, 4, "Y") @ rv.matrix_world
            sp.append(rv)
    keep("SK_Rogue_Shoulder_01", join("shoulder", sp))

    # Hood (close-fitting) and a separate cloth face mask.
    hood = lathe("rhood", [(1.44, 0.15, 0.14, 0.02), (1.58, 0.12, 0.125, 0.03), (1.72, 0.115, 0.125, 0.03), (1.82, 0.085, 0.1, 0.04), (1.87, 0.02, 0.03, 0.05)], cloth, 40, fold_amp=0.03, fold_freq=4, open_front=1.3, noise_amp=0.015, seed=11, thickness=0.009)
    keep("SK_Rogue_Hood_01", hood)
    mask = lathe("mask", [(1.52, 0.095, 0.105, -0.01), (1.6, 0.09, 0.11, -0.015), (1.66, 0.088, 0.108, -0.015)], dark, 32, open_front=0.0, noise_amp=0.01, seed=12, thickness=0.006)
    # Trim the back of the mask away: keep only faces in front (y < 0.02).
    bm = bmesh.new()
    bm.from_mesh(mask.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > 0.03], context="FACES")
    bm.to_mesh(mask.data)
    bm.free()
    keep("SK_Rogue_Mask_01", mask)

    # Utility belt: wide belt, iron buckle, 3 pouches, a dagger frog and a coiled rope.
    bl = [band("rbelt", 0.98, 0.19, 0.14, 0.065, dark, thick=0.009), box("rbuckle", (0.065, 0.014, 0.07), (0, -0.145, 0.98), mat=iron, bevel=0.005, segs=2)]
    for i, a in enumerate((-0.9, -0.3, 0.6)):
        bl.append(box(f"rpouch{i}", (0.08, 0.055, 0.1), (math.sin(a) * 0.2, -math.cos(a) * 0.15, 0.93), rot=(0, 0, a), mat=leather, bevel=0.012, segs=3, jitter=0.003, seed=i))
        bl.append(box(f"rpflap{i}", (0.085, 0.06, 0.035), (math.sin(a) * 0.2, -math.cos(a) * 0.152, 0.975), rot=(0.25, 0, a), mat=dark, bevel=0.008, segs=2, seed=i))
    bl.append(box("frog", (0.05, 0.025, 0.2), (0.21, 0.02, 0.86), rot=(0, 0.25, 0), mat=leather, bevel=0.008, segs=2))
    coil = [Vector((-0.21 + 0.05 * math.cos(a), 0.06 + 0.012 * (a / (2 * math.pi)), 0.9 + 0.05 * math.sin(a))) for a in [i * 0.3 for i in range(64)]]
    bl.append(tube_along("rope", coil, [0.007] * 64, M("Straw"), sides=5, cap=True))
    keep("SK_Rogue_Belt_01", join("rbelt", bl))

    # Pants (dark cloth) with leather knee guards; boots with buckled straps and a hidden boot knife.
    pn = []
    for sx in (-1, 1):
        pn.append(tube_along(f"leg{sx}", [Vector((sx * 0.095, 0, 0.98)), Vector((sx * 0.1, -0.005, 0.72)), Vector((sx * 0.1, 0, 0.5)), Vector((sx * 0.1, 0.01, 0.3))], [0.1, 0.075, 0.06, 0.052], cloth, sides=16, twist_noise=0.06, seed=sx))
        pn.append(box(f"knee{sx}", (0.09, 0.03, 0.12), (sx * 0.1, -0.06, 0.5), rot=(0.1, 0, 0), mat=leather, bevel=0.015, segs=3, jitter=0.003, seed=sx))
    keep("SK_Rogue_Pants_01", join("pants", pn))
    bt = []
    for sx in (-1, 1):
        bt.append(lathe(f"rboot{sx}", [(0.0, 0.055, 0.07, -0.02), (0.1, 0.05, 0.058, -0.01), (0.3, 0.052, 0.054, 0), (0.42, 0.06, 0.06, 0)], leather, 20, thickness=0.007))
        bt[-1].location.x = sx * 0.1
        bt.append(box(f"rtoe{sx}", (0.085, 0.17, 0.07), (sx * 0.1, -0.125, 0.035), mat=leather, bevel=0.03, segs=3, jitter=0.003, seed=sx))
        bt.append(box(f"rsole{sx}", (0.1, 0.3, 0.025), (sx * 0.1, -0.06, 0.0125), mat=dark, bevel=0.01, segs=2))
        for sz in (0.14, 0.24, 0.34):
            bt.append(band(f"rstrap{sx}{sz}", sz, 0.056, 0.058, 0.022, dark, thick=0.005))
            bt[-1].location.x = sx * 0.1
            bt.append(box(f"rsbuckle{sx}{sz}", (0.022, 0.008, 0.024), (sx * 0.1 + sx * 0.055, -0.01, sz), mat=iron, bevel=0.002, segs=1))
    bt.append(box("bootknife", (0.02, 0.012, 0.09), (0.16, 0.0, 0.44), mat=iron, bevel=0.003, segs=1))
    keep("SK_Rogue_Boots_01", join("rboots", bt))

    # Gloves with reinforced knuckle plates and long bracers.
    gl = []
    for sx in (-1, 1):
        gl.append(tube_along(f"rglove{sx}", [Vector((sx * 0.29, -0.03, 0.95)), Vector((sx * 0.3, -0.04, 0.82)), Vector((sx * 0.3, -0.045, 0.76))], [0.043, 0.036, 0.031], dark, sides=12))
        gl.append(tube_along(f"bracer{sx}", [Vector((sx * 0.28, -0.025, 1.06)), Vector((sx * 0.29, -0.03, 0.9))], [0.046, 0.04], leather, sides=12))
        gl.append(box(f"knuck{sx}", (0.05, 0.02, 0.03), (sx * 0.3, -0.07, 0.775), mat=iron, bevel=0.004, segs=2))
    keep("SK_Rogue_Gloves_01", join("rgloves", gl))

    # Short hooded cloak (back only, tattered hem).
    ck = lathe("cloak", [(0.7, 0.28, 0.2, 0.06), (0.95, 0.26, 0.19, 0.05), (1.25, 0.23, 0.16, 0.03), (1.45, 0.2, 0.13, 0.02), (1.5, 0.12, 0.1, 0.02)], cloth, 48, fold_amp=0.06, fold_freq=8, open_front=2.2, noise_amp=0.02, seed=13, thickness=0.007)
    bm = bmesh.new()
    bm.from_mesh(ck.data)
    rnd = random.Random(3)
    for v in bm.verts:
        if v.co.z < 0.72:
            v.co.z += rnd.uniform(0.0, 0.08)  # tattered hem
    bm.to_mesh(ck.data)
    bm.free()
    keep("SK_Rogue_Cloak_01", ck)
    return pieces

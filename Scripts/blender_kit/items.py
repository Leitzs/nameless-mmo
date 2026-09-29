"""Items: necromancer staff, arcane staff, rogue dagger. exec() after kitlib.py.

Staffs are authored standing on their foot (origin at the bottom of the ferrule), Z up, 1.75-1.9 m tall.
The dagger's origin is at the grip centre (where the hand socket goes), blade along +Z.
"""


def _crystal(name, length, radius, mat, facets=6, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    top = bm.verts.new((0, 0, length / 2))
    bot = bm.verts.new((0, 0, -length / 2))
    ring_hi, ring_lo = [], []
    for i in range(facets):
        a = 2 * math.pi * i / facets + rnd.uniform(-0.1, 0.1)
        r = radius * rnd.uniform(0.85, 1.1)
        ring_hi.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, length * 0.18)))
        ring_lo.append(bm.verts.new((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, -length * 0.2)))
    for i in range(facets):
        j = (i + 1) % facets
        bm.faces.new((ring_hi[i], ring_hi[j], top))
        bm.faces.new((ring_lo[j], ring_lo[i], bot))
        bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, mat)


def _wrap(parts, name, z0, z1, radius, mat, turns=10, band=0.012):
    """Leather strip spiralled around a shaft."""
    pts, rad = [], []
    steps = turns * 16
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * 2 * math.pi
        pts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, z0 + (z1 - z0) * t)))
        rad.append(band)
    parts.append(tube_along(name, pts, rad, mat, sides=5))


def _skull(name, scale, seed=0, eye_mat=None):
    """Human skull (~20 cm at scale 1) sculpted from one sphere: cranium, flattened face, brow ridge, cheekbones,
    concave eye sockets and nasal cavity (vertex displacement, no booleans), plus a separate jaw and teeth."""
    rnd = random.Random(seed)
    s = scale
    R = 0.1 * s
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=28, radius=R)
    eyes = [Vector((sx * 0.036 * s, -0.1 * s, -0.01 * s)) for sx in (-1, 1)]
    nose = Vector((0, -0.105 * s, -0.052 * s))
    for v in bm.verts:
        p = v.co.copy()
        p.y *= 1.2
        p.x *= 0.86
        # Narrow and flatten the face below the brow; long occiput behind.
        if p.y < 0 and p.z < 0.02 * s:
            k = min(1.0, (0.02 * s - p.z) / (0.1 * s))
            p.x *= 1 - 0.22 * k
            p.y = max(p.y, -0.105 * s - 0.01 * s * (1 - k))
        # Maxilla: pull the lower front down and forward into a muzzle.
        if p.z < -0.05 * s and p.y < -0.02 * s:
            p.z -= 0.025 * s * min(1, (-0.05 * s - p.z) / (0.04 * s))
        # Brow ridge.
        if -0.005 * s < p.z < 0.02 * s and p.y < -0.08 * s:
            p.y -= 0.006 * s
        # Cheekbones.
        if -0.045 * s < p.z < -0.015 * s and abs(p.x) > 0.045 * s and p.y < -0.03 * s:
            p.x *= 1.08
        # Concave sockets and nasal cavity.
        for e in eyes:
            d = (Vector((p.x, p.y, p.z)) - e).length
            if d < 0.038 * s:
                p.y += (0.038 * s - d) * 1.5
        dn = Vector(((p.x - nose.x) * 1.6, p.y - nose.y, (p.z - nose.z) * 0.8)).length
        if dn < 0.026 * s:
            p.y += (0.026 * s - dn) * 1.6
        p += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.0015 * s
        v.co = p
    cran = _obj_from_bm(f"{name}_cran", bm, M("Bone"))
    jaw = tube_along(f"{name}_jaw", [Vector((-0.05 * s, -0.01 * s, -0.06 * s)), Vector((-0.045 * s, -0.07 * s, -0.115 * s)), Vector((0, -0.1 * s, -0.125 * s)),
                                    Vector((0.045 * s, -0.07 * s, -0.115 * s)), Vector((0.05 * s, -0.01 * s, -0.06 * s))], [0.012 * s, 0.016 * s, 0.018 * s, 0.016 * s, 0.012 * s], M("Bone"), sides=8)
    parts = [cran, jaw]
    for i in range(10):
        a = math.pi * (0.15 + 0.7 * i / 9)
        for row, zz in ((0, -0.093 * s), (1, -0.108 * s)):
            parts.append(box(f"{name}_tooth", (0.008 * s, 0.007 * s, 0.014 * s), (math.cos(a) * 0.04 * s, -0.075 * s - math.sin(a) * 0.035 * s, zz), mat=M("Bone"), bevel=0.0015 * s, segs=1, jitter=0.0008 * s, seed=i + row * 20))
    for e in eyes:
        glow = cylinder(f"{name}_eye", 0.014 * s, 0.006 * s, e + Vector((0, 0.018 * s, 0)), (math.pi / 2, 0, 0), eye_mat or M("DarkWood"), verts=10)
        parts.append(glow)
    return join(name, parts)


def build_staff_necromancer(name="SM_Staff_Necromancer_01", seed=71):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    H = 1.82
    # Gnarled dark shaft with a slow twist, knots and a bulging crown that splits into claws.
    pts, radii = [], []
    n = 40
    for i in range(n + 1):
        t = i / n
        z = t * (H - 0.35)
        wob = Vector((math.sin(t * 9.0 + seed) * 0.008 + math.sin(t * 23.0) * 0.003, math.cos(t * 7.0 + seed) * 0.008, 0))
        pts.append(Vector((0, 0, z)) + wob)
        r = 0.02 + 0.004 * math.sin(t * 40) + (0.012 * max(0.0, (t - 0.85) / 0.15))
        if abs(t - 0.33) < 0.02 or abs(t - 0.61) < 0.02:
            r += 0.007  # knots
        radii.append(r)
    parts.append(tube_along(f"{name}_shaft", pts, radii, M("DarkWood"), sides=10, twist_noise=0.12, seed=seed))
    # Iron ferrule and a spiked foot.
    parts.append(cylinder(f"{name}_ferrule", 0.024, 0.09, (0, 0, 0.06), mat=M("RustedIron"), verts=12, radius_top=0.022))
    parts.append(cylinder(f"{name}_spike", 0.02, 0.05, (0, 0, 0.0), mat=M("RustedIron"), verts=8, radius_top=0.024))
    # Leather grip with binding cords; bone charms dangling on thongs.
    _wrap(parts, f"{name}_grip", 0.9, 1.18, 0.024, M("DarkLeather"), turns=14, band=0.009)
    for z in (0.88, 1.2):
        parts.append(cylinder(f"{name}_bind", 0.029, 0.018, (0, 0, z), mat=M("Iron"), verts=12))
    for k in range(3):
        a = k * 2.1
        top = Vector((math.cos(a) * 0.028, math.sin(a) * 0.028, 1.2))
        end = top + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, -0.14 - k * 0.03))
        parts.append(tube_along(f"{name}_thong{k}", [top, (top + end) / 2 + Vector((0, 0, -0.01)), end], [0.003, 0.003, 0.003], M("Leather"), sides=4))
        parts.append(cylinder(f"{name}_bead{k}", 0.012, 0.03, end - Vector((0, 0, 0.015)), mat=M("Bone"), verts=8, radius_top=0.006))
    # Crown: 5 bone-and-wood claws curling up around the crystal.
    crown_z = H - 0.35
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        cp = [Vector((0, 0, crown_z - 0.04)) + d * 0.02]
        for j in range(1, 7):
            t = j / 6
            cp.append(Vector((0, 0, crown_z + t * 0.28)) + d * (0.02 + math.sin(t * math.pi * 0.85) * 0.09) + Vector((0, 0, 0)))
        cp[-1] = cp[-1] - d * 0.03
        parts.append(tube_along(f"{name}_claw{k}", cp, [0.016, 0.015, 0.013, 0.011, 0.008, 0.005, 0.002], M("Bone") if k % 2 == 0 else M("DarkWood"), sides=7))
    # Vertebrae collar under the crown.
    for j in range(4):
        z = crown_z - 0.1 - j * 0.035
        parts.append(cylinder(f"{name}_vert{j}", 0.032 - j * 0.002, 0.022, (0, 0, z), mat=M("Bone"), verts=10, bevel=0.004))
        for sx in (-1, 1):
            parts.append(box(f"{name}_vproc{j}", (0.05, 0.01, 0.012), (sx * 0.035, 0, z), rot=(0, sx * 0.3, 0), mat=M("Bone"), bevel=0.003, segs=1))
    # Skull lashed to the front of the crown with iron wire.
    sk = _skull(f"{name}_skull", 0.6, seed, eye_mat=M("NecroCrystal"))
    sk.location = (0, -0.06, crown_z + 0.02)
    sk.rotation_euler = (0.25, 0, 0)
    parts.append(sk)
    wire = [Vector((0.08 * math.cos(a), -0.02 + 0.06 * math.sin(a), crown_z + 0.03 + 0.01 * math.sin(3 * a))) for a in [2 * math.pi * i / 24 for i in range(25)]]
    parts.append(tube_along(f"{name}_wire", wire, [0.003] * 25, M("RustedIron"), sides=4, cap=False))
    # Sickly green crystal held by the claws.
    cr = _crystal(f"{name}_crystal", 0.2, 0.045, M("NecroCrystal"), 7, seed)
    cr.location = (0, 0.01, crown_z + 0.17)
    cr.rotation_euler = (0.1, 0.05, 0.3)
    parts.append(cr)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=45)
    link_only(obj, "ITEM_Staffs")
    socket(obj, "FX_Core", (0, 0.01, crown_z + 0.17))
    socket(obj, "FX_Tip", (0, 0, crown_z + 0.33))
    socket(obj, "FX_Secondary", (0, -0.12, crown_z + 0.03))
    ucx_box(obj, (0.06, 0.06, H - 0.4), (0, 0, (H - 0.4) / 2), 0)
    ucx_box(obj, (0.22, 0.22, 0.4), (0, 0, crown_z + 0.15), 1)
    make_lods(obj)
    return obj


def build_staff_arcane(name="SM_Staff_Arcane_01", seed=81):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    H = 1.88
    brass = M("Gold")
    # Straight, slightly tapered dark shaft with brass collars and engraved rune bands.
    pts = [Vector((0, 0, z)) for z in (0.0, 0.4, 0.8, 1.2, 1.5)]
    parts.append(tube_along(f"{name}_shaft", pts, [0.019, 0.02, 0.021, 0.022, 0.024], M("DarkWood"), sides=12))
    parts.append(cylinder(f"{name}_ferrule", 0.022, 0.1, (0, 0, 0.05), mat=brass, verts=16, radius_top=0.02, bevel=0.003))
    for z in (0.45, 0.95, 1.25):
        parts.append(cylinder(f"{name}_collar", 0.026, 0.03, (0, 0, z), mat=brass, verts=16, bevel=0.004))
        # Engraved rune ticks around each collar.
        for k in range(10):
            a = 2 * math.pi * k / 10
            parts.append(box(f"{name}_rune", (0.004, 0.003, 0.018 if k % 3 else 0.01), (math.cos(a) * 0.0265, math.sin(a) * 0.0265, z), rot=(0, 0, a), mat=M("ArcaneCrystal"), bevel=0, jitter=0))
    _wrap(parts, f"{name}_grip", 0.98, 1.22, 0.023, M("Leather"), turns=12, band=0.008)
    # Head: flared brass socket, three sweeping prongs, two floating rings (tilted) around a faceted crystal.
    head_z = 1.5
    parts.append(cylinder(f"{name}_socket", 0.028, 0.08, (0, 0, head_z + 0.03), mat=brass, verts=16, radius_top=0.045, bevel=0.004))
    for k in range(3):
        a = 2 * math.pi * k / 3
        d = Vector((math.cos(a), math.sin(a), 0))
        cp = [Vector((0, 0, head_z + 0.07)) + d * 0.04]
        for j in range(1, 8):
            t = j / 7
            cp.append(Vector((0, 0, head_z + 0.07 + t * 0.3)) + d * (0.04 + math.sin(t * math.pi) * 0.1 - t * 0.03))
        parts.append(tube_along(f"{name}_prong{k}", cp, [0.012, 0.011, 0.01, 0.009, 0.008, 0.007, 0.005, 0.003], brass, sides=8))
        # Tiny crystal studs on each prong.
        st = _crystal(f"{name}_stud{k}", 0.03, 0.008, M("ArcaneCrystal"), 5, seed + k)
        st.location = cp[4] + d * 0.012
        parts.append(st)
    core_z = head_z + 0.22
    for i, (r, tilt, spin) in enumerate(((0.085, 0.45, 0.0), (0.11, -0.35, 1.2))):
        ring = [Vector((math.cos(a) * r, math.sin(a) * r, 0)) for a in [2 * math.pi * j / 48 for j in range(49)]]
        ro = tube_along(f"{name}_ring{i}", ring, [0.006] * 49, brass, sides=6, cap=False)
        ro.location = (0, 0, core_z)
        ro.rotation_euler = (tilt, 0, spin)
        parts.append(ro)
        for k in range(6):
            a = 2 * math.pi * k / 6
            g = box(f"{name}_ringrune", (0.012, 0.004, 0.012), (math.cos(a) * r, math.sin(a) * r, 0), rot=(0, 0, a), mat=M("ArcaneCrystal"), bevel=0, jitter=0)
            g.parent = None
            bpy.context.view_layer.update()
            g.matrix_world = Matrix.Translation(Vector((0, 0, core_z))) @ Euler((tilt, 0, spin)).to_matrix().to_4x4() @ g.matrix_world
            parts.append(g)
    cr = _crystal(f"{name}_crystal", 0.16, 0.035, M("ArcaneCrystal"), 6, seed)
    cr.location = (0, 0, core_z)
    parts.append(cr)
    # Floating rune shards above the head.
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        sh = _crystal(f"{name}_shard{k}", 0.05, 0.012, M("ArcaneCrystal"), 4, seed + 10 + k)
        sh.location = (math.cos(a) * 0.06, math.sin(a) * 0.06, core_z + 0.16 + 0.02 * k)
        sh.rotation_euler = (0.3, 0.2 * k, a)
        parts.append(sh)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=45)
    link_only(obj, "ITEM_Staffs")
    socket(obj, "FX_Core", (0, 0, core_z))
    socket(obj, "FX_Tip", (0, 0, core_z + 0.2))
    socket(obj, "FX_Secondary", (0, 0, head_z + 0.02))
    ucx_box(obj, (0.06, 0.06, head_z), (0, 0, head_z / 2), 0)
    ucx_box(obj, (0.26, 0.26, 0.42), (0, 0, head_z + 0.21), 1)
    make_lods(obj)
    return obj


def _blade(name, length, width, thick, curve=0.0, fuller=True, mat=None):
    """Lofted blade: diamond/hollow-ground cross-sections tapering to a point, optional recurve."""
    bm = bmesh.new()
    n = 24
    rings = []
    for i in range(n + 1):
        t = i / n
        # Leaf-ish profile: slight swell at 30%, then taper to the point.
        w = width * (1 - t ** 1.8) * (1 + 0.12 * math.sin(t * math.pi * 1.3)) if t < 1 else 0.0005
        th = thick * (1 - 0.7 * t)
        z = t * length
        x_off = curve * math.sin(t * math.pi) * length
        f = 0.35 if fuller and t < 0.6 else 0.0
        sect = [(-w / 2, 0), (-w * 0.25, th * (0.5 - f * 0.4)), (0, th * (0.5 - f)), (w * 0.25, th * (0.5 - f * 0.4)), (w / 2, 0),
                (w * 0.25, -th * (0.5 - f * 0.4)), (0, -th * (0.5 - f)), (-w * 0.25, -th * (0.5 - f * 0.4))]
        rings.append([bm.verts.new((sx + x_off, sy, z)) for sx, sy in sect])
    for a, b in zip(rings, rings[1:]):
        k = len(a)
        for s in range(k):
            bm.faces.new((a[s], a[(s + 1) % k], b[(s + 1) % k], b[s]))
    bm.faces.new(list(reversed(rings[0])))
    tip = bm.verts.new((curve * 0 + rings[-1][0].co.x, 0, length + 0.01))
    k = len(rings[-1])
    for s in range(k):
        bm.faces.new((rings[-1][s], rings[-1][(s + 1) % k], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, mat)


def build_dagger_rogue(name="SM_Dagger_Rogue_01", seed=91):
    remove_asset(name)
    parts = []
    steel = M("Steel")
    # Blade 24 cm, slight forward curve, fuller in the lower half, blackened ricasso.
    bl = _blade(f"{name}_blade", 0.24, 0.036, 0.007, curve=0.02, mat=steel)
    bl.location = (0, 0, 0.075)
    parts.append(bl)
    parts.append(box(f"{name}_ricasso", (0.034, 0.009, 0.02), (0, 0, 0.082), mat=M("Iron"), bevel=0.002, segs=1))
    # Swept crossguard with drooping quillons and a central langet.
    guard = [Vector((-0.06, 0, 0.055)), Vector((-0.035, 0, 0.068)), Vector((0, 0, 0.072)), Vector((0.035, 0, 0.068)), Vector((0.058, 0, 0.08)), Vector((0.066, 0, 0.095))]
    parts.append(tube_along(f"{name}_guard", guard, [0.004, 0.006, 0.008, 0.006, 0.005, 0.003], M("Iron"), sides=8))
    parts.append(box(f"{name}_langet", (0.02, 0.014, 0.03), (0, 0, 0.078), mat=M("Iron"), bevel=0.003, segs=2))
    # Grip: core + spiral leather wrap + wire.
    parts.append(cylinder(f"{name}_grip", 0.012, 0.1, (0, 0, 0.012), mat=M("DarkWood"), verts=10, radius_top=0.011))
    _wrap(parts, f"{name}_wrap", -0.035, 0.06, 0.012, M("DarkLeather"), turns=8, band=0.0045)
    _wrap(parts, f"{name}_wire", -0.034, 0.059, 0.0135, M("Iron"), turns=8, band=0.0012)
    # Faceted pommel with a ring for a lanyard.
    pm = _crystal(f"{name}_pommel", 0.035, 0.016, M("Iron"), 8, seed)
    pm.location = (0, 0, -0.05)
    parts.append(pm)
    ring = [Vector((0.009 * math.cos(a), 0, -0.075 + 0.009 * math.sin(a))) for a in [2 * math.pi * i / 16 for i in range(17)]]
    parts.append(tube_along(f"{name}_ring", ring, [0.0022] * 17, M("Iron"), sides=5, cap=False))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, origin=None, smooth_angle=30)
    link_only(obj, "ITEM_Weapons")
    socket(obj, "Grip", (0, 0, 0.01))
    socket(obj, "FX_Tip", (0.0, 0, 0.32))
    ucx_box(obj, (0.04, 0.012, 0.25), (0, 0, 0.2), 0)
    ucx_box(obj, (0.13, 0.03, 0.14), (0, 0, 0.01), 1)
    make_lods(obj)
    return obj

"""Village props, batch 2 (higher detail): well, handcart, anvil on stump. exec() after kitlib.py, castle.py, items.py."""


def _dent(obj, amount, seed=0, count=40, radius=0.04):
    """Random dents/chips: pushes clusters of vertices inward along their normal (edge wear, knocks)."""
    rnd = random.Random(seed)
    me = obj.data
    verts = me.vertices
    if not len(verts):
        return
    for _ in range(count):
        c = verts[rnd.randrange(len(verts))].co.copy()
        for v in verts:
            d = (v.co - c).length
            if d < radius:
                v.co -= v.normal * amount * (1 - d / radius)


def _bucket(parts, name, loc, rnd, h=0.3, r=0.14):
    staves = 12
    for i in range(staves):
        a = 2 * math.pi * i / staves
        sh = box(f"{name}_st", (2 * math.pi * r / staves - 0.004, 0.018, h), (0, 0, 0), mat=M("OldWood"), bevel=0.003, segs=1, jitter=0.002, seed=rnd.randint(0, 999))
        sh.location = Vector(loc) + Vector((math.cos(a) * r, math.sin(a) * r, h / 2))
        sh.rotation_euler = (0, -0.06, a)
        sh.rotation_mode = "ZYX"
        sh.rotation_euler = (0.0, 0.06, a + math.pi / 2)
        parts.append(sh)
    for z in (0.05, h - 0.05):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=32, radius1=r + 0.014, radius2=r + 0.014, depth=0.025)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
        hp = _obj_from_bm(f"{name}_hoop", bm, M("RustedIron"))
        hp.location = Vector(loc) + Vector((0, 0, z))
        parts.append(hp)
    parts.append(cylinder(f"{name}_bottom", r - 0.004, 0.02, Vector(loc) + Vector((0, 0, 0.03)), mat=M("Planks"), verts=20))
    handle = [Vector(loc) + Vector((math.cos(a) * (r + 0.02), 0, h + math.sin(a) * 0.14)) for a in [i * math.pi / 12 for i in range(13)]]
    parts.append(tube_along(f"{name}_bail", handle, [0.006] * 13, M("Iron"), sides=6, cap=True))


def build_well(name="SM_Well_Village_01", seed=101):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    stone = M("FoundationStone")
    R_out, R_in = 1.0, 0.72
    z = 0.0
    for course in range(4):
        h = rnd.choice((0.2, 0.22, 0.24))
        n = rnd.randint(9, 11)
        ph = rnd.uniform(0, 1)
        for k in range(n):
            a0 = ph + 2 * math.pi * k / n
            parts.append(_arc_block(f"{name}_blk", R_in, R_out + rnd.uniform(-0.02, 0.02), a0, a0 + 2 * math.pi / n - 0.02, z, z + h - 0.012, stone, 0.01, rnd.randint(0, 99999)))
        z += h
    # Overhanging cap stones, one knocked askew and one missing a chunk.
    n = 8
    for k in range(n):
        a0 = 2 * math.pi * k / n
        blk = _arc_block(f"{name}_cap", R_in - 0.04, R_out + 0.08, a0, a0 + 2 * math.pi / n - 0.015, z, z + 0.14, M("CastleStone"), 0.012, rnd.randint(0, 99999))
        if k == 3:
            blk.rotation_euler = (0.03, -0.02, 0.02)
        _dent(blk, 0.02, seed=k, count=6, radius=0.08)
        parts.append(blk)
    top = z + 0.14
    # Dark water surface deep inside, and moss clumps on the cap.
    parts.append(cylinder(f"{name}_water", R_in - 0.02, 0.02, (0, 0, 0.35), mat=M("DarkWood"), verts=32))
    for i in range(7):
        a = rnd.uniform(0, 2 * math.pi)
        m = rock(f"{name}_moss{i}", (0.08, 0.06, 0.02), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (math.cos(a) * 0.9, math.sin(a) * 0.9, top + 0.005)
        parts.append(m)
    # Timber frame: two posts with knee braces, crossbeam, windlass roller and crank.
    ph_ = 2.1
    for sx in (-1, 1):
        parts.append(box(f"{name}_post", (0.16, 0.16, ph_), (sx * 0.95, 0, ph_ / 2), mat=M("OldWood"), bevel=0.012, segs=2, jitter=0.008, seed=sx + 3))
        parts.append(box(f"{name}_brace", (0.1, 0.1, 0.55), (sx * 0.8, 0, ph_ - 0.3), rot=(0, sx * 0.7, 0), mat=M("OldWood"), bevel=0.008, segs=1, jitter=0.005, seed=sx + 7))
        parts.append(box(f"{name}_bearing", (0.2, 0.2, 0.1), (sx * 0.95, 0, 1.45), mat=M("DarkWood"), bevel=0.01, segs=2, seed=sx))
        for pz in (0.25, 0.6):
            parts.append(cylinder(f"{name}_peg", 0.015, 0.2, (sx * 0.95, 0, pz + 0.9), (math.pi / 2, 0, 0), M("DarkWood"), verts=8))
    parts.append(box(f"{name}_beam", (2.3, 0.18, 0.18), (0, 0, ph_ + 0.09), mat=M("OldWood"), bevel=0.012, segs=2, jitter=0.008, seed=11))
    roller = tube_along(f"{name}_roller", [Vector((-0.9, 0, 1.45)), Vector((0.9, 0, 1.45))], [0.09, 0.09], M("OldWood"), sides=14)
    parts.append(roller)
    # Rope wound around the roller, then hanging down to the bucket.
    coil = [Vector((-0.4 + 0.8 * t / 90, 0.1 * math.cos(t * 0.5), 1.45 + 0.1 * math.sin(t * 0.5))) for t in range(91)]
    parts.append(tube_along(f"{name}_rope", coil, [0.013] * 91, M("Straw"), sides=6))
    drop = [Vector((0.4, 0.0, 1.35)), Vector((0.38, 0.02, 1.1)), Vector((0.37, 0.02, 0.95))]
    parts.append(tube_along(f"{name}_ropedrop", drop, [0.013] * 3, M("Straw"), sides=6))
    _bucket(parts, f"{name}_bucket", (0.37, 0.02, 0.62), rnd)
    crank = [Vector((1.05, 0, 1.45)), Vector((1.15, 0, 1.45)), Vector((1.15, 0, 1.2)), Vector((1.3, 0, 1.2))]
    parts.append(tube_along(f"{name}_crank", crank, [0.018, 0.018, 0.018, 0.02], M("RustedIron"), sides=8))
    parts.append(cylinder(f"{name}_crankgrip", 0.025, 0.14, (1.23, 0, 1.2), (0, math.pi / 2, 0), M("DarkWood"), verts=10))
    # Small gable roof of shingles over the frame.
    for side in (-1, 1):
        pitch = math.radians(38)
        ms = Matrix.Identity(4)
        ms.col[0][:3] = (1, 0, 0)
        ms.col[1][:3] = (0, side * math.cos(pitch), -math.sin(pitch))
        ms.col[2][:3] = (0, side * math.sin(pitch), math.cos(pitch))
        ms.col[3][:3] = (0, 0, ph_ + 0.6)
        L = 0.95
        for r in range(6):
            s = L - r * 0.17
            x = -1.35 + (r % 2) * 0.08
            while x < 1.3:
                pw = rnd.uniform(0.14, 0.24)
                b = box(f"{name}_sh", (pw - 0.01, 0.28, 0.02), (0, 0, 0), mat=M("Shingles"), bevel=0.003, segs=1, jitter=0.003, seed=rnd.randint(0, 99999))
                b.matrix_world = ms @ Matrix.LocRotScale(Vector((x + pw / 2, s - 0.14, 0.03 + r * 0.001)), Euler((0.07, 0, rnd.uniform(-0.03, 0.03))).to_quaternion(), Vector((1, 1, 1)))
                parts.append(b)
                x += pw
        for gx in (-1, 1):
            b = box(f"{name}_rafter", (0.08, L, 0.1), (0, 0, 0), mat=M("OldWood"), bevel=0.006, segs=1, jitter=0.004, seed=gx)
            b.matrix_world = ms @ Matrix.Translation(Vector((gx * 1.1, L / 2, -0.06)))
            parts.append(b)
    parts.append(box(f"{name}_ridge", (2.8, 0.12, 0.14), (0, 0, ph_ + 0.58), mat=M("OldWood"), bevel=0.01, segs=1, jitter=0.005, seed=21))
    for sx in (-1, 1):
        parts.append(box(f"{name}_kingpost", (0.12, 0.12, 0.55), (sx * 0.95, 0, ph_ + 0.35), mat=M("OldWood"), bevel=0.008, segs=1, jitter=0.004, seed=sx + 30))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", 40)
    link_only(obj, "PROP_Village")
    c = cylinder(f"UCX_{name}_00", R_out + 0.08, top, (0, 0, top / 2), verts=12)
    c.parent = obj; c.display_type = "WIRE"; c.hide_render = True
    link_only(c, "PROP_Village")
    for sx in (-1, 1):
        ucx_box(obj, (0.16, 0.16, ph_), (sx * 0.95, 0, ph_ / 2), 1 if sx < 0 else 2)
    make_lods(obj)
    return obj


def _wheel(parts, name, center, radius, rnd, spokes=12, width=0.07):
    """Wooden cart wheel: hub, spokes, 6 felloe segments, iron tyre with nail heads."""
    cx, cy, cz = center
    hub = tube_along(f"{name}_hub", [Vector((cx - 0.09, cy, cz)), Vector((cx - 0.05, cy, cz)), Vector((cx + 0.05, cy, cz)), Vector((cx + 0.09, cy, cz))], [0.05, 0.075, 0.075, 0.05], M("OldWood"), sides=16)
    parts.append(hub)
    for bx in (-0.06, 0.06):
        parts.append(tube_along(f"{name}_hubband", [Vector((cx + bx - 0.008, cy, cz)), Vector((cx + bx + 0.008, cy, cz))], [0.079, 0.079], M("RustedIron"), sides=16))
    for i in range(spokes):
        a = 2 * math.pi * i / spokes + rnd.uniform(-0.01, 0.01)
        d = Vector((0, math.cos(a), math.sin(a)))
        parts.append(tube_along(f"{name}_spoke", [Vector(center) + d * 0.07, Vector(center) + d * (radius - 0.07)], [0.022, 0.016], M("OldWood"), sides=6))
    seg = 6
    for k in range(seg):
        a0 = 2 * math.pi * k / seg
        blk = _arc_block(f"{name}_felloe", radius - 0.08, radius - 0.01, a0, a0 + 2 * math.pi / seg - 0.008, -width / 2, width / 2, M("OldWood"), 0.003, rnd.randint(0, 9999), segs=6)
        blk.rotation_euler = (0, math.pi / 2, 0)
        blk.location = center
        parts.append(blk)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=radius + 0.004, radius2=radius + 0.004, depth=width + 0.008)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
    tyre = _obj_from_bm(f"{name}_tyre", bm, M("RustedIron"))
    tyre.rotation_euler = (0, math.pi / 2, 0)
    tyre.location = center
    parts.append(tyre)
    for i in range(18):
        a = 2 * math.pi * i / 18
        parts.append(cylinder(f"{name}_nail", 0.008, 0.008, (cx, cy + math.cos(a) * (radius + 0.016), cz + math.sin(a) * (radius + 0.016)), (0, 0, 0), M("Iron"), verts=6))


def build_handcart(name="SM_Cart_Hand_01", seed=111):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    R = 0.5
    axle_z = R
    for sx in (-1, 1):
        _wheel(parts, f"{name}_w{sx}", (sx * 0.72, 0.1, axle_z), R, rnd)
    parts.append(box(f"{name}_axle", (1.55, 0.1, 0.1), (0, 0.1, axle_z), mat=M("DarkWood"), bevel=0.01, segs=1, jitter=0.004, seed=1))
    # Bed frame: two long side beams that continue forward as the pulling shafts.
    bed_z = axle_z + 0.12
    for sx in (-1, 1):
        parts.append(tube_along(f"{name}_shaft", [Vector((sx * 0.5, 1.0, bed_z)), Vector((sx * 0.5, -0.8, bed_z)), Vector((sx * 0.46, -1.9, bed_z - 0.08)), Vector((sx * 0.44, -2.2, bed_z - 0.1))], [0.05, 0.05, 0.04, 0.035], M("OldWood"), sides=8, seed=sx))
        for i in range(5):
            y = -0.7 + i * 0.4
            parts.append(box(f"{name}_stake", (0.06, 0.06, 0.55), (sx * 0.56, y, bed_z + 0.28), mat=M("OldWood"), bevel=0.006, segs=1, jitter=0.004, seed=rnd.randint(0, 999)))
        for zr in (0.25, 0.5):
            parts.append(box(f"{name}_rail", (0.05, 1.85, 0.08), (sx * 0.58, 0.1, bed_z + zr), mat=M("Planks"), bevel=0.006, segs=1, jitter=0.004, seed=rnd.randint(0, 999)))
    parts.append(box(f"{name}_crossbar", (0.9, 0.06, 0.06), (0, -2.05, bed_z - 0.09), mat=M("OldWood"), bevel=0.006, segs=1, jitter=0.003, seed=5))
    for i in range(9):
        y = -0.8 + i * 0.21 + 0.1
        pl = box(f"{name}_bedplank", (1.08, 0.2, 0.035), (0, y, bed_z + 0.04), rot=(0, rnd.uniform(-0.01, 0.01), 0), mat=M("Planks"), bevel=0.004, segs=1, jitter=0.003, seed=rnd.randint(0, 999))
        _dent(pl, 0.006, seed=i, count=4, radius=0.05)
        parts.append(pl)
    # Tailboard, prop leg at the front so the cart rests level.
    parts.append(box(f"{name}_tail", (1.1, 0.04, 0.5), (0, 1.0, bed_z + 0.28), mat=M("Planks"), bevel=0.006, segs=1, jitter=0.004, seed=8))
    parts.append(box(f"{name}_leg", (0.07, 0.07, bed_z - 0.02), (0, -0.85, (bed_z - 0.02) / 2), mat=M("OldWood"), bevel=0.006, segs=1, jitter=0.004, seed=9))
    # Load: three grain sacks with tied necks and a small crate.
    for i, (x, y, rz) in enumerate(((-0.25, -0.4, 0.3), (0.2, -0.3, -0.2), (-0.05, 0.25, 1.2))):
        sack = rock(f"{name}_sack{i}", (0.28, 0.2, 0.18), seed=40 + i, mat=M("Straw"), subdiv=4, roughness=0.0, flatten=0.9)
        sack.location = (x, y, bed_z + 0.2)
        sack.rotation_euler = (0, 0, rz)
        parts.append(sack)
        neck = tube_along(f"{name}_neck{i}", [Vector((x + math.cos(rz) * 0.27, y + math.sin(rz) * 0.27, bed_z + 0.22)), Vector((x + math.cos(rz) * 0.36, y + math.sin(rz) * 0.36, bed_z + 0.24))], [0.05, 0.03], M("Straw"), sides=8)
        parts.append(neck)
        parts.append(tube_along(f"{name}_tie{i}", [Vector((x + math.cos(rz) * 0.3, y + math.sin(rz) * 0.3, bed_z + 0.22)), Vector((x + math.cos(rz) * 0.31, y + math.sin(rz) * 0.31, bed_z + 0.23))], [0.042, 0.042], M("Leather"), sides=8))
    parts.append(box(f"{name}_minicrate", (0.4, 0.35, 0.3), (0.2, 0.6, bed_z + 0.2), rot=(0, 0, 0.15), mat=M("Planks"), bevel=0.012, segs=2, jitter=0.006, seed=77))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", 40)
    link_only(obj, "PROP_Village")
    ucx_box(obj, (1.6, 2.0, bed_z + 0.6), (0, 0.1, (bed_z + 0.6) / 2), 0)
    ucx_box(obj, (1.0, 1.2, 0.2), (0, -1.6, bed_z - 0.05), 1)
    make_lods(obj)
    return obj


def build_anvil(name="SM_Anvil_Stump_01", seed=121):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    # Elm stump with bark, cut top with rings and iron bands.
    stump_h = 0.55
    st = tube_along(f"{name}_stump", [Vector((0, 0, 0)), Vector((0, 0, 0.1)), Vector((0, 0, stump_h))], [0.34, 0.3, 0.28], M("Bark"), sides=20, twist_noise=0.08, seed=seed)
    parts.append(st)
    parts.append(cylinder(f"{name}_cut", 0.275, 0.02, (0, 0, stump_h + 0.005), mat=M("OldWood"), verts=24))
    for z in (0.15, 0.42):
        parts.append(tube_along(f"{name}_band", [Vector((0, 0, z - 0.025)), Vector((0, 0, z + 0.025))], [0.305, 0.3], M("RustedIron"), sides=24, cap=False))
    # Anvil body lofted along X: heel (square), waist, face, horn (cone curving down).
    base_z = stump_h + 0.02
    body = []
    body.append(box(f"{name}_foot", (0.42, 0.26, 0.08), (0, 0, base_z + 0.04), mat=M("Iron"), bevel=0.02, segs=3, seed=1))
    body.append(box(f"{name}_waist", (0.26, 0.14, 0.14), (0, 0, base_z + 0.15), mat=M("Iron"), bevel=0.03, segs=3, seed=2))
    body.append(box(f"{name}_face", (0.48, 0.13, 0.1), (-0.02, 0, base_z + 0.27), mat=M("Steel"), bevel=0.012, segs=3, seed=3))
    horn = tube_along(f"{name}_horn", [Vector((0.2, 0, base_z + 0.27)), Vector((0.3, 0, base_z + 0.265)), Vector((0.4, 0, base_z + 0.25)), Vector((0.48, 0, base_z + 0.22))], [0.055, 0.042, 0.025, 0.006], M("Iron"), sides=14)
    body.append(horn)
    body.append(box(f"{name}_heel", (0.1, 0.1, 0.07), (-0.29, 0, base_z + 0.28), mat=M("Iron"), bevel=0.01, segs=2, seed=4))
    body.append(box(f"{name}_hardy", (0.022, 0.022, 0.02), (-0.2, 0, base_z + 0.32), mat=M("DarkWood"), bevel=0, jitter=0))
    body.append(cylinder(f"{name}_pritchel", 0.009, 0.02, (-0.13, 0, base_z + 0.32), mat=M("DarkWood"), verts=8))
    for b_ in body:
        _dent(b_, 0.003, seed=rnd.randint(0, 99), count=10, radius=0.03)
    parts.extend(body)
    # Hammer resting on the face; tongs leaning against the stump.
    hx, hz = -0.05, base_z + 0.33
    parts.append(tube_along(f"{name}_hhandle", [Vector((hx, -0.02, hz)), Vector((hx + 0.05, -0.2, hz - 0.01)), Vector((hx + 0.08, -0.36, hz - 0.02))], [0.016, 0.015, 0.017], M("OldWood"), sides=8))
    parts.append(box(f"{name}_hhead", (0.12, 0.045, 0.045), (hx - 0.01, 0.0, hz), rot=(0, 0, 0.3), mat=M("Iron"), bevel=0.008, segs=2, seed=6))
    for sx in (-1, 1):
        parts.append(tube_along(f"{name}_tong{sx}", [Vector((0.32 + sx * 0.012, 0.25, 0.02)), Vector((0.33 + sx * 0.01, 0.3, 0.35)), Vector((0.34 + sx * 0.02, 0.33, 0.52)), Vector((0.36 + sx * 0.03, 0.36, 0.56))], [0.007] * 4, M("Iron"), sides=6))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", 35)
    link_only(obj, "PROP_Village")
    c = cylinder(f"UCX_{name}_00", 0.34, stump_h, (0, 0, stump_h / 2), verts=10)
    c.parent = obj; c.display_type = "WIRE"; c.hide_render = True
    link_only(c, "PROP_Village")
    ucx_box(obj, (0.6, 0.26, 0.34), (0.05, 0, base_z + 0.17), 1)
    make_lods(obj)
    return obj


def _extrude_profile(name, pts_xz, width, mat, bevel=0.01, y=0.0):
    """Extrudes a closed XZ silhouette along Y (centered), then bevels its outline edges."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y - width / 2, z)) for x, z in pts_xz]
    back = [bm.verts.new((x, y + width / 2, z)) for x, z in pts_xz]
    n = len(pts_xz)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.link_faces[0].normal.angle(e.link_faces[1].normal, 0) > 0.6]
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", profile=0.5)
    return _obj_from_bm(name, bm, mat)


def build_anvil(name="SM_Anvil_Stump_01", seed=121):
    """London-pattern anvil (horn, face, heel, waist, feet) on a banded elm stump, with hammer and tongs."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    stump_h = 0.55
    parts.append(tube_along(f"{name}_stump", [Vector((0, 0, 0)), Vector((0, 0, 0.1)), Vector((0, 0, stump_h))], [0.34, 0.3, 0.28], M("Bark"), sides=20, twist_noise=0.08, seed=seed))
    parts.append(cylinder(f"{name}_cut", 0.275, 0.02, (0, 0, stump_h + 0.005), mat=M("OldWood"), verts=24))
    for z in (0.15, 0.42):
        parts.append(tube_along(f"{name}_band", [Vector((0, 0, z - 0.025)), Vector((0, 0, z + 0.025))], [0.305, 0.3], M("RustedIron"), sides=24, cap=False))
    z0 = stump_h + 0.02
    # Side silhouette (X along the anvil, Z up): feet, concave waist, face with step, heel and a curving horn.
    sil = [(-0.22, 0.0), (0.2, 0.0), (0.2, 0.03), (0.13, 0.06), (0.09, 0.12), (0.1, 0.19), (0.17, 0.21), (0.3, 0.215), (0.42, 0.23), (0.5, 0.26),
           (0.44, 0.27), (0.3, 0.3), (0.16, 0.315), (0.16, 0.33), (-0.28, 0.33), (-0.34, 0.31), (-0.3, 0.26), (-0.16, 0.22), (-0.1, 0.19), (-0.09, 0.12), (-0.13, 0.06), (-0.22, 0.03)]
    body = _extrude_profile(f"{name}_body", [(x, z + z0) for x, z in sil], 0.12, M("Iron"), bevel=0.012)
    parts.append(body)
    # Feet flare wider than the waist; the working face is a slightly wider hardened steel plate.
    parts.append(_extrude_profile(f"{name}_feet", [(-0.22, z0), (0.2, z0), (0.2, z0 + 0.03), (0.13, z0 + 0.06), (-0.13, z0 + 0.06), (-0.22, z0 + 0.03)], 0.24, M("Iron"), bevel=0.01))
    parts.append(_extrude_profile(f"{name}_face", [(-0.28, z0 + 0.315), (0.16, z0 + 0.315), (0.16, z0 + 0.335), (-0.28, z0 + 0.335)], 0.128, M("Steel"), bevel=0.004))
    # Horn is round in section: loft it and blend it into the body.
    parts.append(tube_along(f"{name}_horn", [Vector((0.15, 0, z0 + 0.27)), Vector((0.28, 0, z0 + 0.265)), Vector((0.4, 0, z0 + 0.25)), Vector((0.5, 0, z0 + 0.225))], [0.05, 0.038, 0.022, 0.005], M("Iron"), sides=14))
    parts.append(box(f"{name}_hardy", (0.022, 0.022, 0.01), (-0.22, 0, z0 + 0.336), mat=M("DarkWood"), bevel=0, jitter=0))
    parts.append(cylinder(f"{name}_pritchel", 0.008, 0.01, (-0.15, 0, z0 + 0.336), mat=M("DarkWood"), verts=8))
    for p in parts[-6:]:
        _dent(p, 0.002, seed=rnd.randint(0, 99), count=12, radius=0.025)
    # Hammer resting on the face; tongs leaning against the stump.
    hx, hz = -0.05, z0 + 0.36
    parts.append(tube_along(f"{name}_hhandle", [Vector((hx, -0.02, hz)), Vector((hx + 0.05, -0.2, hz - 0.01)), Vector((hx + 0.08, -0.36, hz - 0.02))], [0.016, 0.015, 0.017], M("OldWood"), sides=8))
    parts.append(tube_along(f"{name}_hhead", [Vector((hx - 0.07, 0.0, hz)), Vector((hx + 0.05, 0.0, hz))], [0.024, 0.022], M("Iron"), sides=10))
    for sx in (-1, 1):
        parts.append(tube_along(f"{name}_tong{sx}", [Vector((0.32 + sx * 0.012, 0.25, 0.02)), Vector((0.33 + sx * 0.01, 0.3, 0.35)), Vector((0.34 + sx * 0.02, 0.33, 0.52)), Vector((0.36 + sx * 0.03, 0.36, 0.56))], [0.007] * 4, M("Iron"), sides=6))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", 35)
    link_only(obj, "PROP_Village")
    c = cylinder(f"UCX_{name}_00", 0.34, stump_h, (0, 0, stump_h / 2), verts=10)
    c.parent = obj; c.display_type = "WIRE"; c.hide_render = True
    link_only(c, "PROP_Village")
    ucx_box(obj, (0.8, 0.24, 0.34), (0.1, 0, z0 + 0.17), 1)
    make_lods(obj)
    return obj

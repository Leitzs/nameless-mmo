"""Castle kit: modular wall section and round tower built from individual ashlar blocks. exec() after kitlib.py."""


def _course_blocks(parts, name, length, z0, height, y, depth, rnd, mat, x0=None, min_len=0.45, max_len=1.05, inset=0.012, skip=None):
    """One horizontal course of stone blocks along X from x0 to x0+length at face plane y (sign gives side)."""
    x = -length / 2 if x0 is None else x0
    end = x + length
    while x < end - 0.05:
        bl = min(rnd.uniform(min_len, max_len), end - x)
        if end - (x + bl) < min_len * 0.5:
            bl = end - x
        cx = x + bl / 2
        if skip is None or not skip(cx, z0 + height / 2):
            out = rnd.uniform(-inset, inset)
            b = box(f"{name}_blk", (bl - 0.018, depth, height - 0.018), (cx, y + math.copysign(out, y), z0 + height / 2),
                    rot=(rnd.uniform(-0.01, 0.01), rnd.uniform(-0.008, 0.008), rnd.uniform(-0.01, 0.01)),
                    mat=mat, bevel=0.025, segs=2, jitter=0.012, seed=rnd.randint(0, 99999))
            parts.append(b)
        x += bl


def build_castle_wall(name="SM_CastleWall_01", seed=31, length=6.0, height=7.0, thickness=2.4):
    """Straight curtain wall module: battered plinth, ashlar faces, flagstone wall walk, crenellated parapet."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    stone = M("CastleStone")
    face_d = 0.32
    z = 0.0
    # Plinth: two deeper, taller courses that stick out 15 cm.
    for course in range(2):
        h = 0.55
        for side in (-1, 1):
            _course_blocks(parts, name, length, z, h, side * (thickness / 2 + 0.15 - face_d / 2 - course * 0.07), face_d, rnd, stone, min_len=0.7, max_len=1.3)
        z += h
    # Plinth weathering slope (chamfered cap course).
    for side in (-1, 1):
        cap = box(f"{name}_plinthcap", (length, 0.3, 0.14), (0, side * (thickness / 2 + 0.03), z + 0.05), rot=(side * 0.6, 0, 0), mat=stone, bevel=0.02, jitter=0.01, seed=rnd.randint(0, 999))
        parts.append(cap)
    # Main ashlar courses to wall-walk height.
    walk_z = height - 1.9
    slit_x = rnd.uniform(-1.2, 1.2)
    while z < walk_z - 0.1:
        h = min(rnd.choice((0.4, 0.45, 0.5)), walk_z - z)
        for side in (-1, 1):
            skip = (lambda cx, cz: abs(cx - slit_x) < 0.25 and 2.4 < cz < 3.6) if side == 1 else None
            _course_blocks(parts, name, length, z, h, side * (thickness / 2 - face_d / 2), face_d, rnd, stone, skip=skip)
        z += h
    # Arrow slit on the outer face: splayed reveal made of 4 dressed stones.
    for sx in (-1, 1):
        parts.append(box(f"{name}_slitjamb", (0.18, face_d + 0.05, 1.25), (slit_x + sx * 0.14, thickness / 2 - face_d / 2, 3.0), mat=stone, bevel=0.02, jitter=0.004, seed=rnd.randint(0, 999)))
    parts.append(box(f"{name}_slitlintel", (0.6, face_d + 0.05, 0.2), (slit_x, thickness / 2 - face_d / 2, 3.7), mat=stone, bevel=0.02, jitter=0.004, seed=rnd.randint(0, 999)))
    parts.append(box(f"{name}_slitsill", (0.6, face_d + 0.08, 0.16), (slit_x, thickness / 2 - face_d / 2 + 0.02, 2.33), mat=stone, bevel=0.02, jitter=0.004, seed=rnd.randint(0, 999)))
    parts.append(box(f"{name}_slitdark", (0.08, 0.05, 1.2), (slit_x, thickness / 2 - face_d - 0.02, 3.0), mat=M("DarkWood")))
    # String course under the parapet (projecting moulding).
    for side in (-1, 1):
        parts.append(box(f"{name}_string", (length, 0.22, 0.18), (0, side * (thickness / 2 + 0.04), walk_z - 0.09), mat=stone, bevel=0.03, jitter=0.008, seed=rnd.randint(0, 999)))
    # Wall walk: irregular flagstones.
    fz = walk_z
    y = -thickness / 2 + 0.05
    while y < thickness / 2 - 0.35:
        w = min(rnd.uniform(0.45, 0.75), thickness / 2 - 0.35 - y)
        x = -length / 2
        while x < length / 2 - 0.05:
            l = min(rnd.uniform(0.5, 1.1), length / 2 - x)
            parts.append(box(f"{name}_flag", (l - 0.02, w - 0.02, 0.12), (x + l / 2, y + w / 2, fz - 0.06 + rnd.uniform(-0.01, 0.01)), rot=(rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), 0), mat=stone, bevel=0.015, jitter=0.01, seed=rnd.randint(0, 99999)))
            x += l
        y += w
    # Inner low parapet (0.5 m) and outer crenellated parapet (merlons 1.9 m, crenels 0.9 m).
    _course_blocks(parts, name, length, walk_z, 0.5, -thickness / 2 + 0.2, 0.4, rnd, stone)
    merlon_w, crenel_w = 1.1, 0.9
    x = -length / 2
    i = 0
    while x < length / 2 - 0.01:
        is_merlon = i % 2 == 0
        w = min(merlon_w if is_merlon else crenel_w, length / 2 - x)
        h = 1.9 if is_merlon else 0.95
        zz = walk_z
        while zz < walk_z + h - 0.05:
            ch = min(0.45, walk_z + h - zz)
            _course_blocks(parts, name, w, zz, ch, thickness / 2 - 0.3, 0.6, rnd, stone, x0=x, min_len=0.35, max_len=0.6)
            zz += ch
        # Coping stone with drip edge on every merlon/crenel.
        parts.append(box(f"{name}_coping", (w + 0.02, 0.68, 0.12), (x + w / 2, thickness / 2 - 0.3, walk_z + h + 0.06), rot=(0.04, 0, 0), mat=stone, bevel=0.025, jitter=0.01, seed=rnd.randint(0, 999)))
        x += w
        i += 1
    # Drain spout through the parapet base, and a wooden putlog beam stub.
    parts.append(box(f"{name}_spout", (0.22, 0.6, 0.16), (length / 2 - 1.8, thickness / 2 + 0.1, walk_z + 0.05), mat=stone, bevel=0.02, jitter=0.01, seed=5))
    for px in (-1.8, 1.4):
        parts.append(box(f"{name}_putlog", (0.16, 0.35, 0.16), (px, -thickness / 2 - 0.05, walk_z - 0.8), mat=M("DarkWood"), bevel=0.01, jitter=0.01, seed=int(px * 10)))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=40)
    link_only(obj, "ENV_Castle")
    ucx_box(obj, (length, thickness + 0.3, walk_z), (0, 0, walk_z / 2), 0)
    ucx_box(obj, (length, 0.6, 1.9), (0, thickness / 2 - 0.3, walk_z + 0.95), 1)
    ucx_box(obj, (length, 0.4, 0.5), (0, -thickness / 2 + 0.2, walk_z + 0.25), 2)
    return obj


def _arc_block(name, r_in, r_out, a0, a1, z0, z1, mat, jitter, seed, segs=4):
    """Curved ashlar block (ring sector) with its outer face slightly pillowed."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = []
    for zz in (z0, z1):
        row_o, row_i = [], []
        for s in range(segs + 1):
            a = a0 + (a1 - a0) * s / segs
            pillow = 0.015 * math.sin(math.pi * s / segs)
            row_o.append(bm.verts.new((math.cos(a) * (r_out + pillow), math.sin(a) * (r_out + pillow), zz)))
            row_i.append(bm.verts.new((math.cos(a) * r_in, math.sin(a) * r_in, zz)))
        rings.append((row_o, row_i))
    (o0, i0), (o1, i1) = rings
    for s in range(segs):
        bm.faces.new((o0[s], o0[s + 1], o1[s + 1], o1[s]))
        bm.faces.new((i0[s + 1], i0[s], i1[s], i1[s + 1]))
        bm.faces.new((o0[s + 1], o0[s], i0[s], i0[s + 1]))
        bm.faces.new((o1[s], o1[s + 1], i1[s + 1], i1[s]))
    bm.faces.new((o0[0], o1[0], i1[0], i0[0]))
    bm.faces.new((o1[segs], o0[segs], i0[segs], i1[segs]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.02, segments=1, affect="EDGES", profile=0.5)
    for v in bm.verts:
        v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * jitter
    return _obj_from_bm(name, bm, mat)


def build_castle_tower(name="SM_CastleTower_Round_01", seed=41, radius=3.2, height=11.0):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    stone = M("CastleStone")
    wall_t = 0.35
    z = 0.0
    door_a = -math.pi / 2  # door faces -Y
    slits = [(door_a + math.pi * 0.75, 4.2), (door_a - math.pi * 0.7, 6.8), (door_a + math.pi * 0.1, 8.2)]
    while z < height - 0.05:
        # Battered base: radius grows toward the ground over the first 2 m.
        batter = max(0.0, (2.0 - z) / 2.0) * 0.35
        r = radius + batter
        h = 0.55 if z < 1.1 else rnd.choice((0.42, 0.47, 0.5))
        h = min(h, height - z)
        circ = 2 * math.pi * r
        n = max(10, int(circ / rnd.uniform(0.75, 0.95)))
        phase = rnd.uniform(0, 2 * math.pi)
        for k in range(n):
            a0 = phase + 2 * math.pi * k / n
            a1 = phase + 2 * math.pi * (k + 1) / n - 0.012 / r
            mid = (a0 + a1) / 2
            dd = math.atan2(math.sin(mid - door_a), math.cos(mid - door_a))
            if abs(dd) < 0.24 and z < 2.35:
                continue  # door opening
            if any(abs(math.atan2(math.sin(mid - sa), math.cos(mid - sa))) < 0.07 and sz - 0.6 < z + h / 2 < sz + 0.6 for sa, sz in slits):
                continue
            out = rnd.uniform(-0.012, 0.012)
            parts.append(_arc_block(f"{name}_blk", r - wall_t, r + out, a0, a1, z, z + h - 0.016, stone, 0.01, rnd.randint(0, 99999)))
        z += h
    # Door: pointed-arch surround of voussoirs, heavy plank door with iron strap hinges and ring handle.
    dy = -(radius + 0.12)
    for sx in (-1, 1):
        parts.append(box(f"{name}_jamb", (0.3, 0.55, 2.0), (sx * 0.72, dy, 1.0), mat=stone, bevel=0.025, jitter=0.006, seed=rnd.randint(0, 999)))
    for i in range(7):
        t = i / 6
        ang = math.pi * (1 - t)
        cx, cz = math.cos(ang) * 0.72, 2.0 + math.sin(ang) * 0.55
        parts.append(box(f"{name}_vouss", (0.3, 0.55, 0.26), (cx, dy, cz), rot=(0, -(ang - math.pi / 2), 0), mat=stone, bevel=0.02, jitter=0.006, seed=rnd.randint(0, 999)))
    for p in range(5):
        px = -0.5 + p * 0.25
        parts.append(box(f"{name}_doorplank", (0.24, 0.08, 2.3), (px, dy + 0.15, 1.15), mat=M("DarkWood"), bevel=0.008, jitter=0.004, seed=rnd.randint(0, 999)))
    for hz in (0.5, 1.7):
        parts.append(box(f"{name}_strap", (1.05, 0.02, 0.07), (-0.05, dy + 0.1, hz), mat=M("RustedIron"), bevel=0.005, jitter=0.002, seed=int(hz * 10)))
        for bx in (-0.5, -0.25, 0.0, 0.25):
            parts.append(cylinder(f"{name}_rivet", 0.012, 0.015, (bx, dy + 0.085, hz), (math.pi / 2, 0, 0), M("RustedIron"), verts=6))
    ring = tube_along(f"{name}_ring", [Vector((0.32 + 0.06 * math.cos(a), dy + 0.07, 1.05 + 0.06 * math.sin(a))) for a in [2 * math.pi * i / 12 for i in range(13)]], [0.01] * 13, M("Iron"), sides=6, cap=False)
    parts.append(ring)
    # Stone step at the threshold.
    parts.append(box(f"{name}_step", (1.8, 0.7, 0.18), (0, dy - 0.3, 0.09), mat=stone, bevel=0.03, jitter=0.01, seed=77))
    # Arrow slits: dark recess + dressed frame.
    for sa, sz in slits:
        ca, sa_ = math.cos(sa), math.sin(sa)
        rr = radius + 0.02
        slit = box(f"{name}_slit", (0.07, 0.3, 1.1), (ca * (rr - 0.15), sa_ * (rr - 0.15), sz), rot=(0, 0, sa - math.pi / 2 + math.pi / 2), mat=M("DarkWood"))
        slit.rotation_euler = (0, 0, sa)
        parts.append(slit)
        for off in (-1, 1):
            j = box(f"{name}_slitjamb", (0.4, 0.14, 1.3), (0, 0, 0), mat=stone, bevel=0.02, jitter=0.005, seed=rnd.randint(0, 999))
            tang = Vector((-sa_, ca, 0))
            j.location = Vector((ca * rr, sa_ * rr, sz)) + tang * off * 0.11
            j.rotation_euler = (0, 0, sa)
            parts.append(j)
    # Corbel ring + machicolation parapet with crenellations at the top.
    top = height
    n_corb = 22
    for k in range(n_corb):
        a = 2 * math.pi * k / n_corb
        for step, (dz, out) in enumerate(((0.0, 0.12), (0.22, 0.26), (0.44, 0.4))):
            c = box(f"{name}_corbel", (0.3, 0.26 + out, 0.2), (0, 0, 0), mat=stone, bevel=0.02, jitter=0.006, seed=rnd.randint(0, 999))
            c.location = (math.cos(a) * (radius + out / 2 - 0.05), math.sin(a) * (radius + out / 2 - 0.05), top - 0.45 + dz)
            c.rotation_euler = (0, 0, a + math.pi / 2)
            parts.append(c)
    pr = radius + 0.45
    zz = top + 0.1
    while zz < top + 1.0:
        h = 0.45
        n = int(2 * math.pi * pr / 0.8)
        ph = rnd.uniform(0, 1)
        for k in range(n):
            a0 = ph + 2 * math.pi * k / n
            parts.append(_arc_block(f"{name}_para", pr - 0.4, pr, a0, a0 + 2 * math.pi / n - 0.01, zz, zz + h - 0.015, stone, 0.01, rnd.randint(0, 99999)))
        zz += h
    n_mer = 12
    for k in range(n_mer):
        a0 = 2 * math.pi * k / n_mer
        a1 = a0 + 2 * math.pi / n_mer * 0.55
        parts.append(_arc_block(f"{name}_merlon", pr - 0.4, pr, a0, a1, zz, zz + 0.85, stone, 0.012, rnd.randint(0, 99999), segs=3))
        parts.append(_arc_block(f"{name}_merloncap", pr - 0.44, pr + 0.04, a0 - 0.01, a1 + 0.01, zz + 0.85, zz + 0.95, stone, 0.006, rnd.randint(0, 99999), segs=3))
    # Floor deck (planks on joists) at the top.
    deck_z = top - 0.05
    for i in range(int(2 * radius / 0.25)):
        x = -radius + 0.125 + i * 0.25
        half = math.sqrt(max(0, (radius - wall_t) ** 2 - x ** 2))
        if half > 0.1:
            parts.append(box(f"{name}_deck", (0.23, 2 * half, 0.06), (x, 0, deck_z + rnd.uniform(-0.005, 0.005)), mat=M("Planks"), bevel=0.005, jitter=0.004, seed=i))
    # Conical roof: shingle rows on a cone, raised on short posts above the parapet.
    roof_base = zz + 0.95 + 0.6
    roof_h = 4.6
    rr0 = pr + 0.35
    for p in range(8):
        a = 2 * math.pi * p / 8
        parts.append(box(f"{name}_roofpost", (0.16, 0.16, 1.6), (math.cos(a) * (pr - 0.6), math.sin(a) * (pr - 0.6), roof_base - 0.8), mat=M("DarkWood"), bevel=0.01, jitter=0.01, seed=p))
    rows = 16
    for row in range(rows):
        t0 = row / rows
        t1 = (row + 1.25) / rows
        r0 = rr0 * (1 - t0)
        r1 = rr0 * (1 - min(1, t1))
        z0 = roof_base + roof_h * t0
        z1 = roof_base + roof_h * min(1, t1)
        n = max(6, int(2 * math.pi * r0 / 0.32))
        ph = (row % 2) * math.pi / n + rnd.uniform(-0.02, 0.02)
        for k in range(n):
            a0 = ph + 2 * math.pi * k / n
            a1 = a0 + 2 * math.pi / n * 0.94
            bm = bmesh.new()
            droop = rnd.uniform(0.0, 0.04)
            v = [bm.verts.new((math.cos(a0) * (r0 + 0.02), math.sin(a0) * (r0 + 0.02), z0 - droop)),
                 bm.verts.new((math.cos(a1) * (r0 + 0.02), math.sin(a1) * (r0 + 0.02), z0 - droop)),
                 bm.verts.new((math.cos(a1) * r1, math.sin(a1) * r1, z1)),
                 bm.verts.new((math.cos(a0) * r1, math.sin(a0) * r1, z1))]
            f = bm.faces.new(v)
            bmesh.ops.solidify(bm, geom=[f], thickness=0.03)
            parts.append(_obj_from_bm(f"{name}_shingle", bm, M("Shingles")))
    # Finial.
    parts.append(tube_along(f"{name}_finial", [Vector((0, 0, roof_base + roof_h - 0.2)), Vector((0, 0, roof_base + roof_h + 0.6)), Vector((0.03, 0, roof_base + roof_h + 1.1))], [0.08, 0.03, 0.01], M("RustedIron"), sides=8))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=40)
    link_only(obj, "ENV_Castle")
    c = cylinder(f"UCX_{name}_00", radius + 0.1, height + 1.0, (0, 0, (height + 1.0) / 2), verts=12)
    c.parent = obj
    c.display_type = "WIRE"
    c.hide_render = True
    link_only(c, "ENV_Castle")
    return obj

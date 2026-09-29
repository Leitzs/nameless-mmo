"""Castle kit, batch 2: corner, damaged/ruined walls, square & broken towers, gatehouse + gate + portcullis,
stairs, arch, bridge, hoarding platform, watchtower, door, window, debris. exec() after kitlib, castle, buildings, items, props3."""

V = Vector
CC = "ENV_Castle"


def _jagged(length, base_h, amp, seed):
    """Broken-top height function: noisy jagged line along X."""
    off = seed * 3.7
    return lambda x: base_h + amp * (noise.noise(V((x * 0.7 + off, 0, 0))) * 0.8 + noise.noise(V((x * 2.3 + off, 1, 0))) * 0.3)


def ashlar_panel(parts, name, length, height, thickness, rnd, mat, top_fn=None, hole=None, face_d=0.3, x0=None, course=(0.4, 0.45, 0.5), both=True, fill_core=True):
    """Double-faced ashlar wall along X centred on Y=0. top_fn(x) caps each block column (broken tops);
    hole(x, z) returns True where blocks are removed (openings, breaches). A rubble core fills broken tops."""
    z = 0.0
    x0 = -length / 2 if x0 is None else x0
    while z < height - 0.05:
        h = min(rnd.choice(course), height - z)
        for side in ((-1, 1) if both else (1,)):
            x = x0
            while x < x0 + length - 0.05:
                bl = min(rnd.uniform(0.45, 1.0), x0 + length - x)
                cx = x + bl / 2
                top = top_fn(cx) if top_fn else height
                if z + h * 0.5 < top and not (hole and hole(cx, z + h / 2)):
                    out = rnd.uniform(-0.012, 0.012)
                    b = box(f"{name}_blk", (bl - 0.018, face_d, h - 0.018), (cx, side * (thickness / 2 - face_d / 2) + side * out, z + h / 2),
                            rot=(rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01)), mat=mat, bevel=0.025, segs=2, jitter=0.012, seed=rnd.randint(0, 99999))
                    if top_fn and z + h > top - 0.3:
                        dent(b, 0.05, seed=rnd.randint(0, 999), count=4, radius=0.2)  # weathered, chipped top stones
                    parts.append(b)
                x += bl
        z += h
    if top_fn and fill_core:
        # Exposed rubble core along the broken top.
        x = x0
        while x < x0 + length:
            t = top_fn(x)
            r = rock(f"{name}_core", (0.25, thickness * 0.3, 0.18), seed=rnd.randint(0, 9999), mat=M("Rock"), subdiv=2)
            r.location = (x, 0, t - 0.25)
            parts.append(r)
            x += rnd.uniform(0.35, 0.6)


def debris(parts, name, center, spread, count, rnd, size=(0.15, 0.45), mat_key="CastleStone"):
    """Fallen dressed blocks and rubble scattered around a point."""
    for i in range(count):
        s = rnd.uniform(*size)
        if rnd.random() < 0.55:
            b = box(f"{name}_deb", (s * rnd.uniform(1.2, 2.2), s, s * rnd.uniform(0.7, 1.1)), (0, 0, 0), mat=M(mat_key), bevel=0.03, segs=2, jitter=0.02, seed=rnd.randint(0, 9999))
            dent(b, 0.04, seed=i, count=5, radius=s * 0.6)
        else:
            b = rock(f"{name}_rub", (s, s * 0.8, s * 0.6), seed=rnd.randint(0, 9999), mat=M("Rock"), subdiv=2)
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, spread)
        b.location = V(center) + V((math.cos(a) * r, math.sin(a) * r * 0.7, s * 0.3))
        b.rotation_euler = (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0, 3.14))
        parts.append(b)


def _merlons(parts, name, length, z, y, rnd, x0=None, thick=0.6):
    x = -length / 2 if x0 is None else x0
    i = 0
    while x < (x0 if x0 is not None else -length / 2) + length - 0.01:
        mer = i % 2 == 0
        w = min(1.1 if mer else 0.9, (x0 if x0 is not None else -length / 2) + length - x)
        h = 1.9 if mer else 0.95
        zz = z
        while zz < z + h - 0.05:
            ch = min(0.45, z + h - zz)
            _course_blocks(parts, name, w, zz, ch, y, thick, rnd, M("CastleStone"), x0=x, min_len=0.35, max_len=0.6)
            zz += ch
        parts.append(box(f"{name}_coping", (w + 0.02, thick + 0.08, 0.12), (x + w / 2, y, z + h + 0.06), rot=(0.04, 0, 0), mat=M("CastleStone"), bevel=0.025, jitter=0.01, seed=rnd.randint(0, 999)))
        x += w
        i += 1


def build_wall_damaged(name="SM_CastleWall_Damaged_01", seed=401, length=6.0, height=7.0, thickness=2.4):
    remove_asset(name); rnd = random.Random(seed); p = []
    top = _jagged(length, height * 0.62, 1.6, seed)
    ashlar_panel(p, name, length, height, thickness, rnd, M("CastleStone"), top_fn=top)
    debris(p, name, (0.8, -thickness / 2 - 0.9, 0), 1.6, 22, rnd)
    debris(p, name, (-1.2, thickness / 2 + 0.7, 0), 1.2, 12, rnd)
    # Ivy/moss creeping over the broken top.
    for i in range(10):
        x = rnd.uniform(-length / 2, length / 2)
        m = rock(f"{name}_moss", (0.3, 0.15, 0.08), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (x, rnd.choice((-1, 1)) * (thickness / 2 - 0.05), top(x) - 0.1)
        p.append(m)
    return finish_asset(name, p, CC, [((length, thickness, height * 0.5), (0, 0, height * 0.25))], lods=False)


def build_wall_corner(name="SM_CastleWall_Corner_01", seed=411, height=7.0, thickness=2.4):
    """90-degree corner block (thickness x thickness footprint) with a projecting pilaster and quoins."""
    remove_asset(name); rnd = random.Random(seed); p = []
    T = thickness
    walk = height - 1.9
    for side in range(4):
        blocks = []
        z = 0.0
        k = 0
        while z < walk - 0.05:
            h = min(0.45, walk - z)
            _course_blocks(blocks, name, T, z, h, T / 2 - 0.15, 0.3, rnd, M("CastleStone"), min_len=0.5, max_len=1.2)
            z += h
            k += 1
        for b in blocks:
            b.matrix_world = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(blocks)
    # Big dressed quoins on the outer corner, alternating long/short.
    z = 0.0
    k = 0
    while z < walk:
        lx = 0.9 if k % 2 == 0 else 0.5
        ly = 0.5 if k % 2 == 0 else 0.9
        p.append(box(f"{name}_quoin", (lx, ly, 0.44), (T / 2 - lx / 2 + 0.06, -T / 2 + ly / 2 - 0.06, z + 0.22), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.01, seed=rnd.randint(0, 999)))
        z += 0.45
        k += 1
    for i in range(int(T / 0.6)):
        for j in range(int(T / 0.6)):
            p.append(box(f"{name}_flag", (0.58, 0.58, 0.12), (-T / 2 + 0.3 + i * 0.6, -T / 2 + 0.3 + j * 0.6, walk - 0.06), mat=M("CastleStone"), bevel=0.015, jitter=0.01, seed=rnd.randint(0, 9999)))
    # Parapet on the two outer faces.
    pp = []
    _merlons(pp, name, T, walk, 0, rnd, x0=-T / 2)
    for b in pp:
        b.matrix_world = Matrix.Translation(V((0, -T / 2 + 0.3, 0))) @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
    p.extend(pp)
    pp = []
    _merlons(pp, name, T, walk, 0, rnd, x0=-T / 2)
    for b in pp:
        b.matrix_world = Matrix.Translation(V((T / 2 - 0.3, 0, 0))) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
    p.extend(pp)
    return finish_asset(name, p, CC, [((T, T, walk), (0, 0, walk / 2))], lods=False)


def build_tower_square(name="SM_CastleTower_Square_Small_01", seed=421, W=4.5, H=12.0):
    """Small square tower: plinth, ashlar faces with quoins, arrow slits, machicolated crenellation, pyramid slate roof."""
    remove_asset(name); rnd = random.Random(seed); p = []
    slits = [(0, 4.0), (1, 6.5), (2, 5.0), (3, 8.0), (0, 8.8)]
    for side in range(4):
        blocks = []
        hole = (lambda s: (lambda x, z: any(ss == s and abs(x) < 0.12 and abs(z - sz) < 0.6 for ss, sz in slits)))(side)
        ashlar_panel(blocks, name, W, H, 0.6, rnd, M("CastleStone"), hole=hole, face_d=0.3, both=False)
        for b in blocks:
            b.matrix_world = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Translation(V((0, -(W / 2 - 0.3) - 0.3, 0))) @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(blocks)
        for ss, sz in slits:
            if ss == side:
                d = box(f"{name}_slit", (0.07, 0.3, 1.1), (0, -W / 2 + 0.12, sz), mat=M("DarkWood"))
                d.matrix_world = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Translation(V((0, -W / 2 + 0.1, sz)))
                p.append(d)
    # Corner quoins.
    for cx, cy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        z = 0.0; k = 0
        while z < H:
            s = 0.8 if k % 2 == 0 else 0.5
            p.append(box(f"{name}_quoin", (s, 1.3 - s, 0.44), (cx * (W / 2 - s / 2 + 0.03), cy * (W / 2 - (1.3 - s) / 2 + 0.03), z + 0.22), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.01, seed=rnd.randint(0, 999)))
            z += 0.45; k += 1
    # Plinth course and corbels + crenellation.
    p.append(box(f"{name}_plinth", (W + 0.4, W + 0.4, 0.6), (0, 0, 0.3), mat=M("CastleStone"), bevel=0.04, segs=2, jitter=0.02, seed=5))
    for side in range(4):
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z")
        for i in range(7):
            x = -W / 2 + 0.35 + i * (W - 0.7) / 6
            for step, (dz, out) in enumerate(((0.0, 0.12), (0.2, 0.25), (0.4, 0.38))):
                c = box(f"{name}_corb", (0.28, 0.2 + out, 0.18), (0, 0, 0), mat=M("CastleStone"), bevel=0.02, jitter=0.006, seed=rnd.randint(0, 999))
                c.matrix_world = m @ Matrix.Translation(V((x, -W / 2 - out / 2 + 0.05, H - 0.4 + dz)))
                p.append(c)
        pp = []
        _merlons(pp, name, W + 0.8, H + 0.2, 0, rnd, x0=-(W + 0.8) / 2, thick=0.45)
        for b in pp:
            b.matrix_world = m @ Matrix.Translation(V((0, -W / 2 - 0.2, 0))) @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(pp)
    # Pyramid roof of slate courses.
    rb, rh = H + 1.6, 4.2
    half = W / 2 + 0.2
    for side in range(4):
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z")
        rows = 18
        for r in range(rows):
            t0 = r / rows
            hw = half * (1 - t0)
            z = rb + rh * t0
            x = -hw + (r % 2) * 0.1
            while x < hw - 0.05:
                pw = min(rnd.uniform(0.2, 0.3), hw - x)
                s = box(f"{name}_slate", (pw - 0.01, 0.33, 0.02), (0, 0, 0), mat=M("RoofTiles"), bevel=0.003, jitter=0.003, seed=rnd.randint(0, 99999))
                s.matrix_world = m @ Matrix.LocRotScale(V((x + pw / 2, -hw - 0.02, z)), Euler((math.atan2(rh, half) * -1 + math.pi / 2 - 0.08 - math.pi / 2 + math.atan2(half, rh) * 0 + (math.pi / 2 - math.atan2(rh, half)) * -1 + math.pi / 2, 0, 0)).to_quaternion(), V((1, 1, 1)))
                s.matrix_world = m @ Matrix.LocRotScale(V((x + pw / 2, -hw - 0.02, z)), Euler((math.atan2(half, rh), 0, 0)).to_quaternion(), V((1, 1, 1)))
                p.append(s)
                x += pw
    p.append(tube_along(f"{name}_finial", [V((0, 0, rb + rh - 0.2)), V((0, 0, rb + rh + 0.7))], [0.07, 0.01], M("RustedIron"), sides=8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"{name}_roofpost", (0.16, 0.16, 1.4), (sx * (W / 2 - 0.4), sy * (W / 2 - 0.4), H + 0.9), mat=M("DarkWood"), bevel=0.01, jitter=0.006, seed=rnd.randint(0, 99)))
    return finish_asset(name, p, CC, [((W + 0.4, W + 0.4, H), (0, 0, H / 2))], lods=False)


def build_tower_broken(name="SM_CastleTower_Broken_01", seed=431, radius=3.2, height=9.0):
    """Ruined round tower: jagged collapsed top, a breach on one side, rubble heaped inside and out."""
    remove_asset(name); rnd = random.Random(seed); p = []
    wall_t = 0.5
    z = 0.0
    top = lambda a: height * 0.55 + 2.6 * (noise.noise(V((math.cos(a) * 1.5 + seed, math.sin(a) * 1.5, 0))) * 0.9 + 0.35)
    breach = lambda a, zz: abs(math.atan2(math.sin(a - 0.8), math.cos(a - 0.8))) < 0.35 and zz > 1.2 and zz < 5.0 - 3 * abs(math.atan2(math.sin(a - 0.8), math.cos(a - 0.8)))
    while z < height:
        h = rnd.choice((0.42, 0.47, 0.5))
        r = radius + max(0.0, (2.0 - z) / 2.0) * 0.35
        n = max(10, int(2 * math.pi * r / rnd.uniform(0.75, 0.95)))
        ph = rnd.uniform(0, 2 * math.pi)
        for k in range(n):
            a0 = ph + 2 * math.pi * k / n
            a1 = a0 + 2 * math.pi / n - 0.012 / r
            mid = (a0 + a1) / 2
            if z + h / 2 > top(mid) or breach(mid, z):
                continue
            b = _arc_block(f"{name}_blk", r - wall_t, r + rnd.uniform(-0.015, 0.015), a0, a1, z, z + h - 0.016, M("CastleStone"), 0.012, rnd.randint(0, 99999))
            if z + h > top(mid) - 0.5:
                dent(b, 0.06, seed=k, count=3, radius=0.25)
            p.append(b)
        z += h
    debris(p, name, (math.cos(0.8) * (radius + 1.5), math.sin(0.8) * (radius + 1.5), 0), 2.2, 35, rnd)
    debris(p, name, (0, 0, 0), radius - 0.8, 30, rnd, size=(0.2, 0.5))
    # Broken floor beams jutting from the inner wall.
    for i in range(4):
        a = rnd.uniform(0, 2 * math.pi)
        s = V((math.cos(a) * (radius - wall_t), math.sin(a) * (radius - wall_t), 4.0 + rnd.uniform(-0.2, 0.2)))
        e = s - V((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.6, 1.6) + V((0, 0, rnd.uniform(-0.6, 0.1)))
        p.append(tube_along(f"{name}_beam{i}", [s, e], [0.1, 0.08], M("DarkWood"), sides=6, twist_noise=0.2, seed=i))
    return finish_asset(name, p, CC, [((radius * 2, radius * 2, height * 0.5), (0, 0, height * 0.25))], lods=False)


def _arch_ring(parts, name, span, spring_z, depth, rnd, pointed=True, thick=0.45, y=0.0, mat_key="CastleStone"):
    """Voussoir arch centred on X=0 springing at spring_z. Pointed (two-centred gothic) or semicircular.
    Returns the apex height of the arch's outer edge."""
    per_side = 7
    rr_in = span * 0.75 if pointed else span / 2
    rmid = rr_in + thick / 2
    if pointed:
        cx = -span / 2 + rr_in                      # left arc centre (right of the left springer)
        a_top = math.acos(max(-1.0, min(1.0, -cx / rr_in)))  # where the two arcs meet above x=0
        arcs = [(cx, math.pi, a_top), (-cx, 0.0, math.pi - a_top)]
    else:
        arcs = [(0.0, math.pi, math.pi / 2), (0.0, 0.0, math.pi / 2)]
    for ccx, a0, a1 in arcs:
        for i in range(per_side):
            a = a0 + (a1 - a0) * (i + 0.5) / per_side
            seg = abs(a1 - a0) * rmid / per_side
            parts.append(box(f"{name}_vou", (thick, depth, seg - 0.012), (ccx + math.cos(a) * rmid, y, spring_z + math.sin(a) * rmid),
                             rot=(0, -a, 0), mat=M(mat_key), bevel=0.02, segs=2, jitter=0.005, seed=rnd.randint(0, 9999)))
    if pointed:
        apex = spring_z + math.sin(a_top) * (rr_in + thick)
        key_z = spring_z + math.sin(a_top) * rmid
    else:
        apex = spring_z + rr_in + thick
        key_z = spring_z + rmid
    parts.append(box(f"{name}_key", (0.3, depth + 0.06, thick + 0.1), (0, y, key_z), mat=M(mat_key), bevel=0.025, segs=2, jitter=0.006, seed=rnd.randint(0, 999)))
    return apex


def build_arch(name="SM_StoneArch_01", seed=441, span=3.0, spring=2.4):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        z = 0.0
        while z < spring:
            h = 0.42
            p.append(box(f"{name}_pier", (0.75, 0.75, h - 0.015), (sx * (span / 2 + 0.375), 0, z + h / 2), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.01, seed=rnd.randint(0, 999)))
            z += h
        p.append(box(f"{name}_impost", (0.9, 0.9, 0.16), (sx * (span / 2 + 0.375), 0, spring + 0.08), mat=M("CastleStone"), bevel=0.02, segs=2, jitter=0.006, seed=sx))
        p.append(box(f"{name}_base", (0.95, 0.95, 0.25), (sx * (span / 2 + 0.375), 0, 0.125), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.01, seed=sx + 3))
    apex = _arch_ring(p, name, span, spring + 0.16, 0.7, rnd)
    for i in range(5):
        m = rock(f"{name}_moss", (0.25, 0.3, 0.06), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-span / 2 - 0.5, span / 2 + 0.5), 0, apex + 0.2 - abs(rnd.uniform(-1, 1)) * 0.8)
        p.append(m)
    return finish_asset(name, p, CC, [((0.75, 0.75, spring), (sx * (span / 2 + 0.375), 0, spring / 2)) for sx in (-1, 1)], lods=False)


def build_portcullis(name="SM_Portcullis_01", seed=451, W=3.2, H=4.2):
    remove_asset(name); p = []
    for i in range(9):
        x = -W / 2 + 0.1 + i * (W - 0.2) / 8
        p.append(box(f"{name}_v", (0.07, 0.07, H), (x, 0, H / 2), mat=M("RustedIron"), bevel=0.008, segs=1, jitter=0.002, seed=i))
        p.append(cylinder(f"{name}_spike", 0.045, 0.22, (x, 0, -0.11), mat=M("RustedIron"), verts=4, radius_top=0.004))
        p[-1].rotation_euler = (math.pi, 0, math.pi / 4)
    for j in range(7):
        z = 0.3 + j * (H - 0.5) / 6
        p.append(box(f"{name}_h", (W, 0.05, 0.07), (0, 0.05, z), mat=M("RustedIron"), bevel=0.006, segs=1, jitter=0.002, seed=j + 20))
        for i in range(9):
            p.append(cylinder(f"{name}_rivet", 0.02, 0.02, (-W / 2 + 0.1 + i * (W - 0.2) / 8, 0.085, z), (math.pi / 2, 0, 0), M("Iron"), verts=6))
    return finish_asset(name, p, CC, [((W, 0.2, H), (0, 0, H / 2))])


def build_gate_doors(name="SM_CastleGate_Doors_01", seed=461, W=3.0, H=3.6):
    """Heavy double gate: vertical planks, horizontal ledges with diagonal braces, iron straps, studs, ring pulls, wicket door."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for side in (-1, 1):
        leaf = W / 2
        for i in range(6):
            x = side * (i * leaf / 6 + leaf / 12)
            p.append(plank(f"{name}_plank", (leaf / 6 - 0.008, 0.1, H), (x, 0, H / 2), mat_key="DarkWood", seed=rnd.randint(0, 999), wear=0.01))
        for z in (0.5, H / 2, H - 0.5):
            p.append(box(f"{name}_strap", (leaf - 0.06, 0.02, 0.1), (side * leaf / 2, -0.06, z), mat=M("RustedIron"), bevel=0.004, segs=1, jitter=0.002, seed=int(z * 10)))
            for k in range(8):
                p.append(cylinder(f"{name}_stud", 0.02, 0.02, (side * (0.1 + k * (leaf - 0.2) / 7), -0.075, z), (math.pi / 2, 0, 0), M("Iron"), verts=8))
        diag = math.hypot(leaf - 0.2, H / 2 - 0.6)
        p.append(plank(f"{name}_brace", (diag, 0.06, 0.16), (side * leaf / 2, 0.08, H * 0.25 + 0.05), rot=(0, side * math.atan2(H / 2 - 0.6, leaf - 0.2), 0), mat_key="DarkWood", seed=side))
        ring = [V((side * 0.25 + 0.09 * math.cos(a), -0.1, 1.3 + 0.09 * math.sin(a))) for a in [2 * math.pi * i / 16 for i in range(17)]]
        p.append(tube_along(f"{name}_ring{side}", ring, [0.014] * 17, M("Iron"), sides=6, cap=False))
    # Wicket door outline in the left leaf.
    for x in (-1.25, -0.55):
        p.append(box(f"{name}_wicket", (0.04, 0.02, 1.8), (x, -0.06, 0.95), mat=M("Iron"), bevel=0.003, segs=1))
    return finish_asset(name, p, CC, [((W, 0.2, H), (0, 0, H / 2))])


def build_gatehouse(name="SM_Gatehouse_01", seed=471, W=9.0, D=6.0, H=10.0, gate_w=3.2, gate_h=4.6):
    """Twin-flanked gatehouse block: ashlar walls with a pointed gate passage through, murder holes,
    portcullis slot, crenellated roof walk. Gate doors/portcullis are separate assets placed in the passage."""
    remove_asset(name); rnd = random.Random(seed); p = []
    passage = lambda x, z: abs(x) < gate_w / 2 + 0.1 and z < gate_h + 0.9
    for side, (L, off) in enumerate(((W, D / 2), (D, W / 2), (W, D / 2), (D, W / 2))):
        blocks = []
        hole = passage if side in (0, 2) else None
        ashlar_panel(blocks, name, L, H, 0.7, rnd, M("CastleStone"), hole=hole, face_d=0.35, both=False)
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Translation(V((0, -off - 0.35 + 0.35, 0)))
        for b in blocks:
            b.matrix_world = m @ Matrix.Translation(V((0, -0.0, 0))) @ Matrix.LocRotScale(b.location.copy() + V((0, -0.35, 0)), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(blocks)
        if side in (0, 2):
            arch = []
            _arch_ring(arch, name, gate_w, gate_h - gate_w * 0.35, 0.8, rnd)
            for b in arch:
                b.matrix_world = m @ Matrix.LocRotScale(b.location.copy() + V((0, -0.35, 0)), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
            p.extend(arch)
    # Passage vault: side walls and a barrel vault of blocks, with the portcullis groove.
    for sx in (-1, 1):
        wall = []
        ashlar_panel(wall, name, D - 0.8, gate_h - 1.0, 0.4, rnd, M("CastleStone"), face_d=0.3, both=False)
        for b in wall:
            b.matrix_world = Matrix.Translation(V((sx * (gate_w / 2 + 0.2), 0, 0))) @ Matrix.Rotation(math.pi / 2 * sx, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(wall)
        p.append(box(f"{name}_groove", (0.12, 0.16, gate_h), (sx * (gate_w / 2 + 0.05), -D / 2 + 1.0, gate_h / 2), mat=M("DarkWood")))
    n = 12
    for k in range(n + 1):
        a = math.pi * k / n
        for y in [(-D / 2 + 0.6) + j * 0.55 for j in range(int((D - 1.2) / 0.55))]:
            p.append(box(f"{name}_vault", (0.34, 0.52, 0.3), (math.cos(a) * gate_w / 2, y, gate_h - 1.0 + math.sin(a) * gate_w / 2 * 0.6), rot=(0, -(a - math.pi / 2), 0), mat=M("CastleStone"), bevel=0.02, jitter=0.008, seed=rnd.randint(0, 9999)))
    # Roof walk flagstones, parapet all round, machicolation brackets over the gate.
    for i in range(int(W / 0.7)):
        for j in range(int(D / 0.7)):
            p.append(box(f"{name}_roof", (0.68, 0.68, 0.12), (-W / 2 + 0.35 + i * 0.7, -D / 2 + 0.35 + j * 0.7, H - 0.06), mat=M("CastleStone"), bevel=0.015, jitter=0.01, seed=rnd.randint(0, 99999)))
    for side, (L, off) in enumerate(((W, D / 2), (D, W / 2), (W, D / 2), (D, W / 2))):
        pp = []
        _merlons(pp, name, L, H, 0, rnd, x0=-L / 2, thick=0.5)
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Translation(V((0, -off + 0.25, 0)))
        for b in pp:
            b.matrix_world = m @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(pp)
    for i in range(5):
        x = -gate_w / 2 - 0.4 + i * (gate_w + 0.8) / 4
        for dz, out in ((0.0, 0.15), (0.22, 0.32), (0.44, 0.5)):
            p.append(box(f"{name}_mach", (0.3, 0.25 + out, 0.2), (x, -D / 2 - out / 2, H - 1.4 + dz), mat=M("CastleStone"), bevel=0.02, jitter=0.006, seed=rnd.randint(0, 999)))
    obj = finish_asset(name, p, CC, [((W, D, 0.8), (0, 0, H - 0.4))] +
                       [((W / 2 - gate_w / 2 - 0.2, D, H), (sx * (W / 4 + gate_w / 4 + 0.1), 0, H / 2)) for sx in (-1, 1)] +
                       [((gate_w + 0.6, D, H - gate_h - 0.9), (0, 0, (H + gate_h + 0.9) / 2))], lods=False)
    socket(obj, "Gate_Doors", (0, D / 2 - 0.9, 0))
    socket(obj, "Gate_Portcullis", (0, -D / 2 + 1.0, 0))
    return obj


def build_stairs(name="SM_CastleStairs_Stone_01", seed=481, steps=12, rise=0.19, run=0.3, width=1.8):
    """Straight stone flight with worn nosings and a solid stringer wall on one side."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for i in range(steps):
        z = i * rise
        y = i * run
        s = box(f"{name}_step", (width, run + 0.05, rise + 0.02), (0, y, z + rise / 2), mat=M("CastleStone"), bevel=0.025, segs=2, jitter=0.008, seed=rnd.randint(0, 999))
        dent(s, 0.025, seed=i, count=3, radius=0.35)  # worn in the middle by foot traffic
        p.append(s)
        p.append(box(f"{name}_fill", (width, run, max(0.02, z)), (0, y, z / 2), mat=M("FoundationStone"), bevel=0.01, jitter=0.01, seed=rnd.randint(0, 999)) if z > 0.02 else rock(f"{name}_pad", (0.1, 0.1, 0.02), seed=i, mat=M("Rock"), subdiv=1))
    Ht = steps * rise
    L = steps * run
    wall = []
    ashlar_panel(wall, name, L + 0.3, Ht + 0.9, 0.4, rnd, M("CastleStone"), top_fn=lambda x: (x + L / 2 + 0.15) / (L + 0.3) * Ht + 0.9, face_d=0.4, both=False, fill_core=False)
    for b in wall:
        b.matrix_world = Matrix.Translation(V((width / 2 + 0.2, L / 2 - 0.15, 0))) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
    p.extend(wall)
    return finish_asset(name, p, CC, [((width, L, Ht), (0, L / 2, Ht / 2))], lods=False)


def build_bridge_stone(name="SM_Bridge_Stone_01", seed=491, span=10.0, width=4.0):
    """Single-arch stone bridge: segmental barrel arch, spandrel walls, parapets with coping, cobbled deck."""
    remove_asset(name); rnd = random.Random(seed); p = []
    rise = 2.6
    R = (span ** 2 / 4 + rise ** 2) / (2 * rise)
    cz = rise - R
    a_max = math.asin((span / 2) / R)
    n = 22
    for k in range(n):
        a = -a_max + 2 * a_max * (k + 0.5) / n
        for j in range(int(width / 0.55)):
            y = -width / 2 + 0.275 + j * 0.55
            p.append(box(f"{name}_vou", (2 * R * a_max / n - 0.02, 0.52, 0.5), (math.sin(a) * (R + 0.25), y, cz + math.cos(a) * (R + 0.25)), rot=(0, a, 0), mat=M("CastleStone"), bevel=0.02, jitter=0.008, seed=rnd.randint(0, 99999)))
    deck = rise + 0.9
    for sy in (-1, 1):
        wall = []
        top = lambda x: deck
        hole = lambda x, z, R=R, cz=cz: (x ** 2 + (z - cz) ** 2) < (R + 0.45) ** 2 and z < rise + 0.4 and abs(x) < span / 2
        ashlar_panel(wall, name, span + 2.0, deck, 0.4, rnd, M("CastleStone"), hole=hole, face_d=0.4, both=False)
        for b in wall:
            b.matrix_world = Matrix.Translation(V((0, sy * (width / 2 - 0.2), 0))) @ Matrix.Rotation(0 if sy < 0 else math.pi, 4, "Z") @ Matrix.LocRotScale(b.location.copy() + V((0, -0.0, 0)), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(wall)
        par = []
        ashlar_panel(par, name, span + 2.0, 0.9, 0.4, rnd, M("CastleStone"), face_d=0.4, both=False, course=(0.45,))
        for b in par:
            b.matrix_world = Matrix.Translation(V((0, sy * (width / 2 - 0.2), deck))) @ Matrix.Rotation(0 if sy < 0 else math.pi, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(par)
        x = -(span + 2.0) / 2
        while x < (span + 2.0) / 2:
            l = min(rnd.uniform(0.7, 1.2), (span + 2.0) / 2 - x)
            p.append(box(f"{name}_coping", (l - 0.02, 0.52, 0.14), (x + l / 2, sy * (width / 2 - 0.2), deck + 0.97), mat=M("CastleStone"), bevel=0.03, jitter=0.01, seed=rnd.randint(0, 9999)))
            x += l
    # Cobbled deck.
    for i in range(int((span + 2.0) / 0.22)):
        for j in range(int((width - 0.8) / 0.22)):
            c = rock(f"{name}_cob", (0.1, 0.09, 0.05), seed=rnd.randint(0, 99999), mat=M("Rock"), subdiv=1)
            c.location = (-(span + 2.0) / 2 + 0.11 + i * 0.22 + rnd.uniform(-0.02, 0.02), -width / 2 + 0.51 + j * 0.22 + (i % 2) * 0.05, deck + 0.02)
            p.append(c)
    return finish_asset(name, p, CC, [((span + 2, width, 0.3), (0, 0, deck - 0.1))] + [((span + 2, 0.4, 1.0), (0, sy * (width / 2 - 0.2), deck + 0.5)) for sy in (-1, 1)], lods=False)


def build_hoarding(name="SM_Hoarding_Wood_01", seed=501, length=6.0):
    """Wooden defensive gallery that cantilevers out over a wall top: joists, plank floor with drop holes,
    plank walls with arrow slots, shingle lean-to roof. Place on top of SM_CastleWall_01 (origin = wall face at walk height)."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for i in range(int(length / 0.75) + 1):
        x = -length / 2 + i * length / int(length / 0.75)
        p.append(plank(f"{name}_joist", (0.16, 1.9, 0.2), (x, -0.6, -0.1), mat_key="OldWood", seed=i, wear=0.008))
        p.append(plank(f"{name}_strut", (0.12, 0.12, 1.4), (x, -1.2, -0.75), rot=(0.75, 0, 0), mat_key="OldWood", seed=i + 50))
        p.append(plank(f"{name}_upright", (0.12, 0.12, 2.1), (x, -1.45, 1.05), mat_key="OldWood", seed=i + 90))
    for j in range(7):
        y = -1.5 + j * 0.22
        hole = j in (1, 2)
        x = -length / 2
        while x < length / 2:
            w = min(rnd.uniform(0.9, 1.4), length / 2 - x)
            if not (hole and rnd.random() < 0.3):
                p.append(plank(f"{name}_floor", (w - 0.01, 0.2, 0.04), (x + w / 2, y, 0.02), seed=rnd.randint(0, 9999)))
            x += w
    for i in range(int(length / 0.2)):
        x = -length / 2 + 0.1 + i * 0.2
        if i % 6 == 3:
            continue  # arrow slot gap
        p.append(plank(f"{name}_wall", (0.19, 0.03, 1.9 + rnd.uniform(-0.05, 0.05)), (x, -1.52, 0.95), seed=rnd.randint(0, 9999)))
    for r in range(8):
        y = -1.7 + r * 0.26
        z = 2.2 + r * 0.12
        x = -length / 2 - 0.1 + (r % 2) * 0.1
        while x < length / 2 + 0.1:
            w = rnd.uniform(0.2, 0.32)
            p.append(box(f"{name}_sh", (w - 0.01, 0.35, 0.02), (x + w / 2, y, z), rot=(-0.5, 0, rnd.uniform(-0.03, 0.03)), mat=M("Shingles"), bevel=0.003, jitter=0.003, seed=rnd.randint(0, 99999)))
            x += w
    return finish_asset(name, p, CC, [((length, 1.6, 0.1), (0, -0.75, 0.0)), ((length, 0.1, 2.0), (0, -1.52, 1.0))], lods=False)


def build_watchtower_wood(name="SM_Watchtower_Wood_01", seed=511):
    """Timber watchtower: 4 splayed log legs with X bracing, ladder, planked lookout with rail and a thatched hip roof."""
    remove_asset(name); rnd = random.Random(seed); p = []
    H = 6.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube_along(f"{name}_leg", [V((sx * 1.6, sy * 1.6, -0.3)), V((sx * 1.1, sy * 1.1, H + 1.4))], [0.13, 0.1], M("Bark"), sides=8, twist_noise=0.08, seed=rnd.randint(0, 99)))
    for level in (1.5, 3.8):
        t = level / (H + 1.7)
        s = 1.6 - 0.5 * t
        for side in range(4):
            m = Matrix.Rotation(side * math.pi / 2, 4, "Z")
            for a, b in ((V((-s, -s, level - 1.2)), V((s, -s, level + 1.0))), (V((s, -s, level - 1.2)), V((-s, -s, level + 1.0)))):
                t_ = tube_along(f"{name}_x", [a, b], [0.06, 0.06], M("OldWood"), sides=6)
                t_.matrix_world = m
                p.append(t_)
    for i in range(int((H + 0.2) / 0.3)):
        z = 0.3 + i * 0.3
        p.append(tube_along(f"{name}_rung", [V((-0.25, -1.75 + z * 0.08, z)), V((0.25, -1.75 + z * 0.08, z))], [0.025, 0.025], M("OldWood"), sides=6))
    for sx in (-1, 1):
        p.append(tube_along(f"{name}_ladder", [V((sx * 0.25, -1.75, 0)), V((sx * 0.25, -1.75 + H * 0.08, H + 0.9))], [0.04, 0.04], M("OldWood"), sides=6))
    for i in range(14):
        p.append(plank(f"{name}_deck", (2.8, 0.2, 0.05), (0, -1.35 + i * 0.2, H), seed=rnd.randint(0, 999)))
    for side in range(4):
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z")
        for z in (H + 0.5, H + 1.0):
            r = plank(f"{name}_rail", (2.9, 0.08, 0.08), (0, 0, 0), mat_key="OldWood", seed=rnd.randint(0, 999))
            r.matrix_world = m @ Matrix.Translation(V((0, -1.42, z)))
            p.append(r)
        for i in range(10):
            b = plank(f"{name}_board", (0.22, 0.03, 0.55), (0, 0, 0), seed=rnd.randint(0, 999))
            b.matrix_world = m @ Matrix.Translation(V((-1.3 + i * 0.29, -1.45, H + 0.3)))
            p.append(b)
    roof = lathe(f"{name}_thatch", [(H + 2.4, 2.1, 2.1, 0), (H + 3.6, 0.2, 0.2, 0)], M("Straw"), 4, noise_amp=0.05, seed=3, thickness=0.25)
    roof.rotation_euler = (0, 0, math.pi / 4)
    p.append(roof)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube_along(f"{name}_roofpost", [V((sx * 1.3, sy * 1.3, H)), V((sx * 1.3, sy * 1.3, H + 2.4))], [0.06, 0.06], M("OldWood"), sides=6))
    return finish_asset(name, p, CC, [((3.2, 3.2, H), (0, 0, H / 2)), ((3.0, 3.0, 1.2), (0, 0, H + 0.6))], lods=False)


def build_castle_door(name="SM_CastleDoor_01", seed=521):
    """Arched oak door set in a dressed stone surround (drop-in for walls). Origin at the threshold centre."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, H = 1.4, 2.4
    for sx in (-1, 1):
        z = 0
        while z < H - 0.3:
            p.append(box(f"{name}_jamb", (0.35 if int(z / 0.4) % 2 else 0.5, 0.6, 0.39), (sx * (W / 2 + 0.2), 0, z + 0.2), mat=M("CastleStone"), bevel=0.02, jitter=0.006, seed=rnd.randint(0, 999)))
            z += 0.4
    _arch_ring(p, name, W + 0.1, H - 0.55, 0.6, rnd, pointed=True, thick=0.35)
    for i in range(6):
        x = -W / 2 + W / 12 + i * W / 6
        top = H - 0.2 - 0.9 * (abs(x) / (W / 2)) ** 2
        p.append(plank(f"{name}_plank", (W / 6 - 0.008, 0.08, top), (x, 0.05, top / 2), mat_key="DarkWood", seed=rnd.randint(0, 999), wear=0.008))
    for z in (0.45, 1.6):
        p.append(box(f"{name}_strap", (W - 0.1, 0.015, 0.08), (0, -0.0, z), mat=M("RustedIron"), bevel=0.003, segs=1))
        for k in range(7):
            p.append(cylinder(f"{name}_stud", 0.015, 0.015, (-W / 2 + 0.12 + k * (W - 0.24) / 6, -0.01, z), (math.pi / 2, 0, 0), M("Iron"), verts=6))
    ring = [V((0.4 + 0.07 * math.cos(a), -0.03, 1.1 + 0.07 * math.sin(a))) for a in [2 * math.pi * i / 16 for i in range(17)]]
    p.append(tube_along(f"{name}_ring", ring, [0.01] * 17, M("Iron"), sides=6, cap=False))
    p.append(box(f"{name}_threshold", (W + 0.8, 0.7, 0.12), (0, 0, 0.06), mat=M("CastleStone"), bevel=0.02, jitter=0.01, seed=7))
    return finish_asset(name, p, CC, [((W + 1.2, 0.6, H + 0.3), (0, 0, (H + 0.3) / 2))])


def build_castle_window(name="SM_CastleWindow_Gothic_01", seed=531):
    """Twin-light gothic window with a central mullion, tracery quatrefoil, iron grille and a projecting sill."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, H = 1.2, 2.0
    for sx in (-1, 1):
        p.append(box(f"{name}_jamb", (0.25, 0.5, H), (sx * (W / 2 + 0.125), 0, H / 2), mat=M("CastleStone"), bevel=0.02, jitter=0.005, seed=sx))
    p.append(box(f"{name}_mullion", (0.1, 0.4, H - 0.4), (0, 0, (H - 0.4) / 2), mat=M("CastleStone"), bevel=0.015, jitter=0.004, seed=3))
    _arch_ring(p, name, W + 0.1, H - 0.5, 0.5, rnd, pointed=True, thick=0.25)
    for sx in (-1, 1):
        _arch_ring(p, name + f"_l{sx}", W / 2 - 0.05, H - 0.65, 0.3, rnd, pointed=True, thick=0.1)
        for b in p[-15:]:
            b.location.x += sx * (W / 4 + 0.025)
    quat = [V((0.12 * math.cos(a) * (1 + 0.3 * math.cos(4 * a)), 0, H - 0.05 + 0.12 * math.sin(a) * (1 + 0.3 * math.cos(4 * a)))) for a in [2 * math.pi * i / 32 for i in range(33)]]
    p.append(tube_along(f"{name}_quatrefoil", quat, [0.03] * 33, M("CastleStone"), sides=6, cap=False))
    p.append(box(f"{name}_dark", (W, 0.05, H), (0, 0.15, H / 2), mat=M("DarkWood")))
    for i in range(5):
        p.append(box(f"{name}_grille", (0.02, 0.02, H - 0.5), (-W / 2 + 0.12 + i * (W - 0.24) / 4, -0.12, (H - 0.5) / 2 + 0.1), mat=M("RustedIron"), bevel=0, jitter=0.001, seed=i))
    p.append(box(f"{name}_sill", (W + 0.7, 0.62, 0.12), (0, -0.06, -0.06), rot=(0.1, 0, 0), mat=M("CastleStone"), bevel=0.02, jitter=0.006, seed=9))
    return finish_asset(name, p, CC, [((W + 0.6, 0.5, H + 0.3), (0, 0, H / 2))])


def build_debris_pile(name="SM_Debris_Stone_01", seed=541):
    remove_asset(name); rnd = random.Random(seed); p = []
    debris(p, name, (0, 0, 0), 1.3, 34, rnd, size=(0.12, 0.5))
    for i in range(6):
        g = rock(f"{name}_gravel", (0.5, 0.4, 0.08), seed=i, mat=M("Rock"), subdiv=2)
        g.location = (rnd.uniform(-1, 1), rnd.uniform(-0.8, 0.8), 0)
        p.append(g)
    return finish_asset(name, p, CC, [((2.4, 2.0, 0.6), (0, 0, 0.3))], lods=False)


def build_wall_ruin(name="SM_CastleWall_Ruin_01", seed=551, length=4.0, height=3.5, thickness=1.6):
    remove_asset(name); rnd = random.Random(seed); p = []
    top = _jagged(length, height * 0.55, 1.4, seed)
    ashlar_panel(p, name, length, height, thickness, rnd, M("CastleStone"), top_fn=top)
    debris(p, name, (0.5, -1.4, 0), 1.2, 16, rnd)
    for i in range(14):
        x = rnd.uniform(-length / 2, length / 2)
        m = rock(f"{name}_moss", (0.35, 0.18, 0.1), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (x, rnd.choice((-1, 1)) * thickness / 2, rnd.uniform(0.2, top(x)))
        p.append(m)
    return finish_asset(name, p, CC, [((length, thickness, height * 0.5), (0, 0, height * 0.25))], lods=False)

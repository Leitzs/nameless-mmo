"""Modular roads (4 m pieces, origin at the centre of the start edge... centred at 0,0, running along +Y).
exec() after kitlib, castle, castle2 (debris), nature2 (_blade_clump), items, armor, props3."""

V = Vector
RC = "ENV_Roads"
L = 4.0


def road_materials():
    mat_stone("M_Dirt_01", (0.11, 0.08, 0.055), (0.05, 0.035, 0.025), 2.0, rough=0.95)
    mat_stone("M_Mud_01", (0.06, 0.045, 0.03), (0.025, 0.018, 0.012), 2.5, rough=0.35)
    mat_stone("M_Cobblestone_01", (0.2, 0.19, 0.17), (0.07, 0.065, 0.06), 2.0, rough=0.8, moss=0.15)


def MM(n):
    return bpy.data.materials[n]


def _strip(name, width, length, mat, ruts=True, seed=0, res=0.1, center_fn=None, dip=0.0):
    """Ground strip with soft edges that feather into the terrain, tyre ruts and a crowned middle."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    nx = int(width / res) + 1
    ny = int(length / res) + 1
    grid = []
    for j in range(ny):
        row = []
        for i in range(nx):
            u = -width / 2 + width * i / (nx - 1)
            v = length * j / (ny - 1)
            cx, ang = (0.0, 0.0) if center_fn is None else center_fn(v)
            x = cx + u * math.cos(ang)
            y = v + u * math.sin(ang) if center_fn else v
            edge = abs(u) / (width / 2)
            z = 0.03 * (1 - edge ** 2) - 0.02 * max(0, edge - 0.8) / 0.2 - dip
            if ruts:
                for rx in (-0.75, 0.75):
                    z -= 0.05 * math.exp(-((u - rx) / 0.12) ** 2)
            z += noise.noise(V((x * 1.7 + seed, y * 1.7, 0))) * 0.02 + noise.noise(V((x * 6, y * 6, seed))) * 0.006
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(ny - 1):
        for i in range(nx - 1):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, mat)


def _pebbles(parts, name, count, width, length, rnd, zfn=lambda x, y: 0.02, size=(0.02, 0.06), mat_key="Rock"):
    for i in range(count):
        s = rnd.uniform(*size)
        x, y = rnd.uniform(-width / 2, width / 2), rnd.uniform(0, length)
        r = rock(f"{name}_peb", (s, s * 0.8, s * 0.5), seed=rnd.randint(0, 99999), mat=M(mat_key), subdiv=1)
        r.location = (x, y, zfn(x, y))
        parts.append(r)


def _cobbles(parts, name, width, length, rnd, gap=0.018, skip=None, center_fn=None, z=0.0, mat=None):
    """Individual domed setts in running bond, each slightly rotated, sunk or raised."""
    mat = mat or MM("M_Cobblestone_01")
    y = 0.0
    row = 0
    while y < length - 0.05:
        h = rnd.uniform(0.14, 0.18)
        x = -width / 2 + (row % 2) * 0.08
        while x < width / 2 - 0.05:
            w = min(rnd.uniform(0.18, 0.26), width / 2 - x)
            cx, cy = x + w / 2, y + h / 2
            if not (skip and skip(cx, cy)):
                c = rock(f"{name}_sett", ((w - gap) / 2, (h - gap) / 2, 0.06), seed=rnd.randint(0, 99999), mat=mat, subdiv=2, roughness=0.15, flatten=0.9)
                if center_fn:
                    ox, ang = center_fn(cy)
                    px, py = ox + cx * math.cos(ang), cy + cx * math.sin(ang)
                    c.rotation_euler = (0, 0, ang + rnd.uniform(-0.05, 0.05))
                else:
                    px, py = cx, cy
                    c.rotation_euler = (0, 0, rnd.uniform(-0.05, 0.05))
                c.location = (px, py, z + rnd.uniform(-0.012, 0.008))
                parts.append(c)
            x += w
        y += h
        row += 1


def build_road_dirt(name="SM_Road_Dirt_01", seed=1501):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(_strip(f"{name}_ground", 3.6, L, MM("M_Dirt_01"), ruts=True, seed=seed))
    # Puddles in the ruts, verge grass and scattered gravel.
    for i in range(3):
        pud = cylinder(f"{name}_puddle{i}", rnd.uniform(0.15, 0.35), 0.01, (rnd.choice((-0.75, 0.75)), rnd.uniform(0.3, L - 0.3), -0.035), mat=MM("M_Mud_01"), verts=16)
        pud.scale = (0.6, 1.6, 1)
        p.append(pud)
    _pebbles(p, name, 60, 3.2, L, rnd)
    for sx in (-1, 1):
        for i in range(5):
            g = _blade_clump(f"{name}_verge", 50, 0.22, 0.2, MM("M_Grass_01"), rnd, width=0.007)
            g.location = (sx * rnd.uniform(1.6, 1.9), rnd.uniform(0, L), 0)
            p.append(g)
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=60)


def build_road_cobble(name="SM_Road_Cobblestone_01", seed=1511, width=3.6):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(_strip(f"{name}_bed", width + 0.4, L, M("Rock"), ruts=False, seed=seed, dip=0.03))
    _cobbles(p, name, width, L, rnd)
    for sx in (-1, 1):
        y = 0
        while y < L:
            l = min(rnd.uniform(0.4, 0.7), L - y)
            k = box(f"{name}_kerb", (0.18, l - 0.01, 0.16), (sx * (width / 2 + 0.09), y + l / 2, 0.0), mat=M("CastleStone"), bevel=0.02, segs=2, jitter=0.008, seed=rnd.randint(0, 9999))
            p.append(k)
            y += l
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_road_village(name="SM_Road_Village_01", seed=1521):
    """Cobbled centre with a drainage gutter and dirt shoulders trodden into the verge."""
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(_strip(f"{name}_dirt", 5.0, L, MM("M_Dirt_01"), ruts=False, seed=seed))
    _cobbles(p, name, 2.8, L, rnd, z=0.02, skip=lambda x, y: rnd.random() < 0.04)
    gy = 0
    while gy < L:
        p.append(box(f"{name}_gutter", (0.2, 0.5, 0.05), (1.55, gy + 0.25, -0.01), mat=M("CastleStone"), bevel=0.02, segs=1, jitter=0.006, seed=rnd.randint(0, 999)))
        gy += 0.5
    _pebbles(p, name, 40, 4.8, L, rnd)
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_path_stone(name="SM_Path_Stone_01", seed=1531):
    """Stepping-flagstone path through grass."""
    remove_asset(name); rnd = random.Random(seed); p = []
    y = 0.2
    while y < L - 0.2:
        s = rnd.uniform(0.28, 0.42)
        f = rock(f"{name}_flag", (s, s * rnd.uniform(0.7, 1.0), 0.05), seed=rnd.randint(0, 9999), mat=M("CastleStone"), subdiv=3, roughness=0.1, flatten=0.95)
        f.location = (rnd.uniform(-0.25, 0.25), y, 0.0)
        p.append(f)
        g = _blade_clump(f"{name}_tuft", 30, 0.12, 0.25, MM("M_Grass_01"), rnd, width=0.006)
        g.location = (rnd.uniform(-0.6, 0.6), y + 0.3, 0)
        p.append(g)
        y += s * 2 + rnd.uniform(0.08, 0.16)
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_trail_forest(name="SM_Trail_Forest_01", seed=1541):
    """Narrow winding dirt trail with exposed roots, fallen leaves and twigs."""
    remove_asset(name); rnd = random.Random(seed); p = []
    wave = lambda v: (0.35 * math.sin(v * 0.9 + seed), 0.3 * math.cos(v * 0.9 + seed))
    p.append(_strip(f"{name}_ground", 1.4, L, MM("M_Dirt_01"), ruts=False, seed=seed, center_fn=wave))
    for i in range(4):
        y = rnd.uniform(0.3, L - 0.3)
        cx, _ = wave(y)
        p.append(tube_along(f"{name}_root{i}", [V((cx - 0.9, y - 0.1, -0.02)), V((cx, y + 0.05, 0.04)), V((cx + 0.9, y + 0.1, -0.02))], [0.04, 0.05, 0.03], M("Bark"), sides=6, twist_noise=0.2, seed=i))
    bm = bmesh.new()
    for i in range(180):
        y = rnd.uniform(0, L)
        cx, _ = wave(y)
        c = V((cx + rnd.gauss(0, 0.5), y, 0.035))
        a = rnd.uniform(0, 2 * math.pi)
        d = V((math.cos(a), math.sin(a), 0)) * 0.04
        s = V((-d.y, d.x, 0)) * 0.6
        vs = [bm.verts.new(c - d), bm.verts.new(c + s), bm.verts.new(c + d), bm.verts.new(c - s)]
        bm.faces.new(vs)
    p.append(_obj_from_bm(f"{name}_leaves", bm, MM("M_Grass_Dead_01")))
    for i in range(8):
        y = rnd.uniform(0, L); cx, _ = wave(y)
        a = rnd.uniform(0, math.pi)
        p.append(tube_along(f"{name}_twig{i}", [V((cx + rnd.uniform(-0.5, 0.5), y, 0.03)), V((cx + rnd.uniform(-0.5, 0.5) + 0.3 * math.cos(a), y + 0.3 * math.sin(a), 0.03))], [0.01, 0.004], M("DeadBark"), sides=4))
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=60)


def build_road_intersection(name="SM_Road_Cobblestone_Cross_01", seed=1551, width=3.6):
    """4-way cobbled crossing (4 x 4 m) that joins SM_Road_Cobblestone_01 on every side; a worn centre stone."""
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(box(f"{name}_bed", (L, L, 0.04), (0, L / 2, -0.04), mat=M("Rock"), bevel=0, jitter=0))
    _cobbles(p, name, L, L, rnd, skip=lambda x, y: math.hypot(x, y - L / 2) < 0.45)
    p.append(cylinder(f"{name}_centre", 0.42, 0.1, (0, L / 2, -0.01), mat=M("CastleStone"), verts=20, bevel=0.02, jitter=0.01, seed=3))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(box(f"{name}_ray{k}", (0.04, 0.3, 0.02), (math.cos(a) * 0.26, L / 2 + math.sin(a) * 0.26, 0.045), rot=(0, 0, a + math.pi / 2), mat=M("Rock"), bevel=0, jitter=0))
    # Corner kerbs.
    for sx in (-1, 1):
        for sy in (0, 1):
            y0 = 0 if sy == 0 else L
            for k in range(3):
                p.append(box(f"{name}_kerb", (0.18, 0.18, 0.16), (sx * (width / 2 + 0.09), y0 + (0.09 + k * 0.18) * (1 if sy == 0 else -1), 0.0), mat=M("CastleStone"), bevel=0.02, segs=2, jitter=0.008, seed=rnd.randint(0, 9999)))
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_road_curve(name="SM_Road_Cobblestone_Curve90_01", seed=1561, width=3.6, R=6.0):
    """90-degree cobbled bend (centreline radius R), starting at (0,0) heading +Y and ending heading +X."""
    remove_asset(name); rnd = random.Random(seed); p = []
    arc_len = R * math.pi / 2

    def cf(v):
        a = v / R
        cx = R - R * math.cos(a)
        return (cx - (v - R * math.sin(a)) * 0, -a)

    def centre(v):
        a = v / R
        return V((R - R * math.cos(a), R * math.sin(a), 0)), a

    y = 0.0
    row = 0
    while y < arc_len - 0.05:
        h = rnd.uniform(0.14, 0.18)
        c, a = centre(y + h / 2)
        t = V((math.cos(a), -math.sin(a), 0)) * -1  # outward normal of the bend
        nrm = V((-math.cos(a), math.sin(a), 0))
        x = -width / 2 + (row % 2) * 0.08
        while x < width / 2 - 0.05:
            w = min(rnd.uniform(0.18, 0.26), width / 2 - x)
            pos = c + nrm * (-(x + w / 2))
            s = rock(f"{name}_sett", ((w - 0.018) / 2 * (1 + (x + w / 2) / R * 0.5), (h - 0.018) / 2, 0.06), seed=rnd.randint(0, 99999), mat=MM("M_Cobblestone_01"), subdiv=2, roughness=0.15, flatten=0.9)
            s.location = (pos.x, pos.y, rnd.uniform(-0.012, 0.008))
            s.rotation_euler = (0, 0, -a + rnd.uniform(-0.05, 0.05))
            p.append(s)
            x += w
        y += h
        row += 1
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_road_broken(name="SM_Road_Cobblestone_Broken_01", seed=1571, width=3.6):
    """Abandoned road: missing setts, heaved stones, mud pits and grass growing through."""
    remove_asset(name); rnd = random.Random(seed); p = []
    holes = [(rnd.uniform(-1.2, 1.2), rnd.uniform(0.5, L - 0.5), rnd.uniform(0.4, 0.8)) for _ in range(4)]
    skip = lambda x, y: any(math.hypot(x - hx, y - hy) < hr for hx, hy, hr in holes) or rnd.random() < 0.06
    p.append(_strip(f"{name}_mud", width + 0.4, L, MM("M_Mud_01"), ruts=False, seed=seed, dip=0.05))
    _cobbles(p, name, width, L, rnd, skip=skip)
    for hx, hy, hr in holes:
        debris(p, name, (hx, hy, -0.05), hr * 0.6, 5, rnd, size=(0.06, 0.14), mat_key="Rock")
        g = _blade_clump(f"{name}_weeds", 70, 0.3, hr * 0.5, MM("M_Grass_01"), rnd, width=0.008)
        g.location = (hx, hy, -0.03)
        p.append(g)
    for c in p:
        if c.name.startswith(f"{name}_sett") and rnd.random() < 0.08:
            c.location.z += rnd.uniform(0.02, 0.05)
            c.rotation_euler.x += rnd.uniform(-0.25, 0.25)
    return finish_asset(name, p, RC, [], lods=False, origin=None, smooth=50)


def build_bridge_wood(name="SM_Bridge_Wood_01", seed=1581, span=8.0, width=2.4):
    """Plank footbridge: log stringers on trestle legs, uneven deck planks with gaps, rope-and-post handrails."""
    remove_asset(name); rnd = random.Random(seed); p = []
    deck = 1.2
    for sy in (-1, 1):
        p.append(tube_along(f"{name}_stringer{sy}", [V((-span / 2 - 0.5, sy * (width / 2 - 0.2), deck - 0.15)), V((0, sy * (width / 2 - 0.2), deck - 0.2)), V((span / 2 + 0.5, sy * (width / 2 - 0.2), deck - 0.15))], [0.14, 0.15, 0.14], M("Bark"), sides=10, twist_noise=0.08, seed=sy))
    for x in (-span / 4, span / 4):
        for sy in (-1, 1):
            p.append(tube_along(f"{name}_leg", [V((x, sy * (width / 2 - 0.1), -1.5)), V((x, sy * (width / 2 - 0.2), deck - 0.25))], [0.12, 0.1], M("Bark"), sides=8, twist_noise=0.1, seed=int(x * 10) + sy))
        p.append(tube_along(f"{name}_xbrace", [V((x, -width / 2, -1.0)), V((x, width / 2, deck - 0.4))], [0.06, 0.06], M("OldWood"), sides=6))
        p.append(plank(f"{name}_cap", (0.2, width + 0.2, 0.16), (x, 0, deck - 0.32), mat_key="OldWood", seed=int(x)))
    x = -span / 2 - 0.5
    while x < span / 2 + 0.5:
        w = rnd.uniform(0.2, 0.28)
        if rnd.random() > 0.04:
            pl = plank(f"{name}_plank", (w - 0.02, width + rnd.uniform(-0.1, 0.1), 0.05), (x + w / 2, rnd.uniform(-0.04, 0.04), deck - 0.02 - 0.03 * math.cos(x / span * math.pi) + rnd.uniform(-0.01, 0.01)), rot=(rnd.uniform(-0.02, 0.02), 0, rnd.uniform(-0.03, 0.03)), seed=rnd.randint(0, 9999), wear=0.01)
            p.append(pl)
        x += w
    for sy in (-1, 1):
        posts = []
        for i in range(6):
            px = -span / 2 + i * span / 5
            p.append(tube_along(f"{name}_post", [V((px, sy * (width / 2 + 0.05), deck - 0.3)), V((px, sy * (width / 2 + 0.05), deck + 1.0))], [0.06, 0.05], M("OldWood"), sides=7))
            posts.append(V((px, sy * (width / 2 + 0.05), deck + 0.95)))
        for a, b in zip(posts, posts[1:]):
            mid = (a + b) / 2 - V((0, 0, 0.12))
            p.append(tube_along(f"{name}_rope", [a, mid, b], [0.018, 0.018, 0.018], M("Straw"), sides=6))
    return finish_asset(name, p, RC, [((span + 1, width, 0.12), (0, 0, deck - 0.02))] + [((span, 0.1, 1.0), (0, sy * (width / 2 + 0.05), deck + 0.5)) for sy in (-1, 1)], lods=False, origin=None, smooth=50)


def build_roads_batch():
    road_materials()
    out = []
    x = -40.0
    for fn in (build_road_dirt, build_road_cobble, build_road_village, build_path_stone, build_trail_forest, build_road_intersection, build_road_curve, build_road_broken, build_bridge_wood):
        o = fn()
        o.location = (x, -45, 0)
        out.append((o.name, tris(o)))
        x += 10
    return out

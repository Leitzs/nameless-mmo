"""Dungeon kit (4 m modular grid): walls, floors, vaults, columns, doors, gates, cells, chains, shackles, braziers,
stairs, collapsed/broken pieces, remains, cage, torture props, chest, altar, ancient magical door.
exec() after kitlib, castle, buildings, items, armor, props2, props3, castle2."""

V = Vector
DC = "ENV_Dungeon"
G = 4.0  # grid size


def dungeon_materials():
    mat_stone("M_DungeonStone_01", (0.13, 0.125, 0.115), (0.035, 0.033, 0.03), 1.4, rough=0.75, moss=0.15)
    mat_stone("M_DungeonFloor_01", (0.11, 0.1, 0.09), (0.03, 0.028, 0.025), 1.6, rough=0.7)
    mat_emissive("M_Rune_Glow_01", (0.2, 0.55, 1.0), 4.0, transmission=0.0)
    mat_emissive("M_Blood_01", (0.12, 0.005, 0.005), 0.0, transmission=0.0)
    b = next(n for n in bpy.data.materials["M_Blood_01"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.15


def DS():
    return bpy.data.materials["M_DungeonStone_01"]


def chain(parts, name, a, b, link=0.05, thick=0.008, sag=0.0):
    """Real chain: alternating perpendicular oval links from a to b (optional sag)."""
    a, b = V(a), V(b)
    L = (b - a).length
    n = max(2, int(L / (link * 0.8)))
    for i in range(n):
        t = (i + 0.5) / n
        pos = a.lerp(b, t) - V((0, 0, sag * 4 * t * (1 - t)))
        nxt = a.lerp(b, min(1, t + 1 / n)) - V((0, 0, sag * 4 * min(1, t + 1 / n) * (1 - min(1, t + 1 / n))))
        d = (nxt - pos).normalized() if (nxt - pos).length > 1e-5 else (b - a).normalized()
        pts = [V((math.cos(u) * link * 0.3, 0, math.sin(u) * link * 0.55)) for u in [2 * math.pi * k / 12 for k in range(13)]]
        o = tube_along(f"{name}_link", pts, [thick] * 13, M("RustedIron"), sides=5, cap=False)
        rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ Matrix.Rotation((i % 2) * math.pi / 2, 4, "Z")
        o.matrix_world = Matrix.Translation(pos) @ rot
        parts.append(o)


def build_dungeon_wall(name="SM_Dungeon_Wall_01", seed=601, niche=False):
    remove_asset(name); rnd = random.Random(seed); p = []
    hole = (lambda x, z: abs(x) < 0.45 and 1.0 < z < 2.2) if niche else None
    ashlar_panel(p, name, G, G, 0.5, rnd, DS(), hole=hole, face_d=0.5, both=False, course=(0.35, 0.4, 0.45))
    for b in p:
        b.location.y -= 0.25
    if niche:
        p.append(box(f"{name}_nicheback", (0.9, 0.1, 1.2), (0, 0.05, 1.6), mat=M("DarkWood")))
        p.append(box(f"{name}_nichesill", (1.0, 0.4, 0.1), (0, -0.2, 0.95), mat=DS(), bevel=0.02, jitter=0.01, seed=3))
        _arch_ring(p, name, 0.9, 2.0, 0.5, rnd, pointed=False, thick=0.2, y=-0.25, mat_key="Rock")
    # Moss and seepage clumps in the lower joints.
    for i in range(8):
        m = rock(f"{name}_moss{i}", (0.25, 0.06, 0.08), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-G / 2 + 0.3, G / 2 - 0.3), -0.5, rnd.uniform(0.1, 1.2))
        p.append(m)
    return finish_asset(name, p, DC, [((G, 0.5, G), (0, 0, G / 2))], lods=False)


def build_dungeon_floor(name="SM_Dungeon_Floor_01", seed=611, broken=False):
    """4x4 m irregular flagstones with gravel in the joints; broken variant has a collapsed hole."""
    remove_asset(name); rnd = random.Random(seed); p = []
    y = -G / 2
    while y < G / 2 - 0.02:
        h = min(rnd.uniform(0.45, 0.8), G / 2 - y)
        x = -G / 2 + rnd.uniform(0, 0.3) * (1 if rnd.random() < 0.5 else 0)
        x = -G / 2
        while x < G / 2 - 0.02:
            w = min(rnd.uniform(0.5, 1.0), G / 2 - x)
            cx, cy = x + w / 2, y + h / 2
            if broken and math.hypot(cx - 0.3, cy + 0.2) < 1.0:
                if rnd.random() < 0.5:
                    s = box(f"{name}_fallen", (w - 0.02, h - 0.02, 0.18), (cx, cy, -0.5 - rnd.uniform(0, 0.8)), rot=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 1)), mat=bpy.data.materials["M_DungeonFloor_01"], bevel=0.02, jitter=0.02, seed=rnd.randint(0, 9999))
                    p.append(s)
                x += w
                continue
            sink = rnd.uniform(-0.015, 0.0) if rnd.random() < 0.3 else 0.0
            s = box(f"{name}_flag", (w - 0.025, h - 0.025, 0.18), (cx, cy, -0.09 + sink), rot=(rnd.uniform(-0.008, 0.008), rnd.uniform(-0.008, 0.008), rnd.uniform(-0.01, 0.01)), mat=bpy.data.materials["M_DungeonFloor_01"], bevel=0.02, segs=2, jitter=0.01, seed=rnd.randint(0, 99999))
            dent(s, 0.015, seed=rnd.randint(0, 999), count=3, radius=0.2)
            p.append(s)
            x += w
        y += h
    grout = box(f"{name}_grout", (G, G, 0.05), (0, 0, -0.035), mat=M("Rock"), bevel=0, jitter=0)
    if broken:
        bm = bmesh.new(); bm.from_mesh(grout.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if math.hypot(f.calc_center_median().x - 0.3, f.calc_center_median().y + 0.2) < 0.9], context="FACES")
        bm.to_mesh(grout.data); bm.free()
        debris(p, name, (0.3, -0.2, -1.4), 0.8, 14, rnd, size=(0.1, 0.35), mat_key="Rock")
    p.append(grout)
    return finish_asset(name, p, DC, [((G, G, 0.2), (0, 0, -0.1))] if not broken else [], lods=False)


def build_dungeon_vault(name="SM_Dungeon_Ceiling_Vault_01", seed=621):
    """4 m barrel-vault segment of voussoirs springing at 3 m, with a transverse rib at each end."""
    remove_asset(name); rnd = random.Random(seed); p = []
    spring = 3.0
    R = G / 2
    n = 14
    for j in range(int(G / 0.5)):
        y = -G / 2 + 0.25 + j * 0.5
        off = (j % 2) * 0.5
        for k in range(n):
            a = math.pi * (k + 0.5 + off * 0.5) / (n + 0.5)
            seg = math.pi * (R + 0.2) / (n + 0.5)
            p.append(box(f"{name}_vou", (0.4, 0.48, seg - 0.015), (math.cos(a) * (R + 0.2), y, spring + math.sin(a) * (R + 0.2)), rot=(0, -a, 0), mat=DS(), bevel=0.02, jitter=0.01, seed=rnd.randint(0, 99999)))
    for yy in (-G / 2 + 0.15, G / 2 - 0.15):
        ring = []
        _arch_ring(ring, name, G - 0.2, spring, 0.3, rnd, pointed=False, thick=0.35, y=yy, mat_key="CastleStone")
        for b in ring:
            b.location.z -= 0.2
        p.extend(ring)
    # Dripping stalactite-like mineral stains.
    for i in range(8):
        a = rnd.uniform(0.6, 2.5)
        s = cylinder(f"{name}_drip", 0.02, rnd.uniform(0.05, 0.15), (math.cos(a) * R * 0.98, rnd.uniform(-1.8, 1.8), spring + math.sin(a) * R * 0.98 - 0.08), mat=M("Bone"), verts=6, radius_top=0.003)
        s.rotation_euler = (math.pi, 0, 0)
        p.append(s)
    return finish_asset(name, p, DC, [], lods=False)


def build_dungeon_column(name="SM_Dungeon_Column_01", seed=631, H=3.2):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(box(f"{name}_plinth", (0.9, 0.9, 0.3), (0, 0, 0.15), mat=DS(), bevel=0.03, segs=2, jitter=0.015, seed=1))
    p.append(tube_along(f"{name}_torus", [V((0, 0, 0.3)), V((0, 0, 0.42))], [0.4, 0.36], DS(), sides=20))
    z = 0.42
    while z < H - 0.5:
        h = rnd.uniform(0.4, 0.55)
        drum = cylinder(f"{name}_drum", 0.32, h - 0.01, (0, 0, z + h / 2), mat=DS(), verts=20, bevel=0.015, jitter=0.01, seed=rnd.randint(0, 999))
        drum.rotation_euler = (0, 0, rnd.uniform(0, 1))
        dent(drum, 0.03, seed=int(z * 10), count=6, radius=0.15)
        p.append(drum)
        z += h
    p.append(tube_along(f"{name}_neck", [V((0, 0, z)), V((0, 0, z + 0.12))], [0.33, 0.36], DS(), sides=20))
    p.append(cylinder(f"{name}_capital", 0.36, 0.3, (0, 0, z + 0.27), mat=DS(), verts=4, radius_top=0.6, bevel=0.02))
    p[-1].rotation_euler = (0, 0, math.pi / 4)
    p.append(box(f"{name}_abacus", (0.95, 0.95, 0.15), (0, 0, z + 0.5), mat=DS(), bevel=0.03, segs=2, jitter=0.01, seed=2))
    chain(p, name, (0.3, 0, z + 0.4), (0.33, -0.2, z - 0.6), sag=0.05)
    return finish_asset(name, p, DC, [((0.8, 0.8, H), (0, 0, H / 2))], lods=False)


def build_dungeon_door(name="SM_Dungeon_Door_01", seed=641):
    """Iron-bound cell door with a barred viewing grate, massive hinges, bolt and padlock, in a stone frame."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, H = 1.2, 2.2
    for sx in (-1, 1):
        p.append(box(f"{name}_jamb", (0.35, 0.55, H + 0.4), (sx * (W / 2 + 0.175), 0, (H + 0.4) / 2), mat=DS(), bevel=0.03, segs=2, jitter=0.01, seed=sx))
    p.append(box(f"{name}_lintel", (W + 0.9, 0.6, 0.45), (0, 0, H + 0.4), mat=DS(), bevel=0.03, segs=2, jitter=0.01, seed=3))
    for i in range(5):
        p.append(plank(f"{name}_plank", (W / 5 - 0.006, 0.09, H), (-W / 2 + W / 10 + i * W / 5, 0, H / 2), mat_key="DarkWood", seed=rnd.randint(0, 999), wear=0.01))
    for z in (0.3, 1.1, 1.9):
        p.append(box(f"{name}_band", (W, 0.02, 0.1), (0, -0.055, z), mat=M("RustedIron"), bevel=0.004, segs=1))
        for k in range(7):
            p.append(cylinder(f"{name}_rivet", 0.016, 0.02, (-W / 2 + 0.08 + k * (W - 0.16) / 6, -0.07, z), (math.pi / 2, 0, 0), M("Iron"), verts=6))
        p.append(box(f"{name}_hinge", (0.5, 0.03, 0.12), (-W / 2 + 0.1, -0.06, z), mat=M("RustedIron"), bevel=0.006, segs=1))
    # Viewing grate: square cut with 3 iron bars.
    p.append(box(f"{name}_gratehole", (0.34, 0.1, 0.24), (0, -0.005, 1.55), mat=M("DarkWood")))
    for k in range(3):
        p.append(cylinder(f"{name}_gbar", 0.012, 0.28, (-0.1 + k * 0.1, -0.06, 1.55), mat=M("Iron"), verts=6))
    p.append(box(f"{name}_bolt", (0.35, 0.05, 0.05), (W / 2 - 0.05, -0.08, 1.0), mat=M("Iron"), bevel=0.01, segs=1))
    p.append(box(f"{name}_padlock", (0.08, 0.04, 0.1), (W / 2 + 0.1, -0.11, 0.95), mat=M("RustedIron"), bevel=0.012, segs=2))
    shackle = [V((W / 2 + 0.1 + 0.03 * math.cos(a), -0.11, 1.0 + 0.035 * math.sin(a))) for a in [math.pi * i / 10 for i in range(11)]]
    p.append(tube_along(f"{name}_shackle", shackle, [0.007] * 11, M("Iron"), sides=5))
    return finish_asset(name, p, DC, [((W + 1.0, 0.55, H + 0.6), (0, 0, (H + 0.6) / 2))])


def build_prison_gate(name="SM_PrisonGate_Iron_01", seed=651, W=1.3, H=2.4):
    remove_asset(name); rnd = random.Random(seed); p = []
    for i in range(8):
        x = -W / 2 + 0.08 + i * (W - 0.16) / 7
        p.append(tube_along(f"{name}_bar{i}", [V((x, 0, 0)), V((x + rnd.uniform(-0.01, 0.01), 0, H))], [0.02, 0.02], M("RustedIron"), sides=8))
    for z in (0.15, 1.0, H - 0.15):
        p.append(box(f"{name}_rail", (W, 0.05, 0.07), (0, 0, z), mat=M("RustedIron"), bevel=0.006, segs=1, jitter=0.002, seed=int(z * 10)))
    for z in (0.3, H - 0.3):
        p.append(cylinder(f"{name}_hinge", 0.035, 0.18, (-W / 2 - 0.02, 0, z), mat=M("Iron"), verts=10))
    p.append(box(f"{name}_lockbox", (0.16, 0.08, 0.22), (W / 2 - 0.12, -0.04, 1.0), mat=M("Iron"), bevel=0.01, segs=2))
    p.append(cylinder(f"{name}_keyhole", 0.012, 0.01, (W / 2 - 0.12, -0.085, 1.02), (math.pi / 2, 0, 0), M("DarkWood"), verts=8))
    return finish_asset(name, p, DC, [((W, 0.12, H), (0, 0, H / 2))])


def build_cell(name="SM_Dungeon_Cell_01", seed=661):
    """Cell front (bars wall with integrated gate) plus furnishing: straw pallet, bucket, wall chain with shackles, bones."""
    remove_asset(name); rnd = random.Random(seed); p = []
    H = 3.0
    for i in range(18):
        x = -G / 2 + 0.1 + i * (G - 0.2) / 17
        if -0.3 < x < 1.0:
            continue  # gate opening (use SM_PrisonGate_Iron_01)
        p.append(tube_along(f"{name}_bar", [V((x, 0, 0)), V((x, 0, H))], [0.022, 0.022], M("RustedIron"), sides=8))
    for z in (0.1, H - 0.1, 1.2):
        p.append(box(f"{name}_rail", (G, 0.06, 0.08), (0, 0, z), mat=M("RustedIron"), bevel=0.006, segs=1))
    straw = rock(f"{name}_straw", (0.8, 0.45, 0.08), seed=seed, mat=M("Straw"), subdiv=3, roughness=0.0, flatten=0.95)
    straw.location = (-1.2, 1.6, 0.04)
    p.append(straw)
    b = []
    _bucket(b, f"{name}_bucket", (1.4, 1.5, 0), rnd)
    p.extend(b)
    chain(p, name, (0.2, G - 0.3, 2.2), (0.0, G - 0.4, 0.4), sag=0.1)
    chain(p, name, (0.6, G - 0.3, 2.2), (0.8, G - 0.45, 0.35), sag=0.1)
    for x in (0.0, 0.8):
        cuff = [V((x + 0.05 * math.cos(a), G - 0.45, 0.3 + 0.04 * math.sin(a))) for a in [2 * math.pi * i / 14 for i in range(15)]]
        p.append(tube_along(f"{name}_cuff", cuff, [0.012] * 15, M("RustedIron"), sides=6, cap=False))
    return finish_asset(name, p, DC, [((G, 0.1, H), (0, 0, H / 2))], lods=False)


def build_wall_shackles(name="SM_Shackles_Wall_01", seed=671):
    remove_asset(name); p = []
    for sx in (-1, 1):
        p.append(box(f"{name}_plate", (0.12, 0.03, 0.12), (sx * 0.5, 0, 1.9), mat=M("RustedIron"), bevel=0.01, segs=2))
        p.append(cylinder(f"{name}_ringbolt", 0.02, 0.06, (sx * 0.5, -0.04, 1.9), (math.pi / 2, 0, 0), M("Iron"), verts=8))
        chain(p, name, (sx * 0.5, -0.06, 1.88), (sx * 0.62, -0.1, 1.35), sag=0.05)
        cuff = [V((sx * 0.62 + 0.05 * math.cos(a), -0.1, 1.3 + 0.045 * math.sin(a))) for a in [2 * math.pi * i / 14 for i in range(15)]]
        p.append(tube_along(f"{name}_cuff{sx}", cuff, [0.014] * 15, M("RustedIron"), sides=6, cap=False))
    return finish_asset(name, p, DC, [], origin=None)


def build_chains_hanging(name="SM_Chains_Hanging_01", seed=681):
    remove_asset(name); rnd = random.Random(seed); p = []
    for i in range(3):
        x = -0.4 + i * 0.4
        L = rnd.uniform(1.2, 2.2)
        chain(p, name, (x, 0, 0), (x + rnd.uniform(-0.05, 0.05), 0, -L))
        if i == 1:
            hook = [V((x + 0.06 * math.sin(a), 0, -L - 0.06 + 0.06 * math.cos(a))) for a in [math.pi * k / 10 for k in range(11)]]
            p.append(tube_along(f"{name}_hook", hook, [0.012] * 11, M("RustedIron"), sides=6))
    p.append(box(f"{name}_beam", (1.2, 0.15, 0.15), (0, 0, 0.08), mat=M("DarkWood"), bevel=0.01, jitter=0.005, seed=1))
    return finish_asset(name, p, DC, [], origin=None)


def build_brazier(name="SM_Brazier_Iron_01", seed=691):
    """Tripod iron brazier with a riveted bowl of coals (torch holder / light source)."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for k in range(3):
        a = 2 * math.pi * k / 3
        p.append(tube_along(f"{name}_leg{k}", [V((math.cos(a) * 0.4, math.sin(a) * 0.4, 0)), V((math.cos(a) * 0.25, math.sin(a) * 0.25, 0.5)), V((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.0))], [0.025, 0.02, 0.022], M("RustedIron"), sides=6))
        p.append(tube_along(f"{name}_foot{k}", [V((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.02)), V((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.02))], [0.025, 0.015], M("RustedIron"), sides=6))
    p.append(tube_along(f"{name}_ring", [V((0.27 * math.cos(a), 0.27 * math.sin(a), 0.5)) for a in [2 * math.pi * i / 24 for i in range(25)]], [0.012] * 25, M("RustedIron"), sides=5, cap=False))
    bowl = lathe(f"{name}_bowl", [(0.9, 0.12, 0.12, 0), (0.98, 0.3, 0.3, 0), (1.1, 0.38, 0.38, 0)], M("RustedIron"), 24, thickness=0.012)
    p.append(bowl)
    coal = bpy.data.materials.get("M_Coals_01") or mat_emissive("M_Coals_01", (1.0, 0.25, 0.04), 3.0, transmission=0.0)
    for i in range(35):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, 0.3)
        c = rock(f"{name}_coal", (0.04, 0.035, 0.03), seed=i, mat=coal if rnd.random() < 0.4 else M("DarkWood"), subdiv=1)
        c.location = (math.cos(a) * r, math.sin(a) * r, 1.02 + rnd.uniform(0, 0.05))
        p.append(c)
    obj = finish_asset(name, p, DC, [((0.8, 0.8, 1.1), (0, 0, 0.55))])
    socket(obj, "FX_Fire", (0, 0, 1.15))
    return obj


def build_spiral_stairs(name="SM_Dungeon_Stairs_Spiral_01", seed=701, turns=1.0, rise=0.2):
    """Newel spiral stair: wedge treads around a central column, enclosed by a curved wall on the outside."""
    remove_asset(name); rnd = random.Random(seed); p = []
    R = 1.5
    steps = int(turns * 16)
    for i in range(steps):
        a0 = 2 * math.pi * i / 16
        z = i * rise
        bm = bmesh.new()
        pts = [(0.25, a0), (R, a0), (R, a0 + 2 * math.pi / 16 + 0.02), (0.25, a0 + 2 * math.pi / 16 + 0.02)]
        bot = [bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, a in pts]
        top = [bm.verts.new((r * math.cos(a), r * math.sin(a), z + rise + 0.02)) for r, a in pts]
        bm.faces.new(bot[::-1]); bm.faces.new(top)
        for k in range(4):
            bm.faces.new((bot[k], bot[(k + 1) % 4], top[(k + 1) % 4], top[k]))
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.015, segments=1, affect="EDGES")
        t = _obj_from_bm(f"{name}_tread", bm, DS())
        dent(t, 0.02, seed=i, count=2, radius=0.3)
        p.append(t)
    H = steps * rise + 2.2
    p.append(cylinder(f"{name}_newel", 0.25, H, (0, 0, H / 2), mat=DS(), verts=16, bevel=0.01, jitter=0.01, seed=1))
    z = 0
    while z < H:
        h = rnd.choice((0.35, 0.4))
        n = 14
        ph = rnd.uniform(0, 1)
        for k in range(n):
            a0 = ph + 2 * math.pi * k / n
            if not (0.0 < a0 % (2 * math.pi) < 1.1 and z < 2.3):
                p.append(_arc_block(f"{name}_wall", R, R + 0.35, a0, a0 + 2 * math.pi / n - 0.01, z, z + h - 0.012, DS(), 0.01, rnd.randint(0, 99999)))
        z += h
    return finish_asset(name, p, DC, [], lods=False)


def build_wall_collapsed(name="SM_Dungeon_Wall_Collapsed_01", seed=711):
    remove_asset(name); rnd = random.Random(seed); p = []
    top = _jagged(G, 1.6, 1.3, seed)
    hole = lambda x, z: math.hypot(x - 0.3, (z - 1.2) * 0.8) < 0.9
    ashlar_panel(p, name, G, G, 0.6, rnd, DS(), top_fn=top, hole=hole, face_d=0.3)
    debris(p, name, (0.3, -1.0, 0), 1.3, 30, rnd, size=(0.12, 0.4), mat_key="Rock")
    for i in range(3):
        p.append(tube_along(f"{name}_root{i}", [V((rnd.uniform(-1.5, 1.5), -0.35, top(0) - 0.2)), V((rnd.uniform(-1.8, 1.8), -0.4, rnd.uniform(0.5, 1.5))), V((rnd.uniform(-1.5, 1.5), -0.8, 0))], [0.04, 0.03, 0.015], M("Bark"), sides=6, twist_noise=0.2, seed=i))
    return finish_asset(name, p, DC, [((G, 0.6, 1.5), (0, 0, 0.75))], lods=False)


def _bone(parts, name, a, b, r=0.018, mat=None):
    """Long bone: shaft with knobbly epiphyses at both ends."""
    a, b = V(a), V(b)
    parts.append(tube_along(f"{name}_shaft", [a, a.lerp(b, 0.5), b], [r, r * 0.8, r], mat or M("Bone"), sides=8))
    for e in (a, b):
        for k in (-1, 1):
            d = (b - a).normalized().cross(V((0, 0, 1)))
            if d.length < 1e-4:
                d = V((1, 0, 0))
            kn = rock(f"{name}_knob", (r * 1.1, r * 1.1, r * 1.1), seed=int(e.x * 100 + k), mat=mat or M("Bone"), subdiv=2, roughness=0.0, flatten=0.0)
            kn.location = e + d.normalized() * r * 0.6 * k
            parts.append(kn)


def build_skeleton_remains(name="SM_Skeleton_Remains_01", seed=721):
    """Slumped skeleton: skull, spine, ribcage, pelvis, scattered limb bones and a rusted shackle."""
    remove_asset(name); rnd = random.Random(seed); p = []
    sk = _skull(f"{name}_skull", 1.0, seed)
    sk.location = (0.05, 0.1, 0.12); sk.rotation_euler = (0.9, 0.2, 0.6)
    p.append(sk)
    spine = [V((0.0, 0.2 + i * 0.045, 0.06 + 0.04 * math.sin(i * 0.4))) for i in range(12)]
    for i, s in enumerate(spine):
        v = cylinder(f"{name}_vert{i}", 0.022, 0.03, s, (math.pi / 2, 0, 0), M("Bone"), verts=8, bevel=0.004)
        p.append(v)
        p.append(box(f"{name}_proc{i}", (0.07, 0.012, 0.012), s + V((0, 0, 0.02)), mat=M("Bone"), bevel=0.003, segs=1))
    for i in range(6):
        y = 0.25 + i * 0.045
        for sx in (-1, 1):
            arc = [V((sx * (0.02 + 0.13 * math.sin(t)), y + 0.02 * t, 0.07 + 0.09 * math.cos(t) - 0.05 * t)) for t in [k * 0.3 for k in range(9)]]
            p.append(tube_along(f"{name}_rib", arc, [0.007] * 9, M("Bone"), sides=5))
    pelvis = rock(f"{name}_pelvis", (0.14, 0.08, 0.07), seed=seed, mat=M("Bone"), subdiv=3, roughness=0.1, flatten=0.3)
    pelvis.location = (0.0, 0.8, 0.06)
    p.append(pelvis)
    for a, b in (((0.1, 0.85, 0.04), (0.35, 1.2, 0.03)), ((-0.1, 0.85, 0.04), (-0.25, 1.25, 0.03)), ((0.35, 1.2, 0.03), (0.4, 1.6, 0.025)),
                 ((0.18, 0.3, 0.05), (0.4, 0.45, 0.03)), ((0.4, 0.45, 0.03), (0.55, 0.3, 0.02)), ((-0.6, 0.6, 0.02), (-0.35, 0.8, 0.02))):
        _bone(p, name, a, b, 0.016 if b[2] > 0.025 else 0.012)
    cuff = [V((0.55 + 0.045 * math.cos(u), 0.3 + 0.045 * math.sin(u), 0.02)) for u in [2 * math.pi * i / 14 for i in range(15)]]
    p.append(tube_along(f"{name}_cuff", cuff, [0.011] * 15, M("RustedIron"), sides=6, cap=False))
    chain(p, name, (0.6, 0.3, 0.02), (1.1, 0.1, 0.02))
    return finish_asset(name, p, DC, [((0.9, 1.6, 0.2), (0.1, 0.8, 0.1))], lods=False)


def build_cage_hanging(name="SM_Cage_Wood_Hanging_01", seed=731):
    """Gibbet-style cage: iron hoops and straps with wooden slats, hanging from a chain; small door with lock."""
    remove_asset(name); rnd = random.Random(seed); p = []
    R, H = 0.55, 1.9
    for z in (0.0, 0.6, 1.3, H):
        rr = R if z < H else R * 0.3
        p.append(tube_along(f"{name}_hoop", [V((rr * math.cos(a), rr * math.sin(a), z)) for a in [2 * math.pi * i / 32 for i in range(33)]], [0.018] * 33, M("RustedIron"), sides=6, cap=False))
    for k in range(12):
        a = 2 * math.pi * k / 12
        pts = [V((R * math.cos(a), R * math.sin(a), 0)), V((R * math.cos(a), R * math.sin(a), 1.3)), V((R * 0.3 * math.cos(a), R * 0.3 * math.sin(a), H))]
        mat = M("OldWood") if k % 2 else M("RustedIron")
        p.append(tube_along(f"{name}_slat{k}", pts, [0.022 if k % 2 else 0.012] * 3, mat, sides=6))
    p.append(cylinder(f"{name}_floor", R, 0.05, (0, 0, 0.02), mat=M("Planks"), verts=24))
    chain(p, name, (0, 0, H), (0, 0, H + 1.5))
    b = []
    _skull_obj = _skull(f"{name}_skull", 0.9, seed)
    _skull_obj.location = (0.15, 0.1, 0.12); _skull_obj.rotation_euler = (1.2, 0, 0.4)
    p.append(_skull_obj)
    obj = finish_asset(name, p, DC, [((R * 2, R * 2, H), (0, 0, H / 2))], origin=None)
    socket(obj, "Hang_Point", (0, 0, H + 1.5))
    return obj


def build_rack_torture(name="SM_TortureRack_01", seed=741):
    """Rack: heavy timber frame with rollers at both ends, ratchet wheel and crank, ropes and cuffs."""
    remove_asset(name); rnd = random.Random(seed); p = []
    L, W, H = 2.2, 0.9, 0.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(plank(f"{name}_leg", (0.14, 0.14, H), (sx * (L / 2 - 0.1), sy * (W / 2 - 0.07), H / 2), mat_key="DarkWood", seed=rnd.randint(0, 99), wear=0.01))
        p.append(plank(f"{name}_side", (0.12, W, 0.12), (sx * (L / 2 - 0.1), 0, H * 0.35), mat_key="DarkWood", seed=sx + 10))
    for sy in (-1, 1):
        p.append(plank(f"{name}_rail", (L, 0.14, 0.18), (0, sy * (W / 2 - 0.07), H - 0.09), mat_key="DarkWood", seed=sy + 20, wear=0.012))
    for i in range(8):
        p.append(plank(f"{name}_bed", (0.24, W - 0.28, 0.04), (-L / 2 + 0.4 + i * 0.2, 0, H - 0.1), seed=i))
    for sx in (-1, 1):
        roller = tube_along(f"{name}_roller{sx}", [V((sx * (L / 2 - 0.1), -W / 2 - 0.05, H - 0.02)), V((sx * (L / 2 - 0.1), W / 2 + 0.05, H - 0.02))], [0.06, 0.06], M("OldWood"), sides=12)
        p.append(roller)
        for sy in (-0.2, 0.2):
            p.append(tube_along(f"{name}_rope", [V((sx * (L / 2 - 0.1), sy, H + 0.03)), V((sx * (L / 2 - 0.45), sy * 0.8, H - 0.05))], [0.01, 0.01], M("Straw"), sides=5))
            cuff = [V((sx * (L / 2 - 0.5), sy * 0.8 + 0.04 * math.cos(a), H - 0.05 + 0.04 * math.sin(a))) for a in [2 * math.pi * k / 12 for k in range(13)]]
            p.append(tube_along(f"{name}_cuff", cuff, [0.01] * 13, M("DarkLeather"), sides=5, cap=False))
    wheel = lathe(f"{name}_ratchet", [(-0.02, 0.2, 0.2, 0), (0.02, 0.2, 0.2, 0)], M("Iron"), 16, thickness=0.02)
    wheel.rotation_euler = (math.pi / 2, 0, 0); wheel.location = (L / 2 - 0.1, -W / 2 - 0.1, H - 0.02)
    p.append(wheel)
    p.append(tube_along(f"{name}_crank", [V((L / 2 - 0.1, -W / 2 - 0.15, H - 0.02)), V((L / 2 - 0.1, -W / 2 - 0.15, H + 0.35)), V((L / 2 - 0.1, -W / 2 - 0.35, H + 0.35))], [0.02] * 3, M("Iron"), sides=6))
    p.append(box(f"{name}_blood", (0.6, 0.4, 0.004), (0, 0, H - 0.078), mat=bpy.data.materials["M_Blood_01"], bevel=0, jitter=0.02, seed=3))
    return finish_asset(name, p, DC, [((L, W, H), (0, 0, H / 2))])


def build_stocks(name="SM_Stocks_Pillory_01", seed=751):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        p.append(plank(f"{name}_post", (0.16, 0.16, 1.2), (sx * 0.8, 0, 0.6), mat_key="OldWood", seed=sx, wear=0.01))
        p.append(plank(f"{name}_foot", (0.18, 0.7, 0.12), (sx * 0.8, 0, 0.06), mat_key="OldWood", seed=sx + 5))
    for z, half in ((0.55, "low"), (0.73, "up")):
        b = plank(f"{name}_board_{half}", (1.8, 0.1, 0.18), (0, 0, z), seed=int(z * 100), wear=0.01)
        p.append(b)
    for x in (-0.35, 0.35):
        p.append(cylinder(f"{name}_hole", 0.07, 0.12, (x, 0, 0.64), (math.pi / 2, 0, 0), M("DarkWood"), verts=12))
    p.append(cylinder(f"{name}_neck", 0.1, 0.12, (0, 0, 0.64), (math.pi / 2, 0, 0), M("DarkWood"), verts=14))
    p.append(box(f"{name}_hasp", (0.05, 0.03, 0.22), (0.85, -0.06, 0.64), mat=M("RustedIron"), bevel=0.006, segs=1))
    return finish_asset(name, p, DC, [((1.8, 0.7, 1.2), (0, 0, 0.6))])


def build_chest_iron(name="SM_Chest_IronBound_01", seed=761):
    """Iron-bound chest: plank box, domed lid, corner brackets, straps with rivets, hasp lock, side handles."""
    remove_asset(name); rnd = random.Random(seed); p = []
    L, W, H = 0.9, 0.55, 0.45
    for i in range(3):
        for side in (-1, 1):
            p.append(plank(f"{name}_side", (L, 0.03, H / 3 - 0.005), (0, side * (W / 2 - 0.015), H / 6 + i * H / 3), seed=rnd.randint(0, 999)))
    for sx in (-1, 1):
        p.append(plank(f"{name}_end", (0.03, W, H), (sx * (L / 2 - 0.015), 0, H / 2), seed=sx))
        cap = _arc_block(f"{name}_lidend{sx}", 0.0, W / 2 - 0.03, math.pi / 2, 3 * math.pi / 2, -0.015, 0.015, M("Planks"), 0.001, sx, segs=12)
        cap.rotation_euler = (0, math.pi / 2, 0)
        cap.location = (sx * (L / 2 - 0.015), 0, H)
        p.append(cap)
    lid = lathe(f"{name}_lid", [(0, W / 2, W / 2 * 0.5, 0), (0.001, W / 2, W / 2 * 0.5, 0)], M("Planks"), 4)
    bpy.data.objects.remove(lid, do_unlink=True)
    n = 8
    for k in range(n):
        a0 = math.pi / 2 + math.pi * k / n
        blk = _arc_block(f"{name}_lidslat", W / 2 - 0.03, W / 2, a0, a0 + math.pi / n - 0.01, -L / 2, L / 2, M("Planks"), 0.002, rnd.randint(0, 999), segs=2)
        blk.rotation_euler = (0, math.pi / 2, 0)
        blk.location = (0, 0, H)
        p.append(blk)
    for x in (-L / 2 + 0.12, 0, L / 2 - 0.12):
        strap = [V((x, (W / 2 + 0.008) * math.cos(a), H + (W / 2 + 0.008) * math.sin(a) * 0.98)) for a in [math.pi * i / 16 for i in range(17)]]
        p.append(tube_along(f"{name}_lidstrap", strap, [0.012] * 17, M("RustedIron"), sides=4))
        for side in (-1, 1):
            p.append(box(f"{name}_strap", (0.05, 0.008, H), (x, side * (W / 2 + 0.004), H / 2), mat=M("RustedIron"), bevel=0.002, segs=1))
            for z in (0.08, H / 2, H - 0.08):
                p.append(cylinder(f"{name}_rivet", 0.008, 0.01, (x, side * (W / 2 + 0.01), z), (math.pi / 2, 0, 0), M("Iron"), verts=6))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"{name}_corner", (0.08, 0.08, 0.08), (sx * (L / 2 - 0.03), sy * (W / 2 - 0.03), 0.04), mat=M("RustedIron"), bevel=0.01, segs=2))
        handle = [V((sx * (L / 2 + 0.03), 0.07 * math.cos(a), H * 0.6 - 0.05 * math.sin(a))) for a in [math.pi * i / 10 for i in range(11)]]
        p.append(tube_along(f"{name}_handle{sx}", handle, [0.008] * 11, M("Iron"), sides=5))
    p.append(box(f"{name}_hasp", (0.07, 0.015, 0.14), (0, -W / 2 - 0.012, H - 0.02), mat=M("Iron"), bevel=0.005, segs=2))
    p.append(box(f"{name}_lock", (0.09, 0.03, 0.1), (0, -W / 2 - 0.03, H - 0.1), mat=M("Gold"), bevel=0.01, segs=2))
    return finish_asset(name, p, DC, [((L + 0.06, W + 0.04, H + W / 2), (0, 0, (H + W / 2) / 2))])


def build_altar_dungeon(name="SM_Altar_Dungeon_01", seed=771):
    """Blood-stained sacrificial altar: stepped stone base, carved slab with rune channel, candles, bowl and skulls."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for i, (w, d, h) in enumerate(((3.2, 2.2, 0.2), (2.8, 1.8, 0.2))):
        p.append(box(f"{name}_step{i}", (w, d, h), (0, 0, 0.1 + i * 0.2), mat=DS(), bevel=0.03, segs=2, jitter=0.015, seed=i))
    body = box(f"{name}_body", (2.0, 1.0, 0.7), (0, 0, 0.75), mat=DS(), bevel=0.04, segs=2, jitter=0.012, seed=3)
    dent(body, 0.03, seed=3, count=10, radius=0.15)
    p.append(body)
    p.append(box(f"{name}_slab", (2.3, 1.25, 0.18), (0, 0, 1.19), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.01, seed=4))
    # Carved front panel: runes as recessed emissive glyph strokes.
    for i in range(9):
        x = -0.8 + i * 0.2
        for k in range(rnd.randint(2, 3)):
            p.append(box(f"{name}_rune", (0.012, 0.005, rnd.uniform(0.06, 0.14)), (x + rnd.uniform(-0.04, 0.04), -0.502, 0.75 + rnd.uniform(-0.1, 0.1)), rot=(0, rnd.choice((0, 0.6, -0.6, 1.57)), 0), mat=bpy.data.materials["M_Rune_Glow_01"], bevel=0, jitter=0))
    p.append(box(f"{name}_channel", (1.9, 0.06, 0.02), (0, 0, 1.285), mat=bpy.data.materials["M_Blood_01"], bevel=0, jitter=0))
    for i in range(5):
        p.append(box(f"{name}_stain", (rnd.uniform(0.1, 0.3), 0.005, rnd.uniform(0.2, 0.5)), (rnd.uniform(-0.9, 0.9), -0.51, 1.0 - rnd.uniform(0, 0.3)), mat=bpy.data.materials["M_Blood_01"], bevel=0, jitter=0.01, seed=i))
    for sx in (-1, 1):
        cc = []
        build_candle_cluster.__globals__  # noqa: keep reference
        for k in range(4):
            h = rnd.uniform(0.1, 0.3)
            p.append(cylinder(f"{name}_candle", rnd.uniform(0.025, 0.04), h, (sx * rnd.uniform(0.75, 1.0), rnd.uniform(-0.4, 0.4), 1.28 + h / 2), mat=M("Bone"), verts=10))
        sk = _skull(f"{name}_skull{sx}", 1.0, seed + sx)
        sk.location = (sx * 1.35, -0.7, 0.53); sk.rotation_euler = (0, 0, sx * 0.3)
        p.append(sk)
    bowl = lathe(f"{name}_bowl", [(0, 0.08, 0.08, 0), (0.06, 0.16, 0.16, 0), (0.1, 0.18, 0.18, 0)], M("Gold"), 20, thickness=0.01)
    bowl.location = (0, 0.3, 1.28)
    p.append(bowl)
    p.append(cylinder(f"{name}_bowlblood", 0.15, 0.01, (0, 0.3, 1.36), mat=bpy.data.materials["M_Blood_01"], verts=20))
    obj = finish_asset(name, p, DC, [((3.2, 2.2, 0.4), (0, 0, 0.2)), ((2.3, 1.25, 0.9), (0, 0, 0.85))], lods=False)
    socket(obj, "FX_Altar", (0, 0.3, 1.4))
    return obj


def build_magic_door(name="SM_Door_AncientMagic_01", seed=781):
    """Ancient sealed door: towering carved frame, two stone leaves with relief bands, circular rune seal
    split down the middle, glowing rune channels; guardian statues' plinths either side."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, H = 3.2, 5.0
    glow = bpy.data.materials["M_Rune_Glow_01"]
    for sx in (-1, 1):
        z = 0
        while z < H:
            p.append(box(f"{name}_pilaster", (0.7, 0.9, 0.49), (sx * (W / 2 + 0.35), 0, z + 0.25), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.008, seed=rnd.randint(0, 999)))
            z += 0.5
        for zz in (0.25, H - 0.2):
            p.append(box(f"{name}_band", (0.85, 1.0, 0.18), (sx * (W / 2 + 0.35), 0, zz), mat=M("CastleStone"), bevel=0.02, segs=2, seed=int(zz * 10)))
        # Leaf: single slab with carved relief panels.
        p.append(box(f"{name}_leaf{sx}", (W / 2 - 0.02, 0.35, H), (sx * W / 4, 0.1, H / 2), mat=DS(), bevel=0.02, segs=2, jitter=0.004, seed=sx + 30))
        for zz in (0.8, 2.0, 3.2, 4.3):
            p.append(box(f"{name}_relief", (W / 2 - 0.4, 0.06, 0.8), (sx * W / 4, -0.1, zz), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.004, seed=int(zz * 10) + sx))
            p.append(box(f"{name}_glyph", (0.6, 0.01, 0.03), (sx * W / 4, -0.135, zz), mat=glow, bevel=0, jitter=0))
    _arch_ring(p, name, W + 0.1, H - 0.2, 0.9, rnd, pointed=True, thick=0.6)
    # Rune seal: two half-discs with concentric glowing rings and radial glyphs.
    for sx in (-1, 1):
        seal = _arc_block(f"{name}_seal{sx}", 0.0, 0.85, (math.pi / 2 if sx < 0 else -math.pi / 2), (3 * math.pi / 2 if sx < 0 else math.pi / 2), -0.08, 0.08, M("Gold"), 0.002, sx + 5, segs=16)
        seal.rotation_euler = (math.pi / 2, 0, 0); seal.location = (sx * 0.01, -0.12, 2.6)
        p.append(seal)
    for r in (0.35, 0.6, 0.8):
        ring = [V((r * math.cos(a), -0.215, 2.6 + r * math.sin(a))) for a in [2 * math.pi * i / 48 for i in range(49)]]
        p.append(tube_along(f"{name}_ring", ring, [0.012] * 49, glow, sides=5, cap=False))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.append(box(f"{name}_sglyph", (0.02, 0.01, 0.12), (0.7 * math.cos(a), -0.215, 2.6 + 0.7 * math.sin(a)), rot=(0, -a, 0), mat=glow, bevel=0, jitter=0))
    for sx in (-1, 1):
        p.append(box(f"{name}_plinth", (1.0, 1.0, 1.2), (sx * (W / 2 + 1.4), -0.3, 0.6), mat=M("CastleStone"), bevel=0.04, segs=2, jitter=0.01, seed=sx + 60))
    obj = finish_asset(name, p, DC, [((W + 1.6, 1.0, H + 1.0), (0, 0.1, (H + 1.0) / 2))], lods=False)
    socket(obj, "FX_Seal", (0, -0.25, 2.6))
    return obj

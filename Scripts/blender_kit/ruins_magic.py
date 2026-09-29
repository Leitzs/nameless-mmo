"""Ruins and magical props. exec() after kitlib, castle, buildings, items, armor, props2, props3, castle2, dungeon, nature, nature2."""

V = Vector
RU, MG = "ENV_Ruins", "PROP_Magic"


def magic_materials():
    mat_stone("M_TempleMarble_01", (0.42, 0.4, 0.36), (0.18, 0.17, 0.15), 1.2, rough=0.6, moss=0.25)
    mat_emissive("M_Mana_Crystal_01", (0.1, 0.35, 1.0), 2.5, transmission=0.8)
    mat_emissive("M_Portal_Glow_01", (0.35, 0.2, 1.0), 3.0, transmission=0.0)
    mat_emissive("M_Potion_Red_01", (0.8, 0.02, 0.03), 0.8, transmission=0.8)
    mat_emissive("M_Potion_Blue_01", (0.05, 0.25, 0.9), 0.8, transmission=0.8)
    mat_emissive("M_Potion_Green_01", (0.1, 0.8, 0.15), 0.8, transmission=0.8)
    mat_emissive("M_Glass_Clear_01", (0.6, 0.65, 0.6), 0.0, transmission=0.95)
    if "M_Rune_Glow_01" not in bpy.data.materials:
        mat_emissive("M_Rune_Glow_01", (0.2, 0.55, 1.0), 4.0, transmission=0.0)
    if "M_Parchment_01" not in bpy.data.materials:
        mat_plaster("M_Parchment_01", (0.55, 0.47, 0.33))


def MM(n):
    return bpy.data.materials[n]


def _fluted_drum(name, r, h, mat, flutes=16, seed=0):
    """Column drum with concave flutes (vertex displacement on a cylinder)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=flutes * 4, radius1=r, radius2=r * 0.985, depth=h)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        rr = math.hypot(v.co.x, v.co.y)
        if rr > r * 0.5:
            k = 1 - 0.06 * max(0.0, math.cos(a * flutes)) ** 2
            v.co.x *= k
            v.co.y *= k
    o = _obj_from_bm(name, bm, mat)
    dent(o, 0.02, seed=seed, count=8, radius=r * 0.5)
    return o


def build_column_broken(name="SM_Ruin_Column_Broken_01", seed=1601, standing=2):
    remove_asset(name); rnd = random.Random(seed); p = []
    mat = MM("M_TempleMarble_01")
    p.append(box(f"{name}_plinth", (1.1, 1.1, 0.3), (0, 0, 0.15), mat=mat, bevel=0.03, segs=2, jitter=0.02, seed=1))
    p.append(tube_along(f"{name}_base", [V((0, 0, 0.3)), V((0, 0, 0.38)), V((0, 0, 0.45))], [0.48, 0.5, 0.42], mat, sides=24))
    z = 0.45
    for i in range(standing):
        h = 0.7
        d = _fluted_drum(f"{name}_drum{i}", 0.4, h, mat, seed=seed + i)
        d.location = (0, 0, z + h / 2)
        d.rotation_euler = (0, 0, rnd.uniform(0, 1))
        p.append(d)
        z += h
    top = _fluted_drum(f"{name}_broken", 0.4, 0.5, mat, seed=seed + 9)
    top.location = (0, 0, z + 0.25)
    bm = bmesh.new(); bm.from_mesh(top.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z -= 0.35 * (0.5 + 0.5 * math.sin(v.co.x * 6 + v.co.y * 4)) * (v.co.z / 0.25)
    bm.to_mesh(top.data); bm.free()
    p.append(top)
    for i in range(2):
        d = _fluted_drum(f"{name}_fallen{i}", 0.4, 0.7, mat, seed=seed + 20 + i)
        d.rotation_euler = (math.pi / 2, 0, rnd.uniform(0, math.pi))
        d.location = (rnd.uniform(1.2, 2.4) * (1 if i else -1), rnd.uniform(-1, 1), 0.38)
        p.append(d)
    cap = box(f"{name}_capital_fallen", (1.0, 1.0, 0.4), (1.6, 1.4, 0.2), rot=(0.2, 0.1, 0.5), mat=mat, bevel=0.05, segs=2, jitter=0.02, seed=5)
    p.append(cap)
    for i in range(5):
        m = rock(f"{name}_moss{i}", (0.25, 0.2, 0.06), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.choice((0.31, z + 0.2)))
        p.append(m)
    return finish_asset(name, p, RU, [((1.1, 1.1, z + 0.4), (0, 0, (z + 0.4) / 2))], lods=False)


def build_temple_column(name="SM_Temple_Column_Intact_01", seed=1611, H=6.0):
    remove_asset(name); rnd = random.Random(seed); p = []
    mat = MM("M_TempleMarble_01")
    p.append(box(f"{name}_plinth", (1.1, 1.1, 0.3), (0, 0, 0.15), mat=mat, bevel=0.03, segs=2, jitter=0.01, seed=1))
    p.append(tube_along(f"{name}_base", [V((0, 0, 0.3)), V((0, 0, 0.38)), V((0, 0, 0.45))], [0.48, 0.5, 0.42], mat, sides=24))
    z = 0.45
    while z < H - 0.8:
        h = min(0.8, H - 0.8 - z)
        d = _fluted_drum(f"{name}_drum", 0.4 - z * 0.008, h - 0.005, mat, seed=int(z * 10))
        d.location = (0, 0, z + h / 2)
        p.append(d)
        z += h
    p.append(tube_along(f"{name}_echinus", [V((0, 0, z)), V((0, 0, z + 0.2)), V((0, 0, z + 0.35))], [0.36, 0.5, 0.58], mat, sides=24))
    p.append(box(f"{name}_abacus", (1.25, 1.25, 0.2), (0, 0, z + 0.45), mat=mat, bevel=0.02, segs=2, jitter=0.008, seed=2))
    return finish_asset(name, p, RU, [((0.9, 0.9, H), (0, 0, H / 2))], lods=False)


def build_temple_platform(name="SM_Temple_Platform_01", seed=1621, W=10.0, D=6.0):
    """Stepped stylobate with cracked, heaved slabs, grass in the joints, a fallen pediment fragment."""
    remove_asset(name); rnd = random.Random(seed); p = []
    mat = MM("M_TempleMarble_01")
    for s in range(3):
        w, d = W - s * 0.8, D - s * 0.8
        z = s * 0.3
        x = -w / 2
        while x < w / 2 - 0.01:
            l = min(rnd.uniform(0.9, 1.6), w / 2 - x)
            for sy in (-1, 1):
                p.append(box(f"{name}_step", (l - 0.02, 0.4, 0.3), (x + l / 2, sy * (d / 2 - 0.2), z + 0.15 + rnd.uniform(-0.01, 0.02)), rot=(rnd.uniform(-0.01, 0.01), 0, rnd.uniform(-0.01, 0.01)), mat=mat, bevel=0.025, segs=2, jitter=0.01, seed=rnd.randint(0, 9999)))
            x += l
    top = 0.9
    for i in range(int((W - 2.4) / 1.0)):
        for j in range(int((D - 2.4) / 1.0)):
            s = box(f"{name}_slab", (0.98, 0.98, 0.12), (-(W - 2.4) / 2 + 0.5 + i, -(D - 2.4) / 2 + 0.5 + j, top - 0.06 + rnd.uniform(-0.02, 0.02)), rot=(rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02), 0), mat=mat, bevel=0.02, segs=2, jitter=0.01, seed=rnd.randint(0, 9999))
            dent(s, 0.02, seed=i * 7 + j, count=3, radius=0.3)
            p.append(s)
    for i in range(10):
        g = _blade_clump(f"{name}_grass{i}", 40, 0.25, 0.15, MM("M_Grass_01"), rnd, width=0.007)
        g.location = (rnd.uniform(-W / 2 + 1.5, W / 2 - 1.5), rnd.uniform(-D / 2 + 1.5, D / 2 - 1.5), top)
        p.append(g)
    # Fallen pediment (triangular gable block with cornice).
    bm = bmesh.new()
    tri = [bm.verts.new(v) for v in ((-1.8, 0, 0), (1.8, 0, 0), (0, 0, 1.0))]
    f = bm.faces.new(tri)
    bmesh.ops.solidify(bm, geom=[f], thickness=0.7)
    ped = _obj_from_bm(f"{name}_pediment", bm, mat)
    dent(ped, 0.05, seed=3, count=10, radius=0.3)
    ped.location = (W / 2 + 0.8, 1.5, 0.35); ped.rotation_euler = (1.35, 0.1, 0.6)
    p.append(ped)
    return finish_asset(name, p, RU, [((W, D, top), (0, 0, top / 2))], lods=False)


def build_ruined_arch(name="SM_Ruin_Arch_01", seed=1631, span=3.4, spring=2.2):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        z = 0.0
        hmax = spring + (0.2 if sx < 0 else -0.6)
        while z < hmax:
            p.append(box(f"{name}_pier", (0.8, 0.8, 0.41), (sx * (span / 2 + 0.4), 0, z + 0.2), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.015, seed=rnd.randint(0, 999)))
            z += 0.42
    ring = []
    _arch_ring(ring, name, span, spring + 0.1, 0.8, rnd, pointed=False, thick=0.45)
    # Keep only the left springing voussoirs (the rest have fallen).
    keep = [b for b in ring if b.location.x < -0.2 and "_key" not in b.name]
    for b in ring:
        if b not in keep:
            bpy.data.objects.remove(b, do_unlink=True)
    p.extend(keep[:5])
    for b in keep[5:]:
        bpy.data.objects.remove(b, do_unlink=True)
    debris(p, name, (0.6, -0.4, 0), 1.6, 18, rnd)
    for i in range(3):
        iv = rock(f"{name}_ivy{i}", (0.35, 0.3, 0.5), seed=i, mat=MM("M_Ivy_01") if "M_Ivy_01" in bpy.data.materials else M("MossRock"), subdiv=2)
        iv.location = (-(span / 2 + 0.4) + rnd.uniform(-0.3, 0.3), -0.42, rnd.uniform(0.5, spring))
        iv.scale = (1, 0.2, 1)
        p.append(iv)
    return finish_asset(name, p, RU, [((0.8, 0.8, spring), (sx * (span / 2 + 0.4), 0, spring / 2)) for sx in (-1, 1)], lods=False)


def build_statue_broken(name="SM_Ruin_Statue_Knight_Broken_01", seed=1641):
    """Weathered knight statue broken at the waist: legs with sword on the plinth, torso and head fallen beside it."""
    remove_asset(name); rnd = random.Random(seed); p = []
    mat = MM("M_TempleMarble_01")
    p.append(box(f"{name}_plinth", (1.2, 1.2, 1.0), (0, 0, 0.5), mat=mat, bevel=0.04, segs=2, jitter=0.01, seed=1))
    p.append(box(f"{name}_plinthcap", (1.35, 1.35, 0.15), (0, 0, 1.07), mat=mat, bevel=0.03, segs=2, jitter=0.01, seed=2))
    for sx in (-1, 1):
        p.append(tube_along(f"{name}_leg{sx}", [V((sx * 0.14, 0, 1.15)), V((sx * 0.15, 0.02, 1.7)), V((sx * 0.14, 0, 2.2))], [0.11, 0.09, 0.12], mat, sides=12))
        p.append(box(f"{name}_boot{sx}", (0.16, 0.3, 0.15), (sx * 0.14, -0.05, 1.22), mat=mat, bevel=0.03, segs=2, seed=sx))
    p.append(lathe(f"{name}_tasset", [(2.1, 0.26, 0.18, 0), (2.4, 0.24, 0.17, 0)], mat, 20, thickness=0.02))
    # Sword planted point-down between the feet (stone).
    p.append(box(f"{name}_sword", (0.07, 0.02, 0.9), (0, -0.2, 1.6), mat=mat, bevel=0.01, segs=1))
    p.append(box(f"{name}_guard", (0.35, 0.05, 0.05), (0, -0.2, 2.08), mat=mat, bevel=0.01, segs=1))
    # Fallen torso and head.
    torso = lathe(f"{name}_torso", [(0, 0.24, 0.16, 0), (0.4, 0.28, 0.17, 0), (0.6, 0.3, 0.16, 0), (0.7, 0.12, 0.1, 0)], mat, 20, cap_top=True)
    torso.location = (1.2, 0.6, 0.25); torso.rotation_euler = (1.4, 0.2, 0.9)
    dent(torso, 0.03, seed=1, count=8, radius=0.1)
    p.append(torso)
    helm = lathe(f"{name}_helm", [(0, 0.12, 0.13, 0), (0.15, 0.13, 0.14, 0), (0.25, 0.09, 0.1, 0), (0.29, 0.02, 0.02, 0)], mat, 18, cap_top=True)
    helm.location = (-1.0, -0.8, 0.12); helm.rotation_euler = (0.6, 1.3, 0)
    p.append(helm)
    debris(p, name, (0.8, 0.3, 0), 1.0, 10, rnd, size=(0.06, 0.18), mat_key="CastleStone")
    for i in range(4):
        m = rock(f"{name}_lichen{i}", (0.15, 0.1, 0.03), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 1.15)
        p.append(m)
    return finish_asset(name, p, RU, [((1.35, 1.35, 2.4), (0, 0, 1.2))], lods=False)


def build_ruined_house(name="SM_Ruin_House_01", seed=1651):
    """Roofless stone cottage shell: jagged walls with an empty window and door, collapsed charred roof beams inside, rubble and weeds."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D = 7.0, 5.0
    for side, (Lw, off) in enumerate(((W, D / 2), (D, W / 2), (W, D / 2), (D, W / 2))):
        blocks = []
        top = _jagged(Lw, 2.2 if side % 2 == 0 else 2.8, 1.1, seed + side)
        hole = (lambda x, z: abs(x - 1.0) < 0.55 and z < 2.0) if side == 0 else ((lambda x, z: abs(x) < 0.5 and 1.0 < z < 2.0) if side == 2 else None)
        ashlar_panel(blocks, name, Lw, 3.6, 0.6, rnd, M("FoundationStone"), top_fn=top, hole=hole, face_d=0.3, course=(0.28, 0.32, 0.36))
        m = Matrix.Rotation(side * math.pi / 2, 4, "Z") @ Matrix.Translation(V((0, -off, 0)))
        for b in blocks:
            b.matrix_world = m @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(blocks)
    for i in range(6):
        a = V((rnd.uniform(-W / 2 + 0.5, W / 2 - 0.5), rnd.uniform(-D / 2 + 0.5, D / 2 - 0.5), rnd.uniform(0.1, 1.8)))
        b = a + V((rnd.uniform(-2, 2), rnd.uniform(-1.5, 1.5), -a.z + 0.1))
        p.append(tube_along(f"{name}_beam{i}", [a, b], [0.1, 0.09], MM("M_Volcanic_01") if "M_Volcanic_01" in bpy.data.materials else M("DarkWood"), sides=6, twist_noise=0.15, seed=i))
    debris(p, name, (0, 0, 0), 2.2, 30, rnd, size=(0.12, 0.35), mat_key="FoundationStone")
    for i in range(12):
        g = _blade_clump(f"{name}_weeds{i}", 40, rnd.uniform(0.3, 0.7), 0.2, MM("M_Grass_01"), rnd, width=0.008)
        g.location = (rnd.uniform(-W / 2 + 0.6, W / 2 - 0.6), rnd.uniform(-D / 2 + 0.6, D / 2 - 0.6), 0)
        p.append(g)
    return finish_asset(name, p, RU, [((W, 0.6, 2.0), (0, sy * D / 2, 1.0)) for sy in (-1, 1)] + [((0.6, D, 2.0), (sx * W / 2, 0, 1.0)) for sx in (-1, 1)], lods=False)


def build_ruin_overgrown(name="SM_Ruin_Wall_Overgrown_01", seed=1661):
    """Low ruined wall swallowed by ivy, moss, ferns and a young tree growing out of it."""
    remove_asset(name); rnd = random.Random(seed); p = []
    top = _jagged(5.0, 1.6, 0.9, seed)
    ashlar_panel(p, name, 5.0, 2.6, 0.9, rnd, MM("M_TempleMarble_01"), top_fn=top, face_d=0.4)
    for i in range(20):
        m = rock(f"{name}_moss{i}", (rnd.uniform(0.15, 0.4), 0.12, rnd.uniform(0.05, 0.12)), seed=i, mat=M("MossRock"), subdiv=2)
        x = rnd.uniform(-2.4, 2.4)
        m.location = (x, rnd.choice((-0.45, 0.45, 0)), rnd.uniform(0.2, top(x)))
        p.append(m)
    for i in range(3):
        ivy_leaves = []
        for k in range(40):
            x = rnd.uniform(-2.3, 2.3); z = rnd.uniform(0.1, top(x) - 0.1)
            leaf = box(f"{name}_ivyleaf", (0.06, 0.005, 0.05), (x, -0.47, z), rot=(0, rnd.uniform(0, 3), 0), mat=MM("M_Ivy_01") if "M_Ivy_01" in bpy.data.materials else M("OakLeaves"), bevel=0, jitter=0.005, seed=k)
            p.append(leaf)
    for i in range(3):
        f = _blade_clump(f"{name}_fern{i}", 30, 0.5, 0.2, MM("M_Fern_01") if "M_Fern_01" in bpy.data.materials else M("OakLeaves"), rnd, width=0.03, bend=0.6)
        f.location = (rnd.uniform(-2, 2), -0.8, 0)
        p.append(f)
    sap = []
    tips = []
    cfg = dict(OAK_CFG); cfg.update(max_depth=2, children=[(3, 4), (2, 3)])
    _grow(sap, tips, (0.8, 0.0, top(0.8) - 0.1), (0.1, 0, 1), 2.0, 0.06, 0, rnd, f"{name}_sap", M("Bark"), cfg)
    sap.append(_leaf_clusters(f"{name}_sap", tips, rnd, M("OakLeaves"), leaves_per_tip=40))
    p.extend(sap)
    return finish_asset(name, p, RU, [((5.0, 0.9, 1.4), (0, 0, 0.7))], lods=False)


# ------------------------------------------------------------------------------------------------------------ magic

def build_crystal_cluster(name="SM_Crystal_Cluster_Mana_01", seed=1701, mat_name="M_Mana_Crystal_01", scale=1.0):
    remove_asset(name); rnd = random.Random(seed); p = []
    base = rock(f"{name}_base", (0.45 * scale, 0.4 * scale, 0.18 * scale), seed=seed, mat=M("Rock"), subdiv=3, flatten=0.9)
    base.location = (0, 0, 0.08 * scale)
    p.append(base)
    for i in range(11):
        h = rnd.uniform(0.25, 0.9) * scale
        c = _crystal(f"{name}_c{i}", h, h * rnd.uniform(0.12, 0.18), MM(mat_name), rnd.choice((5, 6)), seed + i)
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, 0.25) * scale
        tilt = r / (0.25 * scale + 1e-6) * 0.6
        c.location = (math.cos(a) * r, math.sin(a) * r, 0.1 * scale + h * 0.35)
        c.rotation_euler = (-math.sin(a) * tilt, math.cos(a) * tilt, rnd.uniform(0, 1))
        p.append(c)
    obj = finish_asset(name, p, MG, [((0.9 * scale, 0.8 * scale, 0.7 * scale), (0, 0, 0.35 * scale))])
    socket(obj, "FX_Glow", (0, 0, 0.5 * scale))
    return obj


def build_runestone(name="SM_RuneStone_01", seed=1711, H=2.6, floating=False):
    """Standing stone with carved, glowing runes; floating variant hovers over a cracked base with orbiting pebbles."""
    remove_asset(name); rnd = random.Random(seed); p = []
    s = rock(f"{name}_stone", (0.45, 0.25, H / 2), seed=seed, mat=M("Rock"), subdiv=4, roughness=0.3, flatten=0.3)
    s.location = (0, 0, H / 2 + (0.6 if floating else -0.1))
    p.append(s)
    for i in range(10):
        z = (0.6 if floating else 0.0) + 0.3 + i * (H - 0.6) / 10
        for k in range(rnd.randint(1, 3)):
            p.append(box(f"{name}_rune", (0.015, 0.01, rnd.uniform(0.06, 0.14)), (rnd.uniform(-0.15, 0.15), -0.24 + 0.02 * math.sin(z * 3), z + rnd.uniform(-0.04, 0.04)), rot=(0, rnd.choice((0, 0.7, -0.7, 1.57)), 0), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    if floating:
        base = rock(f"{name}_base", (0.7, 0.6, 0.2), seed=seed + 1, mat=M("Rock"), subdiv=3, flatten=0.95)
        base.location = (0, 0, 0.1)
        p.append(base)
        for i in range(6):
            a = 2 * math.pi * i / 6
            pb = rock(f"{name}_orbit{i}", (0.06, 0.05, 0.05), seed=i, mat=M("Rock"), subdiv=2)
            pb.location = (math.cos(a) * 0.7, math.sin(a) * 0.7, 0.9 + 0.15 * math.sin(a * 2))
            p.append(pb)
    else:
        for i in range(5):
            m = rock(f"{name}_moss{i}", (0.2, 0.1, 0.06), seed=i, mat=M("MossRock"), subdiv=2)
            m.location = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.2), rnd.uniform(0.1, 0.5))
            p.append(m)
    obj = finish_asset(name, p, MG, [((0.9, 0.5, H), (0, 0, H / 2 + (0.6 if floating else 0)))], lods=False)
    socket(obj, "FX_Runes", (0, -0.3, H / 2 + (0.6 if floating else 0)))
    return obj


def build_portal_frame(name="SM_Portal_Frame_01", seed=1721, R=2.2):
    """Ring of rune-carved voussoirs on a stepped dais, with a glowing inner membrane disc (swap for Niagara)."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for s in range(2):
        p.append(cylinder(f"{name}_dais{s}", 2.8 - s * 0.5, 0.25, (0, 0, 0.125 + s * 0.25), mat=M("CastleStone"), verts=24, bevel=0.03, jitter=0.01, seed=s))
    cz = R + 0.55
    n = 18
    for k in range(n):
        a0 = 2 * math.pi * k / n
        if math.sin(a0 + math.pi / n) < -0.85:
            continue
        blk = _arc_block(f"{name}_vou{k}", R, R + 0.5, a0, a0 + 2 * math.pi / n - 0.02, -0.35, 0.35, M("CastleStone"), 0.01, rnd.randint(0, 9999), segs=4)
        blk.rotation_euler = (math.pi / 2, 0, 0); blk.location = (0, 0, cz)
        p.append(blk)
        am = a0 + math.pi / n
        p.append(box(f"{name}_glyph{k}", (0.03, 0.02, 0.18), ((R + 0.25) * math.cos(am), -0.36, cz + (R + 0.25) * math.sin(am)), rot=(0, -am, 0), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    disc = cylinder(f"{name}_membrane", R - 0.05, 0.02, (0, 0, cz), (math.pi / 2, 0, 0), MM("M_Portal_Glow_01"), verts=48)
    p.append(disc)
    for sx in (-1, 1):
        p.append(box(f"{name}_foot{sx}", (0.9, 0.9, 1.2), (sx * (R + 0.2), 0, 1.1), mat=M("CastleStone"), bevel=0.04, segs=2, jitter=0.01, seed=sx))
    obj = finish_asset(name, p, MG, [((5.6, 5.6, 0.5), (0, 0, 0.25))] + [((0.9, 0.9, 1.2), (sx * (R + 0.2), 0, 1.1)) for sx in (-1, 1)], lods=False)
    socket(obj, "FX_Portal", (0, 0, cz))
    return obj


def build_book(name, seed, opened=False, ornate=False):
    remove_asset(name); rnd = random.Random(seed); p = []
    W, Dp, T = 0.22, 0.3, 0.06
    cover = M("DarkLeather") if not ornate else M("ClothMageTrim")
    if not opened:
        p.append(box(f"{name}_pages", (W - 0.01, Dp - 0.015, T - 0.01), (0.005, 0, T / 2), mat=MM("M_Parchment_01"), bevel=0.003, segs=1))
        for z in (0.003, T - 0.003):
            p.append(box(f"{name}_cover", (W, Dp, 0.006), (0, 0, z), mat=cover, bevel=0.003, segs=1, jitter=0.001, seed=int(z * 1000)))
        p.append(tube_along(f"{name}_spine", [V((-W / 2, -Dp / 2, T / 2)), V((-W / 2, Dp / 2, T / 2))], [T / 2, T / 2], cover, sides=10))
        if ornate:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    p.append(box(f"{name}_corner", (0.04, 0.04, 0.008), (sx * (W / 2 - 0.02), sy * (Dp / 2 - 0.02), T), mat=M("Gold"), bevel=0.003, segs=1))
            g = _crystal(f"{name}_gem", 0.03, 0.02, MM("M_Void_Glow_01") if "M_Void_Glow_01" in bpy.data.materials else MM("M_Mana_Crystal_01"), 6, seed)
            g.rotation_euler = (math.pi / 2, 0, 0); g.location = (0, 0, T + 0.01)
            p.append(g)
            p.append(box(f"{name}_clasp", (0.05, 0.02, T + 0.01), (W / 2 + 0.005, 0, T / 2), mat=M("Gold"), bevel=0.003, segs=1))
    else:
        for sx in (-1, 1):
            pages = lathe(f"{name}_pages{sx}", [(0, 0.001, Dp / 2 - 0.01, 0), (0.001, 0.001, Dp / 2 - 0.01, 0)], MM("M_Parchment_01"), 4)
            bpy.data.objects.remove(pages, do_unlink=True)
            bm = bmesh.new()
            nx = 10
            rows = []
            for i in range(nx + 1):
                u = i / nx
                x = sx * W * u
                z = 0.04 * math.sin(math.pi * u) * (1 - u) + 0.02
                rows.append([bm.verts.new((x, y, z)) for y in (-Dp / 2 + 0.01, Dp / 2 - 0.01)])
            for a, b in zip(rows, rows[1:]):
                bm.faces.new((a[0], b[0], b[1], a[1]) if sx > 0 else (a[1], b[1], b[0], a[0]))
            bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
            p.append(_obj_from_bm(f"{name}_pageblock{sx}", bm, MM("M_Parchment_01")))
            p.append(box(f"{name}_cover{sx}", (W + 0.01, Dp, 0.006), (sx * (W / 2), 0, 0.003), mat=cover, bevel=0.003, segs=1))
            for k in range(6):
                p.append(box(f"{name}_line{sx}{k}", (W * 0.7, 0.002, 0.003), (sx * W * 0.5, -Dp / 2 + 0.05 + k * 0.035, 0.045 + 0.005 * math.sin(k)), mat=M("DarkWood"), bevel=0, jitter=0))
        p.append(box(f"{name}_rune", (0.06, 0.06, 0.002), (W * 0.5, 0.06, 0.05), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
        p.append(tube_along(f"{name}_ribbon", [V((0, Dp / 2 - 0.02, 0.05)), V((0.02, Dp / 2 + 0.06, 0.0))], [0.004, 0.004], M("ClothMageTrim"), sides=4))
    return finish_asset(name, p, MG, [], smooth=40)


def build_lectern(name="SM_Lectern_MageBook_01", seed=1731):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(cylinder(f"{name}_foot", 0.3, 0.08, (0, 0, 0.04), mat=M("DarkWood"), verts=6, bevel=0.01))
    p.append(tube_along(f"{name}_post", [V((0, 0, 0.08)), V((0, 0, 0.5)), V((0, 0, 1.0))], [0.06, 0.045, 0.06], M("DarkWood"), sides=8))
    top = plank(f"{name}_top", (0.5, 0.4, 0.04), (0, 0, 1.05), rot=(-0.35, 0, 0), mat_key="DarkWood", seed=seed)
    p.append(top)
    p.append(box(f"{name}_lip", (0.5, 0.03, 0.05), (0, -0.19, 0.99), rot=(-0.35, 0, 0), mat=M("DarkWood"), bevel=0.005, segs=1))
    book = build_book(f"{name}_TMPBOOK", seed, opened=True)
    book.location = (0, 0, 1.08); book.rotation_euler = (-0.35, 0, 0)
    link_only(book, MG)
    for c in list(book.children):
        bpy.data.objects.remove(c, do_unlink=True)
    p.append(book)
    for sx in (-1, 1):
        p.append(cylinder(f"{name}_candle{sx}", 0.02, 0.1, (sx * 0.22, -0.05, 1.12), mat=M("Bone"), verts=10))
    return finish_asset(name, p, MG, [((0.5, 0.45, 1.15), (0, 0, 0.575))])


def build_potion(name, seed, shape, liquid):
    remove_asset(name); p = []
    glass = MM("M_Glass_Clear_01")
    prof = {"round": [(0, 0.03, 0.03, 0), (0.05, 0.06, 0.06, 0), (0.1, 0.055, 0.055, 0), (0.13, 0.015, 0.015, 0), (0.18, 0.013, 0.013, 0), (0.185, 0.017, 0.017, 0)],
            "tall": [(0, 0.03, 0.03, 0), (0.15, 0.032, 0.032, 0), (0.18, 0.012, 0.012, 0), (0.24, 0.011, 0.011, 0), (0.245, 0.015, 0.015, 0)],
            "flask": [(0, 0.05, 0.03, 0), (0.08, 0.055, 0.032, 0), (0.12, 0.02, 0.018, 0), (0.16, 0.012, 0.012, 0), (0.165, 0.016, 0.016, 0)]}[shape]
    p.append(lathe(f"{name}_glass", prof, glass, 20, thickness=0.002))
    p.append(cylinder(f"{name}_bottom", prof[0][1], 0.004, (0, 0, 0.002), mat=glass, verts=20))
    liq = [(z, rx * 0.93, ry * 0.93, c) for z, rx, ry, c in prof if z < prof[2][0] * 0.95]
    p.append(lathe(f"{name}_liquid", liq, MM(liquid), 20, cap_top=True))
    top = prof[-1][0]
    p.append(cylinder(f"{name}_cork", prof[-2][1] * 0.95, 0.03, (0, 0, top + 0.01), mat=M("OldWood"), verts=10, radius_top=prof[-2][1] * 1.1))
    p.append(tube_along(f"{name}_string", [V((prof[-2][1] + 0.001 * math.cos(a), 0.001 * math.sin(a), top - 0.01)) for a in [0]] + [V((prof[-2][1] + 0.002, 0, top - 0.04))], [0.0015, 0.0015], M("Straw"), sides=3))
    p.append(box(f"{name}_label", (0.04, 0.001, 0.03), (0, -prof[1][2] - 0.001, prof[1][0]), mat=MM("M_Parchment_01"), bevel=0, jitter=0.001, seed=seed))
    return finish_asset(name, p, MG, [], smooth=60)


def build_magic_lantern(name="SM_Lantern_Magic_Floating_01", seed=1741):
    """Brass cage lantern with a floating wisp crystal instead of a flame; rune bands on the frame."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for z in (0.0, 0.32):
        p.append(tube_along(f"{name}_ring{z}", [V((0.1 * math.cos(a), 0.1 * math.sin(a), z)) for a in [2 * math.pi * i / 24 for i in range(25)]], [0.008] * 25, M("Gold"), sides=5, cap=False))
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(tube_along(f"{name}_rib{k}", [V((0.1 * math.cos(a), 0.1 * math.sin(a), 0)), V((0.12 * math.cos(a), 0.12 * math.sin(a), 0.16)), V((0.1 * math.cos(a), 0.1 * math.sin(a), 0.32))], [0.006] * 3, M("Gold"), sides=5))
    p.append(cylinder(f"{name}_cap", 0.11, 0.1, (0, 0, 0.38), mat=M("Gold"), verts=6, radius_top=0.02, bevel=0.003))
    p.append(tube_along(f"{name}_hook", [V((0.03 * math.cos(a), 0, 0.46 + 0.03 * math.sin(a))) for a in [2 * math.pi * i / 12 for i in range(13)]], [0.005] * 13, M("Gold"), sides=4, cap=False))
    w = _crystal(f"{name}_wisp", 0.1, 0.03, MM("M_Mana_Crystal_01"), 6, seed)
    w.location = (0, 0, 0.16)
    p.append(w)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.5
        p.append(box(f"{name}_rune{k}", (0.012, 0.003, 0.02), (0.108 * math.cos(a), 0.108 * math.sin(a), 0.0), rot=(0, 0, a + math.pi / 2), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    obj = finish_asset(name, p, MG, [], smooth=40)
    socket(obj, "FX_Wisp", (0, 0, 0.16))
    return obj


def build_magic_pillar(name="SM_Pillar_Arcane_Ancient_01", seed=1751, H=4.5):
    """Tapered obelisk-pillar with glowing rune bands, a floating capstone crystal and a cracked stepped base."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for s in range(2):
        p.append(box(f"{name}_step{s}", (1.6 - s * 0.4, 1.6 - s * 0.4, 0.25), (0, 0, 0.125 + s * 0.25), mat=M("CastleStone"), bevel=0.03, segs=2, jitter=0.015, seed=s))
    shaft = cylinder(f"{name}_shaft", 0.4, H, (0, 0, 0.5 + H / 2), mat=M("CastleStone"), verts=8, radius_top=0.28, bevel=0.02, jitter=0.01, seed=seed)
    dent(shaft, 0.04, seed=seed, count=10, radius=0.25)
    p.append(shaft)
    for z in (1.2, 2.4, 3.6):
        r = 0.4 - (z - 0.5) / H * 0.12 + 0.012
        p.append(tube_along(f"{name}_band{z}", [V((r * math.cos(a), r * math.sin(a), z)) for a in [2 * math.pi * i / 32 for i in range(33)]], [0.012] * 33, MM("M_Rune_Glow_01"), sides=4, cap=False))
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            p.append(box(f"{name}_glyph{z}{k}", (0.04, 0.01, 0.1), ((r - 0.005) * math.cos(a), (r - 0.005) * math.sin(a), z + 0.15), rot=(0, 0, a + math.pi / 2), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    cap = _crystal(f"{name}_capstone", 0.5, 0.18, MM("M_Mana_Crystal_01"), 8, seed)
    cap.location = (0, 0, 0.5 + H + 0.45)
    p.append(cap)
    obj = finish_asset(name, p, MG, [((0.9, 0.9, H + 0.5), (0, 0, (H + 0.5) / 2))], lods=False)
    socket(obj, "FX_Capstone", (0, 0, 0.5 + H + 0.45))
    return obj


def build_teleport_shrine(name="SM_Shrine_Teleport_01", seed=1761, R=3.0):
    """Circular platform with an inlaid rune circle, four leaning pillars with braziers and a central focus crystal."""
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(cylinder(f"{name}_platform", R + 0.4, 0.3, (0, 0, 0.15), mat=M("CastleStone"), verts=32, bevel=0.04, jitter=0.01, seed=1))
    n = 20
    for k in range(n):
        a0 = 2 * math.pi * k / n
        p.append(_arc_block(f"{name}_rim{k}", R + 0.1, R + 0.45, a0, a0 + 2 * math.pi / n - 0.02, 0.3, 0.45, M("CastleStone"), 0.01, rnd.randint(0, 9999)))
    for r in (1.2, 2.2):
        p.append(tube_along(f"{name}_circle{r}", [V((r * math.cos(a), r * math.sin(a), 0.305)) for a in [2 * math.pi * i / 64 for i in range(65)]], [0.02] * 65, MM("M_Rune_Glow_01"), sides=4, cap=False))
    for k in range(16):
        a = 2 * math.pi * k / 16
        p.append(box(f"{name}_glyph{k}", (0.12, 0.03, 0.005), (1.7 * math.cos(a), 1.7 * math.sin(a), 0.305), rot=(0, 0, a), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        base = V((R * math.cos(a), R * math.sin(a), 0.3))
        top = base * 0.92 + V((0, 0, 3.2))
        top.z = 3.5
        p.append(tube_along(f"{name}_pillar{k}", [base, (base + top) / 2, top], [0.28, 0.24, 0.2], M("CastleStone"), sides=8))
        p.append(lathe(f"{name}_bowl{k}", [(0, 0.1, 0.1, 0), (0.1, 0.25, 0.25, 0)], M("RustedIron"), 16, thickness=0.01))
        p[-1].location = top
        c = _crystal(f"{name}_flame{k}", 0.2, 0.05, MM("M_Portal_Glow_01"), 5, k)
        c.location = top + V((0, 0, 0.15))
        p.append(c)
    focus = _crystal(f"{name}_focus", 0.8, 0.15, MM("M_Mana_Crystal_01"), 7, seed)
    focus.location = (0, 0, 1.6)
    p.append(focus)
    obj = finish_asset(name, p, MG, [((2 * R + 0.8, 2 * R + 0.8, 0.45), (0, 0, 0.22))], lods=False)
    socket(obj, "FX_Teleport", (0, 0, 0.35))
    socket(obj, "FX_Focus", (0, 0, 1.6))
    return obj


def build_altar_ancient(name="SM_Altar_Ancient_01", seed=1771):
    """Moss-covered ancient altar: monolithic slab on two carved supports, offering bowl with a floating orb, rune rim."""
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        s = box(f"{name}_support{sx}", (0.5, 0.9, 0.9), (sx * 0.8, 0, 0.45), mat=MM("M_TempleMarble_01"), bevel=0.05, segs=2, jitter=0.02, seed=sx)
        dent(s, 0.04, seed=sx + 3, count=8, radius=0.2)
        p.append(s)
        for k in range(3):
            p.append(box(f"{name}_carve{sx}{k}", (0.02, 0.5, 0.04), (sx * 0.8 + sx * 0.26, 0, 0.25 + k * 0.22), mat=MM("M_Rune_Glow_01"), bevel=0, jitter=0))
    slab = box(f"{name}_slab", (2.4, 1.2, 0.25), (0, 0, 1.02), mat=MM("M_TempleMarble_01"), bevel=0.05, segs=2, jitter=0.02, seed=5)
    dent(slab, 0.05, seed=5, count=12, radius=0.25)
    p.append(slab)
    bowl = lathe(f"{name}_bowl", [(0, 0.1, 0.1, 0), (0.06, 0.2, 0.2, 0), (0.12, 0.24, 0.24, 0)], MM("M_TempleMarble_01"), 20, thickness=0.02)
    bowl.location = (0, 0, 1.15)
    p.append(bowl)
    orb = rock(f"{name}_orb", (0.1, 0.1, 0.1), seed=seed, mat=MM("M_Mana_Crystal_01"), subdiv=3, roughness=0.0, flatten=0.0)
    orb.location = (0, 0, 1.55)
    p.append(orb)
    for i in range(10):
        m = rock(f"{name}_moss{i}", (0.3, 0.2, 0.05), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-1.1, 1.1), rnd.uniform(-0.5, 0.5), 1.15)
        p.append(m)
    obj = finish_asset(name, p, MG, [((2.4, 1.2, 1.15), (0, 0, 0.575))], lods=False)
    socket(obj, "FX_Orb", (0, 0, 1.55))
    return obj


def build_ruins_magic_batch():
    magic_materials()
    out = []
    jobs = [build_column_broken, build_temple_column, build_temple_platform, build_ruined_arch, build_statue_broken, build_ruined_house, build_ruin_overgrown,
            lambda: build_crystal_cluster(), lambda: build_crystal_cluster("SM_Crystal_Cluster_Void_01", 1702, "M_Void_Glow_01", 0.7) if "M_Void_Glow_01" in bpy.data.materials else build_crystal_cluster("SM_Crystal_Cluster_Portal_01", 1702, "M_Portal_Glow_01", 0.7),
            lambda: build_runestone(), lambda: build_runestone("SM_RuneStone_Floating_01", 1712, 1.6, floating=True), build_portal_frame,
            lambda: build_book("SM_Book_Spell_Ornate_01", 1781, ornate=True), lambda: build_book("SM_Book_Tome_01", 1782), lambda: build_book("SM_Book_Open_01", 1783, opened=True),
            build_lectern,
            lambda: build_potion("SM_Potion_Health_01", 1791, "round", "M_Potion_Red_01"), lambda: build_potion("SM_Potion_Mana_01", 1792, "tall", "M_Potion_Blue_01"),
            lambda: build_potion("SM_Potion_Poison_01", 1793, "flask", "M_Potion_Green_01"),
            build_magic_lantern, build_magic_pillar, build_teleport_shrine, build_altar_ancient]
    x = -60.0
    for job in jobs:
        o = job()
        o.location = (x, -70, 0)
        out.append((o.name, tris(o)))
        x += 7
    return out

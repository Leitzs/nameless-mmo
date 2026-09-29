"""Buildings batch 2: poor cottage (thatch), merchant house (shopfront), blacksmith (house + forge shed),
and modular building parts. exec() after kitlib, castle, buildings, items, armor, props2, props3, castle2, nature, nature2."""

V = Vector
BC = "ENV_Buildings"


def thatch_material():
    return mat_wood("M_Thatch_01", (0.26, 0.2, 0.1), (0.09, 0.07, 0.035), 6.0, rough=0.97, stretch=(0.25, 6, 0.25))


def _thatch_roof(parts, name, W, D, z_eave, pitch_deg, overhang, rnd, thick=0.35):
    """Thick thatch: rounded, sagging slopes with a ragged eave fringe and a bound ridge roll."""
    mat = bpy.data.materials.get("M_Thatch_01") or thatch_material()
    p = math.radians(pitch_deg)
    half = D / 2 + overhang
    rise = (D / 2) * math.tan(p)
    Lx = W + 2 * overhang
    nx, ns = 36, 14
    for side in (-1, 1):
        bm = bmesh.new()
        grid = []
        for j in range(ns + 1):
            t = j / ns  # 0 at ridge, 1 at eave
            row = []
            for i in range(nx + 1):
                u = -Lx / 2 + Lx * i / nx
                y = side * half * t
                z = z_eave + rise - (rise + overhang * math.tan(p)) * t
                sag = 0.08 * math.sin(math.pi * t) * (1 - (2 * u / Lx) ** 2)
                edge_round = 0.25 * max(0.0, abs(u) - Lx / 2 + 0.4) / 0.4
                z += thick - sag - edge_round * 0.6
                z += noise.noise(V((u * 2 + side, y * 2, 0))) * 0.04
                row.append(bm.verts.new((u, y, z)))
            grid.append(row)
        for j in range(ns):
            for i in range(nx):
                q = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
                bm.faces.new(q if side > 0 else q[::-1])
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
        parts.append(_obj_from_bm(f"{name}_thatch{side}", bm, mat))
        # Ragged eave fringe: hanging straw tufts.
        fr = bmesh.new()
        for i in range(260):
            u = rnd.uniform(-Lx / 2, Lx / 2)
            base = V((u, side * half, z_eave - overhang * math.tan(p) + thick * 0.5))
            tip = base + V((rnd.uniform(-0.03, 0.03), side * rnd.uniform(0.02, 0.1), -rnd.uniform(0.1, 0.25)))
            s = V((0.012, 0, 0))
            vs = [fr.verts.new(base - s), fr.verts.new(base + s), fr.verts.new(tip)]
            fr.faces.new(vs)
        parts.append(_obj_from_bm(f"{name}_fringe{side}", fr, mat))
    ridge = tube_along(f"{name}_ridgeroll", [V((-Lx / 2 - 0.05, 0, z_eave + rise + thick + 0.05)), V((Lx / 2 + 0.05, 0, z_eave + rise + thick + 0.05))], [0.22, 0.22], mat, sides=12)
    parts.append(ridge)
    for i in range(int(Lx / 0.5)):
        x = -Lx / 2 + 0.25 + i * 0.5
        parts.append(tube_along(f"{name}_spar{i}", [V((x - 0.2, -0.25, z_eave + rise + thick - 0.02)), V((x + 0.2, 0.25, z_eave + rise + thick - 0.02))], [0.012, 0.012], M("OldWood"), sides=4))
    return rise + thick


def build_cottage_poor(name="SM_House_Cottage_Poor_01", seed=1801):
    """One-room peasant cottage: rubble walls with limewash patches, low door, tiny shuttered windows,
    thick thatch, stick chimney, lean-to woodpile and a rain barrel."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D, H = 6.0, 4.4, 2.3
    front = [(2.0, 0.9, 0, 1.85, "door"), (4.3, 0.55, 0.95, 1.55, "window")]
    walls = (((-W / 2, -D / 2), (W / 2, -D / 2), front), ((W / 2, -D / 2), (W / 2, D / 2), [(2.2, 0.5, 0.95, 1.5, "window")]),
             ((W / 2, D / 2), (-W / 2, D / 2), []), ((-W / 2, D / 2), (-W / 2, -D / 2), []))
    for (p0, p1, ops) in walls:
        _stone_wall(p, f"{name}_wall", p0, p1, 0.0, H, rnd, M("FoundationStone"), openings=ops)
    # Limewash patches clinging to the rubble.
    for i in range(10):
        side = rnd.choice((-1, 1))
        p.append(box(f"{name}_lime{i}", (rnd.uniform(0.4, 1.2), 0.02, rnd.uniform(0.3, 0.9)), (rnd.uniform(-2.5, 2.5), side * (D / 2 + 0.03), rnd.uniform(0.4, 1.9)), mat=M("Plaster"), bevel=0.01, jitter=0.02, seed=i))
    # Gable ends in wattle-and-daub (plaster over timber) above the stone.
    rise = _thatch_roof(p, name, W, D, H, 50, 0.45, rnd)
    for gx in (-1, 1):
        bm = bmesh.new()
        v = [bm.verts.new((gx * (W / 2 + 0.02), -D / 2, H)), bm.verts.new((gx * (W / 2 + 0.02), D / 2, H)), bm.verts.new((gx * (W / 2 + 0.02), 0, H + (D / 2) * math.tan(math.radians(50))))]
        f = bm.faces.new(v)
        bmesh.ops.solidify(bm, geom=[f], thickness=0.18)
        p.append(_obj_from_bm(f"{name}_gable{gx}", bm, M("Plaster")))
        p.append(box(f"{name}_gablebeam{gx}", (0.14, D, 0.16), (gx * (W / 2 + 0.05), 0, H + 0.05), mat=M("OldWood"), bevel=0.01, jitter=0.006, seed=gx))
    # Chimney of stacked stones rising through the thatch, with a clay pot.
    z = 0
    while z < H + rise + 0.4:
        p.append(box(f"{name}_chim", (0.7, 0.6, 0.24), (-W / 2 + 0.8, D / 2 - 0.5, z + 0.12), mat=M("FoundationStone"), bevel=0.02, segs=1, jitter=0.015, seed=rnd.randint(0, 999)))
        z += 0.25
    p.append(cylinder(f"{name}_chimpot", 0.14, 0.3, (-W / 2 + 0.8, D / 2 - 0.5, z + 0.15), mat=bpy.data.materials.get("M_Clay_01") or M("Plaster"), verts=12, radius_top=0.1))
    # Woodpile lean-to, rain barrel and a step stone.
    for i in range(16):
        p.append(cylinder(f"{name}_log{i}", rnd.uniform(0.07, 0.1), 0.9, (W / 2 + 0.4, -1.2 + (i % 5) * 0.2, 0.1 + (i // 5) * 0.17), (math.pi / 2, 0, 0), M("Bark"), verts=10, jitter=0.01, seed=i))
    p.append(plank(f"{name}_leanto", (0.9, 1.4, 0.04), (W / 2 + 0.45, -0.8, 1.05), rot=(0, 0.35, 0), mat_key="Planks", seed=4))
    b = []
    for i in range(12):
        a = 2 * math.pi * i / 12
        b.append(box(f"{name}_rbstave", (0.12, 0.02, 0.7), (-W / 2 - 0.45 + math.cos(a) * 0.28, -D / 2 - 0.1 + math.sin(a) * 0.28, 0.35), rot=(0, 0, a + math.pi / 2), mat=M("OldWood"), bevel=0.003, segs=1, jitter=0.003, seed=i))
    p.extend(b)
    p.append(box(f"{name}_step", (1.1, 0.5, 0.15), (-W / 2 + 2.0, -D / 2 - 0.35, 0.075), mat=M("FoundationStone"), bevel=0.03, segs=2, jitter=0.02, seed=7))
    return finish_asset(name, p, BC, [((W + 0.2, D + 0.2, H), (0, 0, H / 2))], lods=False)


def build_merchant_house(name="SM_House_Merchant_01", seed=1811):
    """Two-storey merchant house with a ground-floor shopfront (wide opening, fold-down counter shutter,
    awning), jettied timber upper floor, dormer, tile roof and a hanging trade sign."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D = 8.0, 6.0
    g_h = 3.0
    stone = M("FoundationStone")
    _stone_wall(p, f"{name}_gF", (-W / 2, -D / 2), (W / 2, -D / 2), 0, g_h, rnd, stone, openings=[(1.5, 1.0, 0, 2.2, "door")])
    # Replace the right half of the front with a wide shop opening: counter + shutters.
    shop_x0, shop_x1 = 3.6, 7.2
    for i in range(len(p) - 1, -1, -1):
        o = p[i]
        loc = o.matrix_world.translation
        if -D / 2 - 0.6 < loc.y < -D / 2 + 0.6 and -W / 2 + shop_x0 < loc.x < -W / 2 + shop_x1 and 0.95 < loc.z < 2.5:
            bpy.data.objects.remove(o, do_unlink=True)
            p.pop(i)
    sx0, sx1 = -W / 2 + shop_x0, -W / 2 + shop_x1
    p.append(box(f"{name}_shoplintel", (sx1 - sx0 + 0.4, 0.45, 0.3), ((sx0 + sx1) / 2, -D / 2 - 0.13, 2.6), mat=M("OldWood"), bevel=0.015, jitter=0.008, seed=1))
    p.append(box(f"{name}_shopdark", (sx1 - sx0, 0.05, 1.6), ((sx0 + sx1) / 2, -D / 2 + 0.2, 1.75), mat=M("DarkWood")))
    for i in range(int((sx1 - sx0) / 0.2)):
        p.append(plank(f"{name}_counter", (0.2, 0.7, 0.05), (sx0 + 0.1 + i * 0.2, -D / 2 - 0.45, 0.95), rot=(0.05, 0, 0), seed=rnd.randint(0, 999)))
    for k in range(3):
        p.append(box(f"{name}_counterleg{k}", (0.06, 0.06, 0.9), (sx0 + 0.2 + k * (sx1 - sx0 - 0.4) / 2, -D / 2 - 0.72, 0.45), mat=M("OldWood"), bevel=0.006, jitter=0.004, seed=k))
    for i in range(int((sx1 - sx0) / 0.24)):
        p.append(plank(f"{name}_upshutter", (0.23, 0.04, 0.8), (sx0 + 0.12 + i * 0.24, -D / 2 - 0.6, 2.75), rot=(1.1, 0, 0), seed=rnd.randint(0, 999)))
    # Goods on the counter (reuse tableware / baskets if present).
    for k, nm in enumerate(("SM_Bottle_Wine_01", "SM_Mug_Clay_01", "SM_Bowl_Wood_01", "SM_CookingPot_Iron_01")):
        src = bpy.data.objects.get(nm)
        if src:
            c = src.copy(); c.data = src.data.copy(); bpy.context.scene.collection.objects.link(c)
            for ch in list(c.children):
                pass
            c.location = (sx0 + 0.4 + k * 0.8, -D / 2 - 0.45, 0.98)
            c.rotation_euler = (0, 0, rnd.uniform(0, 3))
            p.append(c)
    _stone_wall(p, f"{name}_gR", (W / 2, -D / 2), (W / 2, D / 2), 0, g_h, rnd, stone, openings=[(3.0, 0.8, 1.0, 2.1, "window")])
    _stone_wall(p, f"{name}_gB", (W / 2, D / 2), (-W / 2, D / 2), 0, g_h, rnd, stone, openings=[(4.0, 0.9, 0, 2.1, "door")])
    _stone_wall(p, f"{name}_gL", (-W / 2, D / 2), (-W / 2, -D / 2), 0, g_h, rnd, stone)
    z1 = g_h
    _jetty_joists(p, name, W, -D / 2, z1 - 0.1, rnd)
    y0 = -D / 2 - 0.45
    _timber_wall(p, f"{name}_1F", (-W / 2, y0), (W / 2, y0), z1, z1 + 2.8, rnd, openings=[(1.4, 0.8, 0.9, 2.0, "window"), (4.0, 1.2, 0.9, 2.0, "window"), (6.6, 0.8, 0.9, 2.0, "window")])
    _timber_wall(p, f"{name}_1R", (W / 2, y0), (W / 2, D / 2), z1, z1 + 2.8, rnd, openings=[(3.2, 0.8, 0.9, 2.0, "window")])
    _timber_wall(p, f"{name}_1B", (W / 2, D / 2), (-W / 2, D / 2), z1, z1 + 2.8, rnd, openings=[(4.0, 0.8, 0.9, 2.0, "window")])
    _timber_wall(p, f"{name}_1L", (-W / 2, D / 2), (-W / 2, y0), z1, z1 + 2.8, rnd)
    z_eave = z1 + 2.8
    Du = D + 0.45
    rp = []
    rise = _gable_roof(rp, name, W, Du, z_eave, 48, 0.55, rnd, tiles=True)
    _gable_infill(rp, name, W, Du, z_eave, rise, rnd, 0)
    for o in rp:
        o.location.y -= 0.225
    p.extend(rp)
    # Dormer on the front slope.
    dz = z_eave + 0.9
    for sx in (-1, 1):
        p.append(box(f"{name}_dormerpost{sx}", (0.14, 0.14, 1.1), (sx * 0.7, -Du / 2 + 1.2, dz), mat=M("OldWood"), bevel=0.01, jitter=0.005, seed=sx))
    p.append(box(f"{name}_dormerface", (1.5, 0.12, 1.0), (0, -Du / 2 + 1.2, dz), mat=M("Plaster"), bevel=0.015, jitter=0.01, seed=5))
    dm = Matrix.Translation(V((0, -Du / 2 + 1.12, dz - 0.4)))
    _window(p, dm, f"{name}_dwin", 0.0, 0.2, 0.6, 0.7, rnd, shutters=False)
    for side in (-1, 1):
        p.append(plank(f"{name}_dormerroof{side}", (0.95, 1.4, 0.04), (side * 0.4, -Du / 2 + 1.6, dz + 0.75), rot=(0, side * 0.7, 0), mat_key="Shingles", seed=side))
    # Trade sign (a boot / key / scales: here a gilded key) on an iron bracket.
    bx = -W / 2 + 0.3
    p.append(tube_along(f"{name}_bracket", [V((bx, -D / 2 - 0.3, 2.9)), V((bx - 0.9, -D / 2 - 0.3, 2.9))], [0.02, 0.018], M("Iron"), sides=6))
    key = [V((bx - 0.6, -D / 2 - 0.3, 2.45)), V((bx - 0.6, -D / 2 - 0.3, 2.0))]
    p.append(tube_along(f"{name}_keyshaft", key, [0.035, 0.035], M("Gold"), sides=8))
    p.append(tube_along(f"{name}_keybow", [V((bx - 0.6 + 0.12 * math.cos(a), -D / 2 - 0.3, 2.55 + 0.12 * math.sin(a))) for a in [2 * math.pi * i / 18 for i in range(19)]], [0.025] * 19, M("Gold"), sides=6, cap=False))
    for k in range(2):
        p.append(box(f"{name}_keybit{k}", (0.1, 0.05, 0.06), (bx - 0.55, -D / 2 - 0.3, 2.05 + k * 0.1), mat=M("Gold"), bevel=0.01, segs=1))
    for cz in (2.9,):
        p.append(tube_along(f"{name}_chain", [V((bx - 0.6, -D / 2 - 0.3, cz)), V((bx - 0.6, -D / 2 - 0.3, 2.67))], [0.006, 0.006], M("Iron"), sides=4))
    # Awning over the shop.
    for i in range(10):
        p.append(plank(f"{name}_awning{i}", ((sx1 - sx0) + 0.4, 0.2, 0.03), ((sx0 + sx1) / 2, -D / 2 - 0.35 - i * 0.12, 2.98 - i * 0.05), rot=(-0.4, 0, 0), mat_key="Shingles", seed=i))
    _chimney(p, name, W / 2 - 1.0, 1.0, z_eave - 0.3, z_eave + rise + 1.0, rnd)
    return finish_asset(name, p, BC, [((W + 0.1, D + 0.1, g_h), (0, 0, g_h / 2)), ((W + 0.1, D + 0.55, 2.8), (0, -0.2, z1 + 1.4))], lods=False)


def build_blacksmith(name="SM_House_Blacksmith_01", seed=1821):
    """Smithy: stone house with a slate roof plus an open-fronted timber forge shed attached to the side,
    holding the forge, anvil, quench trough, tool rack and a coal pile."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D, H = 7.0, 5.0, 3.2
    stone = M("FoundationStone")
    _stone_wall(p, f"{name}_F", (-W / 2, -D / 2), (W / 2, -D / 2), 0, H, rnd, stone, openings=[(2.0, 1.0, 0, 2.1, "door"), (4.8, 0.7, 1.1, 2.0, "window")])
    _stone_wall(p, f"{name}_R", (W / 2, -D / 2), (W / 2, D / 2), 0, H, rnd, stone, openings=[(2.5, 1.2, 0, 2.3, "door")])
    _stone_wall(p, f"{name}_B", (W / 2, D / 2), (-W / 2, D / 2), 0, H, rnd, stone, openings=[(3.5, 0.7, 1.1, 2.0, "window")])
    _stone_wall(p, f"{name}_L", (-W / 2, D / 2), (-W / 2, -D / 2), 0, H, rnd, stone)
    rp = []
    rise = _gable_roof(rp, name, W, D, H, 45, 0.45, rnd, tiles=True)
    for gx in (-1, 1):
        wall = []
        top = lambda x, r=rise: (D / 2 - abs(x)) * math.tan(math.radians(45))
        ashlar_panel(wall, f"{name}_gable{gx}", D, rise, 0.4, rnd, stone, top_fn=top, face_d=0.35, both=False, fill_core=False, course=(0.28, 0.32))
        for b in wall:
            b.matrix_world = Matrix.Translation(V((gx * (W / 2 - 0.2), 0, H))) @ Matrix.Rotation(-gx * math.pi / 2, 4, "Z") @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
        p.extend(wall)
    p.extend(rp)
    # Forge shed on the +X side: posts, beams, lean-to shingle roof.
    SX0, SW, SD = W / 2, 4.5, D
    for i, (x, y) in enumerate(((SX0 + SW, -SD / 2), (SX0 + SW, SD / 2), (SX0 + SW / 2, -SD / 2))):
        p.append(plank(f"{name}_shedpost{i}", (0.2, 0.2, 2.8), (x, y, 1.4), mat_key="OldWood", seed=i, wear=0.01))
    for y in (-SD / 2, SD / 2):
        p.append(plank(f"{name}_shedbeam{y}", (SW + 0.3, 0.18, 0.2), (SX0 + SW / 2, y, 2.85), mat_key="OldWood", seed=int(y)))
    for r in range(12):
        z = 3.3 - r * 0.08
        x = SX0 + 0.2 + r * 0.4
        y = -SD / 2 - 0.3
        while y < SD / 2 + 0.3:
            w = rnd.uniform(0.2, 0.32)
            p.append(box(f"{name}_shedsh", (0.45, w - 0.01, 0.02), (x, y + w / 2, z), rot=(0, 0.2, rnd.uniform(-0.03, 0.03)), mat=M("Shingles"), bevel=0.003, jitter=0.003, seed=rnd.randint(0, 99999)))
            y += w
    # Place forge, anvil and fittings inside the shed (copies of the prop assets when present).
    for nm, loc, rz in (("SM_Forge_Smithy_01", (SX0 + 2.8, 1.0, 0), math.pi / 2), ("SM_Anvil_Stump_01", (SX0 + 2.0, -1.0, 0), 0.4), ("SM_WeaponRack_01", (SX0 + 4.2, -1.5, 0), -math.pi / 2), ("SM_Barrel_01", (SX0 + 0.6, -2.0, 0), 0)):
        src = bpy.data.objects.get(nm)
        if src:
            c = src.copy(); c.data = src.data.copy(); bpy.context.scene.collection.objects.link(c)
            c.location = loc; c.rotation_euler = (0, 0, rz)
            p.append(c)
    trough = box(f"{name}_trough", (1.4, 0.5, 0.55), (SX0 + 3.8, 1.9, 0.275), mat=M("OldWood"), bevel=0.02, segs=2, jitter=0.006, seed=3)
    p.append(trough)
    p.append(box(f"{name}_water", (1.3, 0.4, 0.02), (SX0 + 3.8, 1.9, 0.5), mat=M("DarkWood"), bevel=0, jitter=0))
    for i in range(22):
        c = rock(f"{name}_coal{i}", (0.06, 0.05, 0.04), seed=i, mat=M("DarkWood"), subdiv=1)
        c.location = (SX0 + 0.8 + rnd.gauss(0, 0.2), 1.5 + rnd.gauss(0, 0.2), 0.03 + abs(rnd.gauss(0, 0.1)))
        p.append(c)
    _chimney(p, name, -W / 2 + 0.7, 0.8, H - 0.4, H + rise + 1.0, rnd)
    return finish_asset(name, p, BC, [((W + 0.1, D + 0.1, H), (0, 0, H / 2))], lods=False)


# ------------------------------------------------------------------------------------------------ modular parts

def build_modular_parts():
    """Grid-snapped (2 m) building pieces for assembling custom buildings in Unreal."""
    rnd = random.Random(1901)
    out = []

    def make(name, fn, ucx):
        remove_asset(name)
        parts = []
        fn(parts)
        o = finish_asset(name, parts, BC, ucx, lods=False, origin=None)
        out.append(o)

    make("SM_BldKit_Wall_Timber_2m_01", lambda p: _timber_wall(p, "tw", (-1, 0), (1, 0), 0, 2.8, rnd), [((2, 0.25, 2.8), (0, 0, 1.4))])
    make("SM_BldKit_Wall_Timber_Window_2m_01", lambda p: _timber_wall(p, "tww", (-1, 0), (1, 0), 0, 2.8, rnd, openings=[(1.0, 0.8, 0.9, 2.0, "window")]), [((2, 0.25, 2.8), (0, 0, 1.4))])
    make("SM_BldKit_Wall_Timber_Door_2m_01", lambda p: _timber_wall(p, "twd", (-1, 0), (1, 0), 0, 2.8, rnd, openings=[(1.0, 1.0, 0, 2.1, "door")]), [((0.4, 0.25, 2.8), (sx * 0.8, 0, 1.4)) for sx in (-1, 1)])
    make("SM_BldKit_Wall_Stone_2m_01", lambda p: _stone_wall(p, "sw", (-1, 0), (1, 0), 0, 3.0, rnd, M("FoundationStone")), [((2, 0.4, 3.0), (0, 0, 1.5))])
    make("SM_BldKit_Wall_Stone_Window_2m_01", lambda p: _stone_wall(p, "sww", (-1, 0), (1, 0), 0, 3.0, rnd, M("FoundationStone"), openings=[(1.0, 0.8, 1.0, 2.1, "window")]), [((2, 0.4, 3.0), (0, 0, 1.5))])
    make("SM_BldKit_Foundation_2m_01", lambda p: _stone_wall(p, "fd", (-1, 0), (1, 0), 0, 0.6, rnd, M("FoundationStone")), [((2, 0.4, 0.6), (0, 0, 0.3))])

    def roof_seg(p):
        rp = []
        _gable_roof(rp, "rs", 2.0, 5.0, 0.0, 50, 0.0, rnd, tiles=False)
        p.extend(rp)
    make("SM_BldKit_Roof_Shingle_2m_01", roof_seg, [])

    def roof_tile(p):
        rp = []
        _gable_roof(rp, "rt", 2.0, 5.0, 0.0, 50, 0.0, rnd, tiles=True)
        p.extend(rp)
    make("SM_BldKit_Roof_Tile_2m_01", roof_tile, [])

    def chim(p):
        _chimney(p, "ch", 0, 0, 0, 3.0, rnd)
    make("SM_BldKit_Chimney_01", chim, [((1.0, 0.9, 3.0), (0, 0, 1.5))])

    def stairs(p):
        for i in range(14):
            p.append(plank(f"st{i}", (1.0, 0.28, 0.05), (0, i * 0.24, 0.19 * (i + 1)), mat_key="Planks", seed=i))
        for sx in (-1, 1):
            p.append(plank(f"stringer{sx}", (0.06, 3.8, 0.25), (sx * 0.52, 1.6, 1.4), rot=(math.atan2(0.19, 0.24), 0, 0), mat_key="OldWood", seed=sx))
            p.append(tube_along(f"rail{sx}", [V((sx * 0.55, 0, 1.0)), V((sx * 0.55, 3.2, 3.6))], [0.03, 0.03], M("OldWood"), sides=6))
            for k in range(5):
                y = 0.2 + k * 0.7
                p.append(tube_along(f"baluster{sx}{k}", [V((sx * 0.55, y, 0.19 * (y / 0.24) + 0.1)), V((sx * 0.55, y, 0.19 * (y / 0.24) + 0.9))], [0.02, 0.02], M("OldWood"), sides=6))
    make("SM_BldKit_Stairs_Wood_01", stairs, [((1.1, 3.4, 2.7), (0, 1.6, 1.35))])

    def balcony(p):
        for i in range(10):
            p.append(plank(f"bf{i}", (0.2, 1.0, 0.05), (-0.9 + i * 0.2, -0.5, 0.0), seed=i))
        for i in range(4):
            p.append(plank(f"bj{i}", (0.12, 1.3, 0.16), (-0.9 + i * 0.6, -0.4, -0.12), mat_key="OldWood", seed=i + 20))
            p.append(plank(f"bb{i}", (0.08, 0.08, 0.9), (-0.9 + i * 0.6, -0.4, -0.55), rot=(0.75, 0, 0), mat_key="OldWood", seed=i + 40))
        for i in range(11):
            p.append(plank(f"bbal{i}", (0.05, 0.05, 0.9), (-1.0 + i * 0.2, -0.98, 0.47), mat_key="OldWood", seed=i + 60))
        p.append(plank("brail", (2.1, 0.08, 0.08), (0, -0.98, 0.95), mat_key="OldWood", seed=80))
    make("SM_BldKit_Balcony_Wood_2m_01", balcony, [((2, 1, 0.1), (0, -0.5, 0.0)), ((2, 0.1, 1.0), (0, -0.98, 0.5))])

    def window_unit(p):
        _window(p, Matrix.Identity(4), "wu", 0.0, 0.0, 0.8, 1.1, rnd, shutters=True)
    make("SM_BldKit_Window_Shuttered_01", window_unit, [])

    def door_unit(p):
        _door(p, Matrix.Identity(4), "du", 0.0, 1.0, 2.1, rnd)
    make("SM_BldKit_Door_Plank_01", door_unit, [((1.3, 0.2, 2.2), (0, 0, 1.1))])
    x = -60.0
    for o in out:
        o.location = (x, -95, 0)
        x += 5
    return [(o.name, tris(o)) for o in out]


def build_buildings2_batch():
    thatch_material()
    out = []
    for fn, loc in ((build_cottage_poor, (-40, -120, 0)), (build_merchant_house, (-25, -120, 0)), (build_blacksmith, (-5, -120, 0))):
        o = fn(); o.location = loc; out.append((o.name, tris(o)))
    out += build_modular_parts()
    return out

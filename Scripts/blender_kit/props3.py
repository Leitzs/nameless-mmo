"""Village props, batch 3: furniture, lighting, market, tableware, farm and smithy props. exec() after kitlib, castle, items, props2."""

V = Vector
PV = "PROP_Village"


def build_bench(name="SM_Bench_Wood_01", seed=201):
    remove_asset(name); rnd = random.Random(seed); p = []
    L = 1.6
    for i, y in enumerate((-0.1, 0.1)):
        p.append(plank(f"{name}_seat{i}", (L, 0.19, 0.05), (0, y, 0.45), rot=(0, rnd.uniform(-0.01, 0.01), 0), seed=seed + i))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(plank(f"{name}_leg", (0.07, 0.07, 0.46), (sx * 0.6, sy * 0.13, 0.215), rot=(sy * 0.12, sx * 0.08, 0), mat_key="OldWood", seed=rnd.randint(0, 999)))
        p.append(plank(f"{name}_cleat", (0.08, 0.38, 0.06), (sx * 0.6, 0, 0.395), mat_key="OldWood", seed=rnd.randint(0, 999)))
    p.append(plank(f"{name}_stretcher", (1.25, 0.06, 0.06), (0, 0, 0.16), mat_key="OldWood", seed=7))
    for sx in (-1, 1):
        for y in (-0.1, 0.1):
            p.append(cylinder(f"{name}_peg", 0.012, 0.01, (sx * 0.6, y, 0.476), mat=M("DarkWood"), verts=8))
    return finish_asset(name, p, PV, [((L, 0.42, 0.48), (0, 0, 0.24))])


def build_table(name="SM_Table_Trestle_01", seed=211):
    remove_asset(name); rnd = random.Random(seed); p = []
    L, W, H = 2.0, 0.9, 0.78
    for i in range(4):
        y = -W / 2 + W / 8 + i * W / 4
        p.append(plank(f"{name}_top{i}", (L, W / 4 - 0.008, 0.05), (0, y, H - 0.025), rot=(0, 0, rnd.uniform(-0.004, 0.004)), seed=seed + i, wear=0.006))
    for sx in (-1, 1):
        # Trestle: two splayed legs, a foot and a top cleat.
        for sy in (-1, 1):
            p.append(plank(f"{name}_tleg", (0.08, 0.08, H - 0.08), (sx * 0.72, sy * 0.18, (H - 0.08) / 2 + 0.03), rot=(sy * 0.28, 0, 0), mat_key="OldWood", seed=rnd.randint(0, 999)))
        p.append(plank(f"{name}_foot", (0.1, 0.75, 0.08), (sx * 0.72, 0, 0.04), mat_key="OldWood", seed=rnd.randint(0, 999)))
        p.append(plank(f"{name}_cleat", (0.1, W - 0.05, 0.07), (sx * 0.72, 0, H - 0.085), mat_key="OldWood", seed=rnd.randint(0, 999)))
    p.append(plank(f"{name}_rail", (1.5, 0.07, 0.1), (0, 0, 0.35), mat_key="OldWood", seed=3))
    for sx in (-1, 1):
        p.append(box(f"{name}_wedge", (0.04, 0.03, 0.12), (sx * 0.8, 0, 0.35), rot=(0, sx * 0.2, 0), mat=M("DarkWood"), bevel=0.004, segs=1))
    return finish_asset(name, p, PV, [((L, W, H), (0, 0, H / 2))])


def build_chair(name="SM_Chair_Wood_01", seed=221):
    remove_asset(name); rnd = random.Random(seed); p = []
    S = 0.45
    for i in range(3):
        p.append(plank(f"{name}_seat{i}", (S, S / 3 - 0.006, 0.035), (0, -S / 3 + i * S / 3, 0.46), seed=seed + i))
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 1.0 if sy > 0 else 0.45
            p.append(tube_along(f"{name}_leg", [V((sx * 0.2, sy * 0.2, 0)), V((sx * 0.2, sy * 0.2 + (0.03 if sy > 0 else 0), h))], [0.022, 0.02], M("OldWood"), sides=8))
        p.append(tube_along(f"{name}_side", [V((sx * 0.2, -0.2, 0.2)), V((sx * 0.2, 0.2, 0.2))], [0.014, 0.014], M("OldWood"), sides=6))
    for z in (0.7, 0.93):
        p.append(plank(f"{name}_slat", (0.42, 0.025, 0.08), (0, 0.225, z), rot=(0.08, 0, 0), mat_key="OldWood", seed=rnd.randint(0, 999)))
    p.append(tube_along(f"{name}_front", [V((-0.2, -0.2, 0.25)), V((0.2, -0.2, 0.25))], [0.014, 0.014], M("OldWood"), sides=6))
    return finish_asset(name, p, PV, [((0.46, 0.46, 0.48), (0, 0, 0.24)), ((0.46, 0.06, 0.55), (0, 0.22, 0.75))])


def build_stool(name="SM_Stool_Wood_01", seed=231):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(dent(cylinder(f"{name}_seat", 0.17, 0.05, (0, 0, 0.47), mat=M("Planks"), verts=20, bevel=0.01, jitter=0.004, seed=seed), 0.004, seed, 4, 0.05))
    for k in range(3):
        a = 2 * math.pi * k / 3
        p.append(tube_along(f"{name}_leg{k}", [V((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.46)), V((math.cos(a) * 0.17, math.sin(a) * 0.17, 0))], [0.022, 0.018], M("OldWood"), sides=8))
    return finish_asset(name, p, PV, [((0.34, 0.34, 0.5), (0, 0, 0.25))])


def build_lantern(name="SM_Lantern_Iron_01", seed=241):
    """Hanging iron lantern: pyramid cap with vent, ring, 4 horn/glass panes, candle inside, drip tray base."""
    remove_asset(name); p = []
    H = 0.32
    p.append(box(f"{name}_base", (0.16, 0.16, 0.025), (0, 0, 0.0125), mat=M("Iron"), bevel=0.004, segs=2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(box(f"{name}_post", (0.012, 0.012, H - 0.06), (sx * 0.072, sy * 0.072, H / 2 - 0.005), mat=M("Iron"), bevel=0.002, segs=1))
    for k in range(4):
        a = k * math.pi / 2
        pane = box(f"{name}_pane", (0.13, 0.004, H - 0.08), (math.cos(a) * 0.071, math.sin(a) * 0.071, H / 2), rot=(0, 0, a + math.pi / 2), mat=M("Glass"), bevel=0, jitter=0)
        p.append(pane)
        for z in (0.08, 0.2):
            p.append(box(f"{name}_bar", (0.13, 0.006, 0.006), (math.cos(a) * 0.074, math.sin(a) * 0.074, z), rot=(0, 0, a + math.pi / 2), mat=M("Iron"), bevel=0, jitter=0))
    p.append(cylinder(f"{name}_cap", 0.12, 0.09, (0, 0, H + 0.02), mat=M("Iron"), verts=4, radius_top=0.03))
    p[-1].rotation_euler = (0, 0, math.pi / 4)
    p.append(cylinder(f"{name}_vent", 0.03, 0.03, (0, 0, H + 0.08), mat=M("Iron"), verts=8))
    ring = [V((0.03 * math.cos(a), 0, H + 0.13 + 0.03 * math.sin(a))) for a in [2 * math.pi * i / 14 for i in range(15)]]
    p.append(tube_along(f"{name}_ring", ring, [0.005] * 15, M("Iron"), sides=5, cap=False))
    p.append(cylinder(f"{name}_candle", 0.022, 0.1, (0, 0, 0.075), mat=M("Bone"), verts=10))
    p.append(cylinder(f"{name}_flame", 0.008, 0.03, (0, 0, 0.14), mat=M("Glass"), verts=6, radius_top=0.001))
    obj = finish_asset(name, p, PV, [((0.18, 0.18, H + 0.1), (0, 0, (H + 0.1) / 2))])
    socket(obj, "FX_Flame", (0, 0, 0.14))
    return obj


def build_torch_sconce(name="SM_Torch_Wall_01", seed=251):
    """Wall torch: iron bracket plate, basket, wrapped wooden torch with pitch head. Origin at the wall plate."""
    remove_asset(name); p = []
    p.append(box(f"{name}_plate", (0.1, 0.02, 0.22), (0, 0.01, 0), mat=M("RustedIron"), bevel=0.004, segs=2))
    for z in (-0.08, 0.08):
        p.append(cylinder(f"{name}_bolt", 0.01, 0.015, (0, 0.0, z), (math.pi / 2, 0, 0), M("Iron"), verts=6))
    p.append(tube_along(f"{name}_arm", [V((0, -0.01, -0.05)), V((0, -0.12, 0.0)), V((0, -0.16, 0.06))], [0.01, 0.01, 0.01], M("RustedIron"), sides=6))
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(tube_along(f"{name}_cage{k}", [V((math.cos(a) * 0.025, -0.16 + math.sin(a) * 0.025, 0.04)), V((math.cos(a) * 0.045, -0.16 + math.sin(a) * 0.045, 0.12))], [0.004, 0.004], M("RustedIron"), sides=4))
    p.append(tube_along(f"{name}_stick", [V((0, -0.16, -0.18)), V((0, -0.16, 0.14))], [0.018, 0.022], M("OldWood"), sides=8))
    _wrap(p, f"{name}_wrap", 0.0, 0.14, 0.025, M("Straw"), turns=6, band=0.008)
    p[-1].location = (0, -0.16, 0)
    head = rock(f"{name}_pitch", (0.035, 0.035, 0.05), seed=seed, mat=M("DarkWood"), subdiv=2)
    head.location = (0, -0.16, 0.17)
    p.append(head)
    obj = finish_asset(name, p, PV, [((0.12, 0.2, 0.4), (0, -0.09, 0.0))], origin=None)
    socket(obj, "FX_Flame", (0, -0.16, 0.22))
    return obj


def build_candle_cluster(name="SM_Candles_Cluster_01", seed=261):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(dent(cylinder(f"{name}_dish", 0.12, 0.02, (0, 0, 0.01), mat=M("Gold"), verts=20, bevel=0.004), 0.002, seed, 5, 0.04))
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, 0.07); h = rnd.uniform(0.05, 0.16)
        x, y = math.cos(a) * r, math.sin(a) * r
        c = cylinder(f"{name}_c{i}", rnd.uniform(0.012, 0.02), h, (x, y, 0.02 + h / 2), mat=M("Bone"), verts=10, jitter=0.001, seed=i)
        p.append(c)
        # Wax drips running down the side.
        for d in range(3):
            da = rnd.uniform(0, 2 * math.pi)
            p.append(tube_along(f"{name}_drip", [V((x + math.cos(da) * 0.017, y + math.sin(da) * 0.017, 0.02 + h)), V((x + math.cos(da) * 0.019, y + math.sin(da) * 0.019, 0.02 + h * rnd.uniform(0.3, 0.8)))], [0.004, 0.003], M("Bone"), sides=5))
        p.append(cylinder(f"{name}_wick{i}", 0.0015, 0.012, (x, y, 0.026 + h), mat=M("DarkWood"), verts=4))
    return finish_asset(name, p, PV, [((0.24, 0.24, 0.2), (0, 0, 0.1))])


def build_market_stall(name="SM_MarketStall_01", seed=271):
    """Timber market stall: counter, four posts, striped cloth awning sagging between poles, crates and baskets."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D = 2.6, 1.4
    for sx in (-1, 1):
        for sy, h in ((-1, 2.3), (1, 2.6)):
            p.append(plank(f"{name}_post", (0.1, 0.1, h), (sx * W / 2, sy * D / 2, h / 2), mat_key="OldWood", seed=rnd.randint(0, 999), wear=0.006))
    for i in range(4):
        p.append(plank(f"{name}_counter{i}", (W + 0.1, 0.2, 0.05), (0, -D / 2 + 0.1 + i * 0.2, 0.9), seed=rnd.randint(0, 999)))
    for i in range(6):
        p.append(plank(f"{name}_front{i}", (0.42, 0.03, 0.82), (-W / 2 + 0.22 + i * 0.44, -D / 2 - 0.04, 0.45), rot=(0, rnd.uniform(-0.01, 0.01), 0), seed=rnd.randint(0, 999)))
    # Awning: cloth sheet sagging front-to-back, draped fringe at the front.
    bm = bmesh.new()
    nx, ny = 24, 10
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = -W / 2 - 0.15 + (W + 0.3) * i / nx
            t = j / ny
            y = -D / 2 - 0.35 + (D + 0.35) * t
            z = 2.3 + 0.3 * t - 0.12 * math.sin(math.pi * t) - 0.05 * math.sin(math.pi * i / nx * 3) ** 2
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.01)
    stripes = mat_fabric("M_Cloth_Awning_01", (0.28, 0.05, 0.04))
    p.append(_obj_from_bm(f"{name}_awning", bm, stripes))
    for i in range(12):
        x = -W / 2 - 0.1 + i * (W + 0.2) / 11
        p.append(box(f"{name}_fringe", (0.2, 0.01, 0.16), (x, -D / 2 - 0.35, 2.22), rot=(0.1, 0, rnd.uniform(-0.05, 0.05)), mat=M("ClothMageTrim"), bevel=0, jitter=0.01, seed=i))
    p.append(tube_along(f"{name}_pole", [V((-W / 2 - 0.15, -D / 2 - 0.35, 2.3)), V((W / 2 + 0.15, -D / 2 - 0.35, 2.3))], [0.03, 0.03], M("OldWood"), sides=8))
    for sx in (-1, 1):
        p.append(tube_along(f"{name}_prop{sx}", [V((sx * W / 2, -D / 2, 1.6)), V((sx * (W / 2 + 0.1), -D / 2 - 0.35, 2.3))], [0.025, 0.025], M("OldWood"), sides=6))
    # Goods: wicker-ish baskets (bowl lathe) with produce spheres, a small crate and hanging sausages/herbs.
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        b = lathe(f"{name}_basket{i}", [(0.0, 0.12, 0.12, 0), (0.05, 0.18, 0.18, 0), (0.14, 0.22, 0.22, 0)], M("Straw"), 20, thickness=0.01)
        b.location = (x, -0.2, 0.93)
        p.append(b)
        for k in range(9):
            f = rock(f"{name}_fruit", (0.045, 0.045, 0.045), seed=i * 10 + k, mat=bpy.data.materials.get("M_Cloth_Awning_01") if i == 1 else M("OakLeaves"), subdiv=2, roughness=0.0, flatten=0.0)
            f.location = (x + rnd.uniform(-0.12, 0.12), -0.2 + rnd.uniform(-0.12, 0.12), 1.05 + rnd.uniform(0, 0.04))
            p.append(f)
    for i in range(5):
        x = -1.0 + i * 0.5
        p.append(tube_along(f"{name}_string{i}", [V((x, -D / 2 - 0.2, 2.25)), V((x, -D / 2 - 0.2, 2.0))], [0.003, 0.003], M("Straw"), sides=4))
        herb = rock(f"{name}_herb{i}", (0.06, 0.06, 0.12), seed=60 + i, mat=M("OakLeaves"), subdiv=2)
        herb.location = (x, -D / 2 - 0.2, 1.93)
        p.append(herb)
    return finish_asset(name, p, PV, [((W + 0.1, D + 0.1, 0.95), (0, 0, 0.475))] + [((0.1, 0.1, 2.5), (sx * W / 2, sy * D / 2, 1.25)) for sx in (-1, 1) for sy in (-1, 1)], lods=False)


def build_notice_board(name="SM_NoticeBoard_01", seed=281):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        p.append(plank(f"{name}_post", (0.12, 0.12, 2.3), (sx * 0.75, 0, 1.15), mat_key="OldWood", seed=sx + 3, wear=0.008))
    for i in range(6):
        p.append(plank(f"{name}_board{i}", (1.4, 0.03, 0.17), (0, -0.03, 0.95 + i * 0.172), seed=rnd.randint(0, 999)))
    for side in (-1, 1):
        p.append(plank(f"{name}_roof{side}", (1.8, 0.4, 0.03), (0, side * 0.14, 2.1), rot=(side * 0.6, 0, 0), mat_key="Shingles", seed=side))
    # Pinned notices: slightly curled parchment sheets with nails.
    paper = mat_plaster("M_Parchment_01", (0.55, 0.47, 0.33))
    for i in range(7):
        w, h = rnd.uniform(0.18, 0.3), rnd.uniform(0.22, 0.35)
        x, z = rnd.uniform(-0.5, 0.5), rnd.uniform(1.05, 1.75)
        sheet = box(f"{name}_note{i}", (w, 0.003, h), (x, -0.05, z), rot=(rnd.uniform(-0.05, 0.05), 0, rnd.uniform(-0.12, 0.12)), mat=paper, bevel=0, jitter=0.004, seed=i)
        p.append(sheet)
        p.append(cylinder(f"{name}_nail{i}", 0.006, 0.01, (x, -0.055, z + h / 2 - 0.02), (math.pi / 2, 0, 0), M("Iron"), verts=6))
    return finish_asset(name, p, PV, [((1.8, 0.3, 2.3), (0, 0, 1.15))])


def build_fence(name="SM_Fence_Wood_01", seed=291):
    """2.5 m modular split-rail fence section: two leaning posts, three uneven rails lashed with rope."""
    remove_asset(name); rnd = random.Random(seed); p = []
    L = 2.5
    for sx in (-1, 1):
        p.append(tube_along(f"{name}_post{sx}", [V((sx * L / 2, 0, -0.2)), V((sx * L / 2 + rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 1.2))], [0.07, 0.06], M("OldWood"), sides=7, twist_noise=0.12, seed=sx))
        p.append(cylinder(f"{name}_cap{sx}", 0.06, 0.02, (sx * L / 2, 0, 1.2), mat=M("DarkWood"), verts=7))
    for i, z in enumerate((0.35, 0.7, 1.02)):
        pts = [V((-L / 2 - 0.1, 0.05, z + rnd.uniform(-0.03, 0.03))), V((0, 0.05, z - rnd.uniform(0.0, 0.04))), V((L / 2 + 0.1, 0.05, z + rnd.uniform(-0.03, 0.03)))]
        p.append(tube_along(f"{name}_rail{i}", pts, [0.045, 0.05, 0.04], M("OldWood"), sides=7, twist_noise=0.15, seed=i))
        for sx in (-1, 1):
            coil = [V((sx * L / 2 + 0.06 * math.cos(a * 0.5) * 0.9, 0.02 + 0.07 * math.sin(a * 0.5), z + a * 0.004)) for a in range(0, 30)]
            p.append(tube_along(f"{name}_lash", coil, [0.006] * len(coil), M("Straw"), sides=4))
    return finish_asset(name, p, PV, [((L, 0.15, 1.2), (0, 0.03, 0.6))])


def build_hay_pile(name="SM_HayPile_01", seed=301):
    remove_asset(name); rnd = random.Random(seed); p = []
    base = rock(f"{name}_mound", (1.1, 0.9, 0.7), seed=seed, mat=M("Straw"), subdiv=5, roughness=0.0, flatten=0.9)
    base.location = (0, 0, 0.45)
    p.append(base)
    # Loose straw strands poking out everywhere.
    bm = bmesh.new()
    for i in range(1400):
        a = rnd.uniform(0, 2 * math.pi); e = rnd.uniform(-0.2, 1.2)
        c = V((math.cos(a) * 1.05 * math.cos(e), math.sin(a) * 0.85 * math.cos(e), 0.45 + 0.62 * math.sin(e)))
        d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.6))).normalized() * rnd.uniform(0.12, 0.3)
        side = d.cross(V((0, 0, 1))).normalized() * 0.004
        vs = [bm.verts.new(c + side), bm.verts.new(c - side), bm.verts.new(c + d)]
        bm.faces.new(vs)
    p.append(_obj_from_bm(f"{name}_strands", bm, M("Straw")))
    p.append(plank(f"{name}_fork", (0.03, 0.03, 1.5), (0.8, -0.3, 0.8), rot=(0.4, 0.6, 0), mat_key="OldWood", seed=4))
    return finish_asset(name, p, PV, [((2.0, 1.6, 1.0), (0, 0, 0.5))])


def build_tableware(seed=311):
    """Small tabletop set: tankard, clay mug, plate, bowl, wine bottle, cooking pot on legs."""
    out = []
    clay = mat_plaster("M_Clay_01", (0.32, 0.17, 0.09))
    glass = mat_emissive("M_BottleGlass_01", (0.05, 0.12, 0.05), 0.0, transmission=0.8)
    specs = {
        "SM_Tankard_Pewter_01": lambda n: [lathe(f"{n}_b", [(0, 0.045, 0.045, 0), (0.02, 0.047, 0.047, 0), (0.13, 0.042, 0.042, 0), (0.14, 0.044, 0.044, 0)], M("Iron"), 24, thickness=0.004),
                                          cylinder(f"{n}_bottom", 0.045, 0.006, (0, 0, 0.004), mat=M("Iron"), verts=24),
                                          tube_along(f"{n}_h", [V((0.043, 0, 0.12)), V((0.08, 0, 0.11)), V((0.085, 0, 0.05)), V((0.043, 0, 0.03))], [0.006] * 4, M("Iron"), sides=6),
                                          cylinder(f"{n}_lid", 0.047, 0.01, (0, 0, 0.145), mat=M("Iron"), verts=24, bevel=0.002)],
        "SM_Mug_Clay_01": lambda n: [lathe(f"{n}_b", [(0, 0.035, 0.035, 0), (0.03, 0.042, 0.042, 0), (0.09, 0.038, 0.038, 0), (0.1, 0.04, 0.04, 0)], clay, 20, thickness=0.005),
                                     cylinder(f"{n}_bottom", 0.035, 0.006, (0, 0, 0.004), mat=clay, verts=20),
                                     tube_along(f"{n}_h", [V((0.038, 0, 0.08)), V((0.065, 0, 0.065)), V((0.04, 0, 0.03))], [0.007] * 3, clay, sides=6)],
        "SM_Plate_Wood_01": lambda n: [lathe(f"{n}_b", [(0, 0.08, 0.08, 0), (0.008, 0.1, 0.1, 0), (0.018, 0.12, 0.12, 0)], M("OldWood"), 28, thickness=0.006),
                                       cylinder(f"{n}_bottom", 0.08, 0.006, (0, 0, 0.003), mat=M("OldWood"), verts=28)],
        "SM_Bowl_Wood_01": lambda n: [lathe(f"{n}_b", [(0, 0.04, 0.04, 0), (0.03, 0.07, 0.07, 0), (0.06, 0.085, 0.085, 0)], M("OldWood"), 24, thickness=0.006),
                                      cylinder(f"{n}_bottom", 0.04, 0.006, (0, 0, 0.003), mat=M("OldWood"), verts=24)],
        "SM_Bottle_Wine_01": lambda n: [lathe(f"{n}_b", [(0, 0.038, 0.038, 0), (0.18, 0.04, 0.04, 0), (0.22, 0.03, 0.03, 0), (0.24, 0.014, 0.014, 0), (0.3, 0.013, 0.013, 0), (0.305, 0.016, 0.016, 0)], glass, 20, thickness=0.003),
                                        cylinder(f"{n}_cork", 0.012, 0.03, (0, 0, 0.31), mat=M("OldWood"), verts=10),
                                        cylinder(f"{n}_bottom", 0.038, 0.006, (0, 0, 0.003), mat=glass, verts=20)],
        "SM_CookingPot_Iron_01": lambda n: [lathe(f"{n}_b", [(0.06, 0.1, 0.1, 0), (0.12, 0.2, 0.2, 0), (0.25, 0.21, 0.21, 0), (0.33, 0.17, 0.17, 0), (0.35, 0.18, 0.18, 0)], M("Iron"), 28, thickness=0.008),
                                            cylinder(f"{n}_bottom", 0.1, 0.01, (0, 0, 0.06), mat=M("Iron"), verts=20)] +
                                           [tube_along(f"{n}_leg{k}", [V((math.cos(k * 2.09) * 0.12, math.sin(k * 2.09) * 0.12, 0.1)), V((math.cos(k * 2.09) * 0.15, math.sin(k * 2.09) * 0.15, 0))], [0.015, 0.012], M("Iron"), sides=6) for k in range(3)] +
                                           [tube_along(f"{n}_bail", [V((0.18 * math.cos(a), 0, 0.33 + 0.25 * math.sin(a))) for a in [i * math.pi / 12 for i in range(13)]], [0.006] * 13, M("Iron"), sides=6)],
    }
    x = 0.0
    for n, fn in specs.items():
        remove_asset(n)
        obj = finish_asset(n, fn(n), PV, [], lods=False, smooth=50)
        obj.location = (x, 0, 0)
        x += 0.5
        out.append(obj)
    return out


def build_forge(name="SM_Forge_Smithy_01", seed=321):
    """Stone forge: coursed-stone hearth, iron-rimmed fire pit with coals, hooded chimney, leather bellows."""
    remove_asset(name); rnd = random.Random(seed); p = []
    W, D, H = 1.6, 1.2, 0.85
    local = []
    z = 0.0
    while z < H - 0.02:
        h = min(0.2, H - z)
        for side in range(4):
            L = W if side % 2 == 0 else D
            blocks = []
            _course_blocks(blocks, name, L, z, h, 0.0, 0.25, rnd, M("FoundationStone"), min_len=0.25, max_len=0.5)
            ang = side * math.pi / 2
            off = (D / 2 if side % 2 == 0 else W / 2) - 0.12
            for b in blocks:
                b.matrix_world = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation(V((0, -off, 0))) @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), V((1, 1, 1)))
            local.extend(blocks)
        z += h
    p.extend(local)
    p.append(box(f"{name}_top", (W + 0.06, D + 0.06, 0.08), (0, 0, H + 0.04), mat=M("CastleStone"), bevel=0.02, segs=2, jitter=0.01, seed=3))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=32, radius1=0.38, radius2=0.38, depth=0.08)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    rim = _obj_from_bm(f"{name}_rim", bm, M("RustedIron")); rim.location = (0, 0, H + 0.1)
    p.append(rim)
    coal_mat = mat_emissive("M_Coals_01", (1.0, 0.25, 0.04), 3.0, transmission=0.0)
    for i in range(45):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, 0.33)
        c = rock(f"{name}_coal", (0.035, 0.03, 0.025), seed=i, mat=coal_mat if rnd.random() < 0.35 else M("DarkWood"), subdiv=1)
        c.location = (math.cos(a) * r, math.sin(a) * r, H + 0.1 + rnd.uniform(0, 0.03))
        p.append(c)
    # Hood on 4 iron posts, tapering into a stone chimney.
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube_along(f"{name}_hpost", [V((sx * 0.6, sy * 0.45, H + 0.08)), V((sx * 0.6, sy * 0.45, 1.9))], [0.02, 0.02], M("Iron"), sides=6))
    hood = lathe(f"{name}_hood", [(1.9, 0.72, 0.56, 0), (2.4, 0.3, 0.25, 0)], M("RustedIron"), 4, thickness=0.01)
    hood.rotation_euler = (0, 0, math.pi / 4)
    p.append(hood)
    z = 2.4
    while z < 3.6:
        for dx, dy, sx_, sy_ in ((0, -0.2, 0.5, 0.12), (0, 0.2, 0.5, 0.12), (-0.2, 0, 0.12, 0.3), (0.2, 0, 0.12, 0.3)):
            p.append(box(f"{name}_chim", (sx_, sy_, 0.19), (dx, dy, z + 0.1), mat=M("FoundationStone"), bevel=0.012, segs=1, jitter=0.008, seed=rnd.randint(0, 999)))
        z += 0.2
    # Bellows: two wooden boards, pleated leather sides, iron nozzle into the hearth side.
    bx, bz = -W / 2 - 0.55, 0.75
    for zz, rot in ((bz, 0.0), (bz + 0.2, -0.12)):
        p.append(plank(f"{name}_bboard", (0.9, 0.5, 0.04), (bx, 0, zz), rot=(0, rot, 0), mat_key="OldWood", seed=int(zz * 100)))
    bel = lathe(f"{name}_pleat", [(0, 0.4, 0.22, 0), (0.05, 0.36, 0.2, 0), (0.1, 0.4, 0.22, 0), (0.15, 0.35, 0.19, 0), (0.18, 0.38, 0.2, 0)], M("Leather"), 24, thickness=0.006)
    bel.location = (bx, 0, bz + 0.01)
    p.append(bel)
    p.append(tube_along(f"{name}_nozzle", [V((bx + 0.45, 0, bz + 0.08)), V((-W / 2 + 0.05, 0, bz + 0.08))], [0.035, 0.025], M("Iron"), sides=10))
    p.append(tube_along(f"{name}_blever", [V((bx - 0.45, 0, bz + 0.25)), V((bx - 0.6, 0, bz + 1.0))], [0.025, 0.02], M("OldWood"), sides=8))
    obj = finish_asset(name, p, PV, [((W, D, H + 0.1), (0, 0, (H + 0.1) / 2)), ((0.6, 0.6, 1.2), (0, 0, 3.0)), ((0.9, 0.5, 0.3), (bx, 0, bz + 0.1))], lods=False)
    socket(obj, "FX_Fire", (0, 0, H + 0.15))
    return obj


def build_weapon_rack(name="SM_WeaponRack_01", seed=331):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        p.append(plank(f"{name}_side", (0.08, 0.35, 1.6), (sx * 0.7, 0, 0.8), mat_key="OldWood", seed=sx + 2, wear=0.006))
        p.append(plank(f"{name}_foot", (0.1, 0.6, 0.08), (sx * 0.7, 0, 0.04), mat_key="OldWood", seed=sx + 5))
    for z, y in ((0.35, 0.0), (1.35, 0.0)):
        p.append(plank(f"{name}_bar", (1.5, 0.08, 0.06), (0, y, z), mat_key="OldWood", seed=int(z * 10)))
        if z > 1:
            for i in range(6):
                p.append(box(f"{name}_notch", (0.035, 0.1, 0.04), (-0.55 + i * 0.22, 0, z + 0.04), mat=M("DarkWood"), bevel=0.004, segs=1))
    # Two spears and a sword leaning in the rack.
    for i in range(2):
        x = -0.55 + i * 0.22
        p.append(tube_along(f"{name}_spear{i}", [V((x, 0.05, 0.36)), V((x, 0.02, 2.0))], [0.016, 0.014], M("OldWood"), sides=8))
        tip = cylinder(f"{name}_tip{i}", 0.03, 0.22, (x, 0.02, 2.11), mat=M("Steel"), verts=4, radius_top=0.001)
        p.append(tip)
    blade = _blade(f"{name}_sword", 0.75, 0.05, 0.008, mat=M("Steel"))
    blade.location = (0.35, 0.02, 0.55)
    p.append(blade)
    p.append(box(f"{name}_guard", (0.18, 0.025, 0.025), (0.35, 0.02, 0.54), mat=M("Iron"), bevel=0.005, segs=2))
    p.append(tube_along(f"{name}_grip", [V((0.35, 0.02, 0.53)), V((0.35, 0.02, 0.36))], [0.014, 0.014], M("DarkLeather"), sides=8))
    return finish_asset(name, p, PV, [((1.5, 0.6, 1.6), (0, 0, 0.8))])


def build_signpost(name="SM_Signpost_01", seed=341):
    remove_asset(name); rnd = random.Random(seed); p = []
    p.append(tube_along(f"{name}_post", [V((0, 0, -0.3)), V((0.02, 0.01, 2.4))], [0.08, 0.07], M("OldWood"), sides=8, twist_noise=0.08, seed=seed))
    for i, (z, rz) in enumerate(((2.1, 0.3), (1.85, 2.6), (1.6, -0.9))):
        arm = plank(f"{name}_arm{i}", (0.8, 0.03, 0.18), (0.42, 0, 0), mat_key="Planks", seed=i + 3)
        # Pointed end for the arrow sign.
        arm.data.vertices.foreach_get
        tipv = [v for v in arm.data.vertices if v.co.x > 0.35]
        for v in tipv:
            v.co.z *= 0.4
        arm.rotation_euler = (0, 0, rz)
        arm.location = (0, 0, z)
        p.append(arm)
        p.append(cylinder(f"{name}_nail{i}", 0.008, 0.08, (0, 0, z), (math.pi / 2, 0, rz), M("Iron"), verts=6))
    return finish_asset(name, p, PV, [((0.2, 0.2, 2.6), (0, 0, 1.2))])


def build_sack(name="SM_Sack_Grain_01", seed=351):
    remove_asset(name); p = []
    s = rock(f"{name}_body", (0.3, 0.22, 0.35), seed=seed, mat=M("Straw"), subdiv=4, roughness=0.0, flatten=0.95)
    s.location = (0, 0, 0.3)
    p.append(s)
    p.append(tube_along(f"{name}_neck", [V((0, 0, 0.58)), V((0.01, 0, 0.72))], [0.08, 0.06], M("Straw"), sides=10, twist_noise=0.2, seed=seed))
    p.append(tube_along(f"{name}_tie", [V((0, 0, 0.62)), V((0, 0, 0.645))], [0.075, 0.075], M("Leather"), sides=10))
    return finish_asset(name, p, PV, [((0.6, 0.45, 0.7), (0, 0, 0.35))])


def build_bucket(name="SM_Bucket_Wood_01", seed=361):
    remove_asset(name); p = []
    _bucket(p, name, (0, 0, 0), random.Random(seed))
    return finish_asset(name, p, PV, [((0.32, 0.32, 0.32), (0, 0, 0.16))])


def build_shelf(name="SM_Shelf_Wall_01", seed=371):
    remove_asset(name); rnd = random.Random(seed); p = []
    for sx in (-1, 1):
        p.append(plank(f"{name}_side", (0.04, 0.35, 1.8), (sx * 0.6, 0, 0.9), mat_key="OldWood", seed=sx))
    for i in range(5):
        p.append(plank(f"{name}_board{i}", (1.24, 0.35, 0.03), (0, 0, 0.1 + i * 0.42), seed=i + 5))
    p.append(plank(f"{name}_back", (1.24, 0.02, 1.8), (0, 0.17, 0.9), seed=9))
    # Books with varied heights/leather colours, jars.
    book_mats = [M("DarkLeather"), M("Leather"), M("ClothMageTrim"), M("ClothMage")]
    for shelf in range(1, 4):
        x = -0.55
        while x < 0.3:
            w = rnd.uniform(0.03, 0.06); h = rnd.uniform(0.22, 0.32)
            b = box(f"{name}_book", (w, 0.2, h), (x + w / 2, 0.0, 0.115 + shelf * 0.42 + h / 2), rot=(0, rnd.uniform(-0.05, 0.05) if rnd.random() < 0.8 else 0.35, 0), mat=rnd.choice(book_mats), bevel=0.004, segs=2, jitter=0.002, seed=rnd.randint(0, 999))
            p.append(b)
            x += w + 0.004
        for j in range(2):
            jar = lathe(f"{name}_jar", [(0, 0.04, 0.04, 0), (0.1, 0.05, 0.05, 0), (0.13, 0.03, 0.03, 0), (0.15, 0.032, 0.032, 0)], bpy.data.materials.get("M_Clay_01") or M("Bone"), 16, thickness=0.004)
            jar.location = (0.38 + j * 0.13, 0, 0.115 + shelf * 0.42)
            p.append(jar)
    return finish_asset(name, p, PV, [((1.3, 0.36, 1.8), (0, 0, 0.9))])


def build_bed(name="SM_Bed_Straw_01", seed=381):
    remove_asset(name); rnd = random.Random(seed); p = []
    L, W = 2.0, 1.0
    for sx in (-1, 1):
        for sy, h in ((-1, 0.55), (1, 0.9)):
            p.append(plank(f"{name}_post", (0.09, 0.09, h), (sx * W / 2, sy * L / 2, h / 2), mat_key="OldWood", seed=rnd.randint(0, 999)))
        p.append(plank(f"{name}_rail", (0.06, L, 0.15), (sx * W / 2, 0, 0.3), mat_key="OldWood", seed=rnd.randint(0, 999)))
    for sy in (-1, 1):
        p.append(plank(f"{name}_end", (W, 0.05, 0.3 if sy < 0 else 0.55), (0, sy * L / 2, 0.35 if sy < 0 else 0.55), seed=rnd.randint(0, 999)))
    mattress = rock(f"{name}_mattress", (W / 2 - 0.03, L / 2 - 0.04, 0.09), seed=seed, mat=M("Straw"), subdiv=4, roughness=0.0, flatten=0.9)
    mattress.location = (0, 0, 0.46)
    p.append(mattress)
    blanket = lathe(f"{name}_blanket", [(-0.6, 0.53, 0.14, 0), (0.4, 0.53, 0.14, 0)], M("ClothRogue"), 24, fold_amp=0.05, fold_freq=6, open_front=math.pi, thickness=0.01, seed=seed)
    blanket.rotation_euler = (math.pi / 2, 0, 0)
    blanket.location = (0, -0.1, 0.5)
    p.append(blanket)
    pillow = rock(f"{name}_pillow", (0.3, 0.16, 0.07), seed=seed + 1, mat=M("Plaster"), subdiv=3, roughness=0.0, flatten=0.6)
    pillow.location = (0, L / 2 - 0.25, 0.6)
    p.append(pillow)
    return finish_asset(name, p, PV, [((W + 0.1, L + 0.1, 0.62), (0, 0, 0.31))])

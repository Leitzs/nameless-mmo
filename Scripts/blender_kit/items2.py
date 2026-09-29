"""Weapons (swords, daggers, axes, bows) and the remaining staffs. exec() after kitlib, items, props2 (_extrude_profile).
Swords/daggers/axes: origin at the grip centre, blade/head along +Z. Bows: origin at the grip, limbs along Z, string at -Y.
Staffs: origin at the foot, with FX_Core / FX_Tip / FX_Secondary sockets."""

V = Vector
IW, IS = "ITEM_Weapons", "ITEM_Staffs"


def weapon_materials():
    mat_metal("M_Bronze_Aged_01", (0.3, 0.2, 0.08), 0.5, rust=0.0)
    b = bpy.data.materials["M_Bronze_Aged_01"]
    mat_metal("M_BlackSteel_01", (0.05, 0.05, 0.055), 0.35)
    mat_emissive("M_Poison_Glow_01", (0.2, 0.9, 0.1), 2.5, transmission=0.3)
    mat_emissive("M_Fire_Glow_01", (1.0, 0.25, 0.02), 2.0, transmission=0.2)
    mat_emissive("M_Ice_Crystal_01", (0.3, 0.65, 1.0), 0.8, transmission=0.9)
    mat_emissive("M_Lightning_Glow_01", (0.25, 0.5, 1.0), 2.5, transmission=0.3)
    mat_emissive("M_Holy_Glow_01", (1.0, 0.7, 0.2), 1.8, transmission=0.3)
    mat_emissive("M_Void_Glow_01", (0.4, 0.05, 0.85), 2.0, transmission=0.3)
    mat_emissive("M_Nature_Glow_01", (0.3, 0.9, 0.3), 3.0, transmission=0.6)
    mat_wood("M_PaleWood_01", (0.42, 0.38, 0.3), (0.2, 0.18, 0.14), 3.0, stretch=(6, 6, 0.3))
    mat_stone("M_Volcanic_01", (0.06, 0.05, 0.045), (0.015, 0.012, 0.01), 3.0, rough=0.85)


def MM(n):
    return bpy.data.materials[n]


def _grip(parts, name, z0, z1, r, wrap_mat, wire=True):
    parts.append(cylinder(f"{name}_core", r * 0.9, z1 - z0, (0, 0, (z0 + z1) / 2), mat=M("DarkWood"), verts=10))
    _wrap(parts, f"{name}_wrap", z0, z1, r, wrap_mat, turns=int((z1 - z0) / 0.015), band=0.0045)
    if wire:
        _wrap(parts, f"{name}_wire", z0 + 0.005, z1 - 0.005, r + 0.0015, M("Iron"), turns=int((z1 - z0) / 0.015), band=0.0012)


def _pommel(parts, name, z, kind, mat, r=0.022):
    if kind == "disc":
        parts.append(cylinder(f"{name}_pommel", r * 1.3, r * 0.8, (0, 0, z), (math.pi / 2, 0, 0), mat, verts=18, bevel=0.003))
    elif kind == "wheel":
        parts.append(cylinder(f"{name}_pommel", r * 1.6, r * 1.0, (0, 0, z), (math.pi / 2, 0, 0), mat, verts=20, bevel=0.004))
        parts.append(cylinder(f"{name}_boss", r * 0.8, r * 1.3, (0, 0, z), (math.pi / 2, 0, 0), mat, verts=14, bevel=0.002))
    elif kind == "faceted":
        c = _crystal(f"{name}_pommel", r * 2.2, r, mat, 8, 3)
        c.location = (0, 0, z)
        parts.append(c)
    elif kind == "gem":
        parts.append(cylinder(f"{name}_pommelcup", r, r * 0.8, (0, 0, z), mat=mat, verts=12, bevel=0.003))
        g = _crystal(f"{name}_gem", r * 2.0, r * 0.8, MM("M_Void_Glow_01"), 6, 7)
        g.location = (0, 0, z - r * 1.2)
        parts.append(g)
    parts.append(cylinder(f"{name}_peen", r * 0.35, r * 0.4, (0, 0, z - r * (0.7 if kind != "gem" else 1.9)), mat=mat, verts=8))


def _crossguard(parts, name, z, width, style, mat):
    if style == "straight":
        parts.append(tube_along(f"{name}_guard", [V((-width / 2, 0, z)), V((width / 2, 0, z))], [0.009, 0.009], mat, sides=8))
        for sx in (-1, 1):
            parts.append(cylinder(f"{name}_qend", 0.012, 0.018, (sx * width / 2, 0, z), (0, math.pi / 2, 0), mat, verts=8, bevel=0.002))
    elif style == "swept":
        parts.append(tube_along(f"{name}_guard", [V((-width / 2, 0, z + 0.03)), V((-width / 4, 0, z + 0.005)), V((0, 0, z)), V((width / 4, 0, z + 0.005)), V((width / 2, 0, z + 0.03))], [0.006, 0.009, 0.011, 0.009, 0.006], mat, sides=8))
    elif style == "knight":
        parts.append(box(f"{name}_guard", (width, 0.022, 0.02), (0, 0, z), mat=mat, bevel=0.005, segs=2))
        for sx in (-1, 1):
            parts.append(tube_along(f"{name}_qcurl{sx}", [V((sx * width / 2, 0, z)), V((sx * (width / 2 + 0.02), 0, z - 0.02)), V((sx * (width / 2 + 0.01), 0, z - 0.04))], [0.01, 0.008, 0.005], mat, sides=8))
        parts.append(box(f"{name}_langet", (0.03, 0.026, 0.05), (0, 0, z + 0.03), mat=mat, bevel=0.005, segs=2))
    elif style == "wings":
        for sx in (-1, 1):
            parts.append(tube_along(f"{name}_wing{sx}", [V((0, 0, z)), V((sx * width * 0.3, 0, z + 0.02)), V((sx * width * 0.5, 0, z + 0.07)), V((sx * width * 0.45, 0, z + 0.11))], [0.012, 0.01, 0.006, 0.002], mat, sides=8))
        parts.append(cylinder(f"{name}_hub", 0.018, 0.03, (0, 0, z), (math.pi / 2, 0, 0), mat, verts=14))
    elif style == "disc":
        parts.append(cylinder(f"{name}_guard", width / 2, 0.012, (0, 0, z), mat=mat, verts=16, bevel=0.003))


def _runes_on_blade(parts, name, z0, z1, mat, rnd, side_y=0.0035):
    z = z0
    while z < z1:
        for sy in (-1, 1):
            parts.append(box(f"{name}_rune", (0.004, 0.0015, rnd.uniform(0.008, 0.018)), (rnd.uniform(-0.003, 0.003), sy * side_y, z), rot=(0, rnd.choice((0, 0.6, -0.6, 1.57)), 0), mat=mat, bevel=0, jitter=0))
        z += rnd.uniform(0.018, 0.03)


SWORDS = {
    # name: (blade_len, width, thick, curve, fuller, blade_mat, guard_style, guard_w, grip_len, grip_mat, pommel, pommel_mat, extras)
    "SM_Sword_Iron_01": (0.72, 0.048, 0.008, 0.0, True, "Iron", "straight", 0.17, 0.11, "Leather", "disc", "Iron", ()),
    "SM_Sword_Steel_01": (0.8, 0.045, 0.007, 0.0, True, "Steel", "swept", 0.2, 0.13, "DarkLeather", "faceted", "Steel", ()),
    "SM_Sword_Knight_01": (0.95, 0.05, 0.008, 0.0, True, "Steel", "knight", 0.26, 0.2, "DarkLeather", "wheel", "Iron", ("ricasso",)),
    "SM_Sword_Ancient_01": (0.62, 0.06, 0.009, 0.0, False, "M_Bronze_Aged_01", "disc", 0.09, 0.1, "Leather", "disc", "M_Bronze_Aged_01", ("leaf",)),
    "SM_Sword_Runic_01": (0.85, 0.05, 0.008, 0.0, True, "M_BlackSteel_01", "wings", 0.22, 0.15, "DarkLeather", "wheel", "M_BlackSteel_01", ("runes",)),
    "SM_Sword_Magic_01": (0.88, 0.046, 0.007, 0.012, True, "Steel", "wings", 0.24, 0.14, "ClothMage", "gem", "Gold", ("edge_glow",)),
}


def build_sword(name, spec, seed=0):
    remove_asset(name)
    rnd = random.Random(seed)
    L, W, T, curve, fuller, bmat, gstyle, gw, grip, gmat, pk, pmat, extras = spec
    bm_mat = MM(bmat) if bmat.startswith("M_") else M(bmat)
    pm_mat = MM(pmat) if pmat.startswith("M_") else M(pmat)
    gm_mat = MM(gmat) if gmat.startswith("M_") else M(gmat)
    parts = []
    base = grip / 2 + 0.02
    blade = _blade(f"{name}_blade", L, W, T, curve=curve, fuller=fuller, mat=bm_mat)
    if "leaf" in extras:
        for v in blade.data.vertices:
            t = v.co.z / L
            v.co.x *= 0.8 + 0.5 * math.sin(math.pi * min(1, t * 1.2))
    blade.location = (0, 0, base)
    dent(blade, 0.0015, seed=seed, count=6, radius=0.03)  # nicks along the edge
    parts.append(blade)
    if "ricasso" in extras:
        parts.append(box(f"{name}_ricasso", (W * 0.9, T * 1.1, 0.07), (0, 0, base + 0.035), mat=bm_mat, bevel=0.002, segs=1))
    if "runes" in extras:
        _runes_on_blade(parts, name, base + 0.08, base + L * 0.6, MM("M_Rune_Glow_01") if "M_Rune_Glow_01" in bpy.data.materials else MM("M_Lightning_Glow_01"), rnd)
    if "edge_glow" in extras:
        glow = _blade(f"{name}_glow", L * 0.94, W * 0.35, T * 1.2, curve=curve, fuller=False, mat=MM("M_Void_Glow_01"))
        glow.location = (0, 0, base + 0.02)
        parts.append(glow)
    _crossguard(parts, name, base - 0.005, gw, gstyle, pm_mat if gstyle != "straight" else M("Iron"))
    _grip(parts, name, -grip / 2, grip / 2, 0.014, gm_mat)
    _pommel(parts, name, -grip / 2 - 0.02, pk, pm_mat)
    obj = finish_asset(name, parts, IW, [((W + 0.01, 0.02, L), (0, 0, base + L / 2)), ((gw, 0.04, grip + 0.06), (0, 0, 0))], origin=None, smooth=30)
    socket(obj, "Grip", (0, 0, 0))
    socket(obj, "FX_Tip", (0, 0, base + L))
    socket(obj, "FX_Trail_Base", (0, 0, base + 0.05))
    return obj


DAGGERS = {
    "SM_Dagger_Simple_01": (0.2, 0.03, 0.006, 0.0, "Iron", "straight", 0.08, "Leather", "disc", ()),
    "SM_Dagger_Curved_01": (0.22, 0.034, 0.006, 0.07, "Steel", "swept", 0.09, "DarkLeather", "faceted", ()),
    "SM_Dagger_Poison_01": (0.21, 0.03, 0.006, 0.0, "M_BlackSteel_01", "swept", 0.08, "DarkLeather", "disc", ("poison",)),
    "SM_Dagger_Assassin_01": (0.26, 0.018, 0.007, 0.0, "M_BlackSteel_01", "disc", 0.05, "DarkLeather", "faceted", ("stiletto",)),
    "SM_Dagger_Ceremonial_01": (0.23, 0.036, 0.006, 0.02, "Steel", "wings", 0.12, "ClothMageTrim", "gem", ("gold",)),
}


def build_dagger(name, spec, seed=0):
    remove_asset(name)
    rnd = random.Random(seed)
    L, W, T, curve, bmat, gstyle, gw, gmat, pk, extras = spec
    bm_mat = MM(bmat) if bmat.startswith("M_") else M(bmat)
    fit = M("Gold") if "gold" in extras else M("Iron")
    parts = []
    base = 0.06
    blade = _blade(f"{name}_blade", L, W, T, curve=curve, fuller=not ("stiletto" in extras), mat=bm_mat)
    if "stiletto" in extras:
        for v in blade.data.vertices:
            v.co.x *= 0.7
    blade.location = (0, 0, base)
    parts.append(blade)
    if "poison" in extras:
        groove = _blade(f"{name}_groove", L * 0.7, W * 0.25, T * 1.15, curve=curve, fuller=False, mat=MM("M_Poison_Glow_01"))
        groove.location = (0, 0, base + 0.01)
        parts.append(groove)
        for i in range(3):
            d = rock(f"{name}_drip{i}", (0.003, 0.003, 0.006), seed=i, mat=MM("M_Poison_Glow_01"), subdiv=1)
            d.location = (rnd.uniform(-0.01, 0.01), 0, base + L * rnd.uniform(0.3, 0.8))
            parts.append(d)
    _crossguard(parts, name, base - 0.005, gw, gstyle, fit)
    _grip(parts, name, -0.045, 0.045, 0.012, M(gmat) if not gmat.startswith("M_") else MM(gmat))
    _pommel(parts, name, -0.06, pk, fit, r=0.016)
    obj = finish_asset(name, parts, IW, [((W + 0.01, 0.02, L), (0, 0, base + L / 2)), ((gw, 0.03, 0.12), (0, 0, 0))], origin=None, smooth=30)
    socket(obj, "Grip", (0, 0, 0))
    socket(obj, "FX_Tip", (0, 0, base + L))
    return obj


def _axe_head(name, sil, width, mat, edge_x):
    """Axe head from an XZ silhouette, thinned to a sharp bit toward edge_x (sign gives the side)."""
    h = _extrude_profile(name, sil, width, mat, bevel=0.004)
    for v in h.data.vertices:
        t = (v.co.x - 0.0) / edge_x if edge_x else 0
        if t > 0.35:
            v.co.y *= max(0.08, 1 - (t - 0.35) * 1.4)
    return h


def build_axe(name, kind, seed=0):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    if kind == "wood":
        haft = 0.75; top = haft * 0.62
        parts.append(tube_along(f"{name}_haft", [V((0, 0, -haft * 0.38)), V((0.01, 0, 0)), V((0, 0, top))], [0.017, 0.015, 0.018], M("OldWood"), sides=10))
        sil = [(-0.03, -0.04), (0.06, -0.035), (0.13, -0.07), (0.14, 0.06), (0.06, 0.03), (-0.03, 0.04), (-0.05, 0.02), (-0.05, -0.02)]
        head = _axe_head(f"{name}_head", [(x, z + top - 0.03) for x, z in sil], 0.035, M("Iron"), 0.14)
        parts.append(head)
        parts.append(cylinder(f"{name}_wedge", 0.006, 0.02, (0, 0, top + 0.02), mat=M("DarkWood"), verts=6))
    elif kind == "battle":
        haft = 0.9; top = haft * 0.6
        parts.append(tube_along(f"{name}_haft", [V((0, 0, -haft * 0.4)), V((0, 0, top + 0.05))], [0.017, 0.016], M("DarkWood"), sides=10))
        _wrap(parts, f"{name}_wrap", -0.3, -0.05, 0.018, M("DarkLeather"), turns=16, band=0.0045)
        sil = [(-0.03, -0.05), (0.06, -0.05), (0.1, -0.2), (0.2, -0.16), (0.22, 0.02), (0.19, 0.1), (0.07, 0.04), (-0.03, 0.05), (-0.09, 0.02), (-0.11, 0.0), (-0.09, -0.02)]
        parts.append(_axe_head(f"{name}_head", [(x, z + top - 0.03) for x, z in sil], 0.04, M("Steel"), 0.22))
        for z in (top - 0.07, top + 0.03):
            parts.append(tube_along(f"{name}_ring{z}", [V((0, 0, z - 0.008)), V((0, 0, z + 0.008))], [0.02, 0.02], M("Iron"), sides=10))
    elif kind == "twohanded":
        haft = 1.45; top = haft * 0.72
        parts.append(tube_along(f"{name}_haft", [V((0, 0, -haft * 0.28)), V((0, 0, top + 0.1))], [0.02, 0.019], M("DarkWood"), sides=12))
        for z0, z1 in ((-0.35, -0.05), (0.2, 0.45)):
            _wrap(parts, f"{name}_wrap{z0}", z0, z1, 0.021, M("DarkLeather"), turns=18, band=0.005)
        for sx in (-1, 1):
            sil = [(0.0, -0.06), (0.08, -0.07), (0.16, -0.18), (0.26, -0.12), (0.28, 0.0), (0.26, 0.12), (0.16, 0.18), (0.08, 0.07), (0.0, 0.06)]
            h = _axe_head(f"{name}_bit{sx}", [(sx * x, z + top) for x, z in sil], 0.045, M("Steel"), 0.28 * sx)
            parts.append(h)
        parts.append(cylinder(f"{name}_spike", 0.02, 0.14, (0, 0, top + 0.16), mat=M("Steel"), verts=4, radius_top=0.001))
        parts.append(cylinder(f"{name}_butt", 0.024, 0.05, (0, 0, -haft * 0.28), mat=M("Iron"), verts=10, radius_top=0.02))
    elif kind == "ancient":
        haft = 0.7; top = haft * 0.6
        parts.append(tube_along(f"{name}_haft", [V((0, 0, -haft * 0.4)), V((0.02, 0, 0)), V((0, 0, top + 0.08))], [0.02, 0.018, 0.022], M("OldWood"), sides=8, twist_noise=0.15, seed=seed))
        stone = rock(f"{name}_stonehead", (0.1, 0.03, 0.07), seed=seed, mat=MM("M_Volcanic_01"), subdiv=3, roughness=0.6, flatten=0.0)
        for v in stone.data.vertices:
            if v.co.x > 0.02:
                v.co.y *= 0.35
        stone.location = (0.06, 0, top)
        parts.append(stone)
        for i in range(6):
            a = i * 0.9
            parts.append(tube_along(f"{name}_lash{i}", [V((-0.025, -0.025, top - 0.05 + i * 0.018)), V((0.03, 0.025, top - 0.04 + i * 0.018))], [0.004, 0.004], M("Leather"), sides=4))
        for k in range(3):
            f = rock(f"{name}_feather{k}", (0.012, 0.004, 0.06), seed=k, mat=M("Bone"), subdiv=1)
            f.location = (-0.03, 0.0, top - 0.1 - k * 0.02)
            f.rotation_euler = (0, 0.4 + k * 0.2, 0)
            parts.append(f)
    obj = finish_asset(name, parts, IW, [], origin=None, smooth=30)
    socket(obj, "Grip", (0, 0, 0))
    return obj


def build_bow(name, kind, seed=0):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    specs = {"hunting": (1.2, 0.12, M("OldWood"), 0.0), "long": (1.8, 0.14, M("OldWood"), 0.0), "rogue": (1.1, 0.1, M("DarkWood"), 0.08), "dark": (1.35, 0.14, M("M_BlackSteel_01") if False else M("DarkWood"), 0.12)}
    L, draw, wood, recurve = specs[kind]
    half = L / 2
    n = 12
    for sgn in (-1, 1):
        pts, radii = [], []
        for i in range(n + 1):
            t = i / n
            z = sgn * (0.06 + (half - 0.06) * t)
            y = draw * t * t
            if recurve and t > 0.8:
                y -= recurve * (t - 0.8) / 0.2 * 1.5
            pts.append(V((0, y, z)))
            radii.append(0.017 * (1 - 0.6 * t) + 0.004)
        parts.append(tube_along(f"{name}_limb{sgn}", pts, radii, wood, sides=8))
        tip = pts[-1]
        parts.append(cylinder(f"{name}_nock{sgn}", 0.008, 0.03, tip, mat=M("Bone") if kind != "dark" else M("Iron"), verts=8))
        if kind == "dark":
            for k in range(3):
                t = 0.35 + k * 0.2
                z = sgn * (0.06 + (half - 0.06) * t)
                y = draw * t * t
                parts.append(cylinder(f"{name}_barb{sgn}{k}", 0.012, 0.07, (0, y - 0.035, z), (math.pi / 2, 0, 0), M("Bone"), verts=4, radius_top=0.001))
    # Riser grip, arrow shelf, string.
    parts.append(tube_along(f"{name}_riser", [V((0, 0, -0.08)), V((0, -0.005, 0)), V((0, 0, 0.08))], [0.02, 0.022, 0.02], M("DarkWood") if kind != "hunting" else wood, sides=10))
    _wrap(parts, f"{name}_grip", -0.06, 0.06, 0.023, M("Leather") if kind != "dark" else M("DarkLeather"), turns=10, band=0.005)
    parts.append(box(f"{name}_shelf", (0.012, 0.03, 0.015), (0.01, -0.015, 0.07), mat=M("Leather"), bevel=0.003, segs=1))
    top = V((0, draw - (recurve * 1.5 if recurve else 0), half))
    bot = V((0, draw - (recurve * 1.5 if recurve else 0), -half))
    parts.append(tube_along(f"{name}_string", [top, bot], [0.0015, 0.0015], M("Straw"), sides=4))
    if kind == "dark":
        sk = _skull(f"{name}_skull", 0.25, seed)
        sk.location = (0, -0.02, 0.0)
        sk.rotation_euler = (0, 0, math.pi)
        parts.append(sk)
    obj = finish_asset(name, parts, IW, [], origin=None, smooth=30)
    socket(obj, "Grip", (0, 0, 0))
    socket(obj, "Arrow_Nock", (0, draw, 0))
    return obj


def _shaft(parts, name, H, mat, r=0.021, wob=0.006, seed=0, sides=10):
    pts = [V((math.sin(t * 7 + seed) * wob, math.cos(t * 5 + seed) * wob, t * H)) for t in [i / 20 for i in range(21)]]
    parts.append(tube_along(f"{name}_shaft", pts, [r * (1.0 + 0.1 * math.sin(i)) for i in range(21)], mat, sides=sides, twist_noise=0.06, seed=seed))


def build_staff(name, kind, seed=0):
    """Six more staffs, each with a distinct silhouette. Sockets: FX_Core (focus), FX_Tip (top), FX_Secondary."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    H = 1.55
    core = tip = sec = V((0, 0, H + 0.2))
    if kind == "fire":
        _shaft(parts, name, H, M("DarkWood"), seed=seed)
        # Charred cracks glowing with embers.
        for i in range(10):
            z = rnd.uniform(0.9, H)
            parts.append(box(f"{name}_ember", (0.004, 0.002, rnd.uniform(0.03, 0.08)), (0.021 * math.cos(i), 0.021 * math.sin(i), z), rot=(0, 0, i), mat=MM("M_Fire_Glow_01"), bevel=0, jitter=0))
        # Volcanic rock claws cradling a fire crystal; iron band.
        for k in range(4):
            a = 2 * math.pi * k / 4 + 0.3
            d = V((math.cos(a), math.sin(a), 0))
            r = rock(f"{name}_claw{k}", (0.03, 0.03, 0.12), seed=seed + k, mat=MM("M_Volcanic_01"), subdiv=2, roughness=0.6, flatten=0.0)
            r.location = V((0, 0, H + 0.1)) + d * 0.06
            r.rotation_euler = (-d.y * 0.5, d.x * 0.5, 0)
            parts.append(r)
        cr = _crystal(f"{name}_crystal", 0.16, 0.035, MM("M_Fire_Glow_01"), 6, seed)
        cr.location = (0, 0, H + 0.17)
        parts.append(cr)
        parts.append(tube_along(f"{name}_band", [V((0, 0, H - 0.02)), V((0, 0, H + 0.02))], [0.03, 0.03], M("Iron"), sides=12))
        core, tip, sec = V((0, 0, H + 0.17)), V((0, 0, H + 0.3)), V((0, 0, 1.2))
    elif kind == "ice":
        _shaft(parts, name, H, MM("M_PaleWood_01"), r=0.019, wob=0.002, seed=seed)
        for i in range(9):
            a = rnd.uniform(0, 2 * math.pi)
            c = _crystal(f"{name}_shard{i}", rnd.uniform(0.08, 0.2), rnd.uniform(0.01, 0.022), MM("M_Ice_Crystal_01"), 5, seed + i)
            c.location = (math.cos(a) * 0.03, math.sin(a) * 0.03, H + rnd.uniform(0.0, 0.1))
            c.rotation_euler = (math.sin(a) * 0.6, -math.cos(a) * 0.6, a)
            parts.append(c)
        main = _crystal(f"{name}_main", 0.3, 0.035, MM("M_Ice_Crystal_01"), 6, seed + 30)
        main.location = (0, 0, H + 0.2)
        parts.append(main)
        for z in (0.4, 0.8, 1.2):
            f = _crystal(f"{name}_frost{z}", 0.05, 0.025, MM("M_Ice_Crystal_01"), 6, int(z * 10))
            f.location = (0, 0, z)
            parts.append(f)
        core, tip, sec = V((0, 0, H + 0.2)), V((0, 0, H + 0.36)), V((0, 0, 0.8))
    elif kind == "lightning":
        _shaft(parts, name, H, M("DarkWood"), seed=seed)
        for z in (0.5, 1.0, H - 0.05):
            parts.append(tube_along(f"{name}_coil{z}", [V((0.025 * math.cos(a), 0.025 * math.sin(a), z + a * 0.004)) for a in [i * 0.4 for i in range(40)]], [0.003] * 40, M("Gold"), sides=4))
        # Forked copper tines (like a tuning fork) with a charged orb between them.
        for sx in (-1, 1):
            parts.append(tube_along(f"{name}_tine{sx}", [V((0, 0, H)), V((sx * 0.05, 0, H + 0.08)), V((sx * 0.07, 0, H + 0.2)), V((sx * 0.05, 0, H + 0.32)), V((sx * 0.02, 0, H + 0.36))], [0.012, 0.01, 0.008, 0.006, 0.003], M("Gold"), sides=8))
        orb = rock(f"{name}_orb", (0.035, 0.035, 0.035), seed=seed, mat=MM("M_Lightning_Glow_01"), subdiv=3, roughness=0.0, flatten=0.0)
        orb.location = (0, 0, H + 0.2)
        parts.append(orb)
        zig = [V((0, 0, H + 0.02)), V((0.015, 0, H + 0.06)), V((-0.01, 0, H + 0.1)), V((0.012, 0, H + 0.15))]
        parts.append(tube_along(f"{name}_arc", zig, [0.003] * 4, MM("M_Lightning_Glow_01"), sides=4))
        core, tip, sec = V((0, 0, H + 0.2)), V((0, 0, H + 0.38)), V((0.07, 0, H + 0.2))
    elif kind == "nature":
        # Living branch: twisted shaft that splits into roots cradling a green crystal, with leaves and vines.
        _shaft(parts, name, H, M("Bark"), r=0.023, wob=0.015, seed=seed)
        for k in range(5):
            a = 2 * math.pi * k / 5
            d = V((math.cos(a), math.sin(a), 0))
            pts = [V((0, 0, H - 0.05)), V((0, 0, H + 0.05)) + d * 0.05, V((0, 0, H + 0.18)) + d * 0.07, V((0, 0, H + 0.3)) + d * 0.02]
            parts.append(tube_along(f"{name}_root{k}", pts, [0.012, 0.01, 0.007, 0.003], M("Bark"), sides=6, twist_noise=0.2, seed=k))
        cr = _crystal(f"{name}_crystal", 0.14, 0.035, MM("M_Nature_Glow_01"), 7, seed)
        cr.location = (0, 0, H + 0.17)
        parts.append(cr)
        vine = [V((0.026 * math.cos(t * 1.3), 0.026 * math.sin(t * 1.3), 0.6 + t * 0.07)) for t in range(14)]
        parts.append(tube_along(f"{name}_vine", vine, [0.004] * 14, MM("M_Ivy_01") if "M_Ivy_01" in bpy.data.materials else M("OakLeaves"), sides=4))
        bm = bmesh.new()
        for p in vine[::2]:
            c = p * 1.3
            c.z = p.z
            vs = [bm.verts.new(c), bm.verts.new(c + V((0.02, 0.01, 0.02))), bm.verts.new(c + V((0.0, 0.0, 0.05))), bm.verts.new(c + V((-0.02, 0.01, 0.02)))]
            bm.faces.new((vs[0], vs[1], vs[2])); bm.faces.new((vs[0], vs[2], vs[3]))
        parts.append(_obj_from_bm(f"{name}_leaves", bm, M("OakLeaves")))
        core, tip, sec = V((0, 0, H + 0.17)), V((0, 0, H + 0.32)), V((0, 0, 1.0))
    elif kind == "holy":
        _shaft(parts, name, H, MM("M_PaleWood_01"), r=0.019, wob=0.001, seed=seed)
        for z in (0.3, 0.8, 1.3, H):
            parts.append(tube_along(f"{name}_collar{z}", [V((0, 0, z - 0.015)), V((0, 0, z + 0.015))], [0.026, 0.026], M("Gold"), sides=14))
        # Gilded sun-ring halo with rays around a radiant gem; small cross finial.
        ring = [V((0.11 * math.cos(a), 0, H + 0.2 + 0.11 * math.sin(a))) for a in [2 * math.pi * i / 40 for i in range(41)]]
        parts.append(tube_along(f"{name}_halo", ring, [0.008] * 41, M("Gold"), sides=6, cap=False))
        for k in range(12):
            a = 2 * math.pi * k / 12
            parts.append(cylinder(f"{name}_ray{k}", 0.008, 0.06 if k % 2 else 0.1, (0.15 * math.cos(a), 0, H + 0.2 + 0.15 * math.sin(a)), (0, -a + math.pi / 2, 0), M("Gold"), verts=4, radius_top=0.001))
        parts.append(tube_along(f"{name}_neck", [V((0, 0, H)), V((0, 0, H + 0.09))], [0.02, 0.012], M("Gold"), sides=10))
        gem = _crystal(f"{name}_gem", 0.09, 0.03, MM("M_Holy_Glow_01"), 8, seed)
        gem.location = (0, 0, H + 0.2)
        parts.append(gem)
        parts.append(box(f"{name}_crossv", (0.012, 0.012, 0.09), (0, 0, H + 0.38), mat=M("Gold"), bevel=0.002, segs=1))
        parts.append(box(f"{name}_crossh", (0.06, 0.012, 0.012), (0, 0, H + 0.395), mat=M("Gold"), bevel=0.002, segs=1))
        core, tip, sec = V((0, 0, H + 0.2)), V((0, 0, H + 0.43)), V((0, 0, H + 0.2))
    elif kind == "void":
        _shaft(parts, name, H, MM("M_BlackSteel_01"), r=0.018, wob=0.0, seed=seed, sides=6)
        # Broken obsidian ring segments orbiting an unstable void sphere, crescent blades.
        for k in range(5):
            a0 = 2 * math.pi * k / 5
            seg = _arc_block(f"{name}_ringseg{k}", 0.12, 0.14, a0, a0 + 0.9, -0.012, 0.012, MM("M_BlackSteel_01"), 0.003, k, segs=6)
            seg.rotation_euler = (math.pi / 2, 0, 0)
            seg.location = (0, 0, H + 0.22)
            parts.append(seg)
        orb = rock(f"{name}_voidcore", (0.045, 0.045, 0.045), seed=seed, mat=MM("M_Void_Glow_01"), subdiv=3, roughness=0.3, flatten=0.0)
        orb.location = (0, 0, H + 0.22)
        parts.append(orb)
        for sx in (-1, 1):
            parts.append(tube_along(f"{name}_crescent{sx}", [V((0, 0, H - 0.02)), V((sx * 0.08, 0, H + 0.05)), V((sx * 0.1, 0, H + 0.18)), V((sx * 0.05, 0, H + 0.4))], [0.012, 0.01, 0.006, 0.001], MM("M_BlackSteel_01"), sides=4))
        for i in range(4):
            s = _crystal(f"{name}_shard{i}", 0.04, 0.01, MM("M_Void_Glow_01"), 4, i)
            a = 2 * math.pi * i / 4
            s.location = (0.19 * math.cos(a), 0.05 * math.sin(a), H + 0.22 + 0.19 * math.sin(a))
            parts.append(s)
        core, tip, sec = V((0, 0, H + 0.22)), V((0, 0, H + 0.42)), V((0.19, 0, H + 0.22))
    parts.append(cylinder(f"{name}_ferrule", 0.022, 0.08, (0, 0, 0.04), mat=M("Iron"), verts=12, radius_top=0.02))
    staff_detail_pass(parts, name, kind, H, rnd)
    obj = finish_asset(name, parts, IS, [((0.06, 0.06, H), (0, 0, H / 2)), ((0.3, 0.3, 0.45), (0, 0, H + 0.2))], smooth=40)
    socket(obj, "FX_Core", core)
    socket(obj, "FX_Tip", tip)
    socket(obj, "FX_Secondary", sec)
    return obj


def build_weapons_batch():
    weapon_materials()
    if "M_Rune_Glow_01" not in bpy.data.materials:
        mat_emissive("M_Rune_Glow_01", (0.2, 0.55, 1.0), 4.0, transmission=0.0)
    out = []
    x = 60.0
    for i, (n, spec) in enumerate(SWORDS.items()):
        o = build_sword(n, spec, seed=1000 + i); o.location = (x, 0, 1.2); o.rotation_euler = (0, 0, 0); out.append((n, tris(o))); x += 0.45
    for i, (n, spec) in enumerate(DAGGERS.items()):
        o = build_dagger(n, spec, seed=1100 + i); o.location = (x, 0, 1.0); out.append((n, tris(o))); x += 0.35
    for i, (n, kind) in enumerate((("SM_Axe_Wood_01", "wood"), ("SM_Axe_Battle_01", "battle"), ("SM_Axe_TwoHanded_01", "twohanded"), ("SM_Axe_Ancient_01", "ancient"))):
        o = build_axe(n, kind, seed=1200 + i); o.location = (x, 0, 1.0); out.append((n, tris(o))); x += 0.6
    for i, (n, kind) in enumerate((("SM_Bow_Hunting_01", "hunting"), ("SM_Bow_Long_01", "long"), ("SM_Bow_Rogue_01", "rogue"), ("SM_Bow_DarkFantasy_01", "dark"))):
        o = build_bow(n, kind, seed=1300 + i); o.location = (x, 0, 1.0); out.append((n, tris(o))); x += 0.5
    x += 0.5
    for i, (n, kind) in enumerate((("SM_Staff_Fire_01", "fire"), ("SM_Staff_Ice_01", "ice"), ("SM_Staff_Lightning_01", "lightning"), ("SM_Staff_Nature_01", "nature"), ("SM_Staff_Holy_01", "holy"), ("SM_Staff_Void_01", "void"))):
        o = build_staff(n, kind, seed=1400 + i); o.location = (x, 0, 0); out.append((n, tris(o))); x += 0.6
    return out


STAFF_THEME = {  # accent metal, glow material, charm style
    "fire": ("Iron", "M_Fire_Glow_01"), "ice": ("Steel", "M_Ice_Crystal_01"), "lightning": ("Gold", "M_Lightning_Glow_01"),
    "nature": ("Bark", "M_Nature_Glow_01"), "holy": ("Gold", "M_Holy_Glow_01"), "void": ("M_BlackSteel_01", "M_Void_Glow_01"),
}


def staff_detail_pass(parts, name, kind, H, rnd):
    """Shared high-detail dressing for staffs: bound leather grip, engraved collars with glowing rune band,
    a hanging charm on a thong, and theme-specific flourishes."""
    metal_key, glow_key = STAFF_THEME[kind]
    metal = MM(metal_key) if metal_key.startswith("M_") else M(metal_key)
    glow = MM(glow_key)
    _wrap(parts, f"{name}_grip", 0.85, 1.1, 0.023, M("DarkLeather") if kind != "holy" else M("Leather"), turns=13, band=0.0075)
    for z in (0.83, 1.12):
        parts.append(tube_along(f"{name}_gripring{z}", [V((0, 0, z - 0.01)), V((0, 0, z + 0.01))], [0.027, 0.027], metal, sides=14))
    for z in (0.35, H - 0.12):
        parts.append(tube_along(f"{name}_collar{z}", [V((0, 0, z - 0.025)), V((0, 0, z)), V((0, 0, z + 0.025))], [0.026, 0.029, 0.026], metal, sides=16))
        for k in range(10):
            a = 2 * math.pi * k / 10
            parts.append(box(f"{name}_rn{z}{k}", (0.005, 0.002, 0.012 if k % 3 else 0.02), (math.cos(a) * 0.0295, math.sin(a) * 0.0295, z), rot=(0, 0, a + math.pi / 2), mat=glow, bevel=0, jitter=0))
    # Charm: thong from the upper collar, knot, bead and a tiny crystal / token.
    top = V((0.028, 0, H - 0.12))
    end = top + V((0.035, -0.01, -0.16))
    parts.append(tube_along(f"{name}_thong", [top, (top + end) / 2 + V((0.01, 0, -0.01)), end], [0.0025] * 3, M("Leather"), sides=4))
    parts.append(cylinder(f"{name}_bead", 0.008, 0.012, end + V((0, 0, 0.02)), mat=M("Bone"), verts=8))
    c = _crystal(f"{name}_charm", 0.035, 0.009, glow, 5, rnd.randint(0, 99))
    c.location = end - V((0, 0, 0.015))
    parts.append(c)
    if kind == "fire":
        for i in range(3):
            z = H + 0.03 + i * 0.05
            parts.append(tube_along(f"{name}_cage{i}", [V((0.075 * math.cos(a), 0.075 * math.sin(a), z)) for a in [2 * math.pi * k / 20 for k in range(21)]], [0.004] * 21, M("RustedIron"), sides=4, cap=False))
        for i in range(12):
            e = rock(f"{name}_ember{i}", (0.008, 0.008, 0.008), seed=i, mat=glow, subdiv=1)
            a = rnd.uniform(0, 2 * math.pi)
            e.location = (math.cos(a) * rnd.uniform(0.04, 0.09), math.sin(a) * rnd.uniform(0.04, 0.09), H + rnd.uniform(0.25, 0.45))
            parts.append(e)
    elif kind == "ice":
        for i in range(14):
            z = rnd.uniform(H - 0.35, H - 0.05)
            a = rnd.uniform(0, 2 * math.pi)
            s = _crystal(f"{name}_rime{i}", rnd.uniform(0.02, 0.05), 0.006, glow, 4, i)
            s.location = (math.cos(a) * 0.024, math.sin(a) * 0.024, z)
            s.rotation_euler = (math.sin(a) * 1.0, -math.cos(a) * 1.0, 0)
            parts.append(s)
        fil = [V((0.03 * math.cos(t * 0.9), 0.03 * math.sin(t * 0.9), H - 0.4 + t * 0.012)) for t in range(28)]
        parts.append(tube_along(f"{name}_filigree", fil, [0.0025] * 28, M("Steel"), sides=4))
    elif kind == "lightning":
        for i in range(3):
            o = rock(f"{name}_mini{i}", (0.012, 0.012, 0.012), seed=i, mat=glow, subdiv=2)
            a = 2 * math.pi * i / 3
            o.location = (math.cos(a) * 0.1, math.sin(a) * 0.1, H + 0.2 + 0.03 * math.sin(a * 2))
            parts.append(o)
        for sx in (-1, 1):
            parts.append(box(f"{name}_plate{sx}", (0.03, 0.006, 0.07), (sx * 0.028, 0, H - 0.25), mat=M("Gold"), bevel=0.002, segs=1))
            parts.append(box(f"{name}_plrune{sx}", (0.004, 0.002, 0.05), (sx * 0.0315, 0, H - 0.25), mat=glow, bevel=0, jitter=0))
    elif kind == "nature":
        for i in range(8):
            m = rock(f"{name}_moss{i}", (0.02, 0.015, 0.006), seed=i, mat=M("MossRock"), subdiv=1)
            a = rnd.uniform(0, 2 * math.pi)
            m.location = (math.cos(a) * 0.024, math.sin(a) * 0.024, rnd.uniform(H - 0.4, H))
            parts.append(m)
        for i in range(4):
            a = 2 * math.pi * i / 4 + 0.4
            base = V((math.cos(a) * 0.05, math.sin(a) * 0.05, H + 0.12))
            for k in range(5):
                pa = 2 * math.pi * k / 5
                parts.append(box(f"{name}_petal{i}{k}", (0.012, 0.003, 0.018), base + V((math.cos(pa) * 0.01, math.sin(pa) * 0.01, 0.005)), rot=(0.6, 0, pa), mat=bpy.data.materials.get("M_Flower_White_01") or M("Bone"), bevel=0, jitter=0))
    elif kind == "holy":
        for sx in (-1, 1):
            for k in range(5):
                parts.append(box(f"{name}_feather{sx}{k}", (0.012, 0.004, 0.09 - k * 0.012), (sx * (0.05 + k * 0.018), 0, H + 0.02 + k * 0.012), rot=(0, sx * (0.9 + k * 0.12), 0), mat=M("Gold"), bevel=0.001, segs=1))
        beads = [V((0.03 + 0.02 * math.sin(t * 0.5), 0.0, H - 0.1 - t * 0.02)) for t in range(12)]
        for b in beads[::2]:
            parts.append(rock(f"{name}_prayerbead", (0.006, 0.006, 0.006), seed=int(b.z * 100), mat=M("DarkWood"), subdiv=1))
            parts[-1].location = b
    elif kind == "void":
        ring = [V((0.2 * math.cos(a), 0.02 * math.sin(a * 3), H + 0.22 + 0.2 * math.sin(a))) for a in [2 * math.pi * i / 60 for i in range(61)]]
        parts.append(tube_along(f"{name}_runering", ring, [0.0025] * 61, glow, sides=4, cap=False))
        for i in range(6):
            s = rock(f"{name}_obsidian{i}", (0.015, 0.01, 0.025), seed=i, mat=MM("M_BlackSteel_01"), subdiv=1, roughness=0.6)
            a = rnd.uniform(0, 2 * math.pi)
            s.location = (math.cos(a) * 0.25, rnd.uniform(-0.05, 0.05), H + 0.22 + math.sin(a) * 0.25)
            parts.append(s)

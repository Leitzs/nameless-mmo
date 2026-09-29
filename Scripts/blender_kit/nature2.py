"""Nature batch 2: tree variations (oak/dead/pine/small/fallen/stump), vegetation (bushes, ferns, grass, weeds,
flowers, mushrooms, roots, ivy, moss), rocks (small/medium/large, boulders, cliff, formation, cave rock).
exec() after kitlib, castle, items, armor, nature."""

V = Vector
NC = "ENV_Nature"


def nature_materials():
    mat_foliage("M_Leaves_Pine_01", (0.02, 0.04, 0.02), (0.035, 0.055, 0.025))
    mat_foliage("M_Grass_01", (0.04, 0.07, 0.015), (0.09, 0.11, 0.03))
    mat_foliage("M_Grass_Dead_01", (0.16, 0.12, 0.05), (0.24, 0.19, 0.09))
    mat_foliage("M_Fern_01", (0.025, 0.06, 0.015), (0.05, 0.09, 0.02))
    mat_foliage("M_Leaves_Bush_01", (0.03, 0.05, 0.015), (0.06, 0.07, 0.02))
    mat_foliage("M_Ivy_01", (0.02, 0.045, 0.012), (0.04, 0.07, 0.02))
    mat_foliage("M_Flower_Red_01", (0.35, 0.03, 0.03), (0.5, 0.06, 0.05))
    mat_foliage("M_Flower_White_01", (0.6, 0.58, 0.5), (0.75, 0.72, 0.6))
    mat_foliage("M_Flower_Violet_01", (0.2, 0.08, 0.35), (0.3, 0.12, 0.5))
    mat_plaster("M_Mushroom_Cap_01", (0.35, 0.12, 0.06))
    mat_plaster("M_Mushroom_Stem_01", (0.55, 0.5, 0.4))
    mat_stone("M_Rock_Cliff_01", (0.19, 0.18, 0.17), (0.06, 0.058, 0.055), 0.9, rough=0.92, moss=0.25)


def MM(n):
    return bpy.data.materials[n]


# ---------------------------------------------------------------------------------------------------------------- trees

def build_oak_variant(name, seed, height=4.3, radius=0.46, leaves=110, cfg_over=None):
    remove_asset(name)
    rnd = random.Random(seed)
    cfg = dict(OAK_CFG)
    cfg.update(cfg_over or {})
    parts, tips = [], []
    _grow(parts, tips, (0, 0, -0.1), (rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 1), height, radius, 0, rnd, name, M("Bark"), cfg)
    _roots(parts, name, M("Bark"), rnd, rnd.randint(5, 8), 1.2 * radius / 0.46, radius * 0.48, 0.35)
    if leaves:
        parts.append(_leaf_clusters(name, tips, rnd, M("OakLeaves"), leaves_per_tip=leaves))
    obj = finish_asset(name, parts, NC, [((radius * 2.2, radius * 2.2, height * 0.8), (0, 0, height * 0.4))], lods=False, smooth=50)
    return obj


def build_dead_variant(name, seed, height=5.0, radius=0.32, cfg_over=None):
    remove_asset(name)
    rnd = random.Random(seed)
    cfg = dict(DEAD_CFG)
    cfg.update(cfg_over or {})
    parts, tips = [], []
    _grow(parts, tips, (0, 0, -0.1), (rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 1), height, radius, 0, rnd, name, M("DeadBark"), cfg)
    _roots(parts, name, M("DeadBark"), rnd, 5, 1.0, radius * 0.47, 0.35)
    return finish_asset(name, parts, NC, [((radius * 2.2, radius * 2.2, height * 0.8), (0, 0, height * 0.4))], lods=False, smooth=50)


def build_pine(name="SM_Tree_Pine_01", seed=801, height=14.0):
    """Conifer: straight tapering trunk, whorls of drooping branches, needle clusters as layered fan cards (geometry)."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    trunk = [V((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), z)) for z in [height * t for t in (0, 0.2, 0.45, 0.7, 0.9, 1.0)]]
    parts.append(tube_along(f"{name}_trunk", trunk, [0.32, 0.26, 0.19, 0.12, 0.06, 0.01], M("Bark"), sides=14, twist_noise=0.05, seed=seed))
    _roots(parts, name, M("Bark"), rnd, 6, 0.9, 0.15, 0.25)
    bm = bmesh.new()
    z = height * 0.22
    while z < height * 0.97:
        t = (z - height * 0.22) / (height * 0.75)
        n = rnd.randint(5, 7)
        length = (1 - t) ** 0.9 * 3.2 + 0.4
        ph = rnd.uniform(0, 2 * math.pi)
        for k in range(n):
            a = ph + 2 * math.pi * k / n + rnd.uniform(-0.2, 0.2)
            d = V((math.cos(a), math.sin(a), 0))
            pts = [V((0, 0, z)) + d * 0.1]
            for j in range(1, 6):
                s = j / 5
                pts.append(V((0, 0, z)) + d * (0.1 + length * s) + V((0, 0, 0.15 * s - 0.55 * s * s * length / 3)))
            parts.append(tube_along(f"{name}_br", pts, [0.06 * (1 - t) + 0.02, 0.04, 0.03, 0.02, 0.012, 0.005], M("Bark"), sides=5))
            # Needle fans along the branch: drooping V-shaped cards, several layers.
            for j in range(1, 6):
                c = pts[j]
                side = d.cross(V((0, 0, 1))).normalized()
                w = 0.35 * (1.1 - j / 6) + 0.12
                for layer in range(2):
                    off = V((0, 0, layer * 0.05))
                    tip = c + d * 0.4 + V((0, 0, -0.1)) + off
                    vs = [bm.verts.new(c - d * 0.15 + off), bm.verts.new(c + side * w - V((0, 0, 0.12)) + off), bm.verts.new(tip), bm.verts.new(c - side * w - V((0, 0, 0.12)) + off)]
                    bm.faces.new((vs[0], vs[1], vs[2]))
                    bm.faces.new((vs[0], vs[2], vs[3]))
        z += rnd.uniform(0.55, 0.8)
    parts.append(_obj_from_bm(f"{name}_needles", bm, MM("M_Leaves_Pine_01")))
    return finish_asset(name, parts, NC, [((0.7, 0.7, height * 0.8), (0, 0, height * 0.4))], lods=False, smooth=50)


def build_fallen_tree(name="SM_Tree_Fallen_01", seed=811, length=9.0):
    """Fallen trunk lying on the ground: snapped jagged end, root plate torn out of the soil, broken limbs, moss."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    pts = [V((x, 0.1 * math.sin(x * 0.7), 0.35 + 0.05 * math.sin(x * 1.3))) for x in [length * t for t in (0, 0.25, 0.5, 0.75, 1.0)]]
    parts.append(tube_along(f"{name}_log", pts, [0.4, 0.37, 0.33, 0.28, 0.22], M("Bark"), sides=16, twist_noise=0.08, seed=seed))
    # Splintered end: ring of spikes.
    for k in range(10):
        a = 2 * math.pi * k / 10
        base = pts[-1] + V((0, math.cos(a) * 0.18, math.sin(a) * 0.18))
        parts.append(tube_along(f"{name}_splinter", [base, base + V((rnd.uniform(0.1, 0.45), 0, rnd.uniform(-0.05, 0.05)))], [0.05, 0.005], M("OldWood"), sides=4))
    # Root plate: disc of earth and roots.
    plate = rock(f"{name}_rootplate", (0.4, 1.4, 1.3), seed=seed, mat=M("Rock"), subdiv=3, roughness=0.2, flatten=0.0)
    plate.location = (-0.3, 0, 0.8)
    parts.append(plate)
    for k in range(12):
        a = 2 * math.pi * k / 12
        s = V((-0.3, math.cos(a) * 0.4, 0.8 + math.sin(a) * 0.4))
        parts.append(tube_along(f"{name}_root", [s, s + V((-0.4, math.cos(a) * 0.9, math.sin(a) * 0.9)), s + V((-0.3, math.cos(a) * 1.5, math.sin(a) * 1.4 - 0.3))], [0.08, 0.04, 0.01], M("Bark"), sides=6, twist_noise=0.2, seed=k))
    for k in range(5):
        x = rnd.uniform(2, length - 1)
        a = rnd.uniform(0.3, 2.8)
        s = V((x, 0, 0.5))
        parts.append(tube_along(f"{name}_limb", [s, s + V((rnd.uniform(-0.5, 0.5), math.cos(a) * 1.2, math.sin(a) * 1.0))], [0.1, 0.03], M("Bark"), sides=6, twist_noise=0.15, seed=k))
    for k in range(9):
        m = rock(f"{name}_moss", (0.4, 0.3, 0.08), seed=k, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(0.5, length - 0.5), rnd.uniform(-0.15, 0.15), 0.72)
        parts.append(m)
    return finish_asset(name, parts, NC, [((length, 0.8, 0.8), (length / 2, 0, 0.4)), ((0.8, 2.6, 2.4), (-0.3, 0, 1.0))], lods=False, smooth=50)


def build_stump(name="SM_Tree_Stump_01", seed=821):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = [tube_along(f"{name}_body", [V((0, 0, -0.1)), V((0, 0, 0.3)), V((0, 0, 0.55))], [0.55, 0.42, 0.4], M("Bark"), sides=18, twist_noise=0.1, seed=seed)]
    _roots(parts, name, M("Bark"), rnd, 7, 1.0, 0.2, 0.3)
    parts.append(cylinder(f"{name}_cut", 0.38, 0.02, (0, 0, 0.56), mat=M("OldWood"), verts=20, radius_top=0.37))
    for k in range(7):
        a = 2 * math.pi * k / 7
        parts.append(tube_along(f"{name}_jag", [V((math.cos(a) * 0.33, math.sin(a) * 0.33, 0.55)), V((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.55 + rnd.uniform(0.05, 0.25)))], [0.06, 0.005], M("OldWood"), sides=4))
    for k in range(6):
        m = rock(f"{name}_shroom", (0.06, 0.06, 0.02), seed=k, mat=MM("M_Mushroom_Cap_01"), subdiv=2)
        a = rnd.uniform(0, 2 * math.pi)
        m.location = (math.cos(a) * 0.45, math.sin(a) * 0.45, rnd.uniform(0.1, 0.4))
        parts.append(m)
    return finish_asset(name, parts, NC, [((1.0, 1.0, 0.6), (0, 0, 0.3))], lods=False, smooth=50)


# ----------------------------------------------------------------------------------------------------------- vegetation

def _blade_clump(name, count, height, spread, mat, rnd, width=0.012, bend=0.3, segs=3):
    """Grass/weed clump: curved tapered blades as real geometry."""
    bm = bmesh.new()
    for i in range(count):
        a = rnd.uniform(0, 2 * math.pi)
        r = abs(rnd.gauss(0, spread))
        base = V((math.cos(a) * r, math.sin(a) * r, 0))
        h = height * rnd.uniform(0.6, 1.2)
        d = V((math.cos(a), math.sin(a), 0)) * bend * rnd.uniform(0.3, 1.2)
        side = V((-math.sin(a + 1.3), math.cos(a + 1.3), 0)) * width
        prev_l = bm.verts.new(base - side)
        prev_r = bm.verts.new(base + side)
        for s in range(1, segs + 1):
            t = s / segs
            c = base + V((0, 0, h * t)) + d * h * t * t
            w = 1 - t
            if s == segs:
                tip = bm.verts.new(c)
                bm.faces.new((prev_l, prev_r, tip))
            else:
                l = bm.verts.new(c - side * w)
                rr = bm.verts.new(c + side * w)
                bm.faces.new((prev_l, prev_r, rr, l))
                prev_l, prev_r = l, rr
    return _obj_from_bm(name, bm, mat)


def build_grass(name, seed, tall=False, dead=False):
    remove_asset(name)
    rnd = random.Random(seed)
    mat = MM("M_Grass_Dead_01") if dead else MM("M_Grass_01")
    g = _blade_clump(f"{name}_blades", 260 if tall else 180, 0.75 if tall else 0.25, 0.18 if tall else 0.14, mat, rnd, width=0.01 if tall else 0.007, bend=0.35 if not dead else 0.6)
    parts = [g]
    if tall:
        # Seed heads on some stems.
        for i in range(14):
            a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, 0.15)
            h = rnd.uniform(0.7, 1.0)
            parts.append(tube_along(f"{name}_stem", [V((math.cos(a) * r, math.sin(a) * r, 0)), V((math.cos(a) * (r + 0.05), math.sin(a) * (r + 0.05), h))], [0.003, 0.002], mat, sides=3))
            parts.append(cylinder(f"{name}_head", 0.008, 0.07, (math.cos(a) * (r + 0.05), math.sin(a) * (r + 0.05), h + 0.03), mat=MM("M_Grass_Dead_01"), verts=5, radius_top=0.002))
    return finish_asset(name, parts, NC, [], lods=False, smooth=60)


def build_weeds(name="SM_Weeds_Forest_01", seed=851):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = [_blade_clump(f"{name}_blades", 90, 0.4, 0.2, MM("M_Grass_01"), rnd, width=0.018, bend=0.5)]
    # Broad-leaf weeds (dock/plantain): rosettes of oval leaves.
    bm = bmesh.new()
    for c in range(4):
        cx, cy = rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)
        for k in range(7):
            a = 2 * math.pi * k / 7 + rnd.uniform(-0.2, 0.2)
            d = V((math.cos(a), math.sin(a), 0))
            s = V((-d.y, d.x, 0))
            L = rnd.uniform(0.15, 0.28)
            base = V((cx, cy, 0.01))
            vs = [bm.verts.new(base), bm.verts.new(base + d * L * 0.5 + s * L * 0.22 + V((0, 0, L * 0.35))), bm.verts.new(base + d * L + V((0, 0, L * 0.2))), bm.verts.new(base + d * L * 0.5 - s * L * 0.22 + V((0, 0, L * 0.35)))]
            bm.faces.new((vs[0], vs[1], vs[2]))
            bm.faces.new((vs[0], vs[2], vs[3]))
    parts.append(_obj_from_bm(f"{name}_rosettes", bm, M("OakLeaves")))
    return finish_asset(name, parts, NC, [], lods=False, smooth=60)


def build_fern(name="SM_Fern_01", seed=861, fronds=11):
    """Fern: arching fronds with paired pinnae (leaflets) decreasing toward the tip."""
    remove_asset(name)
    rnd = random.Random(seed)
    bm = bmesh.new()
    for f in range(fronds):
        a = 2 * math.pi * f / fronds + rnd.uniform(-0.2, 0.2)
        d = V((math.cos(a), math.sin(a), 0))
        s = V((-d.y, d.x, 0))
        L = rnd.uniform(0.6, 0.95)
        rise = rnd.uniform(0.35, 0.6)
        n = 14
        spine = [d * (L * t) + V((0, 0, rise * math.sin(math.pi * t * 0.75) - 0.15 * t * t)) for t in [i / n for i in range(n + 1)]]
        for i in range(1, n):
            c = spine[i]
            w = 0.14 * (1 - i / n) + 0.02
            fwd = (spine[i + 1] - spine[i]).normalized()
            for side in (-1, 1):
                tip = c + s * side * w + fwd * w * 0.4 - V((0, 0, w * 0.3))
                vs = [bm.verts.new(c), bm.verts.new(c + fwd * 0.03 + s * side * w * 0.5 + V((0, 0, 0.01))), bm.verts.new(tip), bm.verts.new(c - fwd * 0.02 + s * side * w * 0.5)]
                bm.faces.new((vs[0], vs[1], vs[2]))
                bm.faces.new((vs[0], vs[2], vs[3]))
        stem = bm.verts.new(V((0, 0, 0)))
        prev = stem
        for pnt in spine[1:]:
            v = bm.verts.new(pnt)
            v2 = bm.verts.new(pnt + s * 0.006)
            p2 = bm.verts.new(prev.co + s * 0.006)
            bm.faces.new((prev, v, v2, p2))
            prev = v
    obj = _obj_from_bm(f"{name}_fronds", bm, MM("M_Fern_01"))
    return finish_asset(name, [obj], NC, [], lods=False, smooth=60)


def build_bush(name, seed, dead=False, size=1.2):
    """Shrub: many thin woody stems from a crown, leaf clusters (or bare twigs with a few dry leaves)."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts, tips = [], []
    cfg = dict(gravity=0.05, wobble=0.35, trunk_wobble=0.3, up=0.1, taper=0.4, max_depth=2, spread=0.6,
               children=[(3, 4), (2, 3)], length_ratio=(0.5, 0.7), first_fork=0.2, min_radius=0.004, leader=False)
    for k in range(rnd.randint(6, 9)):
        a = rnd.uniform(0, 2 * math.pi)
        d = V((math.cos(a) * 0.5, math.sin(a) * 0.5, 1))
        _grow(parts, tips, V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0)), d, size * rnd.uniform(0.6, 1.0), 0.025, 0, rnd, name, M("DeadBark") if dead else M("Bark"), cfg)
    if dead:
        parts.append(_leaf_clusters(name, tips, rnd, MM("M_Grass_Dead_01"), leaves_per_tip=6, spread=0.3, size=(0.03, 0.05)))
    else:
        parts.append(_leaf_clusters(name, tips, rnd, MM("M_Leaves_Bush_01"), leaves_per_tip=55, spread=0.5, size=(0.05, 0.08)))
    return finish_asset(name, parts, NC, [], lods=False, smooth=50)


def build_flowers(name, seed, mat_name):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = [_blade_clump(f"{name}_leaves", 40, 0.2, 0.12, MM("M_Grass_01"), rnd, width=0.01)]
    bm = bmesh.new()
    for i in range(18):
        a = rnd.uniform(0, 2 * math.pi); r = abs(rnd.gauss(0, 0.12))
        h = rnd.uniform(0.25, 0.45)
        base = V((math.cos(a) * r, math.sin(a) * r, 0))
        top = base + V((rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), h))
        parts.append(tube_along(f"{name}_stem{i}", [base, top], [0.003, 0.002], MM("M_Grass_01"), sides=3))
        for k in range(5):
            pa = 2 * math.pi * k / 5
            d = V((math.cos(pa), math.sin(pa), 0.25)).normalized()
            s = V((-d.y, d.x, 0)) * 0.012
            vs = [bm.verts.new(top), bm.verts.new(top + d * 0.02 + s), bm.verts.new(top + d * 0.035), bm.verts.new(top + d * 0.02 - s)]
            bm.faces.new((vs[0], vs[1], vs[2]))
            bm.faces.new((vs[0], vs[2], vs[3]))
        parts.append(cylinder(f"{name}_centre{i}", 0.006, 0.006, top, mat=MM("M_Grass_Dead_01"), verts=6))
    parts.append(_obj_from_bm(f"{name}_petals", bm, MM(mat_name)))
    return finish_asset(name, parts, NC, [], lods=False, smooth=60)


def build_mushrooms(name="SM_Mushrooms_Cluster_01", seed=881):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    for i in range(9):
        a = rnd.uniform(0, 2 * math.pi); r = abs(rnd.gauss(0, 0.1))
        h = rnd.uniform(0.05, 0.16); cr = rnd.uniform(0.025, 0.06)
        x, y = math.cos(a) * r, math.sin(a) * r
        lean = V((rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02), 0))
        parts.append(tube_along(f"{name}_stem{i}", [V((x, y, 0)), V((x, y, h)) + lean], [cr * 0.35, cr * 0.3], MM("M_Mushroom_Stem_01"), sides=8))
        cap = lathe(f"{name}_cap{i}", [(0, cr, cr, 0), (cr * 0.3, cr * 0.85, cr * 0.85, 0), (cr * 0.6, cr * 0.4, cr * 0.4, 0), (cr * 0.7, 0.002, 0.002, 0)], MM("M_Mushroom_Cap_01"), 14, cap_top=True)
        cap.location = V((x, y, h)) + lean
        parts.append(cap)
        gill = cylinder(f"{name}_gill{i}", cr * 0.95, 0.004, V((x, y, h)) + lean, mat=MM("M_Mushroom_Stem_01"), verts=14)
        parts.append(gill)
    return finish_asset(name, parts, NC, [], lods=False, smooth=60)


def build_roots(name="SM_Roots_Exposed_01", seed=891):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    for k in range(7):
        pts = [V((0, 0, 0.1))]
        a = rnd.uniform(0, 2 * math.pi)
        for j in range(1, 7):
            a += rnd.uniform(-0.4, 0.4)
            pts.append(pts[-1] + V((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.1 * math.sin(j * 1.3) - 0.03)))
        parts.append(tube_along(f"{name}_r{k}", pts, [0.09 - j * 0.012 for j in range(7)], M("Bark"), sides=7, twist_noise=0.2, seed=k))
    return finish_asset(name, parts, NC, [], lods=False, smooth=50)


def build_ivy(name="SM_Ivy_Wall_01", seed=901, W=2.0, H=3.0):
    """Ivy patch for walls (grows up the XZ plane at Y=0, leaves facing -Y): wandering vines with heart-shaped leaves."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    bm = bmesh.new()
    for v in range(9):
        p0 = V((rnd.uniform(-W / 2, W / 2), 0, 0))
        pts = [p0]
        a = math.pi / 2
        while pts[-1].z < H * rnd.uniform(0.6, 1.0) and len(pts) < 40:
            a += rnd.uniform(-0.5, 0.5)
            a = max(0.4, min(2.7, a))
            pts.append(pts[-1] + V((math.cos(a) * 0.12, 0, math.sin(a) * 0.12)))
        parts.append(tube_along(f"{name}_vine{v}", pts, [0.012] + [0.008] * (len(pts) - 2) + [0.003], M("Bark"), sides=4))
        for pnt in pts[1:]:
            for side in (-1, 1):
                if rnd.random() < 0.8:
                    c = pnt + V((side * rnd.uniform(0.02, 0.08), -rnd.uniform(0.01, 0.05), rnd.uniform(-0.03, 0.03)))
                    s = rnd.uniform(0.04, 0.07)
                    ang = rnd.uniform(0, 2 * math.pi)
                    d = V((math.cos(ang), 0, math.sin(ang)))
                    q = V((-d.z, 0, d.x))
                    vs = [bm.verts.new(c - d * s * 0.3), bm.verts.new(c + q * s * 0.6 - V((0, 0.01, 0))), bm.verts.new(c + d * s), bm.verts.new(c - q * s * 0.6 - V((0, 0.01, 0)))]
                    bm.faces.new((vs[0], vs[1], vs[2]))
                    bm.faces.new((vs[0], vs[2], vs[3]))
    parts.append(_obj_from_bm(f"{name}_leaves", bm, MM("M_Ivy_01")))
    return finish_asset(name, parts, NC, [], lods=False, smooth=60, origin=None)


def build_moss_patch(name="SM_Moss_Patch_01", seed=911):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    for i in range(12):
        m = rock(f"{name}_clump{i}", (rnd.uniform(0.1, 0.3), rnd.uniform(0.1, 0.3), rnd.uniform(0.02, 0.05)), seed=i, mat=M("MossRock"), subdiv=3, roughness=0.0, flatten=0.95)
        m.location = (rnd.gauss(0, 0.3), rnd.gauss(0, 0.3), 0)
        parts.append(m)
    parts.append(_blade_clump(f"{name}_fuzz", 300, 0.03, 0.3, MM("M_Ivy_01"), rnd, width=0.004, bend=0.4, segs=2))
    return finish_asset(name, parts, NC, [], lods=False, smooth=60)


# ---------------------------------------------------------------------------------------------------------------- rocks

def build_rock(name, seed, size, mat_key="Rock", moss=False, subdiv=5, chunks=0):
    remove_asset(name)
    rnd = random.Random(seed)
    mat = M("MossRock") if moss else (MM("M_Rock_Cliff_01") if mat_key == "Cliff" else M(mat_key))
    main = rock(f"{name}_main", size, seed=seed, mat=mat, subdiv=subdiv, roughness=0.45)
    main.location = (0, 0, size[2] * 0.6)
    parts = [main]
    for i in range(chunks):
        s = rnd.uniform(0.12, 0.3) * max(size)
        c = rock(f"{name}_chunk{i}", (s * 1.2, s, s * 0.7), seed=seed + 20 + i, mat=mat, subdiv=3)
        a = rnd.uniform(0, 2 * math.pi)
        c.location = (math.cos(a) * size[0] * 1.1, math.sin(a) * size[1] * 1.1, s * 0.25)
        c.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3))
        parts.append(c)
    return finish_asset(name, parts, NC, [((size[0] * 1.8, size[1] * 1.8, size[2] * 1.4), (0, 0, size[2] * 0.7))] if max(size) > 0.4 else [], lods=max(size) < 1.0, smooth=60)


def build_cliff(name="SM_Rock_Cliff_01", seed=931, W=8.0, H=7.0):
    """Stratified cliff face: stacked, offset rock layers with vertical fracture lines and ledges."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    z = 0.0
    while z < H:
        h = rnd.uniform(0.6, 1.3)
        x = -W / 2
        inset = rnd.uniform(-0.3, 0.3)
        while x < W / 2:
            w = rnd.uniform(1.0, 2.4)
            r = rock(f"{name}_slab", (w / 2, rnd.uniform(0.9, 1.4), h / 2 * 1.1), seed=rnd.randint(0, 99999), mat=MM("M_Rock_Cliff_01"), subdiv=4, roughness=0.6, flatten=0.4)
            r.location = (x + w / 2, inset + rnd.uniform(-0.15, 0.15) + z * 0.08, z + h / 2)
            parts.append(r)
            x += w * rnd.uniform(0.75, 0.95)
        z += h * 0.9
    for i in range(10):
        m = rock(f"{name}_moss{i}", (0.5, 0.25, 0.08), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-W / 2, W / 2), rnd.uniform(-1.2, -0.6), rnd.uniform(0.5, H))
        parts.append(m)
    return finish_asset(name, parts, NC, [((W, 2.4, H), (0, 0, H / 2))], lods=False, smooth=50)


def build_rock_formation(name="SM_Rock_Formation_01", seed=941):
    """Tall weathered spires leaning together over a scree base (landmark rock)."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    for i in range(5):
        h = rnd.uniform(2.5, 6.0)
        r = rock(f"{name}_spire{i}", (rnd.uniform(0.6, 1.0), rnd.uniform(0.6, 1.0), h / 2), seed=seed + i, mat=MM("M_Rock_Cliff_01"), subdiv=4, roughness=0.5, flatten=0.5)
        a = 2 * math.pi * i / 5
        r.location = (math.cos(a) * 1.2, math.sin(a) * 1.0, h / 2 - 0.2)
        r.rotation_euler = (math.sin(a) * 0.12, -math.cos(a) * 0.12, rnd.uniform(0, 3))
        parts.append(r)
    for i in range(20):
        s = rnd.uniform(0.15, 0.5)
        c = rock(f"{name}_scree{i}", (s * 1.2, s, s * 0.7), seed=seed + 50 + i, mat=M("Rock"), subdiv=2)
        a = rnd.uniform(0, 2 * math.pi); rr = rnd.uniform(1.8, 3.5)
        c.location = (math.cos(a) * rr, math.sin(a) * rr, s * 0.2)
        parts.append(c)
    return finish_asset(name, parts, NC, [((3.5, 3.0, 5.0), (0, 0, 2.5))], lods=False, smooth=50)


def build_cave_rock(name="SM_Rock_CaveArch_01", seed=951):
    """Rock arch / cave mouth: two massive rock legs bridged by a lintel boulder, hollow beneath."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    for sx in (-1, 1):
        leg = rock(f"{name}_leg{sx}", (1.2, 1.6, 2.2), seed=seed + sx, mat=MM("M_Rock_Cliff_01"), subdiv=5, roughness=0.5, flatten=0.8)
        leg.location = (sx * 2.2, 0, 2.0)
        parts.append(leg)
    top = rock(f"{name}_lintel", (3.6, 1.8, 1.2), seed=seed + 7, mat=MM("M_Rock_Cliff_01"), subdiv=5, roughness=0.5, flatten=0.3)
    top.location = (0, 0.1, 4.4)
    parts.append(top)
    for i in range(8):
        m = rock(f"{name}_moss{i}", (0.6, 0.4, 0.1), seed=i, mat=M("MossRock"), subdiv=2)
        m.location = (rnd.uniform(-3, 3), rnd.uniform(-0.5, 0.5), 5.4)
        parts.append(m)
    return finish_asset(name, parts, NC, [((2.2, 3.0, 4.0), (sx * 2.2, 0, 2.0)) for sx in (-1, 1)] + [((7.0, 3.0, 2.0), (0, 0, 4.6))], lods=False, smooth=50)


def build_nature_batch():
    """Builds every nature asset of this batch and lays them out on a grid. Returns [(name, tris)]."""
    nature_materials()
    out = []
    jobs = [
        lambda: build_oak_variant("SM_Tree_Oak_02", 12, 4.8, 0.5, 110, dict(spread=0.72)),
        lambda: build_oak_variant("SM_Tree_Oak_03", 13, 3.6, 0.4, 120, dict(spread=0.9, length_ratio=(0.66, 0.85))),
        lambda: build_oak_variant("SM_Tree_Oak_Ancient_01", 14, 3.4, 0.85, 90, dict(spread=0.95, gravity=0.08, trunk_wobble=0.25, length_ratio=(0.7, 0.9))),
        lambda: build_oak_variant("SM_Tree_Small_Forest_01", 15, 3.2, 0.14, 60, dict(max_depth=3, children=[(3, 4), (2, 3), (2, 2)], spread=0.55)),
        lambda: build_oak_variant("SM_Tree_Small_Forest_02", 16, 2.6, 0.12, 60, dict(max_depth=3, children=[(2, 3), (2, 3), (2, 2)], spread=0.6)),
        lambda: build_dead_variant("SM_Tree_Dead_02", 24, 6.0, 0.36),
        lambda: build_dead_variant("SM_Tree_DeadOak_01", 25, 3.8, 0.55, dict(spread=0.85, max_depth=3, length_ratio=(0.6, 0.8))),
        lambda: build_dead_variant("SM_Tree_Dead_Twisted_01", 26, 4.5, 0.4, dict(wobble=0.55, trunk_wobble=0.35)),
        lambda: build_pine(),
        lambda: build_pine("SM_Tree_Pine_02", 802, 11.0),
        lambda: build_pine("SM_Tree_Pine_Young_01", 803, 5.5),
        lambda: build_fallen_tree(),
        lambda: build_stump(),
        lambda: build_bush("SM_Bush_01", 861),
        lambda: build_bush("SM_Bush_02", 862, size=0.9),
        lambda: build_bush("SM_Bush_Dead_01", 863, dead=True),
        lambda: build_fern(),
        lambda: build_fern("SM_Fern_02", 871, 8),
        lambda: build_grass("SM_Grass_Tall_01", 881, tall=True),
        lambda: build_grass("SM_Grass_Short_01", 882),
        lambda: build_grass("SM_Grass_Dead_01", 883, tall=True, dead=True),
        lambda: build_weeds(),
        lambda: build_flowers("SM_Flowers_Poppy_01", 891, "M_Flower_Red_01"),
        lambda: build_flowers("SM_Flowers_Daisy_01", 892, "M_Flower_White_01"),
        lambda: build_flowers("SM_Flowers_Violet_01", 893, "M_Flower_Violet_01"),
        lambda: build_mushrooms(),
        lambda: build_roots(),
        lambda: build_ivy(),
        lambda: build_moss_patch(),
        lambda: build_rock("SM_Rock_Small_01", 961, (0.25, 0.2, 0.15), subdiv=4),
        lambda: build_rock("SM_Rock_Small_02", 962, (0.3, 0.18, 0.12), subdiv=4),
        lambda: build_rock("SM_Rock_Medium_01", 963, (0.7, 0.55, 0.45), chunks=2),
        lambda: build_rock("SM_Rock_Medium_Mossy_01", 964, (0.8, 0.6, 0.5), moss=True, chunks=2),
        lambda: build_rock("SM_Rock_Large_01", 965, (2.2, 1.7, 1.5), chunks=4),
        lambda: build_rock("SM_Rock_Boulder_01", 966, (1.4, 1.3, 1.2), chunks=0),
        lambda: build_rock("SM_Rock_Broken_01", 967, (0.9, 0.5, 0.35), chunks=5),
        lambda: build_cliff(),
        lambda: build_rock_formation(),
        lambda: build_cave_rock(),
    ]
    x, y = -60.0, 95.0
    for i, job in enumerate(jobs):
        o = job()
        o.location = (x, y, 0)
        out.append((o.name, tris(o)))
        x += 9.0
        if x > 60:
            x = -60.0
            y += 12.0
    return out

"""Nature: mossy boulder, oak, dead tree. exec() after kitlib.py."""


def build_mossy_rock(name="SM_Rock_Mossy_Large_01", seed=7):
    remove_asset(name)
    main = rock(f"{name}_main", (1.9, 1.5, 1.25), seed=seed, mat=M("MossRock"), subdiv=6)
    main.location = (0, 0, 0.75)
    parts = [main]
    rnd = random.Random(seed)
    # Split-off slab leaning on the main mass and a few fallen chunks half buried at the base.
    slab = rock(f"{name}_slab", (0.9, 0.35, 0.8), seed=seed + 3, mat=M("MossRock"), subdiv=5, flatten=0.3)
    slab.location = (1.55, -0.4, 0.55)
    slab.rotation_euler = (0.1, 0.35, 0.5)
    parts.append(slab)
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        s = rnd.uniform(0.15, 0.35)
        c = rock(f"{name}_chunk{i}", (s * 1.3, s, s * 0.8), seed=seed + 10 + i, mat=M("MossRock"), subdiv=3)
        c.location = (math.cos(a) * 2.0, math.sin(a) * 1.6, s * 0.3)
        c.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3))
        parts.append(c)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=60)
    link_only(obj, "ENV_Nature")
    ucx_box(obj, (3.6, 2.9, 1.9), (0, 0, 0.95))
    return obj


def _branch_points(start, direction, length, segments, rnd, gravity=0.0, wobble=0.25, up=0.0):
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    step = length / segments
    for _ in range(segments):
        d = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * wobble + Vector((0, 0, up - gravity))).normalized()
        pts.append(pts[-1] + d * step)
    return pts


def _grow(parts, tips, start, direction, length, radius, depth, rnd, name, mat, cfg, tip_radius=None):
    segs = max(3, int(length / 0.3))
    pts = _branch_points(start, direction, length, segs, rnd, cfg["gravity"] * depth, cfg["wobble"] if depth else cfg["trunk_wobble"], cfg["up"])
    end_r = tip_radius if tip_radius is not None else radius * cfg["taper"]
    radii = [radius + (end_r - radius) * (i / segs) ** 0.8 for i in range(segs + 1)]
    if depth == 0:
        radii[0] *= 1.45
        radii[1] *= 1.15
    parts.append(tube_along(f"{name}_b{len(parts)}", pts, radii, mat, sides=max(5, 14 - depth * 3), twist_noise=0.06, seed=rnd.randint(0, 9999), cap=depth > 0))
    if depth >= cfg["max_depth"]:
        tips.append((pts, radii))
        return
    lo, hi = cfg["children"][min(depth, len(cfg["children"]) - 1)]
    n = rnd.randint(lo, hi)
    for i in range(n):
        t = rnd.uniform(cfg["first_fork"] if depth == 0 else 0.25, 0.92)
        idx = min(segs - 1, int(t * segs))
        base = pts[idx]
        axis = (pts[idx + 1] - pts[idx]).normalized()
        yaw = 2 * math.pi * (i / n) + rnd.uniform(-0.6, 0.6)
        out = Vector((math.cos(yaw), math.sin(yaw), 0))
        out = (out - axis * out.dot(axis)).normalized()
        child_dir = (axis * (1 - cfg["spread"]) + out * cfg["spread"]).normalized()
        child_r = radii[idx] * rnd.uniform(0.55, 0.72)
        _grow(parts, tips, base - axis * child_r * 0.5, child_dir, length * rnd.uniform(*cfg["length_ratio"]), child_r, depth + 1, rnd, name, mat, cfg,
              tip_radius=max(cfg["min_radius"], child_r * cfg["taper"]))
    # Continue the leader past the forks with a thinner top so the trunk does not end in a flat cap.
    if depth == 0 and cfg.get("leader", True):
        _grow(parts, tips, pts[-1] - (pts[-1] - pts[-2]).normalized() * 0.1, (pts[-1] - pts[-2]), length * 0.45, radii[-1], 1, rnd, name, mat, cfg,
              tip_radius=max(cfg["min_radius"], radii[-1] * 0.2))


def _roots(parts, name, mat, rnd, count, reach, base_r, z0=0.3):
    for i in range(count):
        a = 2 * math.pi * i / count + rnd.uniform(-0.25, 0.25)
        steps = 6
        pts, radii = [], []
        for k in range(steps + 1):
            t = k / steps
            dist = 0.1 + reach * t * rnd.uniform(0.85, 1.1)
            pts.append(Vector((math.cos(a) * dist, math.sin(a) * dist, z0 * (1 - t) ** 1.6 - 0.12 * t)) + Vector((rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), 0)))
            radii.append(base_r * (1 - 0.8 * t) + 0.015)
        parts.append(tube_along(f"{name}_root{i}", pts, radii, mat, sides=9, seed=i, twist_noise=0.1))


def _leaf_clusters(name, tips, rnd, mat, leaves_per_tip=120, spread=0.45, size=(0.09, 0.15)):
    bm = bmesh.new()
    for pts, _ in tips:
        n_pts = len(pts)
        for _ in range(leaves_per_tip):
            # Leaves hug the outer half of each twig.
            t = rnd.uniform(0.35, 1.0) * (n_pts - 1)
            i0 = int(t)
            i1 = min(n_pts - 1, i0 + 1)
            anchor = pts[i0].lerp(pts[i1], t - i0)
            p = anchor + Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 0.8))) * spread * 0.5
            n = (p - anchor + Vector((0, 0, 0.6))).normalized()
            side = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.95 else Vector((1, 0, 0))).normalized()
            fwd = side.cross(n).normalized()
            s = rnd.uniform(*size)
            tipv = p + fwd * s * 1.4
            back = p - fwd * s * 0.4
            l1 = p + side * s * 0.55 + fwd * s * 0.3 + n * s * 0.12
            l2 = p + side * s * 0.4 + fwd * s * 0.9 + n * s * 0.08
            r1 = p - side * s * 0.55 + fwd * s * 0.3 + n * s * 0.12
            r2 = p - side * s * 0.4 + fwd * s * 0.9 + n * s * 0.08
            vs = [bm.verts.new(v) for v in (back, l1, l2, tipv, r2, r1)]
            bm.faces.new((vs[0], vs[1], vs[2], vs[3]))
            bm.faces.new((vs[0], vs[3], vs[4], vs[5]))
    return _obj_from_bm(f"{name}_leaves", bm, mat)


OAK_CFG = dict(gravity=0.02, wobble=0.22, trunk_wobble=0.08, up=0.06, taper=0.55, max_depth=4, spread=0.82,
               children=[(4, 5), (3, 4), (2, 3), (2, 3)], length_ratio=(0.62, 0.8), first_fork=0.4, min_radius=0.012)
DEAD_CFG = dict(gravity=0.0, wobble=0.3, trunk_wobble=0.12, up=0.08, taper=0.35, max_depth=3, spread=0.5,
                children=[(3, 4), (2, 3), (1, 3)], length_ratio=(0.45, 0.7), first_fork=0.5, min_radius=0.01, leader=True)


def build_oak(name="SM_Tree_Oak_01", seed=11):
    remove_asset(name)
    rnd = random.Random(seed)
    parts, tips = [], []
    _grow(parts, tips, (0, 0, -0.1), (0.04, 0.02, 1), 4.3, 0.46, 0, rnd, name, M("Bark"), OAK_CFG)
    _roots(parts, name, M("Bark"), rnd, 7, 1.2, 0.22, 0.35)
    parts.append(_leaf_clusters(name, tips, rnd, M("OakLeaves"), leaves_per_tip=110))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=50)
    link_only(obj, "ENV_Nature")
    c = cylinder(f"UCX_{name}_00", 0.5, 4.0, (0, 0, 2.0), verts=8)
    c.parent = obj
    c.display_type = "WIRE"
    c.hide_render = True
    link_only(c, "ENV_Nature")
    return obj


def build_dead_tree(name="SM_Tree_Dead_01", seed=23):
    remove_asset(name)
    rnd = random.Random(seed)
    parts, tips = [], []
    _grow(parts, tips, (0, 0, -0.1), (0.18, -0.08, 1), 5.0, 0.32, 0, rnd, name, M("DeadBark"), DEAD_CFG)
    _roots(parts, name, M("DeadBark"), rnd, 5, 1.0, 0.15, 0.35)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=50)
    link_only(obj, "ENV_Nature")
    c = cylinder(f"UCX_{name}_00", 0.35, 4.0, (0.15, 0, 2.0), verts=8)
    c.parent = obj
    c.display_type = "WIRE"
    c.hide_render = True
    link_only(c, "ENV_Nature")
    return obj

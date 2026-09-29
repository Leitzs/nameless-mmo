"""Buildings: timber-framed village house and tavern. exec() after kitlib.py and castle.py (uses _course_blocks)."""


def _wall_matrix(p0, p1, z):
    """Local frame for a straight wall from p0 to p1 (2D): X along wall, Y outward (right of travel), Z up."""
    d = Vector((p1[0] - p0[0], p1[1] - p0[1], 0))
    length = d.length
    d.normalize()
    out = Vector((d.y, -d.x, 0))
    m = Matrix.Identity(4)
    m.col[0][:3] = d
    m.col[1][:3] = out
    m.col[2][:3] = (0, 0, 1)
    m.col[3][:3] = (p0[0], p0[1], z)
    return m, length


def _lbox(parts, mw, name, size, loc, rot=(0, 0, 0), mat=None, bevel=0.01, jitter=0.004, seed=0):
    b = box(name, size, (0, 0, 0), mat=mat, bevel=bevel, segs=1, jitter=jitter, seed=seed)
    b.matrix_world = mw @ Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector((1, 1, 1)))
    parts.append(b)
    return b


def _lcyl(parts, mw, name, r, depth, loc, rot, mat, verts=8):
    c = cylinder(name, r, depth, (0, 0, 0), mat=mat, verts=verts)
    c.matrix_world = mw @ Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector((1, 1, 1)))
    parts.append(c)
    return c


def _window(parts, mw, name, x, z0, w, h, rnd, shutters=True):
    wood, dark = M("OldWood"), M("DarkWood")
    t = 0.07
    # Frame sits flush with the timber face; glass is recessed 8 cm.
    _lbox(parts, mw, f"{name}_wf", (w + 2 * t, 0.12, t), (x, 0.02, z0 - t / 2), mat=wood, seed=rnd.randint(0, 999))
    _lbox(parts, mw, f"{name}_wf", (w + 2 * t, 0.12, t), (x, 0.02, z0 + h + t / 2), mat=wood, seed=rnd.randint(0, 999))
    for sx in (-1, 1):
        _lbox(parts, mw, f"{name}_wf", (t, 0.12, h), (x + sx * (w / 2 + t / 2), 0.02, z0 + h / 2), mat=wood, seed=rnd.randint(0, 999))
    # Projecting sill.
    _lbox(parts, mw, f"{name}_sill", (w + 0.3, 0.2, 0.05), (x, 0.08, z0 - t - 0.02), rot=(0.08, 0, 0), mat=wood, seed=rnd.randint(0, 999))
    # Leaded glass: pane + mullion/transom cross + thin lead grid.
    _lbox(parts, mw, f"{name}_glass", (w, 0.02, h), (x, -0.08, z0 + h / 2), mat=M("Glass"), bevel=0, jitter=0)
    _lbox(parts, mw, f"{name}_mull", (0.05, 0.06, h), (x, -0.06, z0 + h / 2), mat=dark, seed=1)
    _lbox(parts, mw, f"{name}_tran", (w, 0.06, 0.05), (x, -0.06, z0 + h * 0.62), mat=dark, seed=2)
    for gx in (-w / 4, w / 4):
        _lbox(parts, mw, f"{name}_lead", (0.012, 0.03, h), (x + gx, -0.065, z0 + h / 2), mat=M("Iron"), bevel=0, jitter=0)
    # Dark reveal inside the opening so it never looks paper-thin.
    for sx in (-1, 1):
        _lbox(parts, mw, f"{name}_rev", (0.02, 0.1, h), (x + sx * w / 2, -0.04, z0 + h / 2), mat=dark, bevel=0, jitter=0)
    if shutters:
        for sx in (-1, 1):
            ang = sx * math.radians(rnd.uniform(95, 130))
            hinge = Vector((x + sx * (w / 2 + t), 0.09, 0))
            sw = w / 2 + 0.02
            for k in range(3):
                bw = sw / 3
                lx = sx * (bw / 2 + k * bw)
                piece = box(f"{name}_shut", (bw - 0.008, 0.03, h + 0.02), (0, 0, 0), mat=M("Planks"), bevel=0.004, segs=1, jitter=0.003, seed=rnd.randint(0, 999))
                piece.matrix_world = mw @ Matrix.Translation(hinge + Vector((0, 0, z0 + h / 2))) @ Matrix.Rotation(-ang + (math.pi if sx < 0 else 0) * 0, 4, "Z") @ Matrix.Translation(Vector((lx, 0, 0)))
                parts.append(piece)
            for bz in (0.2, h - 0.2):
                ledge = box(f"{name}_ledge", (sw, 0.02, 0.08), (0, 0, 0), mat=M("OldWood"), bevel=0.003, segs=1, jitter=0.002, seed=rnd.randint(0, 999))
                ledge.matrix_world = mw @ Matrix.Translation(hinge + Vector((0, 0, z0 + bz))) @ Matrix.Rotation(-ang, 4, "Z") @ Matrix.Translation(Vector((sx * sw / 2, 0.025, 0)))
                parts.append(ledge)


def _door(parts, mw, name, x, w, h, rnd, arch=False):
    dark, iron = M("DarkWood"), M("RustedIron")
    t = 0.12
    for sx in (-1, 1):
        _lbox(parts, mw, f"{name}_dpost", (t, 0.2, h + t), (x + sx * (w / 2 + t / 2), 0.02, (h + t) / 2), mat=M("OldWood"), seed=rnd.randint(0, 999))
    _lbox(parts, mw, f"{name}_dlintel", (w + 2 * t + 0.2, 0.22, 0.16), (x, 0.03, h + 0.08), mat=M("OldWood"), seed=rnd.randint(0, 999))
    n = 5
    pw = w / n
    for i in range(n):
        _lbox(parts, mw, f"{name}_dplank", (pw - 0.01, 0.06, h - 0.02), (x - w / 2 + pw * (i + 0.5), -0.06, h / 2), mat=dark, bevel=0.006, jitter=0.003, seed=rnd.randint(0, 999))
    # Ledge-and-brace on the outside + strap hinges with nail heads.
    for bz in (0.35, h - 0.35):
        _lbox(parts, mw, f"{name}_dledge", (w - 0.06, 0.04, 0.14), (x, -0.015, bz), mat=dark, seed=rnd.randint(0, 999))
        _lbox(parts, mw, f"{name}_hinge", (w * 0.75, 0.012, 0.05), (x - w * 0.12, 0.012, bz), mat=iron, bevel=0.003, jitter=0.001)
        _lcyl(parts, mw, f"{name}_pintle", 0.02, 0.1, (x - w / 2 - 0.02, 0.0, bz), (0, 0, 0), iron)
        for nx in range(4):
            _lcyl(parts, mw, f"{name}_nail", 0.01, 0.012, (x - w * 0.45 + nx * w * 0.22, 0.02, bz), (math.pi / 2, 0, 0), iron, verts=6)
    diag = math.hypot(w - 0.1, h - 0.9)
    _lbox(parts, mw, f"{name}_dbrace", (diag, 0.035, 0.12), (x, -0.012, h / 2), rot=(0, -math.atan2(h - 0.9, w - 0.1), 0), mat=dark, seed=rnd.randint(0, 999))
    # Ring pull + latch plate.
    _lbox(parts, mw, f"{name}_plate", (0.08, 0.01, 0.14), (x + w * 0.32, 0.015, 1.0), mat=iron, bevel=0.003, jitter=0.001)
    ring = tube_along(f"{name}_ring", [Vector((0.05 * math.cos(a), 0, 0.05 * math.sin(a))) for a in [2 * math.pi * i / 12 for i in range(13)]], [0.008] * 13, iron, sides=6, cap=False)
    ring.matrix_world = mw @ Matrix.Translation(Vector((x + w * 0.32, 0.03, 0.93)))
    parts.append(ring)


def _timber_wall(parts, name, p0, p1, z0, z1, rnd, openings=(), brace=True, plaster=True):
    """Timber-framed wall: sill, posts, girts, braces, top plate, recessed plaster infill with openings cut out."""
    mw, L = _wall_matrix(p0, p1, z0)
    H = z1 - z0
    wood = M("OldWood")
    bt = 0.2  # beam thickness
    _lbox(parts, mw, f"{name}_sill", (L + 0.1, bt + 0.02, bt), (L / 2, 0, bt / 2), mat=wood, seed=rnd.randint(0, 9999))
    _lbox(parts, mw, f"{name}_plate", (L + 0.1, bt + 0.02, bt), (L / 2, 0, H - bt / 2), mat=wood, seed=rnd.randint(0, 9999))
    # Post positions: ends, around openings, and at ~1.3 m spacing elsewhere.
    posts = {0.0 + bt / 2, L - bt / 2}
    for (cx, w, sz, hz, kind) in openings:
        posts.add(cx - w / 2 - 0.07 - bt / 2)
        posts.add(cx + w / 2 + 0.07 + bt / 2)
    xs = sorted(posts)
    fill = []
    for a, b in zip(xs, xs[1:]):
        gap = b - a
        n = int(gap / 1.35)
        for k in range(1, n + 1):
            fill.append(a + gap * k / (n + 1))
    xs = sorted(set(round(v, 3) for v in xs + fill))
    for px in xs:
        _lbox(parts, mw, f"{name}_post", (bt, bt, H - 2 * bt), (px, 0, H / 2), mat=wood, seed=rnd.randint(0, 9999))
    girt_z = H * 0.52
    bays = list(zip(xs, xs[1:]))
    for bi, (a, b) in enumerate(bays):
        cx = (a + b) / 2
        bw = b - a - bt
        op = next((o for o in openings if a < o[0] < b), None)
        if op is None:
            # Mid-rail + corner braces on the end bays; plain panels with a girt elsewhere.
            _lbox(parts, mw, f"{name}_girt", (bw, bt * 0.9, bt * 0.8), (cx, 0, girt_z), mat=wood, seed=rnd.randint(0, 9999))
            if brace and (bi == 0 or bi == len(bays) - 1):
                sign = 1 if bi == 0 else -1
                ht = girt_z - bt
                ang = math.atan2(ht, bw)
                _lbox(parts, mw, f"{name}_brace", (math.hypot(bw, ht), bt * 0.85, bt * 0.7), (cx, 0.0, bt + ht / 2), rot=(0, -sign * ang, 0), mat=wood, seed=rnd.randint(0, 9999))
            if plaster:
                for zc, hh in ((bt + (girt_z - bt * 1.4) / 2, girt_z - bt * 1.4), (girt_z + (H - girt_z - bt * 0.6) / 2, H - girt_z - bt * 1.4)):
                    _lbox(parts, mw, f"{name}_infill", (bw + 0.02, 0.12, hh + 0.02), (cx, -0.05, zc + bt * 0.3 - bt * 0.3), mat=M("Plaster"), bevel=0.02, jitter=0.012, seed=rnd.randint(0, 9999))
        else:
            ocx, ow, sz, hz, kind = op
            if kind == "door":
                _door(parts, mw, f"{name}_door", ocx, ow, hz, rnd)
            else:
                _lbox(parts, mw, f"{name}_wsill", (bw, bt * 0.9, bt * 0.7), (cx, 0, sz - 0.12), mat=wood, seed=rnd.randint(0, 9999))
                _window(parts, mw, f"{name}_win", ocx, sz, ow, hz - sz, rnd, shutters=rnd.random() < 0.8)
                if plaster:
                    hh = sz - 0.12 - bt * 0.35 - bt
                    _lbox(parts, mw, f"{name}_infill", (bw + 0.02, 0.12, hh), (cx, -0.05, bt + hh / 2), mat=M("Plaster"), bevel=0.02, jitter=0.012, seed=rnd.randint(0, 9999))
            _lbox(parts, mw, f"{name}_head", (bw, bt * 0.9, bt * 0.7), (cx, 0, hz + 0.12), mat=wood, seed=rnd.randint(0, 9999))
            if plaster:
                hh = H - bt - (hz + 0.12 + bt * 0.35)
                if hh > 0.05:
                    _lbox(parts, mw, f"{name}_infill", (bw + 0.02, 0.12, hh), (cx, -0.05, hz + 0.12 + bt * 0.35 + hh / 2), mat=M("Plaster"), bevel=0.02, jitter=0.012, seed=rnd.randint(0, 9999))
    return mw, L


def _stone_wall(parts, name, p0, p1, z0, z1, rnd, mat, openings=()):
    """Rubble/ashlar wall with openings (dressed quoins handled by caller)."""
    mw, L = _wall_matrix(p0, p1, z0)
    local = []
    z = 0.0
    H = z1 - z0

    def skip(cx, cz):
        return any(abs(cx - o[0]) < o[1] / 2 + 0.12 and (o[2] - 0.15) < cz < o[3] + 0.15 for o in openings)
    while z < H - 0.02:
        h = min(rnd.choice((0.28, 0.32, 0.36)), H - z)
        _course_blocks(local, name, L, z, h, -0.15, 0.36, rnd, mat, x0=0.0, min_len=0.3, max_len=0.75, inset=0.02, skip=skip)
        z += h
    for b in local:
        b.matrix_world = mw @ Matrix.LocRotScale(b.location.copy(), b.rotation_euler.to_quaternion(), Vector((1, 1, 1)))
    parts.extend(local)
    for (cx, w, sz, hz, kind) in openings:
        # Dressed stone lintel over each opening.
        _lbox(parts, mw, f"{name}_lintel", (w + 0.5, 0.4, 0.3), (cx, -0.13, hz + 0.16), mat=M("FoundationStone"), bevel=0.02, jitter=0.01, seed=rnd.randint(0, 999))
        if kind == "door":
            _door(parts, mw, f"{name}_door", cx, w, hz, rnd)
        else:
            _window(parts, mw, f"{name}_win", cx, sz, w, hz - sz, rnd)
    return mw, L


def _gable_roof(parts, name, W, D, z_eave, pitch_deg, overhang, rnd, tiles=False):
    """Gable roof, ridge along X, built per slope in a local frame (X along ridge, V down the slope, N out of the roof).
    Exposed rafters under the eaves, individual overlapping shingles/tiles, ridge beam + cap, barge boards."""
    p = math.radians(pitch_deg)
    rise = (D / 2) * math.tan(p)
    z_ridge = z_eave + rise
    slope_len = (D / 2 + overhang) / math.cos(p)
    Lx = W + 2 * overhang
    wood = M("OldWood")
    mat = M("RoofTiles") if tiles else M("Shingles")
    row_h = 0.2 if tiles else 0.24
    for side in (-1, 1):
        v = Vector((0, side * math.cos(p), -math.sin(p)))
        n = Vector((0, side * math.sin(p), math.cos(p)))
        ms = Matrix.Identity(4)
        ms.col[0][:3] = (1, 0, 0)
        ms.col[1][:3] = v
        ms.col[2][:3] = n
        ms.col[3][:3] = (0, 0, z_ridge)
        n_raf = int(Lx / 0.6) + 1
        for i in range(n_raf):
            x = -Lx / 2 + 0.05 + i * (Lx - 0.1) / (n_raf - 1)
            _lbox(parts, ms, f"{name}_rafter", (0.1, slope_len, 0.16), (x, slope_len / 2, -0.1), mat=wood, seed=rnd.randint(0, 9999))
        # Battens + sarking boards under the covering.
        _lbox(parts, ms, f"{name}_deck", (Lx, slope_len, 0.025), (0, slope_len / 2, 0.0), mat=M("DarkWood"), bevel=0, jitter=0.0)
        rows = int(slope_len / row_h) + 1
        for r in range(rows):
            s = slope_len - r * row_h  # start at the eave, work upward so upper rows overlap lower ones
            x = -Lx / 2 - (r % 2) * 0.1
            while x < Lx / 2 - 0.02:
                pw = min(0.22 if tiles else rnd.uniform(0.16, 0.3), Lx / 2 - x)
                if pw < 0.06:
                    break
                th = 0.035 if tiles else 0.022
                _lbox(parts, ms, f"{name}_sh", (pw - 0.012, row_h * 1.7, th), (x + pw / 2, s - row_h * 0.85 + rnd.uniform(-0.01, 0.01), 0.03 + r * 0.0005),
                      rot=(0.06 + rnd.uniform(-0.015, 0.015), rnd.uniform(-0.02, 0.02), rnd.uniform(-0.025, 0.025)), mat=mat,
                      bevel=0.004 if not tiles else 0.01, jitter=0.004, seed=rnd.randint(0, 99999))
                x += pw
        # Barge boards along both gable edges.
        for gx in (-1, 1):
            _lbox(parts, ms, f"{name}_barge", (0.05, slope_len + 0.05, 0.28), (gx * (Lx / 2 + 0.03), slope_len / 2, 0.02), mat=wood, seed=rnd.randint(0, 999))
        # Ridge cap board on this side.
        _lbox(parts, ms, f"{name}_cap", (Lx + 0.05, 0.25, 0.04), (0, 0.1, 0.09), mat=wood, seed=side + 5)
    parts.append(box(f"{name}_ridge", (Lx + 0.2, 0.22, 0.26), (0, 0, z_ridge - 0.08), mat=wood, bevel=0.01, jitter=0.006, seed=3))
    # Wall plates the rafters sit on.
    for side in (-1, 1):
        parts.append(box(f"{name}_wallplate", (W + 0.1, 0.22, 0.18), (0, side * D / 2, z_eave + 0.05), mat=wood, bevel=0.01, jitter=0.005, seed=side + 7))
    return rise


def _gable_infill(parts, name, W, D, z_eave, rise, rnd, y_face, framed=True):
    """Triangular gable end: king post, collar, raked braces and plaster."""
    wood = M("OldWood")
    for gx in (-1, 1):
        mw = Matrix.Translation(Vector((gx * (W / 2), 0, z_eave))) @ Matrix.Rotation(-gx * math.pi / 2, 4, "Z")
        _lbox(parts, mw, f"{name}_king", (0.18, 0.18, rise), (0, 0, rise / 2), mat=wood, seed=rnd.randint(0, 999))
        _lbox(parts, mw, f"{name}_collar", (D * 0.55, 0.18, 0.18), (0, 0, rise * 0.45), mat=wood, seed=rnd.randint(0, 999))
        for sx in (-1, 1):
            pitch = math.atan2(rise, D / 2)
            _lbox(parts, mw, f"{name}_rake", (math.hypot(D / 2, rise), 0.18, 0.2), (sx * D / 4, 0, rise / 2), rot=(0, sx * pitch, 0), mat=wood, seed=rnd.randint(0, 999))
        # Plaster triangle (as a thin prism) recessed behind the frame.
        bm = bmesh.new()
        v = [bm.verts.new((-D / 2, -0.06, 0)), bm.verts.new((D / 2, -0.06, 0)), bm.verts.new((0, -0.06, rise))]
        f = bm.faces.new(v)
        bmesh.ops.solidify(bm, geom=[f], thickness=0.1)
        tri = _obj_from_bm(f"{name}_gableplaster", bm, M("Plaster"))
        tri.matrix_world = mw
        parts.append(tri)


def _chimney(parts, name, x, y, z0, z1, rnd):
    stone = M("FoundationStone")
    z = z0
    while z < z1:
        h = rnd.choice((0.25, 0.3))
        for (dx, dy, sx, sy) in ((0, -0.35, 0.9, 0.2), (0, 0.35, 0.9, 0.2), (-0.35, 0, 0.2, 0.5), (0.35, 0, 0.2, 0.5)):
            parts.append(box(f"{name}_chim", (sx + rnd.uniform(-0.02, 0.02), sy, h - 0.015), (x + dx, y + dy, z + h / 2), mat=stone, bevel=0.015, segs=1, jitter=0.01, seed=rnd.randint(0, 9999)))
        z += h
    parts.append(box(f"{name}_chimcap", (1.05, 0.95, 0.12), (x, y, z + 0.06), mat=stone, bevel=0.02, segs=1, jitter=0.01, seed=9))
    parts.append(box(f"{name}_chimsoot", (0.45, 0.45, 0.05), (x, y, z - 0.1), mat=M("DarkWood"), bevel=0, jitter=0))


def _jetty_joists(parts, name, W, y_face, z, rnd, n=None):
    n = n or int(W / 0.5)
    for i in range(n):
        x = -W / 2 + 0.25 + i * (W - 0.5) / (n - 1)
        parts.append(box(f"{name}_joist", (0.16, 0.55, 0.2), (x, y_face - 0.2, z), mat=M("OldWood"), bevel=0.01, segs=1, jitter=0.006, seed=rnd.randint(0, 999)))


def build_village_house(name="SM_House_Village_01", seed=51):
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    W, D = 7.0, 5.2
    plinth_h = 0.6
    g_h = 2.7
    jetty = 0.4
    u_h = 2.5
    # Rubble stone plinth around the footprint (door threshold notch).
    for (p0, p1) in (((-W / 2, -D / 2), (W / 2, -D / 2)), ((W / 2, -D / 2), (W / 2, D / 2)), ((W / 2, D / 2), (-W / 2, D / 2)), ((-W / 2, D / 2), (-W / 2, -D / 2))):
        _stone_wall(parts, f"{name}_plinth", p0, p1, 0.0, plinth_h, rnd, M("FoundationStone"))
    # Ground floor: door + window at the front, windows on the sides/back.
    z0 = plinth_h
    _timber_wall(parts, f"{name}_gF", (-W / 2, -D / 2), (W / 2, -D / 2), z0, z0 + g_h, rnd, openings=[(2.2, 1.0, 0, 2.05, "door"), (5.0, 0.8, 1.0, 2.0, "window")])
    _timber_wall(parts, f"{name}_gR", (W / 2, -D / 2), (W / 2, D / 2), z0, z0 + g_h, rnd, openings=[(2.6, 0.7, 1.0, 1.9, "window")])
    _timber_wall(parts, f"{name}_gB", (W / 2, D / 2), (-W / 2, D / 2), z0, z0 + g_h, rnd, openings=[(3.5, 0.7, 1.0, 1.9, "window")])
    _timber_wall(parts, f"{name}_gL", (-W / 2, D / 2), (-W / 2, -D / 2), z0, z0 + g_h, rnd)
    # Jettied upper floor overhangs the front by 40 cm.
    z1 = z0 + g_h
    _jetty_joists(parts, name, W, -D / 2, z1 - 0.1, rnd)
    Dy0, Dy1 = -D / 2 - jetty, D / 2
    _timber_wall(parts, f"{name}_uF", (-W / 2, Dy0), (W / 2, Dy0), z1, z1 + u_h, rnd, openings=[(1.6, 0.7, 0.9, 1.8, "window"), (5.2, 0.7, 0.9, 1.8, "window")])
    _timber_wall(parts, f"{name}_uR", (W / 2, Dy0), (W / 2, Dy1), z1, z1 + u_h, rnd)
    _timber_wall(parts, f"{name}_uB", (W / 2, Dy1), (-W / 2, Dy1), z1, z1 + u_h, rnd, openings=[(3.5, 0.6, 0.9, 1.7, "window")])
    _timber_wall(parts, f"{name}_uL", (-W / 2, Dy1), (-W / 2, Dy0), z1, z1 + u_h, rnd)
    # Roof over the upper floor footprint (centered on it).
    z_eave = z1 + u_h
    roof_parts = []
    Du = D + jetty
    rise = _gable_roof(roof_parts, name, W, Du, z_eave, 52, 0.5, rnd, tiles=False)
    _gable_infill(roof_parts, name, W, Du, z_eave, rise, rnd, 0)
    for p in roof_parts:
        p.location.y -= jetty / 2
    parts.extend(roof_parts)
    # Chimney on the right gable, stone steps at the door, a lean-to log pile.
    _chimney(parts, name, W / 2 + 0.55, 0.6, 0.0, z_eave + rise + 0.6, rnd)
    for i in range(2):
        parts.append(box(f"{name}_step", (1.5 - i * 0.2, 0.45, 0.2), (-W / 2 + 2.2, -D / 2 - 0.45 + i * 0.22, 0.1 + i * 0.2), mat=M("FoundationStone"), bevel=0.03, segs=1, jitter=0.015, seed=i + 90))
    for i in range(12):
        lx = W / 2 - 1.0 + (i % 4) * 0.2 - 3.5
        log = cylinder(f"{name}_log", rnd.uniform(0.07, 0.1), 0.9, (lx - 0.8, D / 2 + 0.35, 0.1 + (i // 4) * 0.17), (0, math.pi / 2, math.pi / 2), M("Bark"), verts=10, jitter=0.01, seed=i)
        parts.append(log)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=35)
    link_only(obj, "ENV_Buildings")
    ucx_box(obj, (W + 0.1, D + 0.1, z1), (0, 0, z1 / 2), 0)
    ucx_box(obj, (W + 0.1, Du + 0.1, u_h), (0, -jetty / 2, z1 + u_h / 2), 1)
    return obj


def build_tavern(name="SM_House_Tavern_01", seed=61):
    """Large two-and-a-half storey inn: stone ground floor, two jettied timber floors, tiled roof, sign, porch."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    W, D = 12.0, 8.0
    g_h = 3.2
    stone = M("FoundationStone")
    # Ground floor in coursed rubble with a wide arched double door and big tavern windows.
    front = [(3.0, 1.6, 0, 2.4, "door"), (6.3, 1.2, 1.0, 2.3, "window"), (8.6, 1.2, 1.0, 2.3, "window"), (10.7, 0.9, 1.0, 2.3, "window")]
    _stone_wall(parts, f"{name}_gF", (-W / 2, -D / 2), (W / 2, -D / 2), 0, g_h, rnd, stone, openings=front)
    _stone_wall(parts, f"{name}_gR", (W / 2, -D / 2), (W / 2, D / 2), 0, g_h, rnd, stone, openings=[(4.0, 1.0, 1.0, 2.3, "window")])
    _stone_wall(parts, f"{name}_gB", (W / 2, D / 2), (-W / 2, D / 2), 0, g_h, rnd, stone, openings=[(3.0, 1.0, 0, 2.2, "door"), (8.0, 0.9, 1.0, 2.2, "window")])
    _stone_wall(parts, f"{name}_gL", (-W / 2, D / 2), (-W / 2, -D / 2), 0, g_h, rnd, stone, openings=[(4.0, 1.0, 1.0, 2.3, "window")])
    # Dressed quoins at the four corners.
    for cx, cy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        z = 0
        k = 0
        while z < g_h:
            h = 0.36
            long_x = k % 2 == 0
            parts.append(box(f"{name}_quoin", (0.75 if long_x else 0.42, 0.42 if long_x else 0.75, h - 0.015), (cx * (W / 2 - (0.3 if long_x else 0.14)) + cx * 0.03, cy * (D / 2 - (0.14 if long_x else 0.3)) + cy * 0.03, z + h / 2), mat=M("CastleStone"), bevel=0.025, segs=2, jitter=0.008, seed=rnd.randint(0, 999)))
            z += h
            k += 1
    # First floor (jetty 0.5 m front), second floor (jetty another 0.4 m front).
    z1 = g_h
    _jetty_joists(parts, name, W, -D / 2, z1 - 0.1, rnd)
    y0 = -D / 2 - 0.5
    fh = 2.8
    _timber_wall(parts, f"{name}_1F", (-W / 2, y0), (W / 2, y0), z1, z1 + fh, rnd, openings=[(1.5, 0.8, 0.9, 2.0, "window"), (4.4, 0.8, 0.9, 2.0, "window"), (7.6, 0.8, 0.9, 2.0, "window"), (10.5, 0.8, 0.9, 2.0, "window")])
    _timber_wall(parts, f"{name}_1R", (W / 2, y0), (W / 2, D / 2), z1, z1 + fh, rnd, openings=[(4.2, 0.8, 0.9, 2.0, "window")])
    _timber_wall(parts, f"{name}_1B", (W / 2, D / 2), (-W / 2, D / 2), z1, z1 + fh, rnd, openings=[(2.5, 0.8, 0.9, 2.0, "window"), (9.0, 0.8, 0.9, 2.0, "window")])
    _timber_wall(parts, f"{name}_1L", (-W / 2, D / 2), (-W / 2, y0), z1, z1 + fh, rnd, openings=[(4.2, 0.8, 0.9, 2.0, "window")])
    z2 = z1 + fh
    _jetty_joists(parts, f"{name}_2", W, y0, z2 - 0.1, rnd)
    y1 = y0 - 0.4
    _timber_wall(parts, f"{name}_2F", (-W / 2, y1), (W / 2, y1), z2, z2 + 2.5, rnd, openings=[(3.0, 0.7, 0.9, 1.8, "window"), (6.0, 0.7, 0.9, 1.8, "window"), (9.0, 0.7, 0.9, 1.8, "window")])
    _timber_wall(parts, f"{name}_2R", (W / 2, y1), (W / 2, D / 2), z2, z2 + 2.5, rnd)
    _timber_wall(parts, f"{name}_2B", (W / 2, D / 2), (-W / 2, D / 2), z2, z2 + 2.5, rnd, openings=[(6.0, 0.7, 0.9, 1.8, "window")])
    _timber_wall(parts, f"{name}_2L", (-W / 2, D / 2), (-W / 2, y1), z2, z2 + 2.5, rnd)
    z_eave = z2 + 2.5
    Du = D + 0.9
    roof_parts = []
    rise = _gable_roof(roof_parts, name, W, Du, z_eave, 50, 0.6, rnd, tiles=True)
    _gable_infill(roof_parts, name, W, Du, z_eave, rise, rnd, 0)
    for p in roof_parts:
        p.location.y -= 0.45
    parts.extend(roof_parts)
    # Two chimneys through the roof.
    for cx in (-3.0, 3.5):
        _chimney(parts, f"{name}_c{cx}", cx, 1.2, z_eave - 0.5, z_eave + rise + 1.0, rnd)
    # Porch roof on posts over the main door.
    for px in (-W / 2 + 1.9, -W / 2 + 4.1):
        parts.append(box(f"{name}_porchpost", (0.2, 0.2, 2.8), (px, -D / 2 - 1.6, 1.4), mat=M("OldWood"), bevel=0.012, segs=1, jitter=0.006, seed=int(px * 10)))
        parts.append(box(f"{name}_porchbrace", (0.12, 0.9, 0.14), (px, -D / 2 - 1.2, 2.55), rot=(-0.7, 0, 0), mat=M("OldWood"), bevel=0.01, segs=1, jitter=0.005, seed=int(px * 11)))
    parts.append(box(f"{name}_porchbeam", (2.6, 0.2, 0.22), (-W / 2 + 3.0, -D / 2 - 1.6, 2.9), mat=M("OldWood"), bevel=0.012, segs=1, jitter=0.006, seed=5))
    for i in range(10):
        parts.append(box(f"{name}_porchtile", (2.8, 0.26, 0.03), (-W / 2 + 3.0, -D / 2 - 1.75 + i * 0.19, 3.0 + i * 0.1), rot=(-0.5, 0, rnd.uniform(-0.01, 0.01)), mat=M("RoofTiles"), bevel=0.008, segs=1, jitter=0.006, seed=i))
    # Hanging sign on an iron bracket, lanterns by the door.
    bx = -W / 2 + 5.2
    parts.append(tube_along(f"{name}_bracket", [Vector((bx, -D / 2 - 0.5, z1 - 0.3)), Vector((bx, -D / 2 - 1.3, z1 - 0.28)), Vector((bx, -D / 2 - 1.5, z1 - 0.4))], [0.025, 0.02, 0.015], M("Iron"), sides=6))
    parts.append(tube_along(f"{name}_bracketstay", [Vector((bx, -D / 2 - 0.5, z1 - 0.9)), Vector((bx, -D / 2 - 1.1, z1 - 0.32))], [0.015, 0.015], M("Iron"), sides=6))
    for cy in (-D / 2 - 0.9, -D / 2 - 1.35):
        parts.append(tube_along(f"{name}_chain", [Vector((bx, cy, z1 - 0.3)), Vector((bx, cy, z1 - 0.5))], [0.008, 0.008], M("Iron"), sides=5))
    sign = box(f"{name}_sign", (0.05, 0.75, 0.55), (bx, -D / 2 - 1.12, z1 - 0.8), rot=(0, 0, 0), mat=M("DarkWood"), bevel=0.02, segs=2, jitter=0.006, seed=12)
    parts.append(sign)
    parts.append(box(f"{name}_signtrim", (0.06, 0.8, 0.06), (bx, -D / 2 - 1.12, z1 - 0.52), mat=M("Gold"), bevel=0.01, segs=1, jitter=0.003, seed=13))
    for lx in (-W / 2 + 1.8, -W / 2 + 4.2):
        parts.append(box(f"{name}_lantern", (0.18, 0.18, 0.28), (lx, -D / 2 - 0.2, 2.3), mat=M("Iron"), bevel=0.01, segs=1, jitter=0.002, seed=1))
        parts.append(box(f"{name}_lanternglow", (0.12, 0.2, 0.2), (lx, -D / 2 - 0.2, 2.3), mat=M("Glass"), bevel=0, jitter=0))
    # Barrels stacked by the side wall are placed separately in the presentation (SM_Barrel_01 instances).
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE", smooth_angle=35)
    link_only(obj, "ENV_Buildings")
    ucx_box(obj, (W + 0.1, D + 0.1, g_h), (0, 0, g_h / 2), 0)
    ucx_box(obj, (W + 0.1, D + 0.6, fh), (0, -0.25, z1 + fh / 2), 1)
    ucx_box(obj, (W + 0.1, Du + 0.1, 2.5), (0, -0.45, z2 + 1.25), 2)
    return obj

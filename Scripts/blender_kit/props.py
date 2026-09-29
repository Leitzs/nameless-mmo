"""Village props: barrel, crate. exec() after kitlib.py."""


def build_barrel(name="SM_Barrel_01", seed=1):
    remove_asset(name)
    rnd = random.Random(seed)
    height, r_end, r_mid = 0.9, 0.25, 0.3
    staves = 18
    parts = []
    gap = 0.004
    for i in range(staves):
        a0 = 2 * math.pi * i / staves + gap
        a1 = 2 * math.pi * (i + 1) / staves - gap
        thick = 0.022 + rnd.uniform(-0.002, 0.003)
        push = rnd.uniform(-0.004, 0.004)
        bm = bmesh.new()
        rows = 10
        cols = 3
        grid = []
        for rz in range(rows + 1):
            t = rz / rows
            z = t * height
            bulge = r_end + (r_mid - r_end) * math.sin(math.pi * t)
            ring_o, ring_i = [], []
            for c in range(cols + 1):
                a = a0 + (a1 - a0) * c / cols
                ro = bulge + push
                ri = ro - thick
                ring_o.append(bm.verts.new((math.cos(a) * ro, math.sin(a) * ro, z)))
                ring_i.append(bm.verts.new((math.cos(a) * ri, math.sin(a) * ri, z)))
            grid.append((ring_o, ring_i))
        for rz in range(rows):
            (o0, i0), (o1, i1) = grid[rz], grid[rz + 1]
            for c in range(cols):
                bm.faces.new((o0[c], o0[c + 1], o1[c + 1], o1[c]))
                bm.faces.new((i0[c + 1], i0[c], i1[c], i1[c + 1]))
            bm.faces.new((o0[0], o1[0], i1[0], i0[0]))
            bm.faces.new((o1[cols], o0[cols], i0[cols], i1[cols]))
        for rz, flip in ((0, True), (rows, False)):
            o, ii = grid[rz]
            for c in range(cols):
                f = (o[c], ii[c], ii[c + 1], o[c + 1])
                bm.faces.new(f if flip else tuple(reversed(f)))
        # Chipped stave tops.
        for v in bm.verts:
            if v.co.z > height - 0.001 and rnd.random() < 0.25:
                v.co.z -= rnd.uniform(0.003, 0.012)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(_obj_from_bm(f"{name}_stave{i}", bm, M("OldWood")))
    # Recessed lid of 4 planks sitting 3 cm below the chime, plus the bottom.
    for zc, zname in ((height - 0.035, "lid"), (0.035, "bottom")):
        for p in range(4):
            w = (2 * r_end - 0.04) / 4
            x = -r_end + 0.02 + w * (p + 0.5)
            half_len = math.sqrt(max(0.0, (r_end - 0.018) ** 2 - x ** 2))
            parts.append(box(f"{name}_{zname}{p}", (w - 0.004, 2 * half_len, 0.025), (x, 0, zc), mat=M("Planks"), bevel=0.003, jitter=0.0015, seed=p + seed))
    # Iron hoops: 2 near each end, 1 at the belly is left out on purpose (wear).
    for t in (0.07, 0.2, 0.8, 0.93):
        z = t * height
        rr = r_end + (r_mid - r_end) * math.sin(math.pi * t) + 0.004
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=rr + 0.006, radius2=rr + 0.006, depth=0.035)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.006)
        hoop = _obj_from_bm(f"{name}_hoop", bm, M("RustedIron"))
        hoop.location = (0, 0, z)
        hoop.rotation_euler = (rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02), 0)
        parts.append(hoop)
    # Bung hole plug on the belly.
    parts.append(cylinder(f"{name}_bung", 0.018, 0.04, (r_mid + 0.005, 0, height * 0.55), (0, math.pi / 2, 0), M("DarkWood"), verts=10))
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE")
    link_only(obj, "PROP_Village")
    c = cylinder(f"UCX_{name}_00", r_mid, height, (0, 0, height / 2), verts=10)
    c.parent = obj
    c.display_type = "WIRE"
    c.hide_render = True
    link_only(c, "PROP_Village")
    make_lods(obj)
    return obj


def build_crate(name="SM_Crate_Wood_01", seed=2):
    remove_asset(name)
    rnd = random.Random(seed)
    S = 0.8
    parts = []
    plank_w, plank_t = S / 4, 0.022
    # Side panels made of 4 horizontal planks each, with small gaps and per-plank variation.
    for side in range(4):
        ang = side * math.pi / 2
        for i in range(4):
            z = 0.06 + i * (S - 0.08) / 4 + (S - 0.08) / 8
            off = rnd.uniform(-0.003, 0.003)
            b = box(f"{name}_p{side}{i}", (S - 0.02, plank_t, (S - 0.08) / 4 - 0.008), (0, S / 2 - plank_t / 2 + off, z), mat=M("Planks"), bevel=0.004, jitter=0.0015, seed=seed * 50 + side * 4 + i)
            b.rotation_euler = (rnd.uniform(-0.01, 0.01), 0, 0)
            bpy.context.view_layer.update()
            b.matrix_world = Matrix.Rotation(ang, 4, "Z") @ b.matrix_world
            parts.append(b)
    # Corner posts and frame battens + diagonal brace per side.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box(f"{name}_post", (0.06, 0.06, S), (sx * (S / 2 - 0.02), sy * (S / 2 - 0.02), S / 2), mat=M("OldWood"), bevel=0.006, jitter=0.002, seed=rnd.randint(0, 999)))
    for side in range(4):
        ang = side * math.pi / 2
        for z in (0.04, S - 0.04):
            b = box(f"{name}_batten", (S - 0.1, 0.035, 0.07), (0, S / 2 + 0.01, z), mat=M("OldWood"), bevel=0.005, jitter=0.002, seed=rnd.randint(0, 999))
            bpy.context.view_layer.update()
            b.matrix_world = Matrix.Rotation(ang, 4, "Z") @ b.matrix_world
            parts.append(b)
        diag = math.hypot(S - 0.12, S - 0.14)
        b = box(f"{name}_brace", (diag, 0.03, 0.07), (0, S / 2 + 0.012, S / 2), rot=(0, math.atan2(S - 0.14, S - 0.12) * (1 if side % 2 else -1), 0), mat=M("OldWood"), bevel=0.005, jitter=0.002, seed=rnd.randint(0, 999))
        bpy.context.view_layer.update()
        b.matrix_world = Matrix.Rotation(ang, 4, "Z") @ b.matrix_world
        parts.append(b)
    # Lid planks and bottom.
    for zc in (S - plank_t / 2, plank_t / 2):
        for i in range(4):
            x = -S / 2 + 0.03 + (S - 0.06) / 4 * (i + 0.5)
            parts.append(box(f"{name}_lid", ((S - 0.06) / 4 - 0.006, S - 0.04, plank_t), (x, 0, zc + rnd.uniform(-0.002, 0.002)), mat=M("Planks"), bevel=0.004, jitter=0.0015, seed=rnd.randint(0, 999)))
    # Nail heads on battens.
    for side in range(4):
        ang = side * math.pi / 2
        for z in (0.04, S - 0.04):
            for x in (-S / 2 + 0.08, 0, S / 2 - 0.08):
                n = cylinder(f"{name}_nail", 0.007, 0.008, (x, S / 2 + 0.03, z), (math.pi / 2, 0, 0), M("RustedIron"), verts=6)
                bpy.context.view_layer.update()
                n.matrix_world = Matrix.Rotation(ang, 4, "Z") @ n.matrix_world
                parts.append(n)
    obj = join(name, parts)
    smart_uv(obj)
    finalize(obj, "BASE")
    link_only(obj, "PROP_Village")
    ucx_box(obj, (S + 0.04, S + 0.04, S), (0, 0, S / 2))
    make_lods(obj)
    return obj

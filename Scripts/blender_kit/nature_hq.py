"""
High-detail vegetation pass: replaces the geometry-leaf foliage with textured alpha cards.

exec() after kitlib.py, nature.py and nature2.py (it reuses their branch growth, roots and rock helpers). It:
  1. paints foliage and bark textures procedurally (numpy, supersampled) into Art/Textures/Foliage/*.png:
     oak / bush leaf clusters, pine needle sprays, grass and dry-grass blade strips, fern fronds, tileable bark
     (colour + normal);
  2. rebuilds the foliage materials (same names as before, so every asset that uses them updates) as
     image-textured, alpha-clipped materials, and gives the bark materials the bark texture;
  3. rebuilds the trees, bushes, grass and ferns under their existing names with far denser foliage made of
     textured cards. Card normals are bent outwards from the crown (upwards for grass), so canopies shade as soft
     volumes instead of flat planes.
Then re-run export_kit.py and, in Unreal, Scripts/import_kit.py.
"""

import os

import numpy as np

HQ_TEX_DIR = os.path.normpath(os.path.join(os.path.dirname(bpy.data.filepath), "..", "Textures", "Foliage"))
_rng = np.random.default_rng(1234)


# ------------------------------------------------------------------------------------------------ texture painting

def _canvas(w, h):
    return np.zeros((h, w, 4), np.float32)


def _stamp(img, cx, cy, ang, length, width, color, shape="leaf", rib=0.35, back=0.0):
    """Paints one leaf/needle/blade: u runs along `ang` from the stem (cx, cy), v across. Colours are sRGB."""
    h, w = img.shape[:2]
    reach = length + width
    x0, x1 = int(max(0, cx - reach)), int(min(w, cx + reach + 1))
    y0, y1 = int(max(0, cy - reach)), int(min(h, cy + reach + 1))
    if x0 >= x1 or y0 >= y1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    ca, sa = np.cos(ang), np.sin(ang)
    u = (dx * ca + dy * sa) / length
    v = (-dx * sa + dy * ca)
    if shape == "leaf":
        half = width * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 0.75
    elif shape == "oak":
        half = width * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 0.7 * (1.0 + 0.28 * np.sin(np.clip(u, 0, 1) * np.pi * 7.0))
    elif shape == "blade":
        half = width * (1.0 - np.clip(u, 0, 1)) ** 0.9
    elif shape == "needle":
        half = width * (1.0 - 0.6 * np.clip(u, 0, 1))
    else:
        half = width * np.ones_like(u)
    inside = (u >= 0) & (u <= 1) & (np.abs(v) <= half)
    if not inside.any():
        return
    # Soft edge (1 px) for anti-aliasing after the supersampled downscale.
    edge = np.clip((half - np.abs(v)) / 1.5, 0, 1) * inside
    tone = 0.78 + 0.32 * np.clip(u, 0, 1)
    midrib = 1.0 - rib * np.exp(-(v / (0.09 * width + 0.6)) ** 2)
    veins = 1.0 - 0.08 * (np.sin(u * 40.0 + np.abs(v) / (width + 1e-3) * 6.0) > 0.7) if shape in ("leaf", "oak") else 1.0
    rim = 1.0 - 0.25 * np.clip(1.0 - (half - np.abs(v)) / (0.18 * width + 0.5), 0, 1)
    shade = (tone * midrib * veins * rim * (1.0 - back))[..., None]
    col = np.asarray(color, np.float32)[None, None, :3] * shade
    a = edge[..., None]
    region = img[y0:y1, x0:x1]
    region[..., :3] = region[..., :3] * (1 - a) + col * a
    region[..., 3:] = np.maximum(region[..., 3:], a)


def _line(img, p0, p1, width, color):
    ang = np.arctan2(p1[1] - p0[1], p1[0] - p0[0])
    length = max(1.0, float(np.hypot(p1[0] - p0[0], p1[1] - p0[1])))
    _stamp(img, p0[0], p0[1], ang, length, width, color, shape="rect", rib=0.0)


def _finish(img, out_w, out_h):
    """Downsamples the supersampled canvas and bleeds colour into transparent texels (no dark mip halos)."""
    h, w = img.shape[:2]
    fy, fx = h // out_h, w // out_w
    small = img.reshape(out_h, fy, out_w, fx, 4).mean(axis=(1, 3))
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 1e-3, small[..., :3] / np.maximum(alpha, 1e-3), 0.0)
    mean = (rgb * (alpha > 0.5)).reshape(-1, 3).sum(0) / max(1, int((alpha > 0.5).sum()))
    rgb = np.where(alpha > 0.02, rgb, mean)
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)], axis=-1)


def _save(name, rgba, colorspace="sRGB"):
    os.makedirs(HQ_TEX_DIR, exist_ok=True)
    h, w = rgba.shape[:2]
    img = bpy.data.images.get(name)
    if img is None or img.size[0] != w or img.size[1] != h:
        if img is not None:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(name, w, h, alpha=True)
    img.colorspace_settings.name = colorspace
    # Blender images are stored bottom-up.
    img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1], dtype=np.float32).ravel())
    img.filepath_raw = os.path.join(HQ_TEX_DIR, name + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def paint_leaf_cluster(name, palette, leaf_shape="leaf", leaves=260, leaf_len=(70, 120), leaf_w=(22, 34), size=1024, twig=(0.2, 0.13, 0.07)):
    """A spray of twigs covered in leaves, filling the card (stem at the bottom centre)."""
    S = 2
    W = H = size * S
    img = _canvas(W, H)
    rnd = np.random.default_rng(abs(hash(name)) % 2**32)
    twigs = []
    # Main twig from the bottom centre, side twigs fanning out.
    base = np.array([W * 0.5, H * 0.97])
    main_tip = np.array([W * 0.5 + rnd.uniform(-0.08, 0.08) * W, H * 0.12])
    twigs.append((base, main_tip))
    for k in range(9):
        t = rnd.uniform(0.15, 0.85)
        p = base + (main_tip - base) * t
        side = -1 if k % 2 else 1
        tip = p + np.array([side * rnd.uniform(0.22, 0.42) * W, -rnd.uniform(0.08, 0.25) * H])
        twigs.append((p, np.clip(tip, 0.06 * W, 0.94 * W)))
    for p0, p1 in twigs:
        _line(img, p0, p1, 5 * S, twig)
    order = rnd.random(leaves)
    for i in np.argsort(order):
        p0, p1 = twigs[rnd.integers(len(twigs))]
        t = rnd.uniform(0.2, 1.0)
        anchor = p0 + (p1 - p0) * t
        tw_ang = np.arctan2(p1[1] - p0[1], p1[0] - p0[0])
        ang = tw_ang + rnd.choice([-1, 1]) * rnd.uniform(0.4, 1.3)
        c = np.array(palette[rnd.integers(len(palette))]) * rnd.uniform(0.85, 1.12)
        _stamp(img, anchor[0], anchor[1], ang, rnd.uniform(*leaf_len) * S, rnd.uniform(*leaf_w) * S, c, leaf_shape, back=(1 - order[i]) * 0.35)
    return _save(name, _finish(img, size, size))


def paint_needles(name, palette, size=(1024, 512), twig=(0.18, 0.12, 0.07)):
    """Conifer spray: a horizontal twig with side twigs, densely covered in needles pointing forward."""
    S = 2
    W, H = size[0] * S, size[1] * S
    img = _canvas(W, H)
    rnd = np.random.default_rng(77)
    stems = [(np.array([W * 0.02, H * 0.5]), np.array([W * 0.97, H * 0.5 + rnd.uniform(-0.05, 0.05) * H]))]
    for k in range(8):
        t = 0.12 + 0.1 * k
        p = stems[0][0] + (stems[0][1] - stems[0][0]) * t
        side = -1 if k % 2 else 1
        stems.append((p, p + np.array([rnd.uniform(0.12, 0.2) * W, side * rnd.uniform(0.22, 0.36) * H])))
    for p0, p1 in stems:
        _line(img, p0, p1, 4 * S, twig)
    for p0, p1 in stems:
        count = int(np.hypot(*(p1 - p0)) / (3.2 * S))
        ang0 = np.arctan2(p1[1] - p0[1], p1[0] - p0[0])
        for _ in range(count):
            t = rnd.uniform(0, 1)
            a = p0 + (p1 - p0) * t
            for side in (-1, 1):
                ang = ang0 + side * rnd.uniform(0.5, 1.1)
                c = np.array(palette[rnd.integers(len(palette))]) * rnd.uniform(0.8, 1.15)
                _stamp(img, a[0], a[1], ang, rnd.uniform(45, 75) * S * (1.1 - 0.4 * t), 2.2 * S, c, "needle", rib=0.0, back=rnd.uniform(0, 0.3))
    return _save(name, _finish(img, size[0], size[1]))


def paint_grass(name, palette, tip, blades=180, size=(1024, 512)):
    """Strip of grass blades growing from the bottom edge; darker at the roots, lighter at the tips."""
    S = 2
    W, H = size[0] * S, size[1] * S
    img = _canvas(W, H)
    rnd = np.random.default_rng(abs(hash(name)) % 2**32)
    for i in range(blades):
        x = rnd.uniform(0.03, 0.97) * W
        height = rnd.uniform(0.45, 0.97) * H
        lean = rnd.uniform(-0.35, 0.35)
        c = np.array(palette[rnd.integers(len(palette))]) * rnd.uniform(0.8, 1.15)
        tipc = np.array(tip) * rnd.uniform(0.85, 1.1)
        # A blade as 4 stacked tapered segments so it can curve and brighten toward the tip.
        segs = 4
        p = np.array([x, H * 1.0])
        width = rnd.uniform(5, 11) * S
        for s in range(segs):
            t = (s + 1) / segs
            ang = -np.pi / 2 + lean * t * t * 1.6
            L = height / segs
            col = c * (1 - t) + tipc * t
            w0 = width * (1 - s / segs) + 0.5
            _stamp(img, p[0], p[1], ang, L * 1.08, w0, col, "needle" if s < segs - 1 else "blade", rib=0.18)
            p = p + np.array([np.cos(ang), np.sin(ang)]) * L
    return _save(name, _finish(img, size[0], size[1]))


def paint_fern(name, palette, size=(512, 1024)):
    """Single fern frond pointing up: rachis with paired pinnae that shrink toward the tip."""
    S = 2
    W, H = size[0] * S, size[1] * S
    img = _canvas(W, H)
    rnd = np.random.default_rng(55)
    base, tipp = np.array([W * 0.5, H * 0.99]), np.array([W * 0.5, H * 0.03])
    _line(img, base, tipp, 4 * S, (0.16, 0.22, 0.07))
    n = 34
    for i in range(1, n):
        t = i / n
        p = base + (tipp - base) * t
        L = (1 - t) ** 0.8 * 0.46 * W + 0.03 * W
        for side in (-1, 1):
            ang = -np.pi / 2 + side * (1.25 - 0.3 * t)
            c = np.array(palette[rnd.integers(len(palette))]) * rnd.uniform(0.85, 1.1)
            # Pinna: a row of small lobes along a short axis.
            for k in range(7):
                q = p + np.array([np.cos(ang), np.sin(ang)]) * L * (k / 7)
                _stamp(img, q[0], q[1], ang - side * 0.9, L * 0.22, L * 0.07, c, "leaf", rib=0.2)
    return _save(name, _finish(img, size[0], size[1]))


def _value_noise(shape, freq, rnd):
    fy, fx = freq
    grid = rnd.random((fy, fx)).astype(np.float32)
    h, w = shape
    y = np.linspace(0, fy, h, endpoint=False)
    x = np.linspace(0, fx, w, endpoint=False)
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    ty, tx = (y - y0)[:, None], (x - x0)[None, :]
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    y1, x1 = (y0 + 1) % fy, (x0 + 1) % fx
    g = lambda yy, xx: grid[yy][:, xx]
    return (g(y0, x0) * (1 - tx) + g(y0, x1) * tx) * (1 - ty) + (g(y1, x0) * (1 - tx) + g(y1, x1) * tx) * ty


def paint_bark(name, dark, light, size=512):
    """Tileable bark: vertical furrows and plates (colour) plus a matching normal map."""
    rnd = np.random.default_rng(99)
    h = w = size
    n = sum(_value_noise((h, w), (2 ** o * 2, 2 ** o * 12), rnd) / 2 ** o for o in range(4))
    n = (n - n.min()) / (n.max() - n.min())
    plates = _value_noise((h, w), (6, 16), rnd)
    ridge = 1.0 - np.abs(2.0 * n - 1.0)
    height = np.clip(ridge ** 1.6 * 0.8 + plates * 0.35, 0, 1)
    speck = _value_noise((h, w), (64, 64), rnd)
    col = np.array(dark)[None, None] * (1 - height[..., None]) + np.array(light)[None, None] * height[..., None]
    col *= (0.9 + 0.2 * speck)[..., None]
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((h, w, 1), np.float32)], -1)
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 4.0
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 4.0
    nrm = np.stack([-gx, gy, np.ones_like(gx)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    nrm_rgba = np.concatenate([nrm * 0.5 + 0.5, np.ones((h, w, 1), np.float32)], -1)
    return _save(name, rgba), _save(name + "_N", nrm_rgba, "Non-Color")


# ------------------------------------------------------------------------------------------------ materials

def mat_card(name, image, rough=0.7):
    """Alpha-clipped card material: image colour and alpha (flat values are recorded for the exporter too)."""
    mat, nt, b = _new_material(name)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.location = (-500, 0)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = rough
    for key in ("Subsurface Weight", "Transmission Weight"):
        if key in b.inputs:
            b.inputs[key].default_value = 0.0
    try:
        mat.surface_render_method = "DITHERED"
    except Exception:
        pass
    mat.use_backface_culling = False
    mat["kit_card"] = True
    return mat


def mat_bark_textured(name, color_img, normal_img, tint):
    mat, nt, b = _new_material(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.5, 1.5, 0.6)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = color_img
    tex.projection = "BOX"
    tex.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    mix.inputs["B"].default_value = (*tint, 1.0)
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    ntex = nt.nodes.new("ShaderNodeTexImage")
    ntex.image = normal_img
    ntex.projection = "BOX"
    ntex.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], ntex.inputs["Vector"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.92
    mat["kit_bark"] = True
    mat["kit_tint"] = list(tint)
    return mat


def hq_materials():
    oak = paint_leaf_cluster("T_Leaves_Oak", [(0.2, 0.36, 0.09), (0.26, 0.42, 0.1), (0.17, 0.3, 0.07), (0.32, 0.44, 0.12)], "oak")
    bush = paint_leaf_cluster("T_Leaves_Bush", [(0.16, 0.3, 0.08), (0.22, 0.37, 0.1), (0.13, 0.25, 0.07)], "leaf", leaves=340, leaf_len=(50, 85), leaf_w=(16, 24))
    dry = paint_leaf_cluster("T_Leaves_Dry", [(0.45, 0.32, 0.14), (0.52, 0.38, 0.16), (0.36, 0.24, 0.1)], "leaf", leaves=90, leaf_len=(40, 70), leaf_w=(12, 20))
    pine = paint_needles("T_Needles_Pine", [(0.1, 0.22, 0.1), (0.13, 0.27, 0.12), (0.08, 0.18, 0.09)])
    grass = paint_grass("T_Grass_Blades", [(0.17, 0.3, 0.06), (0.2, 0.34, 0.07), (0.14, 0.26, 0.05)], (0.46, 0.55, 0.2))
    dead = paint_grass("T_Grass_Dry", [(0.42, 0.33, 0.15), (0.5, 0.4, 0.18), (0.36, 0.28, 0.12)], (0.7, 0.6, 0.35), blades=150)
    fern = paint_fern("T_Fern_Frond", [(0.15, 0.3, 0.07), (0.19, 0.35, 0.08), (0.13, 0.26, 0.06)])
    bark, bark_n = paint_bark("T_Bark", (0.07, 0.05, 0.035), (0.3, 0.24, 0.17))
    mats = {
        "oak": mat_card("M_Leaves_Oak_01", oak),
        "bush": mat_card("M_Leaves_Bush_01", bush),
        "dry": mat_card("M_Leaves_Dry_01", dry),
        "pine": mat_card("M_Leaves_Pine_01", pine),
        "grass": mat_card("M_Grass_01", grass, 0.8),
        "grass_dead": mat_card("M_Grass_Dead_01", dead, 0.85),
        "fern": mat_card("M_Fern_01", fern),
    }
    mat_bark_textured("M_Bark_Oak_01", bark, bark_n, (1.0, 0.95, 0.9))
    mat_bark_textured("M_Bark_Dead_01", bark, bark_n, (0.85, 0.85, 0.85))
    return mats


# ------------------------------------------------------------------------------------------------ card geometry

class Cards:
    """Accumulates textured quads (with UVs and per-corner custom normals) into one mesh."""

    def __init__(self, name, mat):
        self.name, self.mat = name, mat
        self.verts, self.faces, self.uvs, self.normals = [], [], [], []

    def quad(self, corners, uvs, normals):
        base = len(self.verts)
        self.verts += [tuple(c) for c in corners]
        self.faces.append((base, base + 1, base + 2, base + 3))
        self.uvs += uvs
        self.normals += [tuple(n) for n in normals]

    def strip(self, spine, widths, side, uv_u=(0.0, 1.0), normal_fn=None):
        """Ribbon along spine points (uv v 0->1 along it), `side` a unit vector across."""
        n = len(spine)
        for i in range(n - 1):
            a, b = spine[i], spine[i + 1]
            wa, wb = widths[i], widths[i + 1]
            corners = [a - side * wa, a + side * wa, b + side * wb, b - side * wb]
            va, vb = i / (n - 1), (i + 1) / (n - 1)
            uvs = [(uv_u[0], va), (uv_u[1], va), (uv_u[1], vb), (uv_u[0], vb)]
            normals = [normal_fn(c) for c in corners] if normal_fn else [Vector((0, 0, 1))] * 4
            self.quad(corners, uvs, normals)

    def build(self):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uv.data[li].uv = self.uvs[me.loops[li].vertex_index]
        me.materials.append(self.mat)
        obj = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(obj)
        obj["card_normals"] = [c for n in self.normals for c in n]
        return obj


def _card_facing(p, normal, size, rnd, stretch=1.0):
    """Quad centred on p facing `normal`, randomly rolled; returns corners and UVs."""
    n = normal.normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    right = n.cross(ref).normalized()
    up = right.cross(n).normalized()
    roll = rnd.uniform(0, 2 * math.pi)
    r = right * math.cos(roll) + up * math.sin(roll)
    u = n.cross(r).normalized()
    hw, hh = size * 0.5 * stretch, size * 0.5
    corners = [p - r * hw - u * hh, p + r * hw - u * hh, p + r * hw + u * hh, p - r * hw + u * hh]
    flip = rnd.random() < 0.5
    uvs = [(1, 0), (0, 0), (0, 1), (1, 1)] if flip else [(0, 0), (1, 0), (1, 1), (0, 1)]
    return corners, uvs


def _crown_cards(cards, tips, rnd, per_tip, size, center, up_bias=0.35, spread=0.4):
    """Leaf cluster cards around each twig tip; normals point out of the crown."""
    def out_normal(c):
        return ((c - center).normalized() * (1 - up_bias) + Vector((0, 0, up_bias))).normalized()
    for pts, _ in tips:
        n_pts = len(pts)
        for _ in range(per_tip):
            t = rnd.uniform(0.45, 1.0) * (n_pts - 1)
            i0 = int(t)
            i1 = min(n_pts - 1, i0 + 1)
            anchor = pts[i0].lerp(pts[i1], t - i0) + Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 0.7))) * spread * 0.5
            facing = (anchor - center).normalized() + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(-0.2, 0.8)))
            corners, uvs = _card_facing(anchor, facing, size * rnd.uniform(0.75, 1.25), rnd)
            cards.quad(corners, uvs, [out_normal(c) for c in corners])


def _crown_center(tips):
    pts = [p for pts, _ in tips for p in pts[len(pts) // 2:]]
    c = sum(pts, Vector()) / max(1, len(pts))
    return c


def _finish_hq(name, wood_parts, card_objs, ucx=(), smooth=50, location=None):
    """UV and finalize the wood, then attach the cards (keeping their UVs) and apply the card custom normals."""
    wood = join(name, wood_parts) if wood_parts else None
    if wood is not None:
        smart_uv(wood)
        finalize(wood, "BASE", smooth)
    parts = ([wood] if wood else []) + card_objs
    normals_by_obj = [(o, list(o.get("card_normals", []))) for o in card_objs]
    base_corner_normals = []
    if wood is not None:
        wood.data.update()
        base_corner_normals = [tuple(cn.vector) for cn in wood.data.corner_normals]
    # Card vertices are exported one per corner, so their normals map straight onto loops in order.
    card_loop_normals = []
    for o, flat in normals_by_obj:
        vn = [Vector(flat[i:i + 3]) for i in range(0, len(flat), 3)]
        for poly in o.data.polygons:
            for li in poly.loop_indices:
                card_loop_normals.append(tuple(vn[o.data.loops[li].vertex_index]))
    if wood is None:
        obj = join(name, card_objs)
        obj.location = (0, 0, 0)
    else:
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = wood
        bpy.ops.object.join()
        obj = wood
    obj.name = name
    obj.data.name = name
    # The wood's loops come first after the join, then each card object's in order.
    loops = base_corner_normals + card_loop_normals
    if len(loops) == len(obj.data.loops):
        obj.data.normals_split_custom_set([Vector(n).normalized() for n in loops])
    if wood is None:
        mn_z = min(v.co.z for v in obj.data.vertices)
        obj.data.transform(Matrix.Translation((0, 0, -mn_z)))
    link_only(obj, NC)
    for i, (size, center) in enumerate(ucx):
        ucx_box(obj, size, center, i)
    for c in obj.children:
        if c.name.startswith("UCX_"):
            c.hide_set(True)
    if "card_normals" in obj:
        del obj["card_normals"]
    if location is not None:
        obj.location = location
    return obj


def _old_location(name):
    o = bpy.data.objects.get(name)
    return o.location.copy() if o else None


# ------------------------------------------------------------------------------------------------ assets

def hq_oak(name, seed, height=4.3, radius=0.46, per_tip=4, card=1.0, cfg_over=None, mat_key="oak"):
    loc = _old_location(name)
    remove_asset(name)
    rnd = random.Random(seed)
    cfg = dict(OAK_CFG)
    cfg.update(cfg_over or {})
    wood, tips = [], []
    _grow(wood, tips, (0, 0, -0.1), (rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 1), height, radius, 0, rnd, name, M("Bark"), cfg)
    _roots(wood, name, M("Bark"), rnd, rnd.randint(5, 8), 1.2 * radius / 0.46, radius * 0.48, 0.35)
    cards = Cards(f"{name}_cards", HQ[mat_key])
    _crown_cards(cards, tips, rnd, per_tip, card, _crown_center(tips))
    return _finish_hq(name, wood, [cards.build()], [((radius * 2.2, radius * 2.2, height * 0.8), (0, 0, height * 0.4))], location=loc)


def hq_pine(name, seed, height=14.0):
    loc = _old_location(name)
    remove_asset(name)
    rnd = random.Random(seed)
    wood = []
    trunk = [Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), z)) for z in [height * t for t in (0, 0.2, 0.45, 0.7, 0.9, 1.0)]]
    wood.append(tube_along(f"{name}_trunk", trunk, [0.32 * height / 14 + 0.06, 0.26 * height / 14 + 0.04, 0.19 * height / 14 + 0.03, 0.12 * height / 14 + 0.02, 0.05, 0.01], M("Bark"), sides=14, twist_noise=0.05, seed=seed))
    _roots(wood, name, M("Bark"), rnd, 6, 0.9, 0.15, 0.25)
    cards = Cards(f"{name}_cards", HQ["pine"])
    axis_top = height

    def normal_fn(c):
        radial = Vector((c.x, c.y, 0))
        radial = radial.normalized() if radial.length > 1e-3 else Vector((1, 0, 0))
        return (radial * 0.7 + Vector((0, 0, 0.55))).normalized()

    z = height * 0.18
    while z < height * 0.96:
        t = (z - height * 0.18) / (height * 0.78)
        n = rnd.randint(6, 8)
        length = (1 - t) ** 0.85 * height * 0.26 + 0.35
        ph = rnd.uniform(0, 2 * math.pi)
        for k in range(n):
            a = ph + 2 * math.pi * k / n + rnd.uniform(-0.2, 0.2)
            d = Vector((math.cos(a), math.sin(a), 0))
            spine = []
            for j in range(6):
                s = j / 5
                spine.append(Vector((0, 0, z)) + d * (0.08 + length * s) + Vector((0, 0, 0.12 * s - 0.5 * s * s * length / 3)))
            wood.append(tube_along(f"{name}_br", spine, [0.05 * (1 - t) + 0.02, 0.035, 0.025, 0.017, 0.01, 0.004], M("Bark"), sides=5))
            side = d.cross(Vector((0, 0, 1))).normalized()
            width = 0.28 * length / 3 + 0.3
            # Two overlapping sprays per branch, rolled apart, and a third drooping under it.
            for roll, drop in ((0.35, 0.0), (-0.35, 0.05), (0.0, 0.18)):
                s_vec = (side * math.cos(roll) + Vector((0, 0, 1)) * math.sin(roll)).normalized()
                pts = [p - Vector((0, 0, drop)) for p in spine]
                widths = [width * (0.55 + 0.45 * math.sin(math.pi * min(1.0, j / 4.5 + 0.1))) for j in range(len(pts))]
                cards.strip(pts, widths, s_vec, (0.0, 1.0), normal_fn)
        z += rnd.uniform(0.45, 0.7) * max(0.6, height / 14)
    # Crown tip: crossed sprays around the leader.
    for k in range(4):
        a = k * math.pi / 4
        side = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, axis_top * 0.88 + axis_top * 0.12 * j / 4)) for j in range(5)]
        cards.strip(pts, [0.5, 0.42, 0.3, 0.18, 0.05], side, (0.0, 1.0), normal_fn)
    return _finish_hq(name, wood, [cards.build()], [((0.7, 0.7, height * 0.8), (0, 0, height * 0.4))], location=loc)


def hq_bush(name, seed, dead=False, size=1.2):
    loc = _old_location(name)
    remove_asset(name)
    rnd = random.Random(seed)
    wood, tips = [], []
    cfg = dict(gravity=0.05, wobble=0.35, trunk_wobble=0.3, up=0.1, taper=0.4, max_depth=2, spread=0.6,
               children=[(3, 4), (2, 3)], length_ratio=(0.5, 0.7), first_fork=0.2, min_radius=0.004, leader=False)
    for k in range(rnd.randint(7, 10)):
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1))
        _grow(wood, tips, Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0)), d, size * rnd.uniform(0.6, 1.0), 0.025, 0, rnd, name, M("DeadBark") if dead else M("Bark"), cfg)
    cards = Cards(f"{name}_cards", HQ["dry" if dead else "bush"])
    _crown_cards(cards, tips, rnd, 1 if dead else 4, 0.45 * size, _crown_center(tips) - Vector((0, 0, 0.2)), up_bias=0.5, spread=0.35)
    return _finish_hq(name, wood, [cards.build()], location=loc)


def hq_grass(name, seed, height, count, mat_key, width=(0.45, 0.8)):
    loc = _old_location(name)
    remove_asset(name)
    rnd = random.Random(seed)
    cards = Cards(f"{name}_cards", HQ[mat_key])
    up = lambda c: Vector((0, 0, 1))
    for i in range(count):
        a = rnd.uniform(0, math.pi)
        side = Vector((math.cos(a), math.sin(a), 0))
        out = Vector((-side.y, side.x, 0)) * rnd.choice([-1, 1])
        base = Vector((rnd.gauss(0, 0.12), rnd.gauss(0, 0.12), -0.02))
        h = height * rnd.uniform(0.75, 1.2)
        lean = rnd.uniform(0.05, 0.3)
        spine = [base + Vector((0, 0, h * t)) + out * lean * h * t * t for t in (0, 0.5, 1.0)]
        w = rnd.uniform(*width) * 0.5
        u0 = rnd.choice([0.0, 0.5])
        cards.strip(spine, [w, w * 0.97, w * 0.92], side, (u0, u0 + 0.5), up)
    return _finish_hq(name, [], [cards.build()], location=loc)


def hq_fern(name, seed, fronds=12):
    loc = _old_location(name)
    remove_asset(name)
    rnd = random.Random(seed)
    cards = Cards(f"{name}_cards", HQ["fern"])
    for f in range(fronds):
        a = 2 * math.pi * f / fronds + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        L = rnd.uniform(0.7, 1.05)
        rise = rnd.uniform(0.35, 0.6)
        spine = [d * (L * t) + Vector((0, 0, rise * math.sin(math.pi * t * 0.75) - 0.12 * t * t)) for t in [i / 6 for i in range(7)]]
        normal_fn = lambda c, d=d: (Vector((0, 0, 1)) + d * 0.3).normalized()
        cards.strip(spine, [0.05, 0.16, 0.2, 0.19, 0.15, 0.09, 0.02], side, (0.0, 1.0), normal_fn)
    return _finish_hq(name, [], [cards.build()], location=loc)


def build_nature_hq():
    """Paints the textures, rebuilds the foliage materials and every foliage asset. Returns [(name, tris)]."""
    global HQ
    nature_materials()
    HQ = hq_materials()
    jobs = [
        lambda: hq_oak("SM_Tree_Oak_01", 11, 4.3, 0.46, 4, 1.1),
        lambda: hq_oak("SM_Tree_Oak_02", 12, 4.8, 0.5, 4, 1.15, dict(spread=0.72)),
        lambda: hq_oak("SM_Tree_Oak_03", 13, 3.6, 0.4, 5, 1.0, dict(spread=0.9, length_ratio=(0.66, 0.85))),
        lambda: hq_oak("SM_Tree_Oak_Ancient_01", 14, 3.4, 0.85, 5, 1.3, dict(spread=0.95, gravity=0.08, trunk_wobble=0.25, length_ratio=(0.7, 0.9))),
        lambda: hq_oak("SM_Tree_Small_Forest_01", 15, 3.2, 0.14, 5, 0.8, dict(max_depth=3, children=[(3, 4), (2, 3), (2, 2)], spread=0.55)),
        lambda: hq_oak("SM_Tree_Small_Forest_02", 16, 2.6, 0.12, 5, 0.75, dict(max_depth=3, children=[(2, 3), (2, 3), (2, 2)], spread=0.6)),
        lambda: hq_pine("SM_Tree_Pine_01", 801, 14.0),
        lambda: hq_pine("SM_Tree_Pine_02", 802, 11.0),
        lambda: hq_pine("SM_Tree_Pine_Young_01", 803, 5.5),
        lambda: hq_bush("SM_Bush_01", 861),
        lambda: hq_bush("SM_Bush_02", 862, size=0.9),
        lambda: hq_bush("SM_Bush_Dead_01", 863, dead=True),
        lambda: hq_fern("SM_Fern_01", 861, 13),
        lambda: hq_fern("SM_Fern_02", 871, 9),
        lambda: hq_grass("SM_Grass_Tall_01", 881, 0.9, 16, "grass"),
        lambda: hq_grass("SM_Grass_Short_01", 882, 0.38, 14, "grass", (0.35, 0.6)),
        lambda: hq_grass("SM_Grass_Dead_01", 883, 0.8, 14, "grass_dead"),
    ]
    out = []
    for job in jobs:
        o = job()
        out.append((o.name, tris(o)))
    return out

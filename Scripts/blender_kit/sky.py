"""ENV_Sky: sky meshes (moons, cloud banks, star dome, lightning bolt) and Blender World look-dev presets that mirror
Scripts/atmosphere_presets.json. exec() after kitlib."""
import json

V = Vector
SC = "ENV_Sky"


def build_moon(name="SM_Sky_Moon_01", seed=2001, blood=False):
    """Moon disc-sphere with craters and maria (vertex displacement), unlit emissive material for the sky."""
    remove_asset(name)
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=6, radius=1.0)
    craters = [(V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized(), rnd.uniform(0.05, 0.25)) for _ in range(45)]
    for v in bm.verts:
        d = 0.0
        n = v.co.normalized()
        for c, r in craters:
            ang = n.angle(c)
            if ang < r * 1.3:
                t = ang / r
                d += (-0.04 * (1 - t * t) if t < 1 else 0.015 * (1.3 - t) / 0.3) * r * 3
        d += noise.noise(n * 3 + V((seed, 0, 0))) * 0.01
        v.co = n * (1 + d)
    col = (1.0, 0.25, 0.12) if blood else (0.8, 0.82, 0.9)
    mat = bpy.data.materials.get("M_Sky_Moon_Blood_01" if blood else "M_Sky_Moon_01")
    if mat is None:
        mat, nt, b = _new_material("M_Sky_Moon_Blood_01" if blood else "M_Sky_Moon_01")
        vec = _coords(nt, 1.0)
        n1 = _noise(nt, vec, 2.5, 6, 0.6)
        ramp = _ramp(nt, [(0.35, tuple(c * 0.45 for c in col)), (0.6, col)])
        nt.links.new(n1.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 3.0 if blood else 2.0
        b.inputs["Roughness"].default_value = 1.0
    o = _obj_from_bm(name, bm, mat)
    o.scale = (50, 50, 50)
    return finish_asset(name, [o], SC, [], lods=False, origin=None, smooth=80)


def build_cloud_bank(name="SM_Sky_CloudBank_01", seed=2011, length=400.0):
    """Distant cumulus bank for horizon silhouettes (behind volumetric clouds / for low-spec): merged puffy lobes."""
    remove_asset(name)
    rnd = random.Random(seed)
    parts = []
    mat = bpy.data.materials.get("M_Sky_Cloud_01")
    if mat is None:
        mat, nt, b = _new_material("M_Sky_Cloud_01")
        b.inputs["Base Color"].default_value = (0.85, 0.87, 0.9, 1)
        b.inputs["Roughness"].default_value = 1.0
        if "Subsurface Weight" in b.inputs:
            b.inputs["Subsurface Weight"].default_value = 0.5
    x = -length / 2
    while x < length / 2:
        s = rnd.uniform(15, 40)
        r = rock(f"{name}_puff", (s, s * 0.7, s * 0.6), seed=rnd.randint(0, 99999), mat=mat, subdiv=3, roughness=0.0, flatten=0.9)
        r.location = (x, rnd.uniform(-10, 10), s * 0.3 + rnd.uniform(0, 15))
        parts.append(r)
        x += s * rnd.uniform(0.6, 1.0)
    return finish_asset(name, parts, SC, [], lods=False, smooth=80)


def build_star_dome(name="SM_Sky_StarDome_01", seed=2021, radius=900.0):
    """Hemisphere of tiny emissive quads (stars) with a denser milky band — for Night / BloodMoon presets."""
    remove_asset(name)
    rnd = random.Random(seed)
    mat = bpy.data.materials.get("M_Sky_Star_01") or mat_emissive("M_Sky_Star_01", (0.9, 0.92, 1.0), 20.0, transmission=0.0)
    bm = bmesh.new()
    for i in range(6000):
        band = rnd.random() < 0.45
        if band:
            a = rnd.uniform(0, 2 * math.pi)
            e = rnd.gauss(0.6, 0.12)
            d = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), abs(math.sin(e))))
            d = (Matrix.Rotation(0.5, 3, "X") @ d)
        else:
            d = V((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1))))
        d.normalize()
        if d.z < 0.02:
            continue
        c = d * radius
        s = rnd.uniform(0.4, 1.6) * (2.5 if rnd.random() < 0.02 else 1.0)
        t1 = d.cross(V((0, 0, 1))).normalized() * s
        t2 = d.cross(t1).normalized() * s
        vs = [bm.verts.new(c + t1), bm.verts.new(c + t2), bm.verts.new(c - t1), bm.verts.new(c - t2)]
        bm.faces.new(vs)
    o = _obj_from_bm(name, bm, mat)
    return finish_asset(name, [o], SC, [], lods=False, origin=None, smooth=0)


def build_lightning_bolt(name="SM_Sky_LightningBolt_01", seed=2031, height=300.0):
    """Branching lightning bolt mesh (emissive) for storm flashes; spawn/fade it from gameplay or Sequencer."""
    remove_asset(name)
    rnd = random.Random(seed)
    mat = bpy.data.materials.get("M_Lightning_Glow_01") or mat_emissive("M_Lightning_Glow_01", (0.25, 0.5, 1.0), 2.5, transmission=0.3)
    parts = []

    def bolt(start, direction, length, width, depth):
        pts = [start]
        d = direction.normalized()
        steps = int(length / 8) + 2
        for i in range(steps):
            d = (d + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))).normalized()
            d.z = -abs(d.z) - 0.6
            d.normalize()
            pts.append(pts[-1] + d * (length / steps))
        parts.append(tube_along(f"{name}_seg", pts, [width * (1 - i / (len(pts))) + 0.05 for i in range(len(pts))], mat, sides=4))
        if depth < 3:
            for k in range(rnd.randint(1, 3)):
                idx = rnd.randint(1, len(pts) - 2)
                bolt(pts[idx], V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), -1)), length * 0.4, width * 0.5, depth + 1)

    bolt(V((0, 0, height)), V((0, 0, -1)), height, 1.2, 0)
    return finish_asset(name, parts, SC, [], lods=False, origin=None, smooth=0)


def build_world_presets(json_path=r"D:/dev/nameless-mmo/Scripts/atmosphere_presets.json"):
    """One Blender World per preset (sky gradient from the fog/sun colors + sun strength) for look-dev renders."""
    presets = json.load(open(json_path, encoding="utf8"))
    made = []
    for key, p in presets.items():
        if key.startswith("_"):
            continue
        w = bpy.data.worlds.get(f"W_{key}") or bpy.data.worlds.new(f"W_{key}")
        w.use_nodes = True
        w.use_fake_user = True
        nt = w.node_tree
        for n in list(nt.nodes):
            if n.type not in ("OUTPUT_WORLD", "BACKGROUND"):
                nt.nodes.remove(n)
        bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
        grad = nt.nodes.new("ShaderNodeTexGradient")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        fog = p["fog"]["color"]
        sun = p["sun"]["color"]
        horizon = tuple(min(1, f * 0.7 + s * 0.3) for f, s in zip(fog, sun))
        zenith = tuple(f * 0.35 for f in fog)
        ramp.color_ramp.elements[0].position = 0.5
        ramp.color_ramp.elements[0].color = (*horizon, 1)
        ramp.color_ramp.elements[1].position = 0.8
        ramp.color_ramp.elements[1].color = (*zenith, 1)
        nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.4 + p["sky_light_intensity"] * 0.6
        made.append(w.name)
    return made


def build_sky_batch():
    out = []
    for fn, loc in ((lambda: build_moon(), (0, 700, 300)), (lambda: build_moon("SM_Sky_Moon_Blood_01", 2002, blood=True), (150, 700, 300)),
                    (lambda: build_cloud_bank(), (0, 900, 60)), (lambda: build_cloud_bank("SM_Sky_CloudBank_02", 2012, 300), (0, -900, 60)),
                    (lambda: build_star_dome(), (0, 0, 0)), (lambda: build_lightning_bolt(), (300, 600, 0))):
        o = fn(); o.location = loc; out.append((o.name, tris(o)))
        o.hide_set(True)  # huge sky meshes stay hidden in the working viewport
    out.append(("worlds", build_world_presets()))
    return out

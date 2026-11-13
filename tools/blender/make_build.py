"""Cekic (Poly Haven wooden_hammer_01, CC0, James Ray Cock), golge agaci ve kamis (Blender'da modellendi).
Agac kabugu: Poly Haven bark_willow (CC0, Rob Tuytel) diffuse 1k; yaprak dokusu betikle uretilen alfa kanalli PNG.
  blender -b -P tools/blender/make_build.py -- --hammer-src <klasor> --bark <bark_willow_diff_1k.jpg> --out-build assets/models/build
      --out-tools assets/models/tools --tmp <gecici klasor> [--only hammer,tree,reeds] [--png-dir k]
--hammer-src icinde wooden_hammer_01/wooden_hammer_01.gltf + .bin + textures/wooden_hammer_01_diff_1k.jpg olmali.
Cerceve: metre, Blender Z yukari (glb'de Y yukari). Orijin zeminde / sapin tutulan noktasinda.
"""
import json
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *  # noqa
import numpy as np

ONLY = arg("--only").split(",") if arg("--only") else ["hammer", "tree", "reeds"]
TMP = arg("--tmp", ".")
PNG = arg("--png-dir")
OUT_B = arg("--out-build", "assets/models/build")
OUT_T = arg("--out-tools", "assets/models/tools")


def patch_glb(path, alpha_mats=(), double_sided=()):
    """glb JSON'unda malzeme alfa kipini MASK (kesme 0,5) yapar, cift tarafli isaretler."""
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack("<4sII", data[:12])
    clen, ctype = struct.unpack("<II", data[12:20])
    js = json.loads(data[20:20 + clen].decode("utf-8"))
    rest = data[20 + clen:]
    for m in js.get("materials", []):
        if m.get("name") in alpha_mats:
            m["alphaMode"] = "MASK"
            m["alphaCutoff"] = 0.5
        if m.get("name") in double_sided or m.get("name") in alpha_mats:
            m["doubleSided"] = True
    nj = json.dumps(js, separators=(",", ":")).encode("utf-8")
    nj += b" " * ((4 - len(nj) % 4) % 4)
    out = struct.pack("<4sII", magic, ver, 12 + 8 + len(nj) + len(rest)) + struct.pack("<II", len(nj), ctype) + nj + rest
    open(path, "wb").write(out)


def new_obj(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        set_material(ob, mat)
    return ob


# ------------------------------------------------------------------ cekic
def build_hammer():
    objs = import_ph(arg("--hammer-src"), "wooden_hammer_01")
    h = objs[0]
    # ham: sap Z (uzunluk 0,279), bas ustte, bas uzun ekseni X. Vurus yuzu: X ucu -> Blender +Y (glTF -Z).
    decimate(h, 1300)
    s = 0.35 / 0.2792
    z_bot = -0.1239
    z_head = 0.094
    origin_z = z_bot + (z_head - z_bot) / 3.0
    M = Matrix.Rotation(-math.pi / 2, 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -origin_z))
    transform_mesh(h, M)
    h.name = h.data.name = "Hammer"
    set_material(h, tex_material("Wood", diffuse_path(arg("--hammer-src"), "wooden_hammer_01")))
    finish_mesh(h)
    return [h]


# ------------------------------------------------------------------ yaprak dokusu
def make_leaf_png(path, size=1024, seed=5):
    rnd = np.random.default_rng(seed)
    img = np.zeros((size, size, 4), dtype=np.float32)
    leaves = []
    for _ in range(330):
        r = 0.43 * size * math.sqrt(rnd.random()) ** 1.0
        a = rnd.random() * 2 * math.pi
        cx, cy = size / 2 + r * math.cos(a) * 0.95, size / 2 + r * math.sin(a)
        ang = rnd.normal(math.pi / 2, 0.9)       # genelde asagi dogru sarkar
        L = rnd.uniform(78, 120)
        W = L * rnd.uniform(0.26, 0.36)
        leaves.append((cy, cx, ang, L, W))
    leaves.sort(key=lambda t: rnd.random())
    for cy, cx, ang, L, W in leaves:
        win = int(L * 1.1)
        y0, y1 = int(max(0, cy - win)), int(min(size, cy + win))
        x0, x1 = int(max(0, cx - win)), int(min(size, cx + win))
        if y1 <= y0 or x1 <= x0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        dx, dy = xx - cx, yy - cy
        ca, sa = math.cos(ang), math.sin(ang)
        t = (dx * ca + dy * sa) / (L / 2)          # -1..1 boyunca
        b = (-dx * sa + dy * ca)
        wt = W / 2 * np.clip(1 - np.abs(t) ** 2.2, 0, 1) ** 0.7 * (1.0 - 0.15 * t)
        m = (np.abs(t) <= 1) & (np.abs(b) <= wt) & (wt > 0.6)
        if not m.any():
            continue
        tone = rnd.uniform(0.0, 1.0)
        base = np.array([0.20 + 0.14 * tone, 0.40 + 0.20 * tone, 0.07 + 0.05 * tone])
        edge = np.clip(np.abs(b) / np.maximum(wt, 1e-3), 0, 1)
        shade = (0.78 + 0.35 * (1 - edge) * (0.6 + 0.4 * (t * 0.5 + 0.5)))
        midrib = np.exp(-(b / 1.4) ** 2) * 0.22
        shade = shade + midrib
        # kumedeki genel yukseklik: ust yapraklar acik, alt koyu
        vgrad = 0.72 + 0.5 * (1 - cy / size)
        col = base[None, None, :] * (shade * vgrad)[:, :, None]
        sub = img[y0:y1, x0:x1]
        sub[m, :3] = col[m]
        sub[m, 3] = 1.0
    # cekirdek rengi dusuk alanlari doldur: alfa 0 yerde renk komsu yesil (mip kenar sorunu)
    mask = img[:, :, 3] > 0
    avg = img[mask, :3].mean(axis=0)
    img[~mask, :3] = avg
    img = np.clip(img, 0, 1)
    im = bpy.data.images.new("leaf_tmp", size, size, alpha=True)
    im.pixels.foreach_set(np.flipud(img).reshape(-1))
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def make_reed_png(path, size=256):
    img = np.zeros((size, size, 3), dtype=np.float32)
    v = np.linspace(0, 1, size)[:, None]
    u = np.linspace(0, 1, size)[None, :]
    rnd = np.random.default_rng(2)
    # sol yari: sap yesili (tabandan uca koyudan sarimsiya), orta damar
    g0 = np.array([0.20, 0.34, 0.10])
    g1 = np.array([0.58, 0.62, 0.22])
    left = g0[None, None, :] * (1 - v[:, :, None]) + g1[None, None, :] * v[:, :, None]
    uu = (u * 2)
    vein = np.exp(-((uu - 0.5) / 0.04) ** 2) * 0.12
    left = left + vein[:, :, None] + rnd.normal(0, 0.012, (size, size, 1))
    # sag yari: kahverengi tokmak
    br = np.array([0.30, 0.17, 0.08])
    noise = rnd.normal(0, 0.03, (size, size, 1)) + 0.04 * np.sin(v * 90)[:, :, None]
    right = br[None, None, :] * (0.85 + 0.3 * (1 - np.abs(u * 2 - 1.5)))[:, :, None] + noise
    img[:, :size // 2] = left[:, :size // 2]
    img[:, size // 2:] = right[:, size // 2:]
    img = np.clip(img, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = img
    im = bpy.data.images.new("reed_tmp", size, size, alpha=False)
    im.pixels.foreach_set(np.flipud(rgba).reshape(-1))
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


# ------------------------------------------------------------------ boru (dal / govde)
def tube(bm, pts, radii, sides, uv_scale=(1.0, 1.0), v0=0.0):
    """pts: omurga noktalari; radii: her nokta icin. Uc kapakli degil (alt yer altinda, uc incelir)."""
    uvl = bm.loops.layers.uv.verify()
    rings = []
    for i, p in enumerate(pts):
        p = Vector(p)
        if i < len(pts) - 1:
            t = (Vector(pts[i + 1]) - p).normalized()
        else:
            t = (p - Vector(pts[i - 1])).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.95 else Vector((1, 0, 0))
        n1 = t.cross(ref).normalized()
        n2 = t.cross(n1).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + (n1 * math.cos(a) + n2 * math.sin(a)) * radii[i]))
        rings.append(ring)
    dist = [0.0]
    for i in range(1, len(pts)):
        dist.append(dist[-1] + (Vector(pts[i]) - Vector(pts[i - 1])).length)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            for loop, (uu, vv) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                loop[uvl].uv = (uu / sides * uv_scale[0], (v0 + dist[vv]) * uv_scale[1])
    # uc kapagi (ince uc) tek yuzle
    f = bm.faces.new(rings[-1][::-1])
    for loop in f.loops:
        loop[uvl].uv = (0.5, (v0 + dist[-1]) * uv_scale[1])
    return rings


# ------------------------------------------------------------------ agac
def build_tree():
    rnd = random.Random(21)
    leaf_png = os.path.join(TMP, "leaf_cluster.png")
    make_leaf_png(leaf_png)
    mat_bark = tex_material("Bark", arg("--bark"), 0.95)
    mat_leaf = tex_material("Leaves", leaf_png, 0.8)
    mat_leaf.node_tree.links.new(mat_leaf.node_tree.nodes["Image Texture"].outputs["Alpha"],
                                 mat_leaf.node_tree.nodes["Principled BSDF"].inputs["Alpha"])
    mat_leaf.use_backface_culling = False
    bark = bmesh.new()
    # govde: hafif egri, taban genis
    trunk_pts = [(0.0, 0.0, -0.1), (0.02, 0.0, 0.25), (0.05, 0.03, 0.7), (0.0, 0.06, 1.2), (-0.06, 0.04, 1.7), (-0.05, 0.0, 2.1)]
    trunk_r = [0.44, 0.30, 0.235, 0.205, 0.18, 0.15]
    tube(bark, trunk_pts, trunk_r, 9, (1.3, 0.9))
    # ana dallar
    crown_c = Vector((0.0, 0.0, 3.35))
    branch_tips = []
    nb = 6
    for i in range(nb):
        a = 2 * math.pi * (i + rnd.uniform(-0.15, 0.15)) / nb
        start = Vector((-0.05, 0.0, 1.85 + rnd.uniform(-0.05, 0.25)))
        reach = rnd.uniform(1.25, 1.65)
        top = rnd.uniform(3.0, 3.7)
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = start
        p1 = start + d * 0.35 + Vector((0, 0, 0.55))
        p2 = start + d * (reach * 0.65) + Vector((0, 0, (top - start.z) * 0.72))
        p3 = start + d * reach + Vector((0, 0, top - start.z))
        pts = [p0, p1, p2, p3]
        tube(bark, pts, [0.12, 0.095, 0.065, 0.035], 6, (1.0, 0.9), v0=2.0)
        branch_tips.append(p3)
        # yan dallar
        for _ in range(2):
            t = rnd.uniform(0.45, 0.75)
            base = p1.lerp(p2, t)
            a2 = a + rnd.uniform(-0.9, 0.9)
            d2 = Vector((math.cos(a2), math.sin(a2), rnd.uniform(0.25, 0.8))).normalized()
            q = [base, base + d2 * 0.4, base + d2 * 0.8 + Vector((0, 0, 0.1))]
            tube(bark, q, [0.045, 0.032, 0.015], 4, (1.0, 0.9), v0=1.0)
            branch_tips.append(q[-1])
    trunk = new_obj("Trunk", bark, mat_bark)
    finish_mesh(trunk)
    # yaprak kumeleri: capraz iki kart
    lv = bmesh.new()
    uvl = lv.loops.layers.uv.verify()
    normals_src = []
    N_CL = 330
    centers = []
    for i in range(N_CL):
        # taca dagilim: yassi elipsoit + uca yakin sarkma
        while True:
            v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
            if v.length <= 1.0:
                break
        r = v.length
        p = Vector((v.x * 2.05, v.y * 2.05, 0.0))
        horiz = math.hypot(p.x, p.y) / 2.05
        zc = 3.45 + v.z * 1.0 * (1.0 - 0.25 * horiz) - 0.55 * horiz ** 2.5
        p.z = zc
        if zc > 4.45:
            p.z = 4.45 - rnd.uniform(0, 0.1)
        centers.append(p)
    for c in centers:
        size = rnd.uniform(0.95, 1.3)
        yaw = rnd.uniform(0, math.pi)
        tilt = rnd.uniform(-0.5, 0.5)
        out = (c - crown_c)
        out = out.normalized() if out.length > 1e-3 else Vector((0, 0, 1))
        for k in range(2):
            ang = yaw + k * math.pi / 2
            ux = Vector((math.cos(ang), math.sin(ang), 0))
            uy = Vector((-math.sin(ang) * math.sin(tilt) * 0.0, 0, 1))
            if k == 0:
                uvec = ux * size
                vvec = Vector((0, 0, 1)).lerp(Vector((math.cos(ang + 1.57) * 0.6, math.sin(ang + 1.57) * 0.6, 0)), tilt).normalized() * size
            else:
                uvec = ux * size
                vvec = Vector((0.0, 0.0, 1.0)) * size
                vvec = (Vector((math.cos(ang + 1.57) * 0.9 * (-tilt), math.sin(ang + 1.57) * 0.9 * (-tilt), 1.0))).normalized() * size
            quad = [c - uvec / 2 - vvec / 2, c + uvec / 2 - vvec / 2, c + uvec / 2 + vvec / 2, c - uvec / 2 + vvec / 2]
            vs = [lv.verts.new(q) for q in quad]
            f = lv.faces.new(vs)
            for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[uvl].uv = uv
            normals_src.append(out)
    leaves = new_obj("Leaves", lv, mat_leaf)
    # normaller: tacin merkezinden disa (yumusak aydinlatma)
    try:
        me = leaves.data
        nrm = []
        cen = crown_c
        for v in me.vertices:
            d = (v.co - cen)
            d = Vector((d.x, d.y, d.z * 0.7))
            nrm.append(d.normalized() if d.length > 1e-3 else Vector((0, 0, 1)))
        me.normals_split_custom_set_from_vertices(nrm)
    except Exception as e:  # noqa
        log("ozel normal uygulanamadi:", e)
    return [trunk, leaves]


# ------------------------------------------------------------------ kamis
def build_reeds(png):
    rnd = random.Random(8)
    mat = tex_material("Reeds", png, 0.85)
    mat.use_backface_culling = False
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    NB = 33
    for i in range(NB):
        a = rnd.uniform(0, 2 * math.pi)
        r = 0.28 * math.sqrt(rnd.random())
        base = Vector((r * math.cos(a), r * math.sin(a), -0.02))
        H = rnd.uniform(1.2, 1.5)
        lean_a = a + rnd.uniform(-0.5, 0.5)
        lean = rnd.uniform(0.05, 0.18) * (0.4 + r / 0.28)
        bend = Vector((math.cos(lean_a), math.sin(lean_a), 0))
        facing = rnd.uniform(0, math.pi)
        side = Vector((math.cos(facing), math.sin(facing), 0))
        W = rnd.uniform(0.022, 0.032)
        pts = []
        for k, t in enumerate((0.0, 0.34, 0.68, 1.0)):
            p = base + bend * (lean * t * t * 1.2) + Vector((0, 0, H * t * (1 - 0.04 * t * lean)))
            pts.append(p)
        rows = []
        for k, p in enumerate(pts[:-1]):
            w = W * (1.0 - 0.18 * k)
            rows.append((bm.verts.new(p - side * w), bm.verts.new(p + side * w)))
        tip = bm.verts.new(pts[-1])
        for k in range(len(rows) - 1):
            f = bm.faces.new((rows[k][0], rows[k][1], rows[k + 1][1], rows[k + 1][0]))
            v0, v1 = k / 3.0, (k + 1) / 3.0
            for loop, uv in zip(f.loops, ((0.1, v0), (0.4, v0), (0.4, v1), (0.1, v1))):
                loop[uvl].uv = uv
        f = bm.faces.new((rows[-1][0], rows[-1][1], tip))
        for loop, uv in zip(f.loops, ((0.1, 0.67), (0.4, 0.67), (0.25, 1.0))):
            loop[uvl].uv = uv
    # kahverengi saz basi (tokmak) olan birkac sap
    heads = 4
    for i in range(heads):
        a = rnd.uniform(0, 2 * math.pi) + i * 1.5
        r = rnd.uniform(0.04, 0.2)
        base = Vector((r * math.cos(a), r * math.sin(a), -0.02))
        H = rnd.uniform(1.15, 1.35)
        d = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.03, 0.08)
        stem = [base, base + d * 0.3 + Vector((0, 0, H * 0.5)), base + d * 0.7 + Vector((0, 0, H * 0.82)), base + d + Vector((0, 0, H * 0.97))]
        rings = []
        for k, p in enumerate(stem):
            ring = []
            for s in range(3):
                ang = 2 * math.pi * s / 3
                ring.append(bm.verts.new(p + Vector((math.cos(ang), math.sin(ang), 0)) * 0.009))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for s in range(3):
                s2 = (s + 1) % 3
                f = bm.faces.new((rings[k][s], rings[k][s2], rings[k + 1][s2], rings[k + 1][s]))
                for loop in f.loops:
                    loop[uvl].uv = (0.2, 0.3)
        # tokmak: kapsul (6 kenar, 2 halka + uclar)
        top = stem[-1]
        z0, z1 = top.z - 0.02, top.z + 0.16
        prof = [(0.0, z0 - 0.02), (0.022, z0 + 0.01), (0.026, (z0 + z1) / 2), (0.020, z1 - 0.02), (0.0, z1 + 0.025)]
        hr = []
        for (rr, zz) in prof:
            if rr == 0.0:
                hr.append([bm.verts.new((top.x, top.y, zz))])
            else:
                hr.append([bm.verts.new((top.x + rr * math.cos(2 * math.pi * s / 6), top.y + rr * math.sin(2 * math.pi * s / 6), zz)) for s in range(6)])
        for k in range(len(hr) - 1):
            A, B = hr[k], hr[k + 1]
            for s in range(6):
                s2 = (s + 1) % 6
                if len(A) == 1:
                    f = bm.faces.new((A[0], B[s2], B[s]))
                elif len(B) == 1:
                    f = bm.faces.new((A[s], A[s2], B[0]))
                else:
                    f = bm.faces.new((A[s], A[s2], B[s2], B[s]))
                for loop in f.loops:
                    loop[uvl].uv = (0.5 + 0.4 * rnd.random() * 0 + 0.25 * (s / 6.0) + 0.1, 0.1 + 0.8 * (k / 4.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj("Reeds", bm, mat)
    triangulate(ob)
    finish_mesh(ob)
    return [ob]


def wrap(objs_fn, name, path, post=None, views=None, fz=0.0, **kw):
    reset()
    objs = objs_fn(**kw) if kw else objs_fn()
    bpy.context.view_layer.update()
    tris, mn, mx = total_tris(objs), None, None
    t, mn, mx = (total_tris(objs),) + tuple([[round(c, 3) for c in v] for v in (
        Vector([min(bbox(o)[0][i] for o in objs) for i in range(3)]),
        Vector([max(bbox(o)[1][i] for o in objs) for i in range(3)]))])
    log("MODEL", name, "ucgen", t, "kutu", mn, mx, "nesneler", [o.name for o in objs])
    export_glb(objs, path)
    if post:
        post(path)
    if PNG and views:
        render_views(objs, PNG, name, views, res=(800, 900), floor_z=fz)


if "hammer" in ONLY:
    wrap(build_hammer, "hammer", os.path.join(OUT_T, "hammer.glb"),
         views=[("a", (0.30, -0.45, 0.20), (0, 0, 0.08), 40)], fz=-0.095)
if "tree" in ONLY:
    wrap(build_tree, "tree_shade", os.path.join(OUT_B, "tree_shade.glb"),
         post=lambda p: patch_glb(p, alpha_mats=("Leaves",)), views=[("a", (7.0, -9.5, 3.6), (0, 0, 2.4), 40)])
if "reeds" in ONLY:
    rp = os.path.join(TMP, "reeds_atlas.png")
    reset()
    make_reed_png(rp)
    wrap(lambda: build_reeds(rp), "reeds", os.path.join(OUT_B, "reeds.glb"),
         post=lambda p: patch_glb(p, double_sided=("Reeds",)), views=[("a", (1.6, -2.4, 1.0), (0, 0, 0.75), 40)])

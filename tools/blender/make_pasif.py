"""Pasif su kaynagi ve yapi modelleri (Blender'da modellendi; yalnizca tas/tahta dokulari Poly Haven CC0, depodaki
assets/textures/canal/stone.jpg ve wood.jpg):
  fountain.glb      yigma tas cesme: arka duvar, onunde tas oluk/havuz, duvardan cikan boru; bos nesneler "Spout" (suyun ciktigi nokta)
                    ve "Basin" (havuzdaki su yuzeyi merkezi)
  grass_dew.glb     ciy otu: 0,5 m cap, ~0,35 m, uclarda acik renkli damlalar
  cloud_pole.glb    2,5 m ahsap direk, uc kolunda bez seritler ve ruzgar cani (bulut kodda eklenir)
  stream_mouth.glb  yarim daire tas dizisi ve ortada tas astarli oluk
  crack.glb         kaya yuzeyine yapisan koyu catlak (yuzey normali +Y, uzun eksen X)
  blender -b -P tools/blender/make_pasif.py -- --tex assets/textures/canal --out assets/models/build [--only fountain,dew,pole,mouth,crack] [--png-dir k] [--tmp k]
Sozlesme: metre, glb +Y yukari (Blender Z yukari, on yuz Blender -Y = glb +Z), orijin zeminde merkez, yumusak golgeleme.
"""
import json
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canal_common import *  # noqa
import numpy as np

TEX = os.path.abspath(arg("--tex", "assets/textures/canal"))
OUT = os.path.abspath(arg("--out", "assets/models/build"))
TMP = os.path.abspath(arg("--tmp", "."))
PNG = arg("--png-dir")
ONLY = arg("--only").split(",") if arg("--only") else ["fountain", "dew", "pole", "mouth", "crack"]


def patch_glb(path, double_sided=()):
    """Malzemeleri cift tarafli isaretler (ince seritler/yapraklar icin)."""
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack("<4sII", data[:12])
    clen, ctype = struct.unpack("<II", data[12:20])
    js = json.loads(data[20:20 + clen].decode("utf-8"))
    rest = data[20 + clen:]
    for m in js.get("materials", []):
        if m.get("name") in double_sided:
            m["doubleSided"] = True
    nj = json.dumps(js, separators=(",", ":")).encode("utf-8")
    nj += b" " * ((4 - len(nj) % 4) % 4)
    out = struct.pack("<4sII", magic, ver, 12 + 8 + len(nj) + len(rest)) + struct.pack("<II", len(nj), ctype) + nj + rest
    open(path, "wb").write(out)


def new_obj(name, bm, mat=None, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        set_material(ob, mat)
    triangulate(ob)
    if smooth:
        finish_mesh(ob)
    return ob


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.05
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    return e


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def stone(bm, c, size, deg=0.0, jit=0.012, bevel=0.012):
    """Hafif duzensiz, dondurulmus tas blogu (canal_common.box)."""
    s = [size[i] * (1.0 + random.uniform(-jit, jit) * 4) for i in range(3)]
    p = (c[0] + random.uniform(-jit, jit), c[1] + random.uniform(-jit, jit), c[2])
    box(bm, p, s, grain=2, rot=rz(deg + random.uniform(-2.5, 2.5)), bevel=bevel, dens=1.6)


def cyl(bm, p0, p1, r0, r1, seg=8, caps=True):
    """p0'dan p1'e kesik koni (uclari kapali), duzgun kenar halkalari."""
    a, b = Vector(p0), Vector(p1)
    ax = (b - a).normalized()
    t = ax.cross(Vector((0, 0, 1)))
    if t.length < 1e-3:
        t = Vector((1, 0, 0))
    t.normalize()
    u = ax.cross(t)
    rings = []
    for pt, r in ((a, r0), (b, r1)):
        rings.append([bm.verts.new(pt + (t * math.cos(2 * math.pi * i / seg) + u * math.sin(2 * math.pi * i / seg)) * r) for i in range(seg)])
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[1])
    return rings


def uv_all(bm, fn):
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for lp in f.loops:
            lp[uvl].uv = fn(lp.vert.co, f)


# ------------------------------------------------------------------ cesme
def build_fountain():
    random.seed(11)
    stone_mat = tex_material("Stone", os.path.join(TEX, "stone.jpg"), 0.95)
    bm = new_bm()
    # arka duvar: 4 sira, kaydirmali derz (x -0.42..0.42, y 0.05..0.37)
    H = 0.22
    for ci in range(4):
        z0 = 0.09 + ci * H
        widths = [0.28, 0.28, 0.28] if ci % 2 == 0 else [0.14, 0.28, 0.28, 0.14]
        x = -0.42
        for w in widths:
            stone(bm, (x + w / 2, 0.21, z0 + H / 2), (w - 0.012, 0.32, H - 0.012), 0)
            x += w
    # ust tas (hafif tasan)
    stone(bm, (0.0, 0.21, 0.09 + 4 * H + 0.04), (0.98, 0.44, 0.08), 0, bevel=0.016)
    # havuz tabani
    stone(bm, (0.0, -0.29, 0.04), (1.0, 0.72, 0.08), 0, jit=0.004, bevel=0.012)
    # havuz duvarlari (on ve yanlar)
    stone(bm, (-0.24, -0.62, 0.22), (0.50, 0.13, 0.28), 0)
    stone(bm, (0.26, -0.62, 0.22), (0.46, 0.13, 0.28), 0)
    for sx in (-1, 1):
        stone(bm, (sx * 0.44, -0.12, 0.22), (0.13, 0.34, 0.28), 0)
        stone(bm, (sx * 0.44, -0.44, 0.22), (0.13, 0.30, 0.28), 0)
    # on kose tasi (basamak)
    stone(bm, (0.0, -0.80, 0.04), (0.55, 0.20, 0.08), 0)
    body = new_obj("Fountain", bm, stone_mat)
    # boru: duvar onunden ileri, hafif egimli
    bm2 = new_bm()
    cyl(bm2, (0.0, 0.10, 0.76), (0.0, -0.20, 0.72), 0.045, 0.04, seg=8)
    pipe = new_obj("Pipe", bm2, color_material("PipeStone", (0.46, 0.43, 0.38), 0.9))
    spout = empty("Spout", (0.0, -0.21, 0.72))
    basin = empty("Basin", (0.0, -0.27, 0.27))
    return [body, pipe, spout, basin]


# ------------------------------------------------------------------ ciy otu
def make_dew_png(path):
    n = 128
    img = np.zeros((n, n, 4), dtype=np.float32)
    for y in range(n):
        t = y / (n - 1)
        base = np.array([0.10, 0.27, 0.07]) * (1 - t) + np.array([0.52, 0.72, 0.26]) * t
        for x in range(n):
            u = x / (n - 1)
            if u < 0.70:
                side = 1.0 - abs(u - 0.35) / 0.35
                img[y, x, :3] = base * (0.82 + 0.28 * side)
            else:
                # damla: acik mavi-beyaz, ustte parlak benek
                hl = max(0.0, 1.0 - math.hypot(u - 0.88, t - 0.7) * 9.0)
                img[y, x, :3] = np.array([0.72, 0.86, 0.95]) * (1 - hl) + np.array([1.0, 1.0, 1.0]) * hl
            img[y, x, 3] = 1.0
    im = bpy.data.images.new("dew_tex", n, n, alpha=True)
    im.pixels = img.flatten().tolist()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


def build_dew():
    rnd = random.Random(5)
    png = os.path.join(TMP, "grass_dew_atlas.png")
    make_dew_png(png)
    mat = tex_material("Dew", png, 0.6)
    mat.use_backface_culling = False
    bm = new_bm()
    uvl = bm.loops.layers.uv.verify()
    tips = []
    NB = 36
    for i in range(NB):
        a = rnd.uniform(0, 2 * math.pi)
        r = 0.20 * math.sqrt(rnd.random())
        base = Vector((r * math.cos(a), r * math.sin(a), -0.01))
        H = rnd.uniform(0.22, 0.35) * (1.0 - 0.25 * (r / 0.2))
        lean = rnd.uniform(0.04, 0.14) * (0.5 + r / 0.2)
        bend = Vector((math.cos(a + rnd.uniform(-0.4, 0.4)), math.sin(a + rnd.uniform(-0.4, 0.4)), 0))
        facing = rnd.uniform(0, math.pi)
        side = Vector((math.cos(facing), math.sin(facing), 0))
        W = rnd.uniform(0.014, 0.022)
        pts = [base + bend * (lean * t * t) + Vector((0, 0, H * t)) for t in (0.0, 0.5, 1.0)]
        rows = []
        for k, p in enumerate(pts[:-1]):
            w = W * (1.0 - 0.35 * k)
            rows.append((bm.verts.new(p - side * w), bm.verts.new(p + side * w)))
        tip = bm.verts.new(pts[-1])
        f = bm.faces.new((rows[0][0], rows[0][1], rows[1][1], rows[1][0]))
        for lp, uv in zip(f.loops, ((0.1, 0.0), (0.6, 0.0), (0.6, 0.5), (0.1, 0.5))):
            lp[uvl].uv = uv
        f = bm.faces.new((rows[1][0], rows[1][1], tip))
        for lp, uv in zip(f.loops, ((0.1, 0.5), (0.6, 0.5), (0.35, 1.0))):
            lp[uvl].uv = uv
        if rnd.random() < 0.32:
            tips.append(pts[-1] + Vector((0, 0, -0.012)) + bend * 0.004)
    # damlalar: sekiz yuzlu kucuk kureler
    for c in tips[:10]:
        rad = rnd.uniform(0.011, 0.016)
        top, bot = bm.verts.new(c + Vector((0, 0, rad))), bm.verts.new(c - Vector((0, 0, rad)))
        ring = [bm.verts.new(c + Vector((math.cos(k * math.pi / 2), math.sin(k * math.pi / 2), 0)) * rad) for k in range(4)]
        for k in range(4):
            k2 = (k + 1) % 4
            for tri in ((top, ring[k], ring[k2]), (bot, ring[k2], ring[k])):
                f = bm.faces.new(tri)
                for lp in f.loops:
                    lp[uvl].uv = (0.88, 0.7)
    return [new_obj("Dew", bm, mat)]


# ------------------------------------------------------------------ bulut diregi
def build_pole():
    random.seed(3)
    wood = tex_material("PoleWood", os.path.join(TEX, "wood.jpg"), 0.9)
    bm = new_bm()
    H = 2.38
    seg = 8
    cyl(bm, (0, 0, -0.05), (0, 0, H), 0.075, 0.048, seg=seg, caps=True)
    # uc tepe: kucuk sivri baslik
    cyl(bm, (0, 0, H), (0, 0, H + 0.10), 0.055, 0.0001, seg=seg, caps=False)
    uv_all(bm, lambda co, f: (math.atan2(co.y, co.x) / (2 * math.pi) * 0.5 + 0.5, co.z * 0.8))
    # kol (yatay, tepede) ve baglama blogu
    box(bm, (0.17, 0, H - 0.10), (0.46, 0.045, 0.045), grain=0, bevel=0.006, dens=1.2)
    box(bm, (0.0, 0, H - 0.10), (0.11, 0.11, 0.07), grain=2, bevel=0.008, dens=1.2)
    pole = new_obj("Pole", bm, wood)
    # bez seritler, iki renk
    objs = [pole]
    cols = [("ClothBlue", (0.55, 0.74, 0.88)), ("ClothCream", (0.95, 0.90, 0.78)), ("ClothBlue", (0.55, 0.74, 0.88))]
    strips = [(-0.01, 0.0, 0.50), (0.14, 0.0, 0.62), (0.28, 0.0, 0.46)]
    mats = {}
    for i, ((x, y, L), (mn, rgb)) in enumerate(zip(strips, cols)):
        bm = bmesh.new()
        top = Vector((x, y - 0.03, H - 0.125))
        sway = 0.05 * (1 if i % 2 == 0 else -1)
        W = 0.045
        prof = [(0.0, 0.0), (0.33, sway * 0.5), (0.66, sway), (1.0, sway * 0.4)]
        vs = []
        for t, sx in prof:
            p = top + Vector((sx * 0.4, sx, -L * t))
            w = W * (1.0 - 0.45 * t * t)
            vs.append((bm.verts.new(p + Vector((-w, 0, 0))), bm.verts.new(p + Vector((w, 0, 0)))))
        for k in range(3):
            bm.faces.new((vs[k][0], vs[k][1], vs[k + 1][1], vs[k + 1][0]))
        if mn not in mats:
            mats[mn] = color_material(mn, rgb, 0.95)
        objs.append(new_obj("Strip%d" % i, bm, mats[mn]))
    # ruzgar cani: kucuk koni zil + uc boru
    bm = bmesh.new()
    bx, by, bz = 0.36, 0.0, H - 0.125
    cyl(bm, (bx, by, bz), (bx, by, bz - 0.06), 0.012, 0.012, seg=6)
    cyl(bm, (bx, by, bz - 0.06), (bx, by, bz - 0.19), 0.025, 0.065, seg=8, caps=False)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        cyl(bm, (bx + 0.045 * math.cos(a), by + 0.045 * math.sin(a), bz - 0.2),
            (bx + 0.045 * math.cos(a), by + 0.045 * math.sin(a), bz - 0.2 - 0.17 - 0.03 * k), 0.008, 0.008, seg=5)
    objs.append(new_obj("Chime", bm, color_material("Brass", (0.66, 0.5, 0.2), 0.5)))
    return objs


# ------------------------------------------------------------------ dere agzi
def build_mouth():
    random.seed(21)
    stone_mat = tex_material("Stone", os.path.join(TEX, "stone.jpg"), 0.95)
    bm = new_bm()
    # yarim daire: arkada (+Y) kapali, on (-Y) acik; yaricap 0,68
    n = 9
    for k in range(n):
        ang = math.radians(15 + 150 * k / (n - 1))
        px, py = 0.68 * math.cos(ang), 0.68 * math.sin(ang)
        s = random.uniform(0.24, 0.34)
        h = random.uniform(0.16, 0.26)
        stone(bm, (px, py, h / 2 - 0.03), (s, s * 0.8, h + 0.03), math.degrees(ang) - 90, jit=0.02, bevel=0.016)
    # ikinci sira: arka kemerde daha kucuk ust tas
    for k in range(4):
        ang = math.radians(50 + 80 * k / 3)
        stone(bm, (0.64 * math.cos(ang), 0.64 * math.sin(ang), 0.29), (0.22, 0.18, 0.14), math.degrees(ang) - 90, jit=0.02, bevel=0.012)
    # oluk: iki yan tas siralari (x +-0.22), on yone (-Y)
    for sx in (-1, 1):
        for k in range(5):
            y = 0.05 - 0.2 * k
            stone(bm, (sx * 0.22, y, 0.04), (0.14, 0.2, 0.09), 0, jit=0.01, bevel=0.01)
    bm_floor = new_bm()
    box(bm_floor, (0.0, -0.40, 0.012), (0.30, 1.15, 0.024), grain=1, bevel=0.004, dens=1.6)
    body = new_obj("Mouth", bm, stone_mat)
    floor = new_obj("Gutter", bm_floor, stone_mat)
    return [body, floor]


# ------------------------------------------------------------------ catlak
def build_crack():
    rnd = random.Random(9)
    n = 15
    pts = []
    for i in range(n):
        t = i / (n - 1)
        x = -0.26 + 0.52 * t
        y = 0.035 * math.sin(t * 9.0) + rnd.uniform(-0.012, 0.012)
        pts.append((x, y))
    bm = bmesh.new()

    def strip(points, wmax, depth):
        m = len(points)
        rows = []
        for i, (x, y) in enumerate(points):
            t = i / (m - 1)
            w = wmax * math.sin(math.pi * t) ** 0.7 * (0.75 + 0.25 * rnd.random())
            w = max(w, 0.0005)
            d = depth * math.sin(math.pi * t) ** 0.7
            rows.append((bm.verts.new((x, y - w, 0.003)), bm.verts.new((x, y, -d)), bm.verts.new((x, y + w, 0.003))))
        for i in range(m - 1):
            for k in range(2):
                bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
    strip(pts, 0.026, 0.03)
    b1 = [(pts[5][0] + 0.18 * t, pts[5][1] + 0.12 * t * (1 + 0.3 * math.sin(t * 6))) for t in [i / 5 for i in range(6)]]
    b2 = [(pts[10][0] + 0.12 * t, pts[10][1] - 0.10 * t * (1 + 0.4 * math.sin(t * 5))) for t in [i / 4 for i in range(5)]]
    strip(b1, 0.012, 0.02)
    strip(b2, 0.010, 0.016)
    mat = color_material("CrackDark", (0.05, 0.04, 0.035), 1.0)
    return [new_obj("Crack", bm, mat)]


def wrap(fn, name, post=None, views=None, fz=0.0, **kw):
    reset()
    objs = fn()
    bpy.context.view_layer.update()
    meshes = [o for o in objs if o.type == "MESH"]
    t = total_tris(meshes)
    mn = Vector([min(bbox(o)[0][i] for o in meshes) for i in range(3)])
    mx = Vector([max(bbox(o)[1][i] for o in meshes) for i in range(3)])
    log("MODEL", name, "ucgen", t, "kutu", [round(c, 3) for c in mn], [round(c, 3) for c in mx], "nesneler", [o.name for o in objs])
    export_glb(objs, os.path.join(OUT, name + ".glb"))
    if post:
        post(os.path.join(OUT, name + ".glb"))
    if PNG and views:
        render_views(meshes, PNG, name, views, res=(700, 700), floor_z=fz)


if "fountain" in ONLY:
    wrap(build_fountain, "fountain", views=[("a", (1.6, -2.2, 1.3), (0, -0.2, 0.45), 40), ("b", (-1.8, 1.6, 1.6), (0, -0.1, 0.4), 40)])
if "dew" in ONLY:
    wrap(build_dew, "grass_dew", post=lambda p: patch_glb(p, double_sided=("Dew",)), views=[("a", (0.7, -0.9, 0.55), (0, 0, 0.15), 40)])
if "pole" in ONLY:
    wrap(build_pole, "cloud_pole", post=lambda p: patch_glb(p, double_sided=("ClothBlue", "ClothCream")),
         views=[("a", (2.2, -3.0, 2.0), (0, 0, 1.3), 40), ("b", (0.9, -1.1, 2.4), (0.1, 0, 2.2), 35)])
if "mouth" in ONLY:
    wrap(build_mouth, "stream_mouth", views=[("a", (1.6, -2.4, 1.4), (0, -0.1, 0.1), 40)])
if "crack" in ONLY:
    wrap(build_crack, "crack", views=[("a", (0.0, -0.1, 0.9), (0, 0, 0), 35)])
